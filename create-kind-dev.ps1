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
    [int]$NodeCount = 1,
    [string]$EnvPath  # opcional: si no se pasa, se auto-detecta
)

$ErrorActionPreference = 'Stop'
$root        = Split-Path -Parent $MyInvocation.MyCommand.Path
$clusterName = "kind-$DevPrefix"
$kubectx     = "kind-$clusterName"  # => "kind-kind-<DevPrefix>"
$ns          = "dev-$DevPrefix"

function Run { param($cmd) Write-Host ">> $cmd"; iex $cmd }

function Try-InstallKind {
    Write-Host "Attempting to install kind..."
    if (Get-Command choco -ErrorAction SilentlyContinue) { iex "choco install kind -y"; return $? }
    if (Get-Command scoop -ErrorAction SilentlyContinue) { iex "scoop install kind"; return $? }
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        iex "winget install --id Kubernetes.kind -e --accept-package-agreements --accept-source-agreements" 2>$null
        return $?
    }
    Write-Host "Package managers not available or failed - attempting direct download of kind binary..."
    try {
        $arch = if ([IntPtr]::Size -eq 8) { 'amd64' } else { '386' }
        $url = "https://github.com/kubernetes-sigs/kind/releases/latest/download/kind-windows-$arch"
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
                if (-not ($env:Path -split ';' | Where-Object { $_ -eq $dir })) { $env:Path = "$dir;$env:Path" }
                if (Get-Command kind -ErrorAction SilentlyContinue) { Write-Host "kind installed and available from $dir"; return $true }
            } catch {
                Write-Host ("Failed to download/install to {0}: {1}" -f $dir, $_.Exception.Message)
                continue
            }
        }
    } catch { Write-Host "Direct download attempt failed: $($_.Exception.Message)" }
    return $false
}

function Try-InstallKubectl {
    Write-Host "Attempting to install kubectl..."
    if (Get-Command choco -ErrorAction SilentlyContinue) { iex "choco install kubernetes-cli -y"; return $? }
    if (Get-Command scoop -ErrorAction SilentlyContinue) { iex "scoop install kubectl"; return $? }
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        iex "winget install -e --id Kubernetes.kubectl --accept-package-agreements --accept-source-agreements" 2>$null
        return $?
    }
    Write-Host "kubectl auto-install not available; install it manually from https://kubernetes.io/docs/tasks/tools/"
    return $false
}

function Ensure-Binary {
    param(
        [Parameter(Mandatory=$true)][string]$Name,
        [string[]]$Candidates
    )
    $cmd = Get-Command $Name -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Path }
    foreach ($p in $Candidates) {
        if ($p -and (Test-Path $p)) {
            $dir = Split-Path $p -Parent
            if (-not ($env:Path -split ';' | Where-Object { $_ -eq $dir })) { $env:Path = "$dir;$env:Path" }
            return $p
        }
    }
    try {
        $where = & where.exe $Name 2>$null
        if ($LASTEXITCODE -eq 0 -and $where) {
            $first = ($where -split "`r?`n")[0].Trim()
            if (Test-Path $first) {
                $dir = Split-Path $first -Parent
                if (-not ($env:Path -split ';' | Where-Object { $_ -eq $dir })) { $env:Path = "$dir;$env:Path" }
                return $first
            }
        }
    } catch {}
    return $null
}

function Install-KindToUserBin {
    try {
        $arch = if ([IntPtr]::Size -eq 8) { 'amd64' } else { '386' }
        $url  = "https://github.com/kubernetes-sigs/kind/releases/latest/download/kind-windows-$arch"
        $dir  = Join-Path $env:USERPROFILE '.kind\bin'
        if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        $dest = Join-Path $dir 'kind.exe'
        Write-Host "Downloading kind directly to: $dest"
        Invoke-WebRequest -Uri $url -OutFile $dest -UseBasicParsing -ErrorAction Stop
        if (-not ($env:Path -split ';' | Where-Object { $_ -eq $dir })) { $env:Path = "$dir;$env:Path" }
        return $dest
    } catch {
        Write-Host ("Failed direct download for kind: {0}" -f $_.Exception.Message)
        return $null
    }
}

