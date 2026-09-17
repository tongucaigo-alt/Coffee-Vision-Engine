# Atlas Motor MVP Implementation Candidate

Date: 2026-09-14

Status: IMPLEMENTED AND DIAGNOSTIC-VERIFIED; REAL-INPUT FOUNDER ACCEPTANCE PENDING.

This is an uncommitted implementation record, not a stable release, canonical
Symbol dataset, automatic symbol recognizer, or Interpretation release.

## Baseline and boundaries

- Repository: Atlas Katki Beta, branch `feat/atlas-contribution-beta-v1`.
- HEAD and local `origin/main` tracking ref:
  `86011b4b33df787d08a9202565649bf880361fbc`.
- No commit, tag, push, reset, or WIP merge was performed.
- Existing untracked beta application, contribution documents, and Supabase
  directories remain untracked. They are not all new MVP changes.
- Source Foundation and grouping WIP in the other checkout were not imported.
- Camera, Vision, Pattern, Knowledge, Symbol, their dataset packages, Source,
  canonical JSON, K6, and constitutional production contracts were not edited.
- No S01 research, canonical Tree authoring, Source assessment, admission,
  physical binding, training, ranking, confidence, winner, AI, or fortune text.
- Normal local entrypoint remains `lib/offline_main.dart`. Cloud entrypoint and
  backend acceptance are outside this delivery.

## Implemented flow

The existing contribution and annotation flows remain available. The additional
review flow is app-local and uses public engine barrels only:

```text
1-3 cup photos + optional gallery-only saucer
-> prepared JPEG and explicit user usability confirmation
-> VisionFeatureSet
-> PatternAnalysisResult
-> complete KnowledgeMatchResult list
-> complete SymbolCandidate list (currently empty / notConfigured)
-> separate user observations and candidate responses
-> versioned interpretation input, without interpretation generation
```

- Camera and gallery can be mixed. Known cup roles are user declarations;
  unknown gallery angles remain null, and a saucer is never assigned a cup role.
- Photos retain camera quality metadata when present. Gallery sharpness,
  lighting, and cup detection are not represented as measured quality.
- Analysis uses the same orientation-corrected, metadata-stripped JPEG that is
  annotated. The existing 2048-pixel preparation path is reused.
- Each photo is processed sequentially and transactionally. A failed photo does
  not publish partial engine output or prevent the remaining photos from running.
- Retry targets only a failed photo and preserves successful live result objects.
- The outcome and Symbol catalog availability are independent fields.
- The original 20 contribution labels and ten user regions per photo are reused.
  A user-selected label is never constructed as a SymbolCandidate.
- Candidate responses preserve yes/maybe/no/unanswered, original and edited
  boxes, exact run identity, and candidate exposure. Shown candidates do not
  become independent holdout observations.
- Pattern boxes are mapped out of working-image letterboxing using contentRect.
  User regions are not assigned unmeasured residue density.
- Review records have separate storage, immutable revisions, checksum envelopes,
  optimistic revision checks, and stale-photo/feedback rejection. Old contribution
  records are not migrated or bulk rewritten.
- Replacing a photo preserves the earlier revision and removes stale analysis
  from the new photo. Explicit deletion publishes a tombstone before owned-media
  cleanup. Missing media does not prevent consent withdrawal or deletion.
- Research export is a separate opt-in. ZIP output includes only current,
  consented, non-deleted reviews and exact media checksums. Revoked/deleted review
  identities remain excluded. An already exported offline copy cannot be remotely
  erased by this local-only application.
- Interpretation input separates accepted engine candidates, user observations,
  and an audit section. It contains no raw image, local file path, participant
  identity, generated meaning, or model score. With no selection the result is
  `noSelectedSymbols`; before all photos are analyzed it is `analysisPending`.

## Exact research dataset

Only `kds-001` is loaded. The asset is the exact baseline Git blob, not a new
release. `.gitattributes` disables line-ending conversion for this asset.

- Raw frozen release checksum:
  `sha256:18b65abeca6971cc98153f0c5781bcdffecb2869fc4fabb205d004f9fb372895`
- JCS canonical-content checksum, checked separately:
  `sha256:cdf0e6763c878956c061591631e869051da4cd90e17244dc4adc66c166c90595`
- No Symbol release asset is loaded, no empty fake manifest is created, and no
  synthetic binding is loaded by the normal entrypoint.
