# Atlas M6 Device Validation Closeout

## 1. Milestone and Build Fingerprint
- Milestone: Atlas-01 M6 Camera Integration
- Device: Samsung SM-A566B, Android 16, API 36
- Package: com.coffeeplatform.atlas_m6_camera_vision_demo
- Installed artefact: ARM64 debug split, SHA-256 7eb50ae479b86a7a7d5d96c6591ff2572ab227d7a0f6647df6c07b9f83fd19c5
- Final rebuilt universal APK: SHA-256 3eaad32188c6a2138ae196738ff960eeeed5e8789b9a39073e7be44a90ee9edd

## 2. Timing Contract
Displayed cup and saucer durations include file read, VisionImageInput construction, and CoffeeVisionEngine.analyzeDetailed(). They exclude camera capture and crop generation and are not pure engine execution times.

## 3. Android Device Matrix
One authorized physical Android device was validated: Samsung SM-A566B on Android 16/API 36.

## 4. Checklist Results
- PASS: 18
- NOT RUN: 3 approved physical fault-injection cases with passing automation
- BLOCKED: 1 iOS environment item
- FAIL: 0

## 5. End-to-End Sequence
Three direct runs completed the normative sequence: Cup Capture -> Saucer Capture -> Cup Analysis -> Saucer Analysis. Both full VisionPipelineResult objects and separate durations were rendered.

## 6. Automated Failure Evidence
Cup failure stopping saucer, saucer failure preserving cup, and saucer-only retry remain NOT RUN physically. Their named controller tests passed in the 26/26 demo suite. No debug fault injection was introduced.

## 7. Resource and Lifecycle
Cup and saucer camera background/resume, analysis background/resume, cancellation, physical rotation and route disposal were exercised. Camera service reported no active client after exit and cancellation. No fatal exception or ANR was found.

## 8. Frozen Package Integrity
- coffee_camera: 177 pre/post hashes, 0 differences; analyze clean; 85/85 tests.
- coffee_vision: 84 pre/post hashes, 0 differences; analyze clean; 284/284 tests.
No planned or unplanned production-package change occurred.

## 9. Verification Commands
- dart format --output=none --set-exit-if-changed . : PASS, 9 files, 0 changed
- flutter analyze : PASS
- flutter test --no-pub --reporter expanded : PASS, 26/26
- flutter build apk --debug --no-pub : PASS
- coffee_camera flutter analyze/test : PASS, 85/85
- coffee_vision dart analyze/test : PASS, 284/284

## 10. iOS Status
BLOCKED - physical iOS validation requires macOS/Xcode. Per the approved closeout rule, this does not block Android M6 stability.

## 11. Failures, Blockers, and Deviations
- No reproducible integration defect was found.
- Physical fault injection was not run and was not inferred as physical PASS.
- Universal APK ADB transfer was interrupted; the ARM64 debug split was installed and tested.
- Initial format verification encountered a stale generated build path and sandbox telemetry access. The generated demo build directory was cleaned; no source changed.
- iOS remains blocked by environment.

## 12. Artefacts
Validation evidence is stored under validation/device/m6_android_001. Only validation artefacts and generated build outputs were created during closeout.

## 13. Final Decision

M6 — STABLE