function Read-DotEnv {
    param([string]$Path)
    $map = @{}
    if (-not $Path -or -not (Test-Path $Path)) { return $map }
    foreach ($line in Get-Content -Path $Path -Encoding UTF8) {
        $t = $line.Trim()
        if ($t -eq "" -or $t.StartsWith("#")) { continue }
        if ($t -match '^\s*(?:export\s+)?([^=]+?)\s*=\s*(.*)\s*$') {
            $k = $matches[1].Trim()
            $v = $matches[2]
            if ($v -match '^\s*"(.*)"\s*$') { $v = $matches[1] }
            elseif ($v -match "^\s*'(.*)'\s*$") { $v = $matches[1] }
            $map[$k] = $v
        }
    }
    return $map
}

function Find-DotEnv {
    param([string]$PreferredPath)
    if ($PreferredPath -and (Test-Path $PreferredPath)) { return $PreferredPath }
    $candidates = @(
        (Join-Path $root ".env"),
        (Join-Path $root "services\.env"),
        (Join-Path $root "services\api-services\.env")
    )
    foreach ($p in $candidates) { if (Test-Path $p) { return $p } }
    return $null
}

function Get-ConnStrPassword {
    param([string]$Conn)
    if (-not $Conn) { return $null }
    if ($Conn -match '(?i)(?:Password|Pwd)\s*=\s*([^;]+)') { return $matches[1] }
    return $null
}

# Ensure kind
if (-not (Get-Command kind -ErrorAction SilentlyContinue)) {
    if ($AutoInstallKind) {
        $ok = Try-InstallKind
        if (-not $ok) { Write-Error "Auto-install failed. Please install kind manually: https://kind.sigs.k8s.io"; exit 1 }
    } else { throw 'kind is required. Install from https://kind.sigs.k8s.io or rerun with -AutoInstallKind to attempt an installer.' }
}
$kindPath = Ensure-Binary -Name 'kind' -Candidates @(
    (Join-Path $env:ProgramFiles 'kind\kind.exe'),
    (Join-Path $env:ProgramFiles 'Kubernetes\kind.exe'),
    (Join-Path $env:ProgramFiles 'Kubernetes\kind\kind.exe'),
    (Join-Path $env:LOCALAPPDATA 'Programs\kind\kind.exe'),
    (Join-Path $env:USERPROFILE '.kind\bin\kind.exe'),
    (Join-Path $env:ProgramData 'chocolatey\bin\kind.exe'),
    (Join-Path $env:USERPROFILE 'scoop\shims\kind.exe')
)
if (-not $kindPath) {
    Write-Host "kind not found in PATH after install. Attempting direct download fallback..."
    $kindPath = Install-KindToUserBin
    if (-not $kindPath) { throw "kind could not be located or downloaded. Close/reopen PowerShell or add it to PATH manually." }
}
Write-Host "Using kind at: $kindPath"

# Ensure kubectl
if (-not (Get-Command kubectl -ErrorAction SilentlyContinue)) {
    if ($AutoInstallKind) {
        $ok2 = Try-InstallKubectl
        if (-not $ok2) { Write-Error "kubectl is required. Please install it: https://kubernetes.io/docs/tasks/tools/"; exit 1 }
    } else { throw 'kubectl is required. Install it (e.g. winget install -e --id Kubernetes.kubectl) or rerun with -AutoInstallKind.' }
}
$kubectlPath = Ensure-Binary -Name 'kubectl' -Candidates @(
    (Join-Path $env:ProgramFiles 'Kubernetes\kubectl.exe'),
    (Join-Path $env:ProgramFiles 'Docker\Docker\resources\bin\kubectl.exe'), # Docker Desktop
    (Join-Path $env:ProgramData 'chocolatey\bin\kubectl.exe'),
    (Join-Path $env:USERPROFILE 'scoop\shims\kubectl.exe')
)
if (-not $kubectlPath) { Write-Host "kubectl not found in PATH; you may need to reopen PowerShell if winget just installed it." }
else { Write-Host "Using kubectl at: $kubectlPath" }

# --- Resolución de .env y variables ---
$EnvPath       = Find-DotEnv -PreferredPath $EnvPath
$envMap        = Read-DotEnv -Path $EnvPath
$connFromEnv   = if ($envMap.ContainsKey('SQL_CONN_STR')) { $envMap['SQL_CONN_STR'] } else { $null }
$saFromEnv     = if ($envMap.ContainsKey('SA_PASSWORD'))  { $envMap['SA_PASSWORD']  } else { $null }

# Fallback: variables de entorno del proceso
if (-not $connFromEnv -and $env:SQL_CONN_STR) { $connFromEnv = $env:SQL_CONN_STR }
if (-not $saFromEnv  -and $env:SA_PASSWORD)   { $saFromEnv   = $env:SA_PASSWORD }

