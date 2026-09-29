param(
    [Parameter(Mandatory)][string]$Device,
    [switch]$RealAi,
    [switch]$RemoteAi,
    [switch]$Export,
    [switch]$PhotoSet,
    [switch]$RichFortune,
    [switch]$SimpleFlow,
    [string]$Flutter = "$env:LOCALAPPDATA/FlutterSdk/3.44.6/flutter/bin/flutter.bat",
    [string]$Aapt = "$env:LOCALAPPDATA/Android/Sdk/build-tools/36.0.0/aapt.exe"
)
$ErrorActionPreference = 'Stop'
$app = (Resolve-Path (Join-Path $PSScriptRoot '../../atlas_contribution_app')).Path
Push-Location $app
try {
    if (($RealAi -and $RemoteAi) -or ($Export -and ($RealAi -or $RemoteAi))) { throw 'Choose one diagnostic test mode.' }
    if ($PhotoSet -and ($RealAi -or $RemoteAi -or $Export)) { throw 'Choose one diagnostic test mode.' }
    if ($RichFortune -and ($RealAi -or $RemoteAi -or $Export -or $PhotoSet)) { throw 'Choose one diagnostic test mode.' }
    $target = if ($SimpleFlow) { 'integration_test/simple_flow_device_test.dart' } elseif ($RichFortune) { 'integration_test/rich_fortune_device_test.dart' } elseif ($PhotoSet) { 'integration_test/photo_set_device_test.dart' } elseif ($Export) { 'integration_test/export_device_test.dart' } elseif ($RemoteAi) { 'integration_test/ai_remote_device_test.dart' } else { 'integration_test/ai_device_test.dart' }
    $defines = @('--dart-define=ATLAS_AI_LAB=true', '--dart-define=ATLAS_DIAGNOSTIC=true')
    if ($RealAi) { $defines += '--dart-define=ATLAS_REAL_AI_TEST=true' }
    # Flutter reads the existing APK's identity BEFORE it builds the listener.
    # Seed that cache with a diagnostic APK; never with the distribution beta.
    & $Flutter build apk --debug --target $target @defines
    if ($LASTEXITCODE -ne 0) { throw 'Diagnostic prebuild failed.' }
    $badging = & $Aapt dump badging build/app/outputs/flutter-apk/app-debug.apk
    if ($LASTEXITCODE -ne 0 -or -not ($badging -match "^package: name='com.coffeeplatform.atlas_contribution_app.diagnostic' ")) {
        throw 'Refusing device test: APK identity is not diagnostic.'
    }
    & $Flutter test $target --no-pub --no-uninstall -d $Device @defines
    if ($LASTEXITCODE -ne 0) { throw 'Diagnostic test failed; inspect the test output.' }
} finally { Pop-Location }
