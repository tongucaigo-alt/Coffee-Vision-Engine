#requires -Version 7.0
# Run locally by the owner. Secrets stay outside Git and are never printed.
param([string]$PrivateDirectory = "$env:LOCALAPPDATA\AtlasAiBeta")
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$private = [IO.Path]::GetFullPath($PrivateDirectory)
New-Item -ItemType Directory -Path $private -Force | Out-Null
$configuration = Join-Path $private 'gateway.json'
if (-not (Test-Path -LiteralPath $configuration)) {
    $credentials = @(1..12 | ForEach-Object {
        $bytes = [Security.Cryptography.RandomNumberGenerator]::GetBytes(32)
        $token = [Convert]::ToBase64String($bytes).TrimEnd('=').Replace('+', '-').Replace('/', '_')
        @{ id = "tester-$_"; token = $token }
    })
    $testers = @($credentials | ForEach-Object {
        $digest = [Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($_.token))
        @{ id = $_.id; hash = [Convert]::ToHexString($digest).ToLowerInvariant(); revoked = $false }
    })
    @{ port = 8787; models = @{ atlas = @{ baseUrl = 'http://127.0.0.1:1234/v1'; model = 'qwen3-14b'; noThink = $true } }; testers = $testers } |
        ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $configuration -Encoding utf8NoBOM
    $credentials | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $private 'tester-credentials.json') -Encoding utf8NoBOM
}
$keyProperties = Join-Path $repo 'atlas_contribution_app/android/key.properties'
if (-not (Test-Path -LiteralPath $keyProperties)) {
    $keystore = Join-Path $private 'atlas-founder.jks'
    if (Test-Path -LiteralPath $keystore) { throw 'Existing keystore found. Restore its key.properties; do not overwrite the key.' }
    $keytool = 'C:/Program Files/Android/Android Studio/jbr/bin/keytool.exe'
    if (-not (Test-Path -LiteralPath $keytool)) { $keytool = (Get-Command keytool -ErrorAction Stop).Source }
    $password = [Convert]::ToBase64String([Security.Cryptography.RandomNumberGenerator]::GetBytes(32))
    $env:ATLAS_BETA_SIGN_PASS = $password
    try {
        & $keytool -genkeypair -noprompt -keystore $keystore -storetype JKS -alias atlas-founder -keyalg RSA -keysize 3072 -validity 10000 -dname 'CN=Atlas Founder, O=Atlas, C=TR' -storepass:env ATLAS_BETA_SIGN_PASS -keypass:env ATLAS_BETA_SIGN_PASS
        if ($LASTEXITCODE -ne 0) { throw 'Signing-key creation failed.' }
        $lines = @("storeFile=$($keystore.Replace('\','/'))", "storePassword=$password", "keyPassword=$password", 'keyAlias=atlas-founder')
        $lines | Set-Content -LiteralPath $keyProperties -Encoding utf8NoBOM
        $lines | Set-Content -LiteralPath (Join-Path $private 'key.properties.backup') -Encoding utf8NoBOM
    } finally { Remove-Item Env:ATLAS_BETA_SIGN_PASS -ErrorAction SilentlyContinue }
}
$cloudflared = Join-Path $private 'cloudflared.exe'
if (-not (Test-Path -LiteralPath $cloudflared)) {
    $release = Invoke-RestMethod 'https://api.github.com/repos/cloudflare/cloudflared/releases/latest'
    $asset = $release.assets | Where-Object name -eq 'cloudflared-windows-amd64.exe' | Select-Object -First 1
    if ($asset.digest -notmatch '^sha256:[a-f0-9]{64}$') { throw 'Official release has no SHA-256 digest; download requires manual verification.' }
    $download = Join-Path $private 'cloudflared.download'
    Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $download
    $actual = (Get-FileHash -LiteralPath $download -Algorithm SHA256).Hash.ToLowerInvariant()
    if ("sha256:$actual" -ne $asset.digest) { throw 'Cloudflared checksum mismatch.' }
    Move-Item -LiteralPath $download -Destination $cloudflared
}
Write-Output "Setup ready. Private credentials and signing backup: $private"
Write-Output 'Do not share the complete credentials file or the signing backup. Give each tester only their own token.'
Write-Output 'Start the test service using run-local.ps1; LM Studio must already be running.'
