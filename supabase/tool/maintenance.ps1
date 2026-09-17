param([Parameter(Mandatory=$true)][string]$ProjectUrl)
$ErrorActionPreference = 'Stop'
if (-not $ProjectUrl.StartsWith('https://') -or $env:ATLAS_MAINTENANCE_SECRET.Length -lt 32) { throw 'HTTPS project and operator maintenance secret required' }
$result = Invoke-RestMethod -Method Post -Uri "$ProjectUrl/functions/v1/contribution-api" -Headers @{ Authorization = "Bearer $env:ATLAS_MAINTENANCE_SECRET" } -ContentType 'application/json' -Body '{"action":"maintenance"}'
$result | ConvertTo-Json -Compress