- A user observation named Tree does not bypass the canonical Tree source or
  physical-evidence gates.

## Automated verification

All final analyzer and test commands returned exit 0.

| Package | Passing tests |
| --- | ---: |
| atlas_contribution_app | 90 |
| coffee_camera | 86 |
| atlas_k6_end_to_end_demo | 56 |
| atlas_canonical_json | 44 |
| coffee_symbol | 33 |
| coffee_symbol_dataset | 55 |
| coffee_source | 23 |
| coffee_knowledge | 87 |
| coffee_knowledge_dataset | 100 |
| coffee_pattern | 55 |
| coffee_vision | 357 |

App tests include the existing contribution suite, new models/store/engine/
feedback tests, and 360x800 and 412x915 layouts at normal and 200% text scaling.
Positive Symbol branches are injected only in tests. This does not demonstrate
real canonical Symbol detection on camera images.

Commands, from the application directory:

```powershell
dart format --output=none --set-exit-if-changed lib test integration_test test_driver
./tool/verify_mvp_regressions.ps1 -Flutter <flutter.bat> -Dart <dart.bat> -FrozenReferenceRoot <isolated-baseline>
node tool/check_frozen.cjs
git diff --check
```

Format checked 39 Dart files, with zero changes. Protected comparison checked
162 files against the baseline, with no mismatches. Its inventory SHA-256 is
`08809da5943f90267792d1a1e0f42d7b07333c274ae8cd1d29373b50397a4393`.

### Frozen regression environment limitation

The active Windows checkout has pre-existing line-ending/lockfile issues: K6's
lockfile references camera 0.0.1 while the package is 0.1.0, some boundary tests
expect LF metadata, and the KDS test expects exact Git fixture bytes. The raw
Windows CRLF copy of that fixture hashes to
`3a51b5c94948dcd5b7457396762e764fc1e8cb01afd37c7473bcaa38715c558e`.

An initial K6 enforced-lockfile resolution failed, and an initial isolated KDS
run reported 99/100 because of the fixture line endings. No frozen files in the
active checkout were repaired. Final frozen regressions ran in the external
`C:/Users/exzau/.codex/verification/atlas-mvp-frozen-20260914` copy of 86011b4,
with exact Git metadata/fixture bytes and offline dependency resolution confined
to that copy. The 90 app tests ran in the active application. These results must
not be described as a clean enforced-lockfile run in the active frozen checkout.

Final per-package logs and command exit codes are in ignored
`atlas_contribution_app/build/mvp-verification/`.

## Physical Android evidence

- Device: Samsung SM_A566B, serial R5GL329BC0N, Android 16.
- Build fingerprint:
  `samsung/a56xnatur/a56x:16/BP4A.251205.006/A566BXXSDCZHB_OXMDCZHB:user/release-keys`.
- M0 gesture verification: 17 gesture cases plus teardown, 18 reported passes,
  using the separate diagnostic application and a verified backup.
- Final MVP diagnostic: two cases plus teardown, three reported passes.
- First case: generated test image through the actual physical engine pipeline,
  noMatch, zero Pattern/Knowledge/Symbol candidates, one separate test-only Tree
  user observation, and interpretation-input status ready.
- Second case: test-only three-photo input with a middle-photo technical error,
  successful retry, exact successful-result preservation, and durable reload.
- Neither case is a real camera capture or real Tree recognition claim.
- Diagnostic screenshots were visually inspected. The flat photo in them is the
  deliberately uniform generated test image, not a failed photo renderer.

Build and run commands:

```powershell
flutter build apk --debug --no-pub -t integration_test/mvp_device_test.dart
python tool/run_verified_diagnostic.py --flutter <flutter.bat> --adb <adb.exe> --aapt <aapt.exe> --apk build/mvp-diagnostic-final-verified.apk --sha256 2aabb1c2a9ba2c9f6605b500d8e66a28efaadaba411932ad3629decb591ec59e --target integration_test/mvp_device_test.dart --serial R5GL329BC0N --backup-dir <new-external-backup>
flutter build apk --debug --no-pub -t lib/offline_main.dart
adb -s R5GL329BC0N install -r <verified-normal-apk>
adb -s R5GL329BC0N shell am start -W -n com.coffeeplatform.atlas_contribution_app/com.coffeeplatform.atlas_contribution_app.MainActivity
```

