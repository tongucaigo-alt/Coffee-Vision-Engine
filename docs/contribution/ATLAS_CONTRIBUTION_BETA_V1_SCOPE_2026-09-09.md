# Atlas Contribution Beta v1

Status: IMPLEMENTATION CANDIDATE - NOT FROZEN - LIVE PILOT NOT OPEN

## Authority and baseline

Founder approved the Atlas Katki Beta v1 plan in this task. Work starts at
`86011b4b33df787d08a9202565649bf880361fbc`, on
`feat/atlas-contribution-beta-v1`, in a separate worktree. The existing
`wip/s4-source-tree-grouping-2026-09-06` branch is not changed or merged.
No commit, tag, push, account creation, paid service or external deployment is included in this checkpoint.

## Scope

- Separate Android app and Flutter Web administrator entrypoint in `atlas_contribution_app`.
- Frozen public `coffee_camera` reused for one capture per attempt. No K6 or engine imports.
- Roles: top, handleRight, handleLeft. Durable private draft and transactional replacement.
- Three photos per completed session; zero to ten normalized regions per photo.
- Twenty research labels in `atlas_contribution_app/assets/contribution-labels-v1.json`.
- No canonical Symbol IDs, SourceRef, admission, binding, interpretation or model training.
- A label is an independent participant observation, not a proven detection.
- Region uncertainty, photo uncertainty, no shape seen and skipped photo stay distinct.
- Group identity is participant-declared. Same-cup recapture is not an independent sample.
- Admin review/corrections append separately; submitted user documents are not overwritten.

## Data lifecycle

Adult and research-use permission are explicit, initially unselected checkboxes. Draft creation after both approvals records the consent version/time. Every photo must be reviewed or explicitly skipped, but no shape label is required.

The camera image is decoded, oriented, resized to at most 2048 pixels on its long edge and re-encoded to a fresh JPEG without EXIF metadata. Original input and derivative checksums are distinct. Coordinates refer to the exact displayed/uploaded derivative; no pixel-identical claim is made.

Interrupted uploads reuse an immutable reservation. Only full verification of all three JPEG decodes, byte lengths, dimensions and SHA-256 values permits submitted status. Queued drafts cannot be edited in place. Submitted edits create a new revision.

Limits: ten enrolled participants, three completed sessions each, thirty completed sessions total, ten regions per image, 5 MiB per image and 600 MiB including reserved uploads. Superseded/pending data remains charged conservatively. These are usability pilot limits, not training sufficiency.

Withdrawal immediately excludes the root from live review/export and creates a tombstone. Already issued private read links expire within sixty seconds; downloaded copies cannot be recalled. Hourly active-media cleanup must meet a monitored 24-hour operational maximum. Expiry is 180 days from root creation; revisions do not extend it. Local drafts/receipts expire too.

Weekly backups belong in a Founder-owned private external directory. Daily pruning removes expired/withdrawn data and refreshes hashes. Restore verification requires current project state and tombstones; missing current membership is a denial. No automatic restore is provided. Minimal withdrawal IDs prevent resurrection until affected backups are retired.

## Live acceptance still required

PGlite tests execute actual PostgreSQL rules with minimal Auth/Storage stubs. They do not prove hosted Supabase Auth, CAPTCHA, Storage or scheduling. No cloud project, admin e-mail, signing key or Android device was available for live acceptance during this checkpoint.

Before invitations: live cross-account/abuse/deletion tests; monitored cleanup and backup schedules; configured signed APK; Android capture/cancel/retake/restart/offline/TalkBack verification; then four of the first five people must complete the flow without live coaching. Stop expansion if this usability gate fails.

Supabase Free inactivity or outage can interrupt cleanup. The Founder must monitor and resolve this operational constraint before collecting data. Neither cloud availability nor a wall-clock deletion SLA is claimed by local tests.

The target READY FOR CONSENTED COLLECTION AND REVIEW status is not yet granted.
S01 source work, the original PDF, WIP Source contracts and the deterministic engine are not advanced by this beta.
