# Atlas Katki Beta v1

Implementation candidate. **Not deployed or approved for participant distribution.** No AI, fortune interpretation, training, canonical Symbol release or engine changes.

## Entrypoints

- `lib/main.dart`: Android participant app. Missing configuration shows a non-uploading setup screen.
- `lib/offline_main.dart`: dedicated-phone collection. It uses no invite, cloud or network and exports verified ZIP files to Android Downloads.
- `lib/admin_main.dart`: Flutter Web admin, e-mail OTP and server allowlist.
- `tool/preview_main.dart`: synthetic local UI preview without auth/backend/upload. Never distribute as the beta.

Only `../coffee_camera` is imported from Atlas. The application ID is `com.coffeeplatform.atlas_contribution_app`; K6 remains independent.

## Dedicated-phone offline collection

This mode is for one Founder-controlled Android phone. Completed sessions and
their metadata-stripped JPEG derivatives stay in private application storage
until they are deleted. `Paketi dışa aktar` writes a research-only ZIP to Android
Downloads containing each revision, its three exact photos, a file checksum
inventory and a package checksum shown on screen. Copy the ZIP and displayed
checksum together. The ZIP is not encrypted; protect it after export and remove
old copies from Downloads when they are no longer needed.

```powershell
flutter build apk --release --target lib/offline_main.dart
```

The same Founder keystore rules below apply. The local mode is capped at thirty
independent root sessions. Revisions of an existing physical sample keep their
own records and do not consume another root slot. Local completion is not a cloud
submission, canonical evidence decision or training admission.

## Local verification

```powershell
flutter pub get
dart format --output=none --set-exit-if-changed lib test tool
flutter analyze
flutter test --reporter expanded
flutter build apk --debug
flutter build web --target lib/admin_main.dart --output build/admin
node tool/check_frozen.cjs
```

From `../supabase/tests`: `npm ci`, then `npm test`. From `../supabase/functions/contribution-api`:

```powershell
../../tests/node_modules/.bin/deno.cmd check index.ts ../../tool/intake_backup.ts ../../tool/prune_backups.ts
../../tests/node_modules/.bin/deno.cmd test validation_test.ts
```

PGlite executes the actual SQL migration with Auth/Storage schema stubs. It does not replace hosted integration tests. UI screenshots come from a local `tool/preview_main.dart` web build served at `127.0.0.1:8790`; `tool/visual_check.cjs` uses Playwright and ignored `build/ui-checks`. Set `PLAYWRIGHT_MODULE` when Playwright is outside Node's normal search path.

## Founder-owned cloud setup

No deployment has been performed. Each step below requires separate deployment approval.

1. Create a dedicated Supabase Free project; keep paid upgrades off. Apply `../supabase/migrations/202609090001_contributions.sql` through the authorized CLI/dashboard.
2. Enable anonymous Auth and Turnstile protection. Put the Turnstile secret only in Supabase Auth; the public site key goes in the CAPTCHA page. Keep e-mail self-signup disabled.
3. Provision the Founder admin Auth user, then add its exact UUID to `intake_admins` via the server/dashboard. Configure the e-mail OTP template to show `{{ .Token }}`. Client code cannot grant admin access.
4. Generate up to ten unpredictable private invite codes of 8-16 uppercase letters/digits/hyphens. Store only their SHA-256 hex in `intake_invites`. Each code binds to one anonymous account and expires after thirty days. Reinstallation/account loss requires Founder support.
5. Deploy `contribution-api` with gateway JWT verification disabled as configured. The function itself calls `auth.getUser()` for every user request. Set exact `ADMIN_ORIGIN` and random 32+ character `MAINTENANCE_SECRET`; never put service/maintenance secrets in Flutter.
6. Build the admin with `tool/build_admin.ps1`: Flutter executable, HTTPS project URL, public client key and public Turnstile site key. Publish only the generated `build/web` directory to Founder-owned Cloudflare Pages after approval. No domain purchase is needed. Allow the Pages hostname in Turnstile.
7. Use its HTTPS `/captcha.html` URL for Android configuration. `tool/build_android.ps1` builds `lib/main.dart` in release mode by default; `-DebugBuild` is technical-only. Both build wrappers reject service-role keys.

References: [anonymous Auth](https://supabase.com/docs/guides/auth/auth-anonymous), [CAPTCHA](https://supabase.com/docs/guides/auth/auth-captcha), [private Storage](https://supabase.com/docs/guides/storage/buckets/fundamentals), [signed upload lifetime](https://supabase.com/docs/reference/javascript/file-buckets-createsigneduploadurl), [pricing](https://supabase.com/pricing).

## Operations required before invitations

- Store `atlas_project_url` and `atlas_maintenance_secret` in Supabase Vault. Apply `../supabase/tool/schedule_maintenance.sql` once, checking for an existing job first. It invokes cleanup hourly.
- Monitor cron execution **and** HTTP status/body. A successful SQL job is not proof that cleanup succeeded. The operator retry is `../supabase/tool/maintenance.ps1` with `ATLAS_MAINTENANCE_SECRET` in its environment.
- A paused/unreachable Free project cannot guarantee a wall-clock deletion SLA. The Founder must accept and monitor this constraint before data collection, and intervene before the 24-hour active-store deletion target is missed.
- Schedule `intake_backup.ts backup EXTERNAL_PRIVATE_DIRECTORY` weekly on a reliable Founder-controlled machine. Use service credentials only in the operator process, protect the directory with OS access controls/encryption, and keep the printed manifest hash separately.
- Run `prune_backups.ts EXTERNAL_PRIVATE_DIRECTORY` at least daily. With operator credentials it checks current withdrawals as well as expiry. Review incomplete backups promptly rather than retaining them indefinitely.
- Run `intake_backup.ts verify-restore SNAPSHOT_DIRECTORY` before any proposed restore. It checks hashes/current tombstones and changes nothing. Missing live state fails closed. Database-loss recovery requires a separately verified current deletion ledger and Founder decision; never import historical backups wholesale.
- Operator Deno commands use the config in `../supabase/functions/contribution-api/deno.json`. Limit filesystem permissions to the chosen external backup directory. No schedules have been installed by this task.
- Upload tokens can remain valid for two hours; cleanup rechecks purged paths. Read links expire after sixty seconds. Already downloaded copies cannot be recalled.
- The 600 MiB cap covers this application's media/reservations, not unrelated buckets, Auth traffic, egress or provider billing. Keep the project dedicated and monitor the $10 monthly ceiling. There is no automatic paid upgrade.

## Signing and acceptance

Keep the Founder keystore outside Git. Supply ignored `android/key.properties` with `storeFile`, `storePassword`, `keyAlias`, `keyPassword`. Release builds fail rather than falling back to debug signing. Record the APK SHA-256 and signing-certificate identity before distribution. The unconfigured local debug APK is not a participant build.

Live Android acceptance: three captures, cancel, retake cancel/replace, process restart, same-cup recapture, offline send/retry, withdrawal and TalkBack. Hosted acceptance with two participants/admin: cross-account access denied, partial uploads hidden, idempotent finalization, forged admin rejected, quota enforcement, deletion/export exclusion, signed URL expiry and actual cleanup within 24 hours.

First usability gate: four of the first five participants finish capture/annotation/submission after installation without live coaching. Fix difficult steps before expanding to ten. This user trial has not happened.

See `../docs/contribution/ATLAS_CONTRIBUTION_BETA_V1_SCOPE_2026-09-09.md`. All changes remain uncommitted and research-only.
