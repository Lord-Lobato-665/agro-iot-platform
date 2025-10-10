<#
deploy-k8s.ps1
Automates deploying the repo's Kubernetes manifests to a local cluster (minikube, kind, or Docker Desktop kubernetes).

Usage:
  # dry run (no changes)
  .\deploy-k8s.ps1 -DryRun

  # full flow: build images, load into cluster, apply manifests, run migrations, run smoke tests
  .\deploy-k8s.ps1

Options:
  -NoBuild         Skip building Docker images (useful if already built)
  -SkipMigrations  Don't run EF migrations in-cluster
  -DryRun          Only validate prerequisites and print actions (no docker/kubectl calls)
  -ImagesPrefix    Optional prefix for image names (default uses the tags in k8s/ manifests)
#>
param(
    [switch]$NoBuild,
    [switch]$SkipMigrations,
    [switch]$DryRun,
    [string]$ImagesPrefix = '',
    [string]$Namespace = 'agro-iot'
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Write-Host "deploy-k8s: root=$root"

function Run { param($cmd) Write-Host "=> $cmd"; if (-not $DryRun) { iex $cmd } }

function Check-CommandExists {
    param($name)
    $c = Get-Command $name -ErrorAction SilentlyContinue
    return $null -ne $c
}

# 1. prerequisites
if (-not (Check-CommandExists 'kubectl')) { throw 'kubectl not found in PATH. Install kubectl before running this script.' }
if (-not (Check-CommandExists 'docker')) { throw 'docker not found in PATH. Install Docker before running this script.' }

# detect cluster provider (minikube / kind / docker-desktop)
$clusterType = 'docker-desktop'
try {
    if (Check-CommandExists 'minikube') {
        $minikubeStatus = & minikube status 2>$null | Out-String
        if ($minikubeStatus -match 'host: Running') { $clusterType = 'minikube' }
    }
} catch {}
try {
    if (Check-CommandExists 'kind') {
        $nodes = kubectl get nodes -o jsonpath='{.items[0].metadata.name}' 2>$null
        if ($nodes -and $nodes -match 'kind-') { $clusterType = 'kind' }
    }
} catch {}
Write-Host "Detected cluster type: $clusterType"

# Verify kubectl can talk to a cluster (fail fast with actionable instructions)
try {
    $clusterInfo = & kubectl cluster-info 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) { throw $clusterInfo }
} catch {
    Write-Host "ERROR: kubectl cannot connect to a Kubernetes cluster or the API server is not reachable." -ForegroundColor Red
    Write-Host "kubectl output:" -ForegroundColor Yellow
    Write-Host $_ -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Common fixes:" -ForegroundColor Cyan
    Write-Host " - If you use Docker Desktop: enable 'Kubernetes' in Docker Desktop Settings and wait until it's running." -ForegroundColor Cyan
    Write-Host " - If you use minikube: run 'minikube start' and ensure 'minikube status' reports Running." -ForegroundColor Cyan
    Write-Host " - If you use kind: create a cluster with 'kind create cluster' or set KUBECONFIG to a reachable cluster." -ForegroundColor Cyan
    Write-Host " - Verify with: kubectl cluster-info or kubectl get nodes" -ForegroundColor Cyan
    Write-Host ""
    throw "kubectl not connected to a cluster. Aborting deploy-k8s." 
}

# image names (as used in k8s/ manifests). If ImagesPrefix provided, prepend it.
$images = @(
    @{ name='services-api-services:latest'; path='services/api-services'; dockerfile='services/api-services/Dockerfile' },
    @{ name='services-agroapi-api:latest'; path='services/AgroService'; dockerfile='services/AgroService/AgroAPI.API/Dockerfile' },
    @{ name='services-agroapi-gateway:latest'; path='services/AgroService'; dockerfile='services/AgroService/AgroAPI.Gateway/Dockerfile' }
)

if ($ImagesPrefix -ne '') {
    foreach ($img in $images) { $img.name = "$ImagesPrefix/$($img.name)" }
}

# 2. build images
if (-not $NoBuild) {
    foreach ($img in $images) {
        $buildCmd = "docker build -t $($img.name) -f $($root)\$($img.dockerfile) $($root)\$($img.path)"
        Run $buildCmd
    }
} else { Write-Host "Skipping image build (-NoBuild)" }

