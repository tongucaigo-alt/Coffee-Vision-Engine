# Atlas K6 End-to-End Validation

Independent Flutter validation app for the frozen physical processing chain:

```text
Coffee Camera
-> CoffeeVisionEngine.analyzeFeatures()
-> PatternEngine.analyzePatterns()
-> KnowledgeRecordCollectionMatcher.match()
-> structured physical match results
```

The app requires approved cup and saucer captures and processes cup before
saucer. It bundles a byte-identical deployment copy of the frozen `kds-001`
research baseline.

## Result Boundary

The UI displays Pattern candidate identities, topology counts, physical
constraint outcomes, and matched Knowledge record IDs. It does not produce
symbols, interpretation, ranking, confidence, fortune meaning, or AI output.

`kds-001` contains one minimally validated physical record authored from cup
observations. Results are research evidence and do not claim production
readiness. Saucer results exercise the same generic physical contract but are
not independent proof of dataset generalization.

## Timing

Each displayed surface duration starts after camera capture and crop creation.
It includes file read, Vision feature extraction, Pattern extraction, and
Knowledge collection matching. It is not pure Vision Engine execution time.

## Verification

```text
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test --reporter expanded
flutter build apk --debug --no-pub
```

Physical validation requires an authorized Android device. Complete one full
cup and saucer flow, then confirm the final screen shows both surfaces, every
Pattern candidate, all three constraint outcomes, and the dataset version.
