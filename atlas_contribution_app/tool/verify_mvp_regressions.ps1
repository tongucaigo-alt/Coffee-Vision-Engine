param([Parameter(Mandatory=$true)][string]$Flutter, [Parameter(Mandatory=$true)][string]$Dart,
  [string]$FrozenReferenceRoot)
$ErrorActionPreference = 'Stop'
$app = Split-Path $PSScriptRoot -Parent
$root = Split-Path $app -Parent
$out = Join-Path $app 'build/mvp-verification'
New-Item -ItemType Directory -Path $out -Force | Out-Null
$packages = @('atlas_contribution_app', 'coffee_camera', 'atlas_k6_end_to_end_demo',
  'atlas_canonical_json', 'coffee_symbol', 'coffee_symbol_dataset', 'coffee_source',
  'coffee_knowledge', 'coffee_knowledge_dataset', 'coffee_pattern', 'coffee_vision')
$report = @()
foreach ($package in $packages) {
  $flutterPackage = $package -in @('atlas_contribution_app', 'coffee_camera', 'atlas_k6_end_to_end_demo')
  $packageRoot = if ($FrozenReferenceRoot -and $package -ne 'atlas_contribution_app') { $FrozenReferenceRoot } else { $root }
  Push-Location (Join-Path $packageRoot $package)
  try {
    if ($flutterPackage) { $exe = $Flutter; $analyzeArgs = @('analyze', '--no-pub'); $testArgs = @('test', '--no-pub', '--reporter', 'expanded') }
    else { $exe = $Dart; $analyzeArgs = @('analyze'); $testArgs = @('test', '--reporter', 'expanded') }
    if ($packageRoot -ne $root) {
      $resolution = & $exe pub get --offline 2>&1 | Out-String
      $resolutionExit = $LASTEXITCODE
      $resolution | Set-Content -LiteralPath (Join-Path $out "$package-reference-resolution.log") -Encoding utf8
      if ($resolutionExit -ne 0) { throw "Isolated reference resolution failed: $package" }
    }
    $analyzeOutput = & $exe @analyzeArgs 2>&1 | Out-String
    $analyzeExit = $LASTEXITCODE
    $analyzeOutput | Set-Content -LiteralPath (Join-Path $out "$package-analyze.log") -Encoding utf8
    $testOutput = & $exe @testArgs 2>&1 | Out-String
    $testExit = $LASTEXITCODE
    $testOutput | Set-Content -LiteralPath (Join-Path $out "$package-test.log") -Encoding utf8
    $counts = [regex]::Matches($testOutput, '\+(\d+): All tests passed!')
    $count = if ($counts.Count) { [int]$counts[$counts.Count-1].Groups[1].Value } else { $null }
    $row = [ordered]@{package=$package; sourceRoot=$packageRoot; analyzerExit=$analyzeExit; testExit=$testExit; passed=$count}
    $report += $row
    $row | ConvertTo-Json -Compress
    $report | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $out 'regressions.json') -Encoding utf8
    if ($analyzeExit -ne 0 -or $testExit -ne 0 -or $null -eq $count) { throw "Verification failed: $package" }
  } finally { Pop-Location }
}
