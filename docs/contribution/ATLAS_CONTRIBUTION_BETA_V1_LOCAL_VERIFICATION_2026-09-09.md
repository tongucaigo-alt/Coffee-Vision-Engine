# Atlas Contribution Beta v1 - Local Verification

Date: 2026-09-09

Status: IMPLEMENTATION CANDIDATE - LOCAL CHECKS PASS - LIVE PILOT NOT READY

Addendum: a dedicated-phone offline entrypoint was subsequently added for
Founder testing. It preserves completed revisions locally and exports a verified,
research-only ZIP to Android Downloads. This does not change the live-pilot gate.

This is an implementation self-check, not an independent freeze verdict. No
participant data, canonical Symbol record, training run, AI output or Source
admission was created. No commit, tag, push or cloud deployment was performed.

## Isolation

- Worktree: `Atlas Katki Beta`
- Branch: `feat/atlas-contribution-beta-v1`
- HEAD and locally recorded `origin/main`: `86011b4b33df787d08a9202565649bf880361fbc`
- Original worktree branch: `wip/s4-source-tree-grouping-2026-09-06`
- Original worktree HEAD: `cdda2541f995cd8e6d54d7abbe204a29f5e180b9`
- Original worktree remained clean. Existing WIP was not copied into this beta.
- New files are restricted to `atlas_contribution_app/`, `supabase/` and
  `docs/contribution/`. No tracked baseline file changed; index remains empty.
- Build outputs, local settings, APKs, screenshots, caches and installed tooling
  are ignored and excluded from the proposed Git scope.

## Implemented Candidate

- Android camera-only three-role capture using the existing camera public API.
- Explicit unchecked adult/usage consent; durable private draft, resume, retake,
  annotation, twenty-label selection, separate abstention states and queued send.
- Oriented, resized, metadata-stripped JPEG derivatives with exact upload hashes.
- Invite/anonymous-session integration, private storage, idempotent reservation and
  finalization, ownership checks, media/session limits and withdrawal handling.
- Admin email OTP/allowlist integration, linked photo boxes and rows, append-only
  reviews/corrections and research-only counts/export.
- Operator backup/hash verification, fail-closed restore planning, expiration and
  deletion maintenance tools. These tools are not scheduled or deployed.

## Executed Local Checks

All commands in this table returned exit code 0. Flutter/Dart commands use local
Flutter 3.44.6 on Windows. Paths are relative to the named package.

| Scope | Command | Result |
| --- | --- | --- |
| Contribution app | `dart format --output=none --set-exit-if-changed lib test tool` | 22 files, 0 changes |
| Contribution app | `flutter analyze --no-pub` | No issues |
| Contribution app | `flutter test --no-pub --reporter compact` | 29/29 |
| Frozen camera | `flutter test --no-pub --reporter expanded` | 86/86 |
| Supabase tests | `node database.test.mjs` | 14/14 SQL checks |
| Edge function | `deno test validation_test.ts` | 10/10 |
| Edge/operator tools | `deno check index.ts ../../tool/intake_backup.ts ../../tool/prune_backups.ts` | PASS |
| Contribution app | `flutter build apk --debug --no-pub` | APK built |
| Contribution app | `flutter build web --no-pub --target lib/admin_main.dart --output build/admin` | Admin built |
| Contribution app | `flutter build web --no-pub --target tool/preview_main.dart --output build/preview` | Synthetic preview built |
| Contribution app | `node tool/visual_check.cjs` | Edge/Playwright, no page errors at 360x800 and 412x915 |
| Contribution app | `node tool/check_frozen.cjs` | 162 protected production/document files, zero mismatches |
| Repository | `git diff --check` | PASS; tracked delta empty |

SQL checks execute the actual migration using PostgreSQL/PGlite with Auth and
Storage schema stubs. They do not prove hosted Supabase Auth, signed uploads,
RLS integration or provider operation. Edge-function type checking is not a live
end-to-end test. The rest of the engine suites were not rerun; their protected
production files were compared with the baseline and are not imported by the app.

