param(
  [Parameter(Mandatory = $true)][string]$DevPrefix,
  [switch]$AutoInstallKind,
  [int]$NodeCount = 1,
  [switch]$SkipBuild,               # pasa a create-kind-dev.ps1 (evita rebuild)
  [string]$EnvPath,                 # si quieres forzar services/.env u otro
  [string]$ManifestsPath = (Join-Path $PSScriptRoot 'k8s'),
  [string]$ImagesPrefix,            # si vas a subir a registro y tirar del cluster
  [switch]$UseLocalImages,          # usa imágenes locales (kind load) con tag :latest
  [int]$WaitTimeoutSec = 180,
  [switch]$PortForwardGateway
)

$ErrorActionPreference = 'Stop'
function Run { param($cmd) Write-Host ">> $cmd"; iex $cmd }

$root = $PSScriptRoot

# 1) Crear/asegurar cluster + namespace + secrets
$create = Join-Path $root 'create-kind-dev.ps1'
if (-not (Test-Path $create)) { throw "No se encontró create-kind-dev.ps1 en $root" }

$createArgs = @(
  "-DevPrefix `"$DevPrefix`""
  ($SkipBuild         ? "-SkipBuild" : $null)
  ($AutoInstallKind   ? "-AutoInstallKind" : $null)
  ("-NodeCount $NodeCount")
  ($EnvPath           ? "-EnvPath `"$EnvPath`"" : $null)
) | Where-Object { $_ }
Run ("`"$create`" {0}" -f ($createArgs -join ' '))

# 2) Deploy k8s manifests + rollouts + (opcional) port-forward
$deploy = Join-Path $root 'deploy-k8s.ps1'
if (-not (Test-Path $deploy)) { throw "No se encontró deploy-k8s.ps1 en $root" }

$deployArgs = @(
  "-DevPrefix `"$DevPrefix`""
  ("-ManifestsPath `"$ManifestsPath`"")
  ("-WaitTimeoutSec $WaitTimeoutSec")
  ($UseLocalImages   ? "-UseLocalImages" : $null)
  ($ImagesPrefix     ? "-ImagesPrefix `"$ImagesPrefix`"" : $null)
  ($PortForwardGateway ? "-PortForwardGateway" : $null)
) | Where-Object { $_ }
Run ("`"$deploy`" {0}" -f ($deployArgs -join ' '))

Write-Host "Todo listo 🚀"
