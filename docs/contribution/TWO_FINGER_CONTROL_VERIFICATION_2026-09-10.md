# Two-Finger Photo Control - 2026-09-10

Status: LOCAL VERIFICATION PASS; ANDROID ACCEPTANCE BLOCKED.
No commit, tag, push, dependency or frozen engine change was made.

## Implementation

One viewport pointer manager owns photo and region interaction. One finger
pans in Photo mode and edits regions in Mark mode. Two fingers pan and pinch
in either mode. A second finger rolls back tentative region edits; a remaining
finger cannot resume region editing until every pointer is lifted. Scale remains
1..4. Buttons, Fit and normalized stored coordinates are preserved.

Current-turn file scope, relative to atlas_contribution_app unless noted:

- lib/src/annotation_page.dart
- test/annotation_widget_test.dart
- test/annotation_multitouch_test.dart
- integration_test/multitouch_device_test.dart
- tool/backup_device_data.py
- android/app/build.gradle.kts
- test/package_boundary_test.dart
- docs/contribution/TWO_FINGER_CONTROL_VERIFICATION_2026-09-10.md (repository root)

Earlier beta work remains untracked and is not attributed to this change.

## Local Evidence

- `flutter test --no-pub --reporter expanded`: 65/65, exit 0.
- Camera `flutter test --no-pub --reporter expanded`: 86/86, exit 0.
- App and Camera `flutter analyze --no-pub`: no issues, exit 0.
- `dart format --output=none --set-exit-if-changed lib test integration_test`:
  29 files, zero changes, exit 0.
- Camera/gallery gesture cases include both modes, first and second pointer
  inside/corner/outside, rollback, early lift, cancellation and mode switch.
- Existing viewport/text cases include 360x800, 412x915 and text scale 2.0.
- `node tool/check_frozen.cjs`: 162 protected files, zero mismatches against
  86011b4b33df787d08a9202565649bf880361fbc; inventory SHA-256
  08809da5943f90267792d1a1e0f42d7b07333c274ae8cd1d29373b50397a4393.
- `git diff --check`: exit 0. Tracked Git diff remains empty.

## Backup and Device Safety Incident

Device: Samsung SM_A566B, serial R5GL329BC0N.
Normal package: com.coffeeplatform.atlas_contribution_app.

Before any device installation, the complete application files/shared_prefs
archive was captured outside the repository and restored into a temporary local
directory. All 10 restored file hashes matched the device inventory.

Backup directory:
`C:\Users\exzau\.codex\backups\atlas-contribution\two-finger-pre-update-20260910-01`

Archive: application-data.tar
SHA-256: 44b3faef470091598be696f0621121ac16fb0a79ebd82d204887c05df0a83a71
Per-file inventory and restore result: verification.json in the same directory.

The first diagnostic build failed at packageDebug (exit 1); a verbose retry
succeeded (exit 0) without source/dependency correction. aapt verified the built
APK as com.coffeeplatform.atlas_contribution_app.diagnostic.

However, the following command rebuilt a DIFFERENT APK using a generated
flutter_test_listener target outside integration_test/:

`flutter test --no-pub --no-uninstall integration_test/multitouch_device_test.dart -d R5GL329BC0N --reporter expanded`

The old target-path guard therefore selected the NORMAL application ID. The
normal app was replaced with the test build. Test loading failed with connection
closed and a host temporary listener PathNotFoundException (exit 1). No device
gesture result passed. This violated the intended test identity boundary despite
the earlier APK check; prechecking a different build was insufficient.

Device writes were stopped once discovered. No uninstall/clear command was
issued. A read-only comparison confirmed all 7 offline-contributions files,
including the photograph, draft and receipts, are byte-identical to backup.
The complete inventory is NOT identical: Android's
shared_prefs/android.app.ActivityThread.IDS.xml is absent (9 vs 10 files).
All other backed-up files match. No backup restore was attempted.

## Local Remediation and Pending Device Work

Gradle now uses a fail-closed production-entrypoint allowlist: only lib/main.dart
and lib/offline_main.dart (including absolute forms) may use the normal ID.
All other targets, including generated listeners, get .diagnostic. A source
boundary regression test guards this policy. Device re-verification remains due.

Both rebuilt APKs were inspected locally with aapt and copied into ignored build/:

- `flutter build apk --debug --no-pub -t integration_test/multitouch_device_test.dart`
  exit 0; diagnostic ID verified; build/multitouch-diagnostic-verified.apk
  SHA-256: 6fbdf44ebb79f25212d25824e8443855e1c2b5c80be87d3bf32d53e034aa0227.
- `flutter build apk --debug --no-pub -t lib/offline_main.dart`
  exit 0; normal ID verified; build/multitouch-offline-verified.apk
  SHA-256: 4bad1daf5e8a7f359ac1dd81f8aeb15ae0a2c56167659eff09089793e75bec0c.

Neither remediated APK has been installed. Founder approval is required to resume
device operations after the safety stop. First recheck/refresh the backup, then
restore the normal entrypoint using only `adb install -r` on the verified normal
APK and compare contribution hashes. Any automated diagnostic run must use the
exact inspected APK, without an implicit unverified rebuild. Android gesture
acceptance and the normal-app update are NOT complete.

## Founder-Approved Normal App Recovery

Following explicit Founder approval, USB authorization was restored and a fresh
read-only backup with local restore rehearsal passed for all 10 files:

`C:\Users\exzau\.codex\backups\atlas-contribution\two-finger-normal-restore-20260910-01\application-data.tar`

SHA-256: 25a4fa355b51921b456e49e2e70029f9feca4ab90228dbe095dc06a03740c698.

The previously built offline APK was rechecked against its exact SHA-256 above
and its normal package identity. No rebuild or automatic Flutter test was used.

`adb -s R5GL329BC0N install -r build/multitouch-offline-verified.apk`

Result: Success, exit 0. All 10 backed-up files matched immediately after install.
Launching the normal MainActivity with `adb shell am start -W -n` succeeded.
Final launch: Status ok, TotalTime 1859 ms, exit 0, live process PID 25319.
The inspected process log contained Flutter startup/VM-service messages and no
Flutter error or AndroidRuntime fatal exception.

After launch, all 7 offline-contributions files remained byte-identical,
including the photograph, draft, gallery record and receipts. The full 10-file
inventory was not byte-identical: files/profileInstalled and
shared_prefs/android.app.ActivityThread.IDS.xml changed. These differences are
reported separately from the unchanged contribution data; nothing was restored
over them or deleted.

Normal application recovery/update is complete. Gesture tests on the physical
device remain unverified; local test evidence is unchanged. No new automated
device test, uninstall, data clear, commit, tag or push was performed during
this recovery.
