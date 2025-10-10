try {
  Invoke-WebRequest -Method POST -Uri 'http://localhost:8081/api/auth/register' -ContentType 'application/json' -Body '{"Nombre":"QA Test","Correo":"test+qa@example.com","Password":"P@ssw0rd123!"}' -ErrorAction Stop | Out-Null
  Write-Host "REGISTER: OK"
} catch {
  $e = $_
  if ($e.Exception.Response -ne $null) {
    $sr = [System.IO.StreamReader]::new($e.Exception.Response.GetResponseStream())
    $body = $sr.ReadToEnd()
    Write-Host "REGISTER HTTP Status: $($e.Exception.Response.StatusCode)"
    Write-Host "REGISTER BODY:`n$body"
  } else { Write-Host "REGISTER: No response" }
}

try {
  Invoke-WebRequest -Method POST -Uri 'http://localhost:8081/api/auth/login' -ContentType 'application/json' -Body '{"Correo":"test+qa@example.com","Password":"P@ssw0rd123!"}' -ErrorAction Stop | Out-Null
  Write-Host "LOGIN: OK"
} catch {
  $e = $_
  if ($e.Exception.Response -ne $null) {
    $sr = [System.IO.StreamReader]::new($e.Exception.Response.GetResponseStream())
    $body = $sr.ReadToEnd()
    Write-Host "LOGIN HTTP Status: $($e.Exception.Response.StatusCode)"
    Write-Host "LOGIN BODY:`n$body"
  } else { Write-Host "LOGIN: No response" }
}
