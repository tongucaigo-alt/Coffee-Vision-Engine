param([Parameter(Mandatory=$true)][string]$Flutter,
      [Parameter(Mandatory=$true)][string]$ProjectUrl,
      [Parameter(Mandatory=$true)][string]$PublishableKey,
      [Parameter(Mandatory=$true)][string]$TurnstileSiteKey)
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
if (-not $ProjectUrl.StartsWith('https://') -or -not $public) { throw 'Only HTTPS and a public client key are allowed' }
if ($TurnstileSiteKey -notmatch '^[a-zA-Z0-9_-]+$') { throw 'Invalid public Turnstile site key' }
& $Flutter build web --target lib/admin_main.dart "--dart-define=SUPABASE_URL=$ProjectUrl" "--dart-define=SUPABASE_ANON_KEY=$PublishableKey"
if ($LASTEXITCODE -ne 0) { throw 'Admin build failed' }
# Generated public deployment configuration; no provider secret is included.
[IO.File]::WriteAllText((Join-Path $PWD 'build/web/captcha-config.js'), "window.ATLAS_TURNSTILE_SITE_KEY='$TurnstileSiteKey';")
Write-Output 'Local admin build prepared. Deployment requires separate Founder approval.'
