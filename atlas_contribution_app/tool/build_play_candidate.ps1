#requires -Version 7.0
<#
Build a local Play preparation candidate without changing the application UI.
Only public support/privacy values may be supplied. Existing signing material
stays outside the checkout; no key generation, installation or upload occurs.
#>
param(
    [string]$Flutter = 'flutter',
    [Parameter(Mandatory=$true)][ValidateRange(1,2100000000)][int]$BuildNumber,
    [Parameter(Mandatory=$true)][ValidatePattern('^[0-9A-Za-z.+-]+$')][string]$BuildName,
    [Parameter(Mandatory=$true)][string]$SigningProperties,
    [string]$PublicConfig,
    [Parameter(Mandatory=$true)][string]$OutputDirectory
)
$ErrorActionPreference = 'Stop'
$app = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$signingPath = (Resolve-Path -LiteralPath $SigningProperties).Path
$destination = [IO.Path]::GetFullPath($OutputDirectory)
if (Test-Path -LiteralPath $destination) { throw 'Use a new output directory to preserve previous evidence.' }
$defines = @('--dart-define=ATLAS_PLAY_TEST=true', '--dart-define=ATLAS_IMAGE_SCREEN=true')
$publicValues = @{}
if ($PublicConfig) {
    $configuration = Get-Content -LiteralPath $PublicConfig -Raw | ConvertFrom-Json -AsHashtable
    if ($configuration -isnot [Collections.IDictionary]) { throw 'Expected a public JSON object.' }
    $allowed = @('ATLAS_OPERATOR_NAME', 'ATLAS_PRIVACY_URL', 'ATLAS_SUPPORT_URL', 'ATLAS_SUPPORT_EMAIL')
    foreach ($name in $configuration.Keys) {
        if ($name -notin $allowed -or $configuration[$name] -isnot [string]) {
            throw 'Only public operator/privacy/support strings are allowed; private test defines must never be supplied.'
        }
        $publicValues[$name] = $configuration[$name]
        $defines += "--dart-define=$name=$($configuration[$name])"
    }
}
New-Item -ItemType Directory -Path $destination | Out-Null
$previousSigning = $env:ORG_GRADLE_PROJECT_ATLAS_SIGNING_PROPERTIES
$env:ORG_GRADLE_PROJECT_ATLAS_SIGNING_PROPERTIES = $signingPath
Push-Location $app
try {
    # Flutter's normal build preparation regenerates the release plugin
    # registrant without dev-only integration_test. --no-pub skips that step.
    & $Flutter build appbundle --release --target lib/offline_main.dart `
        "--build-name=$BuildName" "--build-number=$BuildNumber" @defines *> (Join-Path $destination 'build.log')
    if ($LASTEXITCODE -ne 0) { throw 'Play candidate build failed; inspect the local build log.' }
    $artifact = Join-Path $destination 'Atlas-Play-Preparation.aab'
    Copy-Item -LiteralPath (Join-Path $app 'build/app/outputs/bundle/release/app-release.aab') -Destination $artifact
    [ordered]@{
        purpose = 'Local preparation only; not authorized or ready for store submission'
        buildNumber = $BuildNumber; buildName = $BuildName
        package = 'com.coffeeplatform.atlas_contribution_app'
        playProfile = $true; imageScreen = $true; aiLab = $false; diagnostic = $false
        bundledProviderCredential = $false; readyForSubmission = $false
        publicConfiguration = $publicValues
        sha256 = (Get-FileHash -LiteralPath $artifact -Algorithm SHA256).Hash.ToLowerInvariant()
    } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $destination 'build.json') -Encoding utf8
    Write-Output 'Local Play preparation AAB built. Signing identity, native compatibility, public configuration and Console acceptance still require verification.'
} finally {
    Pop-Location
    if ($null -eq $previousSigning) { Remove-Item Env:ORG_GRADLE_PROJECT_ATLAS_SIGNING_PROPERTIES -ErrorAction SilentlyContinue }
    else { $env:ORG_GRADLE_PROJECT_ATLAS_SIGNING_PROPERTIES = $previousSigning }
}
