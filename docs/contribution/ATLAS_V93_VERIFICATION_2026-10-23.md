# Atlas V93 — source checkpoint and phone verification

23 October 2026. This checkpoint includes the V91 gallery limits, V92 record
summary performance work, and V93 final-photo screening candidate. It preserves
the existing camera algorithm, scan effects, capture controls and crop geometry.

## Behavior

- Gallery selection allows at most three cup photos and one separate saucer.
  Replacement and recovery enforce the remaining capacity before importing.
- Record lists load grouped state/star summaries together, preserving old
  results, revision integrity checks and unreadable-state recovery.
- New cup fortune generation requires a supported final-photo assessment.
  Uncertainty, rejection, pending assessment and technical errors hold generation;
  photo annotation and save-only remain available. Existing fortunes remain readable.
- The final screen combines full-frame and visible-crop results. Optional
  automatic-capture evidence cannot override a negative view. Evidence uses a
  separate private cache; durable photo/record schemas and the camera API are unchanged.
- File content and suitability are checked again immediately before AI requests,
  including retries. No real AI generation was triggered during installation checks.

## Candidate status

**The V6 model has not passed its release acceptance gates.** The user requested
the phone update after receiving that result, so V93 was installed as a local
test build. The installation does not validate the model or change its thresholds.

| Separate desktop evaluation | Result | Required |
|---|---|---|
| Real cups directly accepted | 29/33, 87.9% | At least 90% |
| Real cups explicitly rejected | 0/33 | Zero |
| New ashtray groups explicitly rejected | 6/10, 60% | At least 80% |
| New bowl/container groups with all views rejected | 7/10, 70% | At least 80% |
| New negative groups accepted | Zero | Zero |
| Technical errors | 0/128 photos | Zero |

See [candidate methodology and limits](PHOTO_FILTER_V6_CANDIDATE_2026-10-22.md),
[frozen metadata](PHOTO_FILTER_V6_METADATA_2026-10-22.json) and
[licensed public-source inventory](PHOTO_FILTER_V6_SOURCES_2026-10-22.json).
Training/evaluation images and private device data are excluded from Git.

## Software verification

- Camera package: 132 tests passed; its 80 source/test files matched the task's
  starting file inventory.
- Related application tests with image screening enabled: 155 passed in 21 files.
  Coverage includes decision conflicts, missing/manual evidence, stale cache,
  modified photos/crops, request blocking, save-only, gallery limits, early finish,
  saucer handling, old results and V92 record-summary regressions.
- Standard full application suite: 588 passed, 15 skipped, 9 failed. The nine
  existing layout failures were reproduced in an isolated copy of V90 HEAD:
  eight large-text landing-page scroll expectations and one 16-pixel overflow
  in the default-size AI widget test. They were left unchanged.
- Application and camera static analysis: no issues. Android debug build passed.

## Phone installation

- Package: `com.coffeeplatform.atlas_contribution_app.diagnostic`
- Version: `1.0.0-kimi-test.93`, version code `93`; previously installed version `92`.
- APK SHA-256: `110ac5367d3c0464ffb385838ddafb0b648b2f92b0582a61eb62d778a5b97698`
- Model SHA-256: `73becef6afcea56138cff83acc8645dc6674fc3e9a7d33441002e18cb4a400f7`
- Same signer as the installed app; 122 previous assets and 30 native libraries
  were byte-identical. V6 is an additional model asset.
- A private local backup of 432 files was reopened and checked against every
  file hash. A second check immediately before installation matched.
- `install_preserving_data.py` independently checked package, signer and strictly
  increasing version, then used only `adb install -r`. No uninstall or data clear.
- Before opening the updated app, all 432 files were unchanged. The initial
  installation date was preserved, and the separate normal Atlas package was unchanged.
- V93 launched successfully. The live camera preview displayed an image; no black
  preview was observed. Camera was cancelled without capture/approval and the
  draft immediately before/after cancellation was identical.
- An existing ashtray photo received the expected uncertainty warning from the
  native V6 model. This is a limited device observation, not an independent
  accuracy measurement. No fortune-generation action was taken.
- Final review accounted for intervening use: one new photo and working draft,
  two screening caches and two trace caches predated our resumed camera check.
  Old photos, primary receipts, fortunes, Tarot, review revisions and profile
  files remained unchanged; no old files disappeared. Runtime markers and an
  exact primary-receipt backup rotation were separately identified.

Three-angle physical coffee-cup capture, saucer, difficult light and real fortune
generation were not retested on the phone in this installation round. No APK,
private build credentials, device backup or user photograph is included in this
Git checkpoint. No application-store release or production deployment was made.
