param([switch]$Stop, [string]$PrivateDirectory = "$env:LOCALAPPDATA\AtlasAiBeta")
$ErrorActionPreference = 'Stop'
$private = [IO.Path]::GetFullPath($PrivateDirectory)
$server = (Resolve-Path (Join-Path $PSScriptRoot '../server.mjs')).Path
$cloudflared = Join-Path $private 'cloudflared.exe'
$state = Join-Path $private 'processes.json'
if (Test-Path -LiteralPath $state) {
    $previous = Get-Content -LiteralPath $state -Raw | ConvertFrom-Json
    foreach ($item in $previous) {
        $process = Get-CimInstance Win32_Process -Filter "ProcessId=$([int]$item.id)" -ErrorAction SilentlyContinue
        if ($process -and $process.CommandLine.Contains($item.marker)) {
            if (-not $Stop) { throw 'A service is already running. Use -Stop before restarting.' }
            Stop-Process -Id $item.id
        }
    }
}
if ($Stop) { Write-Output 'Atlas service stopped. LM Studio was left unchanged.'; return }
$env:ATLAS_AI_CONFIG = Join-Path $private 'gateway.json'
if (-not (Test-Path -LiteralPath $env:ATLAS_AI_CONFIG) -or -not (Test-Path -LiteralPath $cloudflared)) { throw 'Run setup-local.ps1 first.' }
$gateway = Start-Process -FilePath (Get-Command node -ErrorAction Stop).Source -ArgumentList ('"' + $server + '"') -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $private 'gateway.log') -RedirectStandardError (Join-Path $private 'gateway.error.log')
$tunnel = Start-Process -FilePath $cloudflared -ArgumentList @('tunnel','--url','http://127.0.0.1:8787','--no-autoupdate') -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $private 'tunnel.log') -RedirectStandardError (Join-Path $private 'tunnel.error.log')
@(@{id=$gateway.Id;marker=$server},@{id=$tunnel.Id;marker=$cloudflared}) | ConvertTo-Json | Set-Content -LiteralPath $state -Encoding utf8NoBOM
for ($attempt=0; $attempt -lt 80; $attempt++) {
    Start-Sleep -Milliseconds 250
    $log = Get-Content -LiteralPath (Join-Path $private 'tunnel.error.log') -Raw -ErrorAction SilentlyContinue
    if ($log -match 'https://[a-z0-9-]+\.trycloudflare\.com') {
        $Matches[0] | Set-Content -LiteralPath (Join-Path $private 'test-address.txt') -Encoding utf8NoBOM
        Write-Output "APK Atlas address: $($Matches[0])"
        Write-Output 'Model alias: atlas. Give each tester only their own access token.'
        return
    }
}
throw "Tunnel address not ready. Inspect logs in $private; use -Stop before retrying."
