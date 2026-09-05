# Atlas K6 End-to-End Validation

Independent Flutter validation app for the frozen physical processing chain:

```text
Coffee Camera
-> CoffeeVisionEngine.analyzeFeatures()
-> PatternEngine.analyzePatterns()
-> KnowledgeRecordCollectionMatcher.match()
-> SymbolCandidateResolver.resolve()
-> complete physical and Symbol-candidate results
```

The app requires approved cup and saucer captures and processes cup before
saucer. It bundles a byte-identical deployment copy of the frozen `kds-001`
research baseline.

The bundled Symbol bundle uses only explicit `test-*` identities. It is a
definition-only technical fixture with no binding and is not a real Symbol
release. Non-empty Symbol paths are verified with synthetic bindings in tests.

## Result Boundary

The UI displays Pattern candidate identities, topology counts, physical
constraint outcomes, matched Knowledge record IDs, aggregate outcome, and all
eligible Symbol candidates. It does not rank, select a winner, interpret,
generate fortune meaning, calculate confidence, or invoke AI.

The aggregate result distinguishes `NO MATCH`, `INSUFFICIENT SYMBOL EVIDENCE`,
and `SYMBOL CANDIDATES AVAILABLE`. Processing exceptions remain a separate
technical error state.

`kds-001` contains one minimally validated physical record authored from cup
observations. Results are research evidence and do not claim production
readiness. Saucer results exercise the same generic physical contract but are
not independent proof of dataset generalization.

## Timing

Each displayed surface duration starts after camera capture and crop creation.
It includes file read, Vision feature extraction, Pattern extraction,
Knowledge collection matching, and Symbol projection. It is not pure Vision
Engine execution time.

## Verification

The guided three-angle capture and angle-local engine experience runs from a
separate target:

```text
flutter run -t lib/three_angle_main.dart
```

It processes `top`, `handleRight`, and `handleLeft` sequentially through the
same app-local surface processor. Each angle keeps its complete physical and
Symbol-candidate result. It does not fuse, deduplicate, rank, select a winner,
or claim interpretation output. The bundled definition-only Symbol fixture has
no binding, so a non-empty Symbol result is not expected from real captures.

Android diagnostic evidence uses a separate, visibly marked test-only target.
The fixture is disabled unless one of these explicit scenarios is selected:

```text
flutter run -t lib/three_angle_diagnostic_main.dart \
  --dart-define=ATLAS_THREE_ANGLE_DIAGNOSTIC_SCENARIO=mixed-outcomes

flutter run -t lib/three_angle_diagnostic_main.dart \
  --dart-define=ATLAS_THREE_ANGLE_DIAGNOSTIC_SCENARIO=technical-retry
```

These scenarios inject synthetic angle results at the app-local
`processSurface` boundary. They do not inspect the captured image, create a
canonical release, or prove real Symbol recognition.

```text
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test --reporter expanded
flutter build apk --debug --no-pub
```

Physical validation requires an authorized Android device. Complete one full
cup and saucer flow, then confirm the final screen shows both surfaces, every
Pattern candidate, all three constraint outcomes, and the dataset version.
Until an admitted real binding exists, a physical match must remain
`INSUFFICIENT SYMBOL EVIDENCE` rather than being presented as a real symbol.
