param(
  [Parameter(Mandatory = $true)][string]$DevPrefix,
  [string]$KubeContext,
  [string]$Namespace,
  [string]$ManifestsPath = (Join-Path $PSScriptRoot 'k8s'),
  [string]$ImagesPrefix,              # p.ej. 'ghcr.io/tu-org/'  (vacío = usa imágenes locales)
  [switch]$UseLocalImages,            # si usas imágenes locales cargadas a kind (services-*:latest)
  [int]$WaitTimeoutSec = 180,
  [switch]$PortForwardGateway         # crea port-forward al gateway si lo encuentra
)

$ErrorActionPreference = 'Stop'
function Run { param($cmd) Write-Host ">> $cmd"; iex $cmd }

# Contexto/namespace por defecto en entorno Kind per-dev
if (-not $KubeContext) { $KubeContext = "kind-kind-$('kind-' + $DevPrefix)" }  # => kind-kind-<DevPrefix>
if (-not $Namespace)   { $Namespace   = "dev-$DevPrefix" }

# Validaciones mínimas
if (-not (Get-Command kubectl -ErrorAction SilentlyContinue)) {
  throw "kubectl no está disponible en PATH."
}
$contexts = & kubectl config get-contexts -o name 2>$null
if (-not ($contexts -contains $KubeContext)) {
  throw "El contexto '$KubeContext' no existe. Usa: kubectl config get-contexts"
}

# Crear/asegurar namespace
Run ("kubectl create namespace {0} --context {1} --dry-run=client -o yaml | kubectl apply -f -" -f $Namespace, $KubeContext)

# Aplicar manifests (kustomize si hay kustomization.yaml, si no aplica recursivo -f)
$kustom = Join-Path $ManifestsPath 'kustomization.yaml'
if (Test-Path $kustom) {
  Run ("kubectl apply -k ""{0}"" --namespace {1} --context {2}" -f $ManifestsPath, $Namespace, $KubeContext)
} else {
  Run ("kubectl apply -f ""{0}"" --recursive --namespace {1} --context {2}" -f $ManifestsPath, $Namespace, $KubeContext)
}

# --- Ajuste de imágenes para dev ---
# Mapeo esperado de contenedor -> imagen local construida
$containerToLocalImage = @{
  # nombra tus contenedores EXACTAMENTE como en los manifests de k8s
  'api-services'     = 'services-api-services:latest'
  'agroapi-api'      = 'services-agroapi-api:latest'
  'agroapi-gateway'  = 'services-agroapi-gateway:latest'
}

# Si se usa prefijo de registro, construimos imagen como <prefix><nombre>:latest
$containerToPrefixedImage = @{}
if ($ImagesPrefix) {
  $containerToPrefixedImage['api-services']    = ($ImagesPrefix.TrimEnd('/') + '/services-api-services:latest')
  $containerToPrefixedImage['agroapi-api']     = ($ImagesPrefix.TrimEnd('/') + '/services-agroapi-api:latest')
  $containerToPrefixedImage['agroapi-gateway'] = ($ImagesPrefix.TrimEnd('/') + '/services-agroapi-gateway:latest')
}

if ($UseLocalImages -or $ImagesPrefix) {
  # Enumerar deployments y setear imagen contenedor por contenedor
  $deploys = & kubectl -n $Namespace --context $KubeContext get deploy -o json | ConvertFrom-Json
  foreach ($d in $deploys.items) {
    $depName = $d.metadata.name
    foreach ($c in $d.spec.template.spec.containers) {
      $cname = $c.name
      $newImg = $null
      if ($ImagesPrefix -and $containerToPrefixedImage.ContainsKey($cname)) {
        $newImg = $containerToPrefixedImage[$cname]
      } elseif ($UseLocalImages -and $containerToLocalImage.ContainsKey($cname)) {
        $newImg = $containerToLocalImage[$cname]
      }
      if ($newImg) {
        Run ("kubectl -n {0} --context {1} set image deploy/{2} {3}={4}" -f $Namespace, $KubeContext, $depName, $cname, $newImg)
      }
    }
  }
}

# Esperar rollouts
$deployList = (& kubectl -n $Namespace --context $KubeContext get deploy -o name 2>$null)
foreach ($dep in $deployList) {
  Run ("kubectl -n {0} --context {1} rollout status {2} --timeout={3}s" -f $Namespace, $KubeContext, $dep, $WaitTimeoutSec)
}

# Mostrar estado básico
Run ("kubectl -n {0} --context {1} get pods,svc" -f $Namespace, $KubeContext)

# (Opcional) Port-forward al gateway si hay un Service apropiado
if ($PortForwardGateway) {
  # Heurística: busca svc por nombre o puerto 5172
  $svcs = & kubectl -n $Namespace --context $KubeContext get svc -o json | ConvertFrom-Json
  $gw = $svcs.items | Where-Object {
    $_.metadata.name -match 'gateway' -or ($_.spec.ports | Where-Object { $_.port -eq 5172 })
  } | Select-Object -First 1

  if ($gw) {
    $svcName = $gw.metadata.name
    Write-Host "Haciendo port-forward de $svcName 5172:5172 (Ctrl+C para cortar) ..."
    # No uses Run aquí para no encapsular el proceso (permite Ctrl+C)
    kubectl -n $Namespace --context $KubeContext port-forward svc/$svcName 5172:5172
  } else {
    Write-Host "No se encontró Service del gateway para port-forward. Revisa nombres/puertos en tus manifests."
  }
}

Write-Host "Deploy listo en namespace $Namespace, contexto $KubeContext."