$pwdFromConn    = Get-ConnStrPassword -Conn $connFromEnv
$effectiveSaPwd = if ($pwdFromConn) { $pwdFromConn } elseif ($saFromEnv) { $saFromEnv } else { $SaPassword }
$effectiveConn  = if ($connFromEnv) { $connFromEnv } else { "Server=sqlserver;Database=AgroIoT_Parcelas;User Id=sa;Password=$effectiveSaPwd;TrustServerCertificate=True;" }

# Validación final
if (-not $effectiveSaPwd -or $effectiveSaPwd -eq 'REPLACE_WITH_STRONG_PASSWORD') {
    $where = if ($EnvPath) { $EnvPath } else { "(no .env found)" }
    throw "SA password not provided. Set SQL_CONN_STR or SA_PASSWORD in $where, or pass -SaPassword."
}

# --- Crear cluster si falta ---
$clusters = & kind get clusters 2>$null
if (-not ($clusters -contains $clusterName)) {
    Write-Host "Creating kind cluster: $clusterName (nodes: $NodeCount)"
    if ($NodeCount -le 1) {
        Run "kind create cluster --name $clusterName"
    } else {
        $cfgLines = @(
            "kind: Cluster",
            "apiVersion: kind.x-k8s.io/v1alpha4",
            "nodes:",
            "- role: control-plane"
        )
        for ($i = 1; $i -lt $NodeCount; $i++) { $cfgLines += "- role: worker" }
        $tmpCfg = [System.IO.Path]::Combine($env:TEMP, "kind-config-$DevPrefix.yaml")
        Set-Content -Path $tmpCfg -Value ($cfgLines -join "`n") -Force
        Run "kind create cluster --name $clusterName --config $tmpCfg"
        Remove-Item -Path $tmpCfg -ErrorAction SilentlyContinue
    }
} else { Write-Host "Cluster $clusterName already exists" }

# --- Forzar contexto para evitar mismatches ---
Run ("kubectl config use-context {0}" -f $kubectx)

# --- Build images (opcional) ---
$images = @(
    @{ name='services-api-services:latest';    path='services/api-services'; dockerfile='services/api-services/Dockerfile' },
    @{ name='services-agroapi-api:latest';     path='services/AgroService';  dockerfile='services/AgroService/AgroAPI.API/Dockerfile' },
    @{ name='services-agroapi-gateway:latest'; path='services/AgroService';  dockerfile='services/AgroService/AgroAPI.Gateway/Dockerfile' }
)
if (-not $SkipBuild) {
    foreach ($img in $images) {
        $buildCmd = "docker build -t $($img.name) -f `"$($root)\$($img.dockerfile)`" `"$($root)\$($img.path)`""
        Run $buildCmd
    }
}

# --- Cargar imágenes a kind ---
foreach ($img in $images) { Run "kind load docker-image $($img.name) --name $clusterName" }

# --- Namespace ---
Run ("kubectl create namespace {0} --context {1} --dry-run=client -o yaml | kubectl apply -f -" -f $ns, $kubectx)

# --- Secrets (via --from-env-file para evitar problemas de quoting) ---
$saEnvTmp  = [System.IO.Path]::Combine($env:TEMP, "sa_secret_{0}.env" -f $DevPrefix)
$dbEnvTmp  = [System.IO.Path]::Combine($env:TEMP, "db_conn_{0}.env"  -f $DevPrefix)
Set-Content -Path $saEnvTmp -Value ("SA_PASSWORD={0}" -f $effectiveSaPwd) -Encoding UTF8
Set-Content -Path $dbEnvTmp -Value ("ConnectionStrings__DefaultConnection={0}" -f $effectiveConn) -Encoding UTF8

Run ("kubectl -n {0} --context {1} create secret generic sqlserver-secret --from-env-file=""{2}"" --dry-run=client -o yaml | kubectl apply -f -" -f $ns, $kubectx, $saEnvTmp)
Run ("kubectl -n {0} --context {1} create secret generic db-conn-secret  --from-env-file=""{2}"" --dry-run=client -o yaml | kubectl apply -f -" -f $ns, $kubectx, $dbEnvTmp)

Remove-Item -Path $saEnvTmp,$dbEnvTmp -ErrorAction SilentlyContinue

Write-Host "Created namespace $ns and injected secrets (from .env or parameters). Next run deploy-k8s.ps1."
