param([Parameter(Mandatory=$true)][string]$Flutter,
      [Parameter(Mandatory=$true)][string]$ProjectUrl,
      [Parameter(Mandatory=$true)][string]$PublishableKey,
      [Parameter(Mandatory=$true)][string]$CaptchaUrl,
      [switch]$DebugBuild)
$ErrorActionPreference = 'Stop'
$public = $PublishableKey -match '^sb_publishable_[A-Za-z0-9_-]+$'
if (-not $public) {
  try {
    $part = $PublishableKey.Split('.')[1].Replace('-','+').Replace('_','/')
    $part = $part.PadRight([int]([Math]::Ceiling($part.Length / 4.0) * 4),'=')
    $payload = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($part)) | ConvertFrom-Json
    $public = $payload.role -eq 'anon'
  } catch { $public = $false }
}
if (-not $ProjectUrl.StartsWith('https://') -or -not $CaptchaUrl.StartsWith('https://') -or -not $public) { throw 'HTTPS endpoints and a public client key are required' }
$mode = if ($DebugBuild) { '--debug' } else { '--release' }
& $Flutter build apk $mode --target lib/main.dart "--dart-define=SUPABASE_URL=$ProjectUrl" "--dart-define=SUPABASE_ANON_KEY=$PublishableKey" "--dart-define=CAPTCHA_URL=$CaptchaUrl"
if ($LASTEXITCODE -ne 0) { throw 'Android build failed' }
Write-Output 'Local APK built. Invitation distribution requires physical-device and hosted-access acceptance.'
