<#
create-kind-dev.ps1
Create a per-developer kind cluster, load images, create namespace and common secrets.

Usage:
  .\create-kind-dev.ps1 -DevPrefix <your-name>

This script will:
 - create a kind cluster named kind-<DevPrefix> (if it doesn't exist)
 - create namespace dev-<DevPrefix>
 - create secrets: sqlserver-secret (SA_PASSWORD) and db-conn-secret (ConnectionStrings__DefaultConnection)
 - load local images into the cluster
#>
param(
    [Parameter(Mandatory=$true)][string]$DevPrefix,
    [string]$SaPassword = 'REPLACE_WITH_STRONG_PASSWORD',
    [switch]$SkipBuild,
    [switch]$AutoInstallKind,
    [int]$NodeCount = 1
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$clusterName = "kind-$DevPrefix"
$ns = "dev-$DevPrefix"

function Run { param($cmd) Write-Host ">> $cmd"; iex $cmd }

function Try-InstallKind {
    Write-Host "Attempting to install kind..."
    # Try choco, scoop, winget in that order
    if (Get-Command choco -ErrorAction SilentlyContinue) {
        Write-Host "Installing kind with choco..."
        iex "choco install kind -y"
        return $?
    }
    if (Get-Command scoop -ErrorAction SilentlyContinue) {
        Write-Host "Installing kind with scoop..."
        iex "scoop install kind"
        return $?
    }
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        Write-Host "Installing kind with winget..."
        iex "winget install --id Microsoft.kind -e --accept-package-agreements --accept-source-agreements" 2>$null
        return $?
    }
    # Fallback: try direct download of the official kind binary for Windows
    Write-Host "Package managers not available or failed - attempting direct download of kind binary..."
    try {
        $arch = if ([IntPtr]::Size -eq 8) { 'amd64' } else { '386' }
        $url = "https://github.com/kubernetes-sigs/kind/releases/latest/download/kind-windows-$arch"

        # Candidate install directories (prefer ProgramFiles, then LocalAppData, then user profile)
        $candidateDirs = @()
        if ($env:ProgramFiles) { $candidateDirs += Join-Path $env:ProgramFiles 'kind' }
        if ($env:LOCALAPPDATA) { $candidateDirs += Join-Path $env:LOCALAPPDATA 'Programs\kind' }
        $candidateDirs += Join-Path $env:USERPROFILE '.kind\bin'

        foreach ($dir in $candidateDirs) {
            try {
                if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
                $dest = Join-Path $dir 'kind.exe'
                Write-Host "Downloading kind from $url to $dest"
                Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing -ErrorAction Stop

                # Ensure the downloaded file is writable/executable by this session and add to PATH for the current process
                if (-not ($env:Path -split ';' | Where-Object { $_ -eq $dir })) { $env:Path = "$dir;$env:Path" }

                if (Get-Command kind -ErrorAction SilentlyContinue) {
                    Write-Host "kind installed and available from $dir"
                    return $true
                }
            } catch {
                Write-Host "Failed to download/install to $dir: $($_.Exception.Message)"
                continue
            }
        }
    } catch {
        Write-Host "Direct download attempt failed: $($_.Exception.Message)"
    }

    return $false
}

if (-not (Get-Command kind -ErrorAction SilentlyContinue)) {
    if ($AutoInstallKind) {
        $ok = Try-InstallKind
        if (-not $ok) {
            Write-Error "Auto-install failed. Please install kind manually: https://kind.sigs.k8s.io"
            exit 1
        }
    } else {
        throw 'kind is required. Install from https://kind.sigs.k8s.io or rerun with -AutoInstallKind to attempt an installer.'
    }
}

# Create cluster if missing
$clusters = & kind get clusters 2>$null
if (-not ($clusters -contains $clusterName)) {
    Write-Host "Creating kind cluster: $clusterName (nodes: $NodeCount)"
    if ($NodeCount -le 1) {
        Run "kind create cluster --name $clusterName"
    } else {
        # Generate a kind config with one control plane and ($NodeCount - 1) workers
        $cfgLines = @()
        $cfgLines += "kind: Cluster"
        $cfgLines += "apiVersion: kind.x-k8s.io/v1alpha4"
        $cfgLines += "nodes:"
        $cfgLines += "- role: control-plane"
        for ($i = 1; $i -lt $NodeCount; $i++) { $cfgLines += "- role: worker" }
        $tmpCfg = [System.IO.Path]::Combine($env:TEMP, "kind-config-$DevPrefix.yaml")
        Set-Content -Path $tmpCfg -Value ($cfgLines -join "`n") -Force
        Run "kind create cluster --name $clusterName --config $tmpCfg"
        Remove-Item -Path $tmpCfg -ErrorAction SilentlyContinue
    }
} else { Write-Host "Cluster $clusterName already exists" }

# Build images unless requested to skip
$images = @(
    @{ name='services-api-services:latest'; path='services/api-services'; dockerfile='services/api-services/Dockerfile' },
    @{ name='services-agroapi-api:latest'; path='services/AgroService'; dockerfile='services/AgroService/AgroAPI.API/Dockerfile' },
    @{ name='services-agroapi-gateway:latest'; path='services/AgroService'; dockerfile='services/AgroService/AgroAPI.Gateway/Dockerfile' }
)
if (-not $SkipBuild) {
    foreach ($img in $images) {
        $buildCmd = "docker build -t $($img.name) -f $($root)\$($img.dockerfile) $($root)\$($img.path)"
        Run $buildCmd
    }
}

# Load images into kind cluster
foreach ($img in $images) { Run "kind load docker-image $($img.name) --name $clusterName" }

# Create namespace and secrets
Run "kubectl create namespace $ns --context kind-$clusterName --dry-run=client -o yaml | kubectl apply -f -"

# Create SQL secret and DB connection secret in the namespace
$conn = "Server=sqlserver;Database=AgroIoT_Parcelas;User Id=sa;Password=$SaPassword;TrustServerCertificate=True;"
Run "kubectl -n $ns create secret generic sqlserver-secret --from-literal=SA_PASSWORD='$SaPassword' --dry-run=client -o yaml | kubectl apply -f -"
Run "kubectl -n $ns create secret generic db-conn-secret --from-literal=ConnectionStrings__DefaultConnection='$conn' --dry-run=client -o yaml | kubectl apply -f -"

Write-Host "Created namespace $ns and injected secrets. Next run deploy-k8s.ps1 with --ImagesPrefix if you pushed images to a registry, or run deploy-k8s.ps1 normally to apply manifests (it will detect kind and load images)."