# 3. load images into cluster if needed
switch ($clusterType) {
    'minikube' {
        foreach ($img in $images) { Run "minikube image load $($img.name)" }
    }
    'kind' {
        # Detect the kind cluster name(s) and load images into the first cluster found.
        try {
            $clustersOut = & kind get clusters 2>&1
            if ($LASTEXITCODE -eq 0 -and $clustersOut) {
                $clusterLines = ($clustersOut -split "`n" | Where-Object { \\$_ -ne '' })
                $clusterName = $clusterLines[0].Trim()
            } else {
                $clusterName = 'kind'
            }
        } catch {
            $clusterName = 'kind'
        }
        Write-Host "Loading images into kind cluster: $clusterName"
        foreach ($img in $images) { Run "kind load docker-image $($img.name) --name $clusterName" }
    }
    default { Write-Host "Assuming Docker Desktop local images are available to the cluster" }
}

# 4. apply manifests
Run "kubectl apply -f $root\k8s\namespace.yaml"
Run "kubectl apply -n $Namespace -f $root\k8s\mongo-statefulset.yaml"
Run "kubectl apply -n $Namespace -f $root\k8s\sqlserver-deployment.yaml"
Run "kubectl apply -n $Namespace -f $root\k8s\api-services-deployment.yaml"
Run "kubectl apply -n $Namespace -f $root\k8s\agroapi-api-deployment.yaml"
Run "kubectl apply -n $Namespace -f $root\k8s\agroapi-gateway-deployment.yaml"

# 5. wait for readiness
function Wait-DeploymentReady($name, $timeoutSec=180) {
    Write-Host "Waiting rollout for deployment/$name in namespace $Namespace"
    $cmd = "kubectl -n $Namespace rollout status deploy/$name --timeout=${timeoutSec}s"
    Run $cmd
}

Wait-DeploymentReady 'api-services' 120
Wait-DeploymentReady 'agroapi-api' 120
Wait-DeploymentReady 'agroapi-gateway' 120

# wait for mongo statefulset pod ready
Run "kubectl -n $Namespace wait --for=condition=ready pod -l app=mongo --timeout=120s"

# 6. run migrations by copying local source into a temporary pod that has dotnet SDK
if (-not $SkipMigrations) {
    if ($DryRun) { Write-Host "DryRun: would run migrations using a temporary dotnet/sdk pod and kubectl cp" }
    else {
    Write-Host "Starting ef-runner pod in namespace $Namespace"
    Run "kubectl -n $Namespace run ef-runner --image=mcr.microsoft.com/dotnet/sdk:8.0 --restart=Never --command -- sleep 3600"
    Run "kubectl -n $Namespace wait --for=condition=ready pod/ef-runner --timeout=60s"
        # copy local source into pod
    $localPath = Join-Path $root 'services\AgroService'
        if (-not (Test-Path $localPath)) { throw "Local source not found at $localPath; cannot run migrations" }
    Write-Host "Copying source to ef-runner pod (this may take a moment) in namespace $Namespace"
    # kubectl cp expects a local path format; convert backslashes to forward slashes to avoid issues
    $localPathForCp = $localPath -replace '\\','/'
    Run "kubectl cp $localPathForCp $Namespace/ef-runner:/src"
        # execute migration inside pod
    $conn = 'Server=sqlserver;Database=AgroIoT_Parcelas;User Id=sa;Password=REPLACE_WITH_STRONG_PASSWORD;TrustServerCertificate=True;'
    # Build the kubectl exec command using a PowerShell single-quoted string so shell tokens
    # like $PATH, && and || are not interpreted by PowerShell. Insert the connection string
    # by concatenation (wrapped in single quotes for the shell).
        $execCmd = 'kubectl -n ' + $Namespace + ' exec ef-runner -- sh -c "export PATH=$PATH:/root/.dotnet/tools && dotnet tool install --global dotnet-ef --version 8.* || true && cd /src && export ConnectionStrings__DefaultConnection=''' + $conn + ''' && dotnet ef database update --project AgroAPI.Infrastructure --startup-project AgroAPI.API"'
        Run $execCmd
        Run "kubectl -n $Namespace delete pod ef-runner --ignore-not-found"
    }
} else { Write-Host "Skipping migrations (-SkipMigrations)" }

# 7. run smoke tests job
Run "kubectl -n $Namespace apply -f $root\k8s\smoke-tests-job.yaml"
Write-Host "You can inspect the job logs with: kubectl logs -n $Namespace job/smoke-tests"

Write-Host "deploy-k8s completed"
