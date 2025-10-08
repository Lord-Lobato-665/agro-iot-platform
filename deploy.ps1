# Deploy the whole project with a single command.
# Usage: .\deploy.ps1    (run from repository root in PowerShell)
# Optional: .\deploy.ps1 -Force  (recreate services/.env from example)

param(
    [switch]$Force,
    [switch]$ManagedDb
)

$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$servicesDir = Join-Path $scriptDir 'services'
$composeFile = Join-Path $servicesDir 'docker-compose.yml'
$envExample = Join-Path $servicesDir '.env.example'
$envFile = Join-Path $servicesDir '.env'

Write-Host "Deploy script running from: $scriptDir"

# Check Docker availability
try {
    docker version > $null 2>&1
} catch {
    Write-Error "Docker is not available in PATH or not running. Please install/start Docker Desktop and try again."
    exit 1
}

# Ensure docker-compose file exists
if (-not (Test-Path $composeFile)) {
    Write-Error "Compose file not found: $composeFile"
    exit 1
}

# Create .env from example if missing (safe default)
if ((Test-Path $envFile) -and (-not $Force)) {
    Write-Host ".env already exists in services; using existing file. (use -Force to overwrite)"
} elseif (Test-Path $envExample) {
    Copy-Item -Path $envExample -Destination $envFile -Force
    Write-Host "Created $envFile from example. Edit it to set real secrets before re-running if needed."
} else {
    Write-Warning "No .env.example found in services. Proceeding without a .env file."
}

# Run docker compose (uses services directory as project dir so compose reads services/.env automatically)
Write-Host "Building and starting containers (this may take a while)..."
$composeArgs = "compose -f `"$composeFile`" --project-directory `"$servicesDir`" up -d --build"
if ($ManagedDb) { $composeArgs += ' --profile managed-db' }
$proc = Start-Process -FilePath docker -ArgumentList $composeArgs -NoNewWindow -Wait -PassThru
if ($proc.ExitCode -ne 0) {
    Write-Error "docker compose failed with exit code $($proc.ExitCode)"
    exit $proc.ExitCode
}

## Run Entity Framework migrations from an SDK container attached to the compose network
try {
    $projectName = Split-Path -Leaf $servicesDir
    $networkName = "$($projectName)_default"
    $agroSrc = Join-Path $servicesDir 'AgroService'

    Write-Host "Running EF migrations using SDK container on network: $networkName"

    # Wait for SQL Server to be ready (if managed-db was requested)
    function Wait-For-Sql {
        param(
            [string]$Network,
            [int]$Retries = 20,
            [int]$DelaySec = 5,
            [string]$SaPassword = $env:SA_PASSWORD
        )
        if (-not $SaPassword) { Write-Warning "SA_PASSWORD not set; skipping wait-for-sql"; return }
        for ($i=0; $i -lt $Retries; $i++) {
            Write-Host "Checking SQL Server readiness (attempt $($i+1)/$Retries)..."
            $check = docker run --rm --network $Network mcr.microsoft.com/mssql-tools sh -c "/opt/mssql-tools/bin/sqlcmd -S sqlserver -U sa -P '$SaPassword' -Q \"SELECT 1\"" 2>&1
            if ($LASTEXITCODE -eq 0) { Write-Host "SQL Server is ready"; return $true }
            Start-Sleep -Seconds $DelaySec
        }
        Write-Warning "SQL Server did not become ready after $Retries attempts"
        return $false
    }

    if ($ManagedDb) { Wait-For-Sql -Network $networkName -SaPassword (Get-Content (Join-Path $servicesDir '.env') | Select-String '^SA_PASSWORD=' -SimpleMatch | ForEach-Object { $_.ToString().Split('=')[1].Trim() }) }

    # Only add migration if it does not already exist
    $migrationsPath = Join-Path $agroSrc 'AgroAPI.Infrastructure/Migrations'
    $needAdd = $true
    if (Test-Path $migrationsPath) {
        $exists = Get-ChildItem -Path $migrationsPath -Filter '*AddSoftDeleteToUsuario*' -Recurse -ErrorAction SilentlyContinue
        if ($exists) { $needAdd = $false; Write-Host "Migration AddSoftDeleteToUsuario already exists; skipping 'dotnet ef migrations add'" }
    }

    $efCmd = @()
    if ($needAdd) { $efCmd += 'dotnet ef migrations add AddSoftDeleteToUsuario --project AgroAPI.Infrastructure --startup-project AgroAPI.API' }
    $efCmd += 'dotnet ef database update --project AgroAPI.Infrastructure --startup-project AgroAPI.API'
    $efCmd = $efCmd -join ' && '

    # Run the SDK image, mount the AgroService source and attach to compose network so it can reach sqlserver by service name
    $runArgs = @(
        'run', '--rm',
        '-v', ($agroSrc + ':/src'),
        '-w', '/src',
        '--network', $networkName,
        'mcr.microsoft.com/dotnet/sdk:8.0', 'sh', '-c', $efCmd
    )

    $procEf = Start-Process -FilePath docker -ArgumentList $runArgs -NoNewWindow -Wait -PassThru
    if ($procEf.ExitCode -ne 0) {
        Write-Warning "EF commands exited with code $($procEf.ExitCode). Check logs for details."
    } else {
        Write-Host "EF migrations applied successfully."
    }
} catch {
    Write-Warning "Failed to run EF migrations: $($_.Exception.Message)"
}

Write-Host "Compose finished. Current service status:"
& docker compose -f "$composeFile" --project-directory "$servicesDir" ps

Write-Host "To follow logs run:\n  docker compose -f `"$composeFile`" --project-directory `"$servicesDir`" logs -f"

Write-Host "Deployment complete."
exit 0
