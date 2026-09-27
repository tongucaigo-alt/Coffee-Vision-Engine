param([string]$Config = "$env:LOCALAPPDATA\AtlasAiBeta\gateway.json", [string]$NodePath = (Get-Command node -ErrorAction Stop).Source)
$ErrorActionPreference = 'Stop'
$env:ATLAS_AI_CONFIG = $Config
& $NodePath (Join-Path $PSScriptRoot '..\server.mjs')
