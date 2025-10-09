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

# Ensure .env.example exists but DO NOT overwrite real .env files.
if (Test-Path $envFile) {
    Write-Host ".env already exists in services; using existing file. Deploy will NOT overwrite it."
} else {
    if (Test-Path $envExample) {
        Write-Warning "No services/.env found. I will NOT create or overwrite your production/dev .env.\nPlease copy `services/.env.example` to `services/.env` and fill in credentials (eg SA_PASSWORD, SQL_CONN_STR) before running deploy."
        Write-Host "Example file available at: $envExample"
        exit 1
    } else {
        Write-Host "No .env.example found in services. Creating a minimal `services/.env.example` with placeholder keys."
        $exampleContent = @'
# Example environment variables for services
# Copy this to .env and update values before running deploy.ps1

# SQL Server sa password (choose a strong password per-developer)
# Example: SA_PASSWORD=YourStrongP@ssw0rd
SA_PASSWORD=REPLACE_WITH_STRONG_PASSWORD

# Node ingestion service (edit per-developer if needed)
PORT=3001
# If you use the managed Docker DBs set this to: mongodb://mongo:27017/agro-iot-platform
MONGO_URI=mongodb://mongo:27017/agro-iot-platform

# SQL connection string used by the .NET services at runtime. For Docker-managed SQL Server:
SQL_CONN_STR=Server=sqlserver;Database=AgroIoT_Parcelas;User Id=sa;Password=REPLACE_WITH_STRONG_PASSWORD;TrustServerCertificate=True;
'@
        Set-Content -Path $envExample -Value $exampleContent -Force
        Write-Host "Created: $envExample. Please copy it to services/.env and fill the placeholders before rerunning deploy." 
        exit 1
    }
}

# Ensure api-services .env.example exists (do not create real api-services/.env)
$apiEnvExample = Join-Path $servicesDir 'api-services\.env.example'
if (-not (Test-Path $apiEnvExample)) {
    $apiExample = @'
# api-services .env.example
PORT=3001
# MONGO_URI when using docker-managed mongo
MONGO_URI=mongodb://mongo:27017/agro-iot-platform
'@
    New-Item -Path $apiEnvExample -ItemType File -Force | Out-Null
    Set-Content -Path $apiEnvExample -Value $apiExample -Force
    Write-Host "Created: $apiEnvExample"
}

# Run docker compose (uses services directory as project dir so compose reads services/.env automatically)
Write-Host "Building and starting containers (this may take a while)..."

