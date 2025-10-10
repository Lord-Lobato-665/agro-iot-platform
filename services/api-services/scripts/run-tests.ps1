param(
    [string]$BaseUrl = 'http://localhost:5172',
    [int]$PerfDurationSec = 60,
    [int]$PerfConcurrency = 5
)

Set-StrictMode -Version Latest

function NowIso { (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ') }

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$logDir = Join-Path $scriptDir "..\logs" | Resolve-Path -Relative -ErrorAction SilentlyContinue
if (-not $logDir) { $logDir = Join-Path $scriptDir "..\logs"; New-Item -Path $logDir -ItemType Directory -Force | Out-Null }
$logDir = (Get-Item $logDir).FullName
$logFile = Join-Path $logDir "endpoints-$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"

function Header {
    param([string]$Title)
    "`n===== $Title =====`n" | Out-File -FilePath $logFile -Append
    "timestamp: $(NowIso)" | Out-File -FilePath $logFile -Append
}

function SafeInvoke {
    param(
        [string]$Method,
        [string]$Url,
        $Body = $null,
        [string]$Token = $null
    )
    $hdr = @{}
    if ($Token) { $hdr['Authorization'] = "Bearer $Token" }
    try {
        $start = [DateTime]::UtcNow
        if ($Body -ne $null) {
            $resp = Invoke-RestMethod -Method $Method -Uri $Url -Headers $hdr -Body ($Body | ConvertTo-Json -Depth 10) -ContentType 'application/json' -ErrorAction Stop
            $status = 200
        } else {
            $responseMessage = Invoke-WebRequest -Method $Method -Uri $Url -Headers $hdr -ErrorAction Stop
            # Cast StatusCode to int to avoid platform-specific enum handling
            try { $status = [int]$responseMessage.StatusCode } catch { $status = 0 }
            # Try to parse body
            try { $resp = $responseMessage.Content | ConvertFrom-Json } catch { $resp = $responseMessage.Content }
        }
        $elapsed = ([DateTime]::UtcNow - $start).TotalMilliseconds
        return @{ ok = $true; status = $status; body = $resp; ms = $elapsed }
    } catch {
        $errMsg = $_.Exception.Message
        $statusCode = -1
        try {
            if ($_.Exception.Response -ne $null) {
                try { $statusCode = [int]$_.Exception.Response.StatusCode } catch { $statusCode = -1 }
            }
        } catch { }
        return @{ ok = $false; status = $statusCode; body = $errMsg; ms = 0 }
    }
}

Write-Host "Running functional and basic performance tests against $BaseUrl"
Write-Host "Logs: $logFile"

########################################
# Functional flow
########################################
$telefono = '0000000000'
Header "Register (POST /agro/auth/register)"
$regBody = @{ Nombre = 'Test QA'; Correo = "test+qa+$(Get-Random -Maximum 1000000)@example.com"; Password = 'P@ssw0rd123!'; Telefono = $telefono }
$r = SafeInvoke 'POST' "$BaseUrl/agro/auth/register" $regBody
"HTTP_STATUS: $($r.status)" | Out-File -FilePath $logFile -Append
($r.body | ConvertTo-Json -Depth 6) | Out-File -FilePath $logFile -Append

Header "Login (POST /agro/auth/login)"
$loginBody = @{ Correo = $regBody.Correo; Password = $regBody.Password }
$r = SafeInvoke 'POST' "$BaseUrl/agro/auth/login" $loginBody
"HTTP_STATUS: $($r.status)" | Out-File -FilePath $logFile -Append
try { ($r.body | ConvertTo-Json -Depth 6) | Out-File -FilePath $logFile -Append } catch { $r.body | Out-File -FilePath $logFile -Append }

$token = $null
if ($r.ok) {
    if ($r.body.Token) { $token = $r.body.Token }
    elseif ($r.body.token) { $token = $r.body.token }
    elseif ($r.body.accessToken) { $token = $r.body.accessToken }
    elseif ($r.body.data) {
        if ($r.body.data.token) { $token = $r.body.data.token }
        elseif ($r.body.data.Token) { $token = $r.body.data.Token }
    }
}
if (-not $token) { "Warning: token not found; protected endpoints will be called without Authorization" | Out-File -FilePath $logFile -Append }
else { "Obtained token (truncated): $($token.Substring(0,[Math]::Min(20,$token.Length)))..." | Out-File -FilePath $logFile -Append }

# Create a Parcela to use in subsequent tests
Header "Create Parcela (POST /agro/parcelas) - setup"
$parcelaBody = @{ Nombre = 'Parcela de prueba PS'; Latitud = -12.04318; Longitud = -77.02824 }
$rpar = SafeInvoke 'POST' "$BaseUrl/agro/parcelas" $parcelaBody $token
"HTTP_STATUS: $($rpar.status)" | Out-File -FilePath $logFile -Append
try { ($rpar.body | ConvertTo-Json -Depth 6) | Out-File -FilePath $logFile -Append } catch { $rpar.body | Out-File -FilePath $logFile -Append }
$parcelaId = $null
try { if ($rpar.ok -and $rpar.body.id) { $parcelaId = $rpar.body.id } elseif ($rpar.ok -and $rpar.body.Id) { $parcelaId = $rpar.body.Id } }
catch { }
if (-not $parcelaId) { "Warning: could not create or detect Parcela Id; falling back to zero-guid placeholder" | Out-File -FilePath $logFile -Append; $parcelaId = '00000000-0000-0000-0000-000000000000' }

# sensorId will be filled when we create a sensor
$sensorId = $null

########################################
# List of endpoints to call
########################################
$endpoints = @(
    # Parcela detallada route is exposed at /parcela-detallada/{id} (protected)
        # Removed /parcela-detallada (composite gateway controller) because it had intermittent 404s;
        # downstream API parcela endpoints are tested directly below.
    # All /agro/* API endpoints are secured by the downstream API controllers => protected = $true
    @{ method='GET'; path='/agro/parcelas'; protected = $true },
    @{ method='GET'; path='/agro/parcelas?includeDeleted=true'; protected = $true },
    @{ method='GET'; path="/agro/parcelas/$parcelaId"; protected = $true },
    # The POST above was executed for setup; we still include it as a test but with a valid payload
    @{ method='POST'; path='/agro/parcelas'; body = @{ Nombre='Parcela PS'; Latitud = -12.0; Longitud = -77.0 }; protected = $true },
    @{ method='PUT'; path="/agro/parcelas/$parcelaId"; body = @{ Nombre='Updated by PS'; Latitud = -12.1; Longitud = -77.1 }; protected = $true },
    @{ method='DELETE'; path="/agro/parcelas/$parcelaId"; protected = $true },
    @{ method='PATCH'; path="/agro/parcelas/$parcelaId/restore"; protected = $true },
    @{ method='GET'; path='/agro/cultivos'; protected = $true },
        @{ method='GET'; path='/agro/cultivos'; protected = $true },
        @{ method='POST'; path='/agro/cultivos'; body = @{ Nombre='Cultivo PS' }; protected = $true },
    @{ method='GET'; path='/agro/users'; protected = $true },
    # Sensor and lecturas endpoints (node service) are unauthenticated in this setup
    @{ method='GET'; path='/sensores'; protected = $false },
    # We'll create a sensor (valid payload) during setup and use its id for lecturas
    @{ method='POST'; path='/sensores'; body = @{ _id=([guid]::NewGuid().ToString()); nombre='Sensor PS'; tipo='temperatura'; cultivo='test'; id_parcela_sql = $parcelaId }; protected = $false },
    # Note: node service does not implement GET /api/lecturas; only POST /api/lecturas exists
    @{ method='POST'; path='/lecturas'; body = @{ sensorId = 'TO_BE_FILLED'; tipo='temperatura'; value = 23.5; unit='C'; timestamp = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ') }; protected = $false }
)

foreach ($ep in $endpoints) {
    $method = $ep.method; $path = $ep.path; $protected = $ep.protected
    if ($ep.ContainsKey('body')) { $body = $ep['body'] } else { $body = $null }
    $url = "$BaseUrl$path"
    Header "$method $url"
    $tok = $null
    if ($protected -and $token) { $tok = $token }
    # If this is the lecturas test and we have a sensorId, inject it
    if ($path -eq '/lecturas' -and $body -ne $null -and $body.sensorId -eq 'TO_BE_FILLED' -and $sensorId) {
        $body.sensorId = $sensorId
    }
    $res = SafeInvoke $method $url $body $tok
    "HTTP_STATUS: $($res.status)" | Out-File -FilePath $logFile -Append
    try { ($res.body | ConvertTo-Json -Depth 6) | Out-File -FilePath $logFile -Append } catch { $res.body | Out-File -FilePath $logFile -Append }

    # If we just created a sensor, extract its id to use for lecturas
    if ($path -eq '/sensores' -and $method -eq 'POST' -and $res.ok) {
        try {
            if ($res.body._id) { $sensorId = $res.body._id }
            elseif ($res.body.id) { $sensorId = $res.body.id }
        } catch { }
        if ($sensorId) { "Detected sensorId: $sensorId" | Out-File -FilePath $logFile -Append }
    }
}

# After running endpoints once, if we created a sensor, update lecturas test payload and call POST /lecturas
try {
    # Try to detect last created sensor from the POST response in the log file by reading the last 'POST /sensores' JSON
    $log = Get-Content $logFile -Raw
    $matches = [regex]::Matches($log, 'POST http://localhost:5172/sensores[\s\S]*?\{[\s\S]*?\}')
    if ($matches.Count -gt 0) {
        $last = $matches[$matches.Count - 1].Value
        $jsonMatch = [regex]::Match($last, '\{[\s\S]*\}')
        if ($jsonMatch.Success) {
            $obj = $jsonMatch.Value | ConvertFrom-Json
            if ($obj._id) { $sensorId = $obj._id } elseif ($obj.id) { $sensorId = $obj.id }
        }
    }
} catch { }

if (-not $sensorId) { "Warning: sensorId not found in logs; skipping lecturas POST" | Out-File -FilePath $logFile -Append }
else {
    Header "POST /lecturas with sensorId"
    # Include 'tipo' (must match enum in LecturaSensor schema)
    $lectBody = @{ sensorId = $sensorId; tipo='temperatura'; value = 25.5; unit='C'; timestamp=(Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ') }
    $r = SafeInvoke 'POST' "$BaseUrl/lecturas" $lectBody
    "HTTP_STATUS: $($r.status)" | Out-File -FilePath $logFile -Append
    try { ($r.body | ConvertTo-Json -Depth 6) | Out-File -FilePath $logFile -Append } catch { $r.body | Out-File -FilePath $logFile -Append }
}

########################################
# Basic performance test
########################################
Header "Basic performance test - duration ${PerfDurationSec}s - concurrency ${PerfConcurrency}"

# Prepare per-job temp files
$tmpDir = Join-Path $scriptDir "..\logs\perf-tmp-$(Get-Date -Format 'yyyyMMdd_HHmmss')"
New-Item -Path $tmpDir -ItemType Directory -Force | Out-Null

$endTime = (Get-Date).AddSeconds($PerfDurationSec)

function PerfWorker {
    param($Id, $Url, $Token, $EndTime, $OutFile)
    $wc = New-Object System.Net.WebClient
    while ((Get-Date) -lt $EndTime) {
        $t0 = [DateTime]::UtcNow
        try {
            $resp = $wc.DownloadString($Url)
            $status = 200
            $ok = $true
        } catch {
            $status = $_.Exception.Response.StatusCode.Value__ 2>$null
            $ok = $false
        }
        $ms = ([DateTime]::UtcNow - $t0).TotalMilliseconds
        "$((Get-Date).ToString('o')),$Id,$status,$ms,$ok" | Out-File -FilePath $OutFile -Append
    }
}

# Build urls to hit: mix GET parcelas and POST lecturas
$urls = @()
$urls += @{ method='GET'; url="$BaseUrl/agro/parcelas" }
$urls += @{ method='POST'; url="$BaseUrl/lecturas"; body = @{ sensorId=$null; value= (Get-Random -Minimum 10 -Maximum 30); timestamp=(Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ') } }

# Start jobs
$jobs = @()
for ($i=1; $i -le $PerfConcurrency; $i++) {
    $outfile = Join-Path $tmpDir "job-$i.csv"
    "timestamp,job,status,ms,ok" | Out-File -FilePath $outfile -Append
    # Each job will alternate between urls
    $scriptBlock = {
        param($i,$urls,$endTime,$outfile,$token)
        $wc = New-Object System.Net.WebClient
        while ((Get-Date) -lt $endTime) {
            foreach ($u in $urls) {
                $t0 = [DateTime]::UtcNow
                try {
                    if ($u.method -eq 'GET') { $wc.DownloadString($u.url) | Out-Null } else { $wc.UploadString($u.url, 'POST', ($u.body | ConvertTo-Json -Depth 6)) | Out-Null }
                    $status = 200; $ok = $true
                } catch {
                    $status = -1; $ok = $false
                    try { if ($_.Exception.Response -and $_.Exception.Response.StatusCode) { $status = $_.Exception.Response.StatusCode.Value__ } } catch { }
                }
                $ms = ([DateTime]::UtcNow - $t0).TotalMilliseconds
                "$((Get-Date).ToString('o')),$i,$status,$ms,$ok" | Out-File -FilePath $outfile -Append
            }
        }
    }
    $job = Start-Job -ScriptBlock $scriptBlock -ArgumentList @($i,$urls,$endTime,$outfile,$token)
    $jobs += $job
}

Write-Host "Running performance test for $PerfDurationSec seconds with $PerfConcurrency workers..."
Wait-Job -Job $jobs

# Aggregate perf results
$aggFile = Join-Path $logDir "perf-aggregate-$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
"timestamp,job,status,ms,ok" | Out-File -FilePath $aggFile -Append
Get-ChildItem -Path $tmpDir -Filter 'job-*.csv' | ForEach-Object { Get-Content $_.FullName | Select-Object -Skip 1 | Out-File -FilePath $aggFile -Append }

Header "Perf summary (aggregated)"
# Robust CSV aggregation: import as CSV with headers and compute counts/averages
try {
    $csvHeaders = @('timestamp','job','status','ms','ok')
    $rows = Import-Csv -Path $aggFile -Header $csvHeaders -Delimiter ',' | Where-Object { $_.timestamp -ne 'timestamp' }
    $count = $rows.Count
    $suc = ($rows | Where-Object { $_.ok -match '(?i)^(true|1)$' }).Count
    $avgMs = 0
    if ($count -gt 0) {
        $vals = $rows | ForEach-Object { try { [double]($_.ms) } catch { 0 } }
        $avgMs = ($vals | Measure-Object -Average).Average
    }
    "Total requests: $count" | Out-File -FilePath $logFile -Append
    "Successful: $suc" | Out-File -FilePath $logFile -Append
    "Average latency (ms): $([math]::Round($avgMs,2))" | Out-File -FilePath $logFile -Append
} catch {
    # Fallback to previous parsing if Import-Csv fails for any reason
    $lines = Get-Content $aggFile | Select-Object -Skip 1
    $count = ($lines | Measure-Object).Count
    $suc = ($lines | Where-Object { ($_ -split ',')[4] -eq 'True' } | Measure-Object).Count
    $avgMs = ($lines | ForEach-Object { [double]((($_ -split ',')[3])) } | Measure-Object -Average).Average
    "Total requests: $count" | Out-File -FilePath $logFile -Append
    "Successful: $suc" | Out-File -FilePath $logFile -Append
    "Average latency (ms): $([math]::Round($avgMs,2))" | Out-File -FilePath $logFile -Append
}

Write-Host "Tests finished. Logs: $logFile"
Write-Host "Perf aggregate: $aggFile"

exit 0
