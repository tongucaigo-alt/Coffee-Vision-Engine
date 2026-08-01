# Atlas K6 Research Baseline and Android End-to-End Closeout

## Status

K6 foundation and the Android physical end-to-end validation are complete.
The bundled `kds-001` remains a research baseline and does not claim production generalization.

Final decision: **ATLAS K6 RESEARCH BASELINE AND ANDROID END-TO-END INTEGRATION - VALIDATED**

## Build Fingerprint

- Validation ID: `k6_android_001`
- Date: 2026-08-01
- Device: Samsung SM-A566B
- OS: Android 16, API 36
- Application ID: `com.coffeeplatform.atlas_k6_end_to_end_demo`
- APK SHA-256: `1649738e02b2e8fcc3ccdf409ea211f43fe91d4944a80fb9374742f7d202c017`
- Dataset: `kds-001`
- Canonical and bundled dataset SHA-256: `18b65abeca6971cc98153f0c5781bcdffecb2869fc4fabb205d004f9fb372895`

## Timing Contract

The displayed duration starts after camera capture and crop generation. It includes file read, `VisionImageInput` construction, `CoffeeVisionEngine.analyzeFeatures()`, `PatternEngine.analyzePatterns()`, and `KnowledgeRecordCollectionMatcher.match()`. It is not pure Vision execution time.

## Physical Result

The complete public chain ran in the required order:

```text
Cup Capture
-> Saucer Capture
-> Cup Vision / Pattern / Knowledge
-> Saucer Vision / Pattern / Knowledge
```

| Surface | Candidates | Matched records | Duration | Observed physical result |
|---|---:|---:|---:|---|
| Cup | 1 | 0 | 966.8 ms | Candidate 1; 249 nodes; 61,752 directed edges; complete three-constraint NO MATCH result |
| Saucer | 1 | 0 | 1682.4 ms | Candidate 1; 419 nodes; 175,142 directed edges; complete three-constraint NO MATCH result |

A `NO MATCH` result is valid. The matcher preserved passed and failed atomic outcomes without filtering, ranking, confidence, interpretation, or semantic output.

## Permission and Camera Lifecycle

- First-run camera permission was displayed and manually granted by the user.
- Immediately after the permission transition, the existing camera flow required one use of its `Tekrar dene` recovery action.
- Recovery succeeded and the full cup/saucer flow completed.
- A second camera opening from the completed result succeeded on its first attempt.
- Cancelling the second opening restored the completed result.
- Camera service inspection after completion and after cancellation reported `Active Camera Clients: []`.
- The accepted observation is limited to the one-time post-permission retry. No production package was changed for it.

## Automated Verification

All commands exited with code `0`.

| Package | Analyzer | Tests |
|---|---|---:|
| `atlas_k6_end_to_end_demo` | Clean | 16/16 |
| `coffee_knowledge_dataset` | Clean | 40/40 |
| `coffee_knowledge` | Clean | 87/87 |
| `coffee_pattern` | Clean | 55/55 |
| `coffee_vision` | Clean | 357/357 |

The integration app also passed a clean format check and produced the same debug APK hash used for physical validation.

Commands:

```text
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test --reporter expanded
flutter build apk --debug --no-pub

dart analyze / dart test for coffee_knowledge_dataset
dart analyze / dart test for coffee_knowledge
dart analyze / dart test for coffee_pattern
dart analyze lib test tool / dart test for coffee_vision
```

## Frozen Package Integrity

Pre/post deterministic aggregate SHA-256 inventories were identical:

| Package | Files | Aggregate SHA-256 |
|---|---:|---|
| `coffee_vision` | 97 | `f475a08de539ceafdfdf381801b9974b438a18de3060ea7f2527486315b9bdf4` |
| `coffee_pattern` | 18 | `ef76b718c9588e16db896ab8d2751de3c441c46ea8f1bf8d71bfec9e5587e976` |
| `coffee_knowledge` | 22 | `36b06695478ef8af3dc04ced4cb358e46f0f8549808230d359b44c1aaf3fbdd1` |
| `coffee_knowledge_dataset` | 23 | `695addf77959cefd41c825dbf9ba53dcbefe381543c52a0ebb625a9cd8a4a91b` |

No Vision, Pattern, Knowledge, Dataset, threshold, algorithm, validation, baseline, dependency, or pipeline source was modified by the integration closeout.

## Evidence

- `validation_checklist.csv`: itemized device decisions
- `device_profile.txt`: device, APK, app, and dataset fingerprints
- `screenshots/cup_result.png`: complete cup result
- `screenshots/saucer_result.png`: complete saucer result
- `screenshots/camera_reopen.png`: successful second camera opening
- `ui_dumps/`: machine-readable UI evidence
- `logs/`: concise logcat and camera-resource summaries
- `evidence_sha256.txt`: immutable evidence inventory

Raw logcat and APK files remain local. This avoids committing unrelated device data and generated binaries.

## Limitations

- `kds-001` contains one minimally validated physical record. It is a research baseline, not a production-complete knowledge dataset.
- Both physical candidates correctly produced `NO MATCH`; this test validates complete composition and result preservation, not dataset recall.
- iOS physical validation is blocked pending macOS/Xcode access.
- Future dataset expansion requires additional legally usable captures and independent holdout evidence.

## Closure

K6 research infrastructure, the baseline dataset, the independent integration app, automated verification, and one Android physical flow are complete. The next architectural phase may proceed without changing the frozen physical engines.