function Invoke-DockerCompose {
    param(
        [string[]]$ArgumentList
    )
    Write-Host "docker $($ArgumentList -join ' ')"
    # Use Start-Process to capture the exit code reliably and stream output to the current console
    $proc = Start-Process -FilePath docker -ArgumentList $ArgumentList -NoNewWindow -Wait -PassThru
    return $proc.ExitCode
}

    if ($ManagedDb) {
        # Ensure compose picks up managed-db services by setting COMPOSE_PROFILES
        $origComposeProfiles = $env:COMPOSE_PROFILES
        $env:COMPOSE_PROFILES = 'managed-db'
        try {
            $composeArgs = @('compose', '-f', $composeFile, '--project-directory', $servicesDir, 'up', '-d', '--build')
            Write-Host "Running docker compose with COMPOSE_PROFILES=managed-db"
            $rc = Invoke-DockerCompose -ArgumentList $composeArgs
        } finally {
            if ($null -ne $origComposeProfiles) { $env:COMPOSE_PROFILES = $origComposeProfiles } else { Remove-Item Env:COMPOSE_PROFILES -ErrorAction SilentlyContinue }
        }
        if ($rc -ne 0) {
            Write-Error "docker compose failed with exit code $rc"
            exit $rc
        }
    } else {
        $composeArgs = @('compose', '-f', $composeFile, '--project-directory', $servicesDir, 'up', '-d', '--build')
        $rc = Invoke-DockerCompose -ArgumentList $composeArgs
        if ($rc -ne 0) {
            Write-Error "docker compose failed with exit code $rc"
            exit $rc
        }
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
            [string]$SaPassword
        )
        if (-not $SaPassword) { Write-Warning "SA_PASSWORD not set; skipping wait-for-sql"; return }
        for ($i=0; $i -lt $Retries; $i++) {
            Write-Host "Checking SQL Server readiness (attempt $($i+1)/$Retries)..."
            # Try original password first, then try stripped variant if it fails (handle trailing brace issues)
            $attempts = @($SaPassword)
            if ($SaPassword -and $SaPassword.EndsWith('}')) { $attempts += $SaPassword.TrimEnd('}') }
            $ok = $false
            foreach ($pw in $attempts) {
                $dockerArgs = @('run','--rm','--network',$Network,'mcr.microsoft.com/mssql-tools','/opt/mssql-tools/bin/sqlcmd','-S','sqlserver','-U','sa','-P',$pw,'-Q','SELECT 1')
                & docker @dockerArgs 2>&1 | Out-Null
                if ($LASTEXITCODE -eq 0) { $ok = $true; break }
            }
            if ($ok) { Write-Host "SQL Server is ready"; return $true }
            Start-Sleep -Seconds $DelaySec
        }
        Write-Warning "SQL Server did not become ready after $Retries attempts"
        return $false
    }

    # Require an existing services/.env for non-destructive deploy
    $envFilePath = Join-Path $servicesDir '.env'
    if (-not (Test-Path $envFilePath)) {
        Write-Warning "services/.env not found. EF migrations will not run. Create services/.env from services/.env.example first and re-run deploy."
    } else {
    $saPassword = (Get-Content $envFilePath | Select-String '^SA_PASSWORD=' | ForEach-Object { $_.ToString().Split('=')[1].Trim() })
        if ($ManagedDb) { Wait-For-Sql -Network $networkName -SaPassword $saPassword }

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
        # Pass services/.env into the container with --env-file so ConnectionStrings and SA_PASSWORD are available and correctly escaped.
        # Create a small shell script to run inside the SDK container. This avoids complex quoting issues.
        $efScriptPath = Join-Path $servicesDir '.ef-run.sh'
        $scriptLines = @()
        $scriptLines += '#!/bin/sh'
        $scriptLines += 'export PATH="$PATH:/root/.dotnet/tools"'
        $scriptLines += 'dotnet tool install --global dotnet-ef --version 8.* || true'
        $scriptLines += 'cd /src'
        $scriptLines += $efCmd
        # Write script file with LF line endings (avoid CRLF issues inside linux containers).
        # Use UTF8 without BOM to prevent '/tmp/ef-run.sh: 1: #!/bin/sh: not found' inside busybox sh.
        $scriptContent = $scriptLines -join "`n"
        $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllText($efScriptPath, $scriptContent, $utf8NoBom)

        # Create a temporary env file that maps SQL_CONN_STR -> ConnectionStrings__DefaultConnection
        $efEnvPath = Join-Path $servicesDir '.ef.env'
        $sqlLine = (Get-Content $envFilePath | Select-String '^SQL_CONN_STR=' | ForEach-Object { $_.ToString() })
        if ($sqlLine) {
            $sqlVal = $sqlLine -replace '^SQL_CONN_STR=',''
            $sqlVal = $sqlVal.Trim()
            Set-Content -Path $efEnvPath -Value ("ConnectionStrings__DefaultConnection=$sqlVal") -Force
        } else {
            # Fallback: if SQL_CONN_STR not present, don't create ef env - migrations will likely fail but continue to allow manual debug
            Remove-Item -Path $efEnvPath -ErrorAction SilentlyContinue
        }

        # Build docker run arguments. Include services/.env and the temporary ef.env if present.
        $runArgs = @('run','--rm')
        if (Test-Path $envFilePath) { $runArgs += @('--env-file', $envFilePath) }
        if (Test-Path $efEnvPath) { $runArgs += @('--env-file', $efEnvPath) }
        $runArgs += @('-v', ($agroSrc + ':/src'))
        $runArgs += @('-v', ($efScriptPath + ':/tmp/ef-run.sh:ro'))
        $runArgs += @('--network', $networkName)
        $runArgs += @('mcr.microsoft.com/dotnet/sdk:8.0','sh','/tmp/ef-run.sh')

        $procEf = Start-Process -FilePath docker -ArgumentList $runArgs -NoNewWindow -Wait -PassThru
        # cleanup script and temp env file
        Remove-Item -Path $efScriptPath -ErrorAction SilentlyContinue
        Remove-Item -Path $efEnvPath -ErrorAction SilentlyContinue
    if ($procEf.ExitCode -ne 0) {
        Write-Warning "EF commands exited with code $($procEf.ExitCode). Check logs for details."
    } else {
        Write-Host "EF migrations applied successfully."
    }
    }
} catch {
    Write-Warning "Failed to run EF migrations: $($_.Exception.Message)"
}

Write-Host "Compose finished. Current service status:"
& docker compose -f "$composeFile" --project-directory "$servicesDir" ps

Write-Host "To follow logs run:\n  docker compose -f `"$composeFile`" --project-directory `"$servicesDir`" logs -f"

Write-Host "Deployment complete."
exit 0
