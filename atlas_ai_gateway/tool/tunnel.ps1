param([string]$Cloudflared = "$env:LOCALAPPDATA\AtlasAiBeta\cloudflared.exe", [int]$Port = 8787)
$ErrorActionPreference = 'Stop'
& $Cloudflared tunnel --url "http://127.0.0.1:$Port" --no-autoupdate
