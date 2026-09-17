# Atlas Contribution - Annotation Modes and Gallery

Date: 2026-09-10

Status: IMPLEMENTED - LOCAL CHECKS PASS - EXISTING DEVICE DATA PRESERVATION FAILED

This is not a freeze or pilot acceptance record. No commit, tag, push, cloud
deployment, model training or canonical Symbol admission was performed.

## Implemented behavior

- Separate Photo and Mark modes outside the photograph. Photo mode pans and
  pinches even with an active region; Mark mode moves/resizes only the region.
- Removed the opaque central arrow and the in-photo text badges. Selected labels
  are shown in the external list. Image navigation does not modify annotations.
- Zoom buttons preserve the viewport-center scene point; fit resets only the view.
- Photo viewport is outside the scrolling action panel, preventing page scrolling
  from consuming image pan gestures.
- Offline-only Android single-image gallery flow via image_picker 1.2.3.
- Durable pending picker state, lost-result recovery, transactional replacement,
  cancellation preservation, orientation-baked metadata-free JPEG derivatives.
- Gallery records have no angle or invented capture time. Import time is explicit.
  Physical independence remains unverified. Legacy three-angle JSON is unchanged.
- Export version 2 carries both record types with exact file hashes. Gallery uses
  gallery.jpg, not a fabricated top/left/right role. The shared 30-record limit is
  not reset by exporting. Cloud upload rejects gallery records locally.

## Verification

- App tests: 47/47, including ten annotation widget tests and gallery storage,
  recovery, quota, checksum, export and 360x800 / 412x915 / 200-percent text tests.
- Camera regression: 86/86.
- Flutter analyzer: no issues.
- Formatter check and git diff --check: exit 0.
- All 728 tracked baseline files SHA-256-identical to the start of this work.
- Physical Samsung SM_A566B: test-only isolated gallery import, annotation, image
  pan while a box is selected, label selection and durable local completion PASS.
- Native Android Photo Picker cancellation PASS on the second test run.
- First native-picker test expected cancellation but received a real selection;
  that run failed its expectation and is not counted as a successful import test.
- Second device test run: 2/2 PASS, but its runner cleanup violated the user-data
  preservation requirement described below. Functional PASS does not override it.

## Device data incident

The agent ran flutter test on a physical phone using the contributor application's
normal package identity, without first taking a complete restorable backup.
Flutter's integration runner uninstalled that APK at cleanup. The package was
subsequently absent, including from pm list packages -u.

Before the first test there were seven private files: three JPEGs, draft.json,
draft.bak, receipts.json and receipts.bak. The receipts were empty. The agent had
recorded SHA-256 values but not the file contents. Hashes are not a backup.

No restorable app-data archive or Downloads export was found in the inspected
project evidence or the phone's Downloads directory. The three-photo local draft
could not be recovered. Its preservation must not be claimed. The user was told
about the incident and the agent's failure to back up before testing.

## Prevention and remaining acceptance

android/app/build.gradle.kts now gives integration_test targets the distinct
application ID com.coffeeplatform.atlas_contribution_app.diagnostic. A built test
APK was inspected with aapt and this distinct identity was verified without
installing or running it. Normal offline builds keep their original identity.

Future device verification must inspect the APK application ID before installing,
use a separate diagnostic package, and take/verify a restorable private-data backup
before any operation on a phone containing participant data. Do not run an
integration test against the normal contributor package.

The normal offline application was rebuilt separately and installed with adb
install -r (exit 0). Its original package identity was verified using aapt, and
am start -W returned Status: ok. The initial empty home screen was visually
inspected; gallery selection is visible. This restores the application, not its
lost local draft.

Normal debug APK SHA-256:
4fdf766524bbf7bb9bcea8aa2c77683e0e45edc971e23f41648f5544b3555c33

A fresh
real gallery selection/annotation/save acceptance with the user remains necessary;
existing records must not be reconstructed or labeled as if recovered.

Changes are confined to the uncommitted contribution app (including app-local
Android test isolation and plugin registration), its tests, and this report.
Frozen engine packages, the previous WIP worktree and Supabase schemas are untouched.