UI widget tests cover annotation at 360/412 widths with normal and 200% text,
zoom-adjusted coordinates, twenty-label scrolling, and admin review at mobile and
desktop widths with 200% text. Actual Android rotation, TalkBack and camera
permission/lifecycle acceptance still require a device.

Web builds emit a Cupertino font-family warning from the Flutter dependency
graph. The current Material/Lucide preview icons rendered in inspected screenshots;
this is not a claim that every platform-specific widget has been visually tested.

## Exact Evidence

- Debug APK: `atlas_contribution_app/build/app/outputs/flutter-apk/app-debug.apk`
- Dedicated-phone debug APK SHA-256: `242f6e45aed5e926dcd00dbcc89202a48546ddc886de9df7d0fb8abcd42ae060`
- Protected inventory SHA-256: `08809da5943f90267792d1a1e0f42d7b07333c274ae8cd1d29373b50397a4393`
- Visually inspected screenshots: `build/ui-checks/annotation-360.png`,
  `build/ui-checks/picker-360.png`, `build/ui-checks/picker-412.png`.
- Additional screenshot: `build/ui-checks/annotation-412.png`.
- Preview URL: `http://127.0.0.1:8790/`; local synthetic image, no upload service.
- Samsung `SM_A566B` (`R5GL329BC0N`) was connected. The dedicated-phone APK
  built and installed successfully; portrait startup, unchecked consent and first
  capture entry were reached without a fatal application error. Completing three
  real captures and saving/pulling an Android Downloads export remains pending.

The debug APK is unconfigured and not a signed participant distribution build.
Screenshots and binaries are local ignored evidence, not Git artifacts.

## Required Before Invitations

1. Founder-owned Supabase and Cloudflare configuration, admin identity, Turnstile
   and explicit deployment approval. No passwords or service secrets in chat/code.
2. Hosted two-participant/admin access tests, retry and partial-upload tests, quota
   tests, revocation/export exclusion and measured cleanup/signed-URL expiration.
3. Reliable hourly cleanup, weekly private backup and daily pruning operations;
   monitored failure recovery. A paused Free project cannot guarantee a 24-hour
   deletion deadline, so the operational constraint must be resolved before intake.
4. Founder signing key, release configuration and physical Android workflow,
   offline restart, retake, deletion, rotation and accessibility acceptance.
5. Four of the first five invited adults complete the workflow without live
   coaching before the pilot expands. No participant usability trial has occurred.

The implementation does not qualify for the requested final pilot-ready status
until these live and human acceptance gates pass. See the application README for
the exact setup and operating commands.

## Follow-up: Precise Region Drag

The selected region now owns its pointer immediately, preventing the surrounding
scroll view and image gestures from consuming short drags. A central move handle
also keeps a clear movement target when corner hit areas overlap on small boxes.

- Focused annotation tests: 9/9; full app tests: 32/32; analyzer: no issues.
- Tests include 4x6 screen-pixel movement at normal/zoomed scale without page
  scrolling, short corner resize, and preservation of image-space coordinates.
- Offline debug build and `adb install -r`: exit 0 on Samsung SM_A566B.
- APK SHA-256: `dd4a39426bf15df071c8faba954f1122a680001550e03bb6166478b3f9c5df92`.
- Android drag from (540,1030) to (600,1120): screenshot move-handle bounds shifted
  exactly (60,90) pixels and retained their dimensions. Evidence is ignored under
  `build/ui-checks/drag-before.png` and `drag-after.png`.
- All seven existing private data files retained identical SHA-256 values before
  installation, after installation and after the unsaved gesture check.
- Protected inventory: 162 files, zero mismatches. No commit/tag/push.
- The real session still requires the user's `handleRight` review before local
  completion and physical ZIP export acceptance. No review choice was inferred.