All build, guarded diagnostic, install, and launch exit codes were 0. The guarded
runner uses the pre-inspected binary with `flutter drive
--use-application-binary`; it does not rebuild an APK during device testing.

| Artifact | Package / SHA-256 |
| --- | --- |
| Diagnostic APK | `com.coffeeplatform.atlas_contribution_app.diagnostic` |
| Diagnostic APK hash | `2aabb1c2a9ba2c9f6605b500d8e66a28efaadaba411932ad3629decb591ec59e` |
| Local normal APK | `com.coffeeplatform.atlas_contribution_app` |
| Normal APK hash | `41a94975f5f24fbe9bb5e23317a5c6385400d82abec2453d7c1ac6a7ed3c3197` |
| Verified pre-update backup hash | `71b689575adacafa9a84d7d632c71bbc54f0a925b2d6ef939e4e3fc80b44d256` |

Backups and local restore-rehearsal inventories are outside Git under
`C:/Users/exzau/.codex/backups/atlas-contribution/`:

- `mvp-m0-20260913-01`
- `mvp-diagnostic-20260914-01`
- `mvp-diagnostic-20260914-02`
- `mvp-normal-update-20260914-01`

Each accepted backup contains 12 files and passed byte-for-byte restore rehearsal.
Both MVP diagnostic runs left all normal-app files unchanged. Normal installation
used only install-r; all 12 files were unchanged immediately after installation.
After launch, only Android runtime `profileInstalled` and `ActivityThread.IDS.xml`
changed. All existing contribution metadata, photos, and image-picker preferences
remained unchanged. No normal-app uninstall, clear-data, or restore was performed.

The normal app launched successfully with zero fatal/Flutter errors in its captured
process log. Its home screenshot confirms the new review entrypoint and the old
saved contribution remain visible. This debug APK is for the dedicated phone,
not a signed external distribution release.

## Exact MVP change scope

The ignored `build/mvp-m0-inventory-2026-09-13.json` captures 829 starting files
including the M0 diagnostic harness. Its SHA-256 is
`da1543e7cdafdc71fd1464f6affa5b6157fa645235253224322ca9e67e55f4e8`.
The final per-file before/after inventory is `build/mvp-verification/scope.json`.
It is a comparison with that M0 inventory, not with a falsely clean beta checkout.

New paths, all under `atlas_contribution_app/` except the final document:

- `.gitattributes`
- `assets/mvp/knowledge_dataset.json`
- `integration_test/mvp_device_test.dart`
- `lib/src/mvp/review_controller.dart`
- `lib/src/mvp/review_engine.dart`
- `lib/src/mvp/review_gallery.dart`
- `lib/src/mvp/review_models.dart`
- `lib/src/mvp/review_page.dart`
- `lib/src/mvp/review_store.dart`
- `test/mvp_review_test.dart`
- `test/mvp_review_widget_test.dart`
- `tool/verify_mvp_regressions.ps1`
- `docs/contribution/ATLAS_MOTOR_MVP_IMPLEMENTATION_2026-09-14.md` (repository root)

Changed application paths relative to the M0 inventory:

- `lib/offline_main.dart`
- `lib/src/contribution_home.dart`
- `lib/src/gallery_import.dart`
- `pubspec.yaml`
- `pubspec.lock`
- `test/package_boundary_test.dart`
- `test_driver/diagnostic_driver.dart`
- `tool/run_verified_diagnostic.py`

The diagnostic driver and guarded runner were prepared during M0, before the
inventory, and subsequently extended for MVP evidence. No existing file was
removed. Build outputs, logs, screenshots, and APKs remain ignored; private backups
remain external. `git diff --check` alone does not check untracked beta contents,
so format checks and the separate hash inventory are also required evidence.

## Remaining acceptance

Implementation and automated/diagnostic verification are complete. Founder
acceptance with actual camera/gallery photos is still pending: select/capture,
confirm usability, annotate, analyze, reopen the saved review, and confirm the
existing contribution flow remains usable. A dedicated normal-app screen-reader
walkthrough and real-input usability are not implied by widget test passes.

Do not publish the final ready verdict or a stable tag before that acceptance.
Commit, tag, push, cloud publication, canonical Symbol release, and Interpretation
remain separate Founder decisions.
