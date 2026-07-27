# Atlas M6 Android Observations

## Environment
- Device: Samsung SM-A566B
- Android: 16 (API 36)
- Serial: R5GL329BC0N
- Package: com.coffeeplatform.atlas_m6_camera_vision_demo
- Physical validation date: 2026-07-22

## Timing Contract
Displayed durations start after camera capture and crop generation. They include file read, VisionImageInput construction, and CoffeeVisionEngine.analyzeDetailed(). They exclude camera capture and crop generation and are not pure engine execution times.

## Direct Observations
- First permission grant opened the cup camera. Denial produced the controlled permission screen; Settings grant plus Retry recovered.
- Cup ring, residue effect, crop preview, retake and automatic capture were exercised. Correct alignment auto-captured. A farther alignment showed the effect but did not auto-capture because ready conditions were not met.
- Saucer overlay, residue points, preview, retake and mandatory stage transition were exercised.
- Three complete flows produced successful cup and saucer results.
- Run 1 durations: cup 896.2 ms, saucer 1360.2 ms.
- Run 2 durations: cup 658.6 ms, saucer 541.3 ms.
- Run 3 durations: cup 657.5 ms, saucer 810.8 ms.
- Rapid repeated capture taps produced one operation.
- Background/resume was exercised in cup camera, saucer camera, and immediately after final approval while analysis continued.
- Physical landscape rotation proposed ROTATION_270 while the app remained portrait ROTATION_0.
- Back from saucer preserved cup preview; full cancellation returned to idle.
- Post-success, post-cancel and final camera dumps had no active camera client.

## Automated Evidence
Physical failure injection was not added. The following passing tests are the approved evidence:
- cup failure prevents saucer analysis
- saucer failure preserves successful cup result and duration
- retry after saucer failure reruns only saucer

## Reliability Notes
- The first recorded run showed an extended saucer capture-in-progress interval before eventual success. It did not reproduce as a failure in the next two complete runs.
- The universal APK transfer was interrupted by an unstable ADB cable connection. The equivalent ARM64 debug split installed successfully. A final universal debug APK was rebuilt after validation.
- Logcat contained no application fatal exception or ANR.

## Integrity
- coffee_camera: 177 hashed files, 0 differences; analysis clean; 85/85 tests passed.
- coffee_vision: 84 hashed files, 0 differences; analysis clean; 284/284 tests passed.
- Demo: format 0 changed; analysis clean; 26/26 tests passed; debug APK built.
- No source, algorithm, threshold, pipeline, validation, dataset, manifest, or baseline file was changed.
