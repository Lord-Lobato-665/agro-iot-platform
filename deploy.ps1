# Deploy the whole project with a single command.
# Usage: .\deploy.ps1    (run from repository root in PowerShell)
# Optional: .\deploy.ps1 -Force  (recreate services/.env from example)

param(
    [switch]$Force
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
$proc = Start-Process -FilePath docker -ArgumentList "compose -f `"$composeFile`" --project-directory `"$servicesDir`" up -d --build" -NoNewWindow -Wait -PassThru
if ($proc.ExitCode -ne 0) {
    Write-Error "docker compose failed with exit code $($proc.ExitCode)"
    exit $proc.ExitCode
}

Write-Host "Compose finished. Current service status:"
& docker compose -f "$composeFile" --project-directory "$servicesDir" ps

Write-Host "To follow logs run:\n  docker compose -f `"$composeFile`" --project-directory `"$servicesDir`" logs -f"

Write-Host "Deployment complete."
exit 0
