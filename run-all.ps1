<#
Run-all convenience script
Usage:
  # Full flow: deploy (with managed DBs), wait for gateway, run tests
  .\run-all.ps1

  # Dry-run / safe: skip deploy and tests (useful for CI linting of script)
  .\run-all.ps1 -SkipDeploy -SkipTests

Options:
  -SkipDeploy    Skip calling deploy.ps1 (useful for local testing)
  -SkipTests     Skip running the tests runner
  -WaitTimeout   Seconds to wait for gateway to become ready (default 120)
  -RetryInterval Seconds between readiness checks (default 5)
#>
param(
    [switch]$SkipDeploy,
    [switch]$SkipTests,
    [int]$WaitTimeout = 120,
    [int]$RetryInterval = 5
)

$ErrorActionPreference = 'Stop'
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

# Detect preferred PowerShell executable (pwsh if available, otherwise fallback to powershell)
if (Get-Command pwsh -ErrorAction SilentlyContinue) {
    $global:PreferredShell = 'pwsh'
} elseif (Get-Command powershell -ErrorAction SilentlyContinue) {
    $global:PreferredShell = 'powershell'
} else {
    throw 'No PowerShell executable found (pwsh or powershell) in PATH.'
}

function Write-Log {
    param([string]$Message)
    $ts = (Get-Date).ToString('s')
    Write-Host "[$ts] $Message"
}

function Invoke-Deploy {
    param([switch]$ManagedDb)
    $deployPath = Join-Path $scriptRoot 'deploy.ps1'
    if (-not (Test-Path $deployPath)) { throw "deploy.ps1 not found at $deployPath" }
    $args = @()
    if ($ManagedDb) { $args += '-ManagedDb' }
    # Avoid forcing overwrite of services/.env unless user explicitly wants -Force; keep current behaviour
    Write-Log "Invoking deploy.ps1 $($args -join ' ')"
    $proc = Start-Process -FilePath $global:PreferredShell -ArgumentList ('-NoProfile','-ExecutionPolicy','Bypass','-File', $deployPath) -Wait -PassThru -NoNewWindow
    if ($proc.ExitCode -ne 0) { throw "deploy.ps1 exited with code $($proc.ExitCode)" }
}

function Wait-For-Gateway {
    param(
        [string]$Url = 'http://localhost:5172',
        [int]$TimeoutSec = 120,
        [int]$IntervalSec = 5
    )
    $deadline = (Get-Date).AddSeconds($TimeoutSec)
    Write-Log "Waiting for gateway at $Url (timeout ${TimeoutSec}s)"
    while ((Get-Date) -lt $deadline) {
        try {
            # -UseBasicParsing is not supported in PowerShell Core (pwsh); omit it so the function works with both
            $resp = Invoke-WebRequest -Uri $Url -TimeoutSec 5 -ErrorAction Stop
            if ($resp.StatusCode -ge 200 -and $resp.StatusCode -lt 500) {
                Write-Log "Gateway responded with HTTP $($resp.StatusCode)"
                return $true
            }
        } catch {
            # swallow and retry
        }
        Start-Sleep -Seconds $IntervalSec
    }
    Write-Log "Gateway did not become ready within timeout"
    return $false
}

function Run-Tests {
    $runner = Join-Path $scriptRoot 'services\api-services\scripts\run-tests.ps1'
    if (-not (Test-Path $runner)) { throw "Test runner not found at $runner" }
    Write-Log "Running tests: $runner"
    $proc = Start-Process -FilePath $global:PreferredShell -ArgumentList ('-NoProfile','-ExecutionPolicy','Bypass','-File', $runner) -Wait -PassThru -NoNewWindow
    return $proc.ExitCode
}

try {
    Write-Log "run-all started (SkipDeploy=$SkipDeploy, SkipTests=$SkipTests)"

    if (-not $SkipDeploy) {
        # Call deploy in a child pwsh so the main env isn't modified
        # Pass ManagedDb by default because project expects managed DBs for tests
        Invoke-Deploy -ManagedDb
    } else {
        Write-Log "Skipping deploy (per -SkipDeploy)"
    }

    # Wait for gateway to respond (best-effort). If it times out we still attempt tests but warn.
    $ready = Wait-For-Gateway -Url 'http://localhost:5172' -TimeoutSec $WaitTimeout -IntervalSec $RetryInterval
    if (-not $ready) { Write-Log "Warning: gateway did not report ready; tests may fail." }

    if (-not $SkipTests) {
        $rc = Run-Tests
        if ($rc -ne 0) {
            Write-Log "Test runner exited with code $rc"
            exit $rc
        }
    } else {
        Write-Log "Skipping tests (per -SkipTests)"
    }

    Write-Log "run-all completed successfully"
    exit 0
} catch {
    Write-Error "run-all failed: $($_.Exception.Message)"
    exit 1
}
