<#
run-kubernetes-all.ps1
Creates a per-dev kind cluster, deploys the app, runs migrations and runs the test suite against the in-cluster gateway.

Usage:
  .\run-kubernetes-all.ps1 -DevPrefix alice

Options:
  -DevPrefix    Required. Short id for your dev namespace/cluster.
  -SaPassword   Optional. SQL SA password to seed in the k8s secret (default placeholder)
  -SkipBuild    Skip docker image build step
  -SkipTests    Skip running the run-tests.ps1 after deployment
#>
param(
  [Parameter(Mandatory=$true)][string]$DevPrefix,
  [string]$SaPassword = 'REPLACE_WITH_STRONG_PASSWORD',
  [switch]$SkipBuild,
  [switch]$SkipTests,
  [switch]$AutoInstallKind,
  [int]$NodeCount = 1
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$ns = "dev-$DevPrefix"

function Exec { param($cmd) Write-Host "> $cmd"; iex $cmd }

# 1. Create per-dev cluster and namespace + secrets
$autoInstallArg = ''
if ($AutoInstallKind) { $autoInstallArg = ' -AutoInstallKind' }
Exec "powershell -NoProfile -ExecutionPolicy Bypass -File $root\create-kind-dev.ps1 -DevPrefix $DevPrefix -SaPassword '$SaPassword' $autoInstallArg -NodeCount $NodeCount" 

# 2. Deploy into the dev namespace
Exec "powershell -NoProfile -ExecutionPolicy Bypass -File $root\deploy-k8s.ps1 -Namespace $ns"

# 3. Port-forward gateway service to localhost:5172 in background
Write-Host "Port-forwarding gateway (svc/agroapi-gateway) to localhost:5172"
$pf = Start-Process -FilePath kubectl -ArgumentList @('port-forward','-n',$ns,'svc/agroapi-gateway','5172:8080') -NoNewWindow -PassThru
Start-Sleep -Seconds 2

# 4. Run tests against http://localhost:5172
if (-not $SkipTests) {
    Exec "powershell -NoProfile -ExecutionPolicy Bypass -File $root\services\api-services\scripts\run-tests.ps1"
} else { Write-Host "Skipping tests per -SkipTests" }

Write-Host "run-kubernetes-all completed. To stop port-forward: stop-process -id $($pf.Id)" 
