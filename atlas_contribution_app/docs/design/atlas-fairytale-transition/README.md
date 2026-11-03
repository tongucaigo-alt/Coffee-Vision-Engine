# Parchment transition from the accepted V125 opening

The accepted natural lake opening was backed up before these edits:

- Repository: https://github.com/tongucaigo-alt/Coffee-Vision-Engine
- Annotated recovery tag: `v125-natural-intro-stable`
- Commit: `352bb6cbb48b25c0c3986b8ad8f022a1a7710e05`
- Backup branch: `codex/v125-natural-intro-backup`

## Result

The last 800 ms of the existing video carry a broad parchment wash. The outer
scene disappears first; the coffee cup remains until the final portion. The
focus is (0.73, 0.48) within the contained source scene, rather than the face.
This uses the existing player and fixed composition. The head motion, water and
audio payload are preserved. See [the sky animation update](../atlas-clouds-orion/README.md)
for the new video asset. Audio gain fades over the same final
800 ms and retains the existing 0.2 peak and silent-mode rules.

Natural completion opens the existing destination through a 200 ms opacity
reveal over the exact home parchment color. There is no additional hold before
the destination. Its widgets keep their positions. Automatic six-second button
hints wait until this reveal completes, without disabling other home animation.

Tap/back skip, error/timeout fallback and background exit keep their previous
paths. Reduced motion bypasses the new transitions. Destination initialization
is unchanged; neither the home page nor guide is mounted early under the video.

## Validation — 2026-11-03

- 105 relevant Flutter tests passed; one optional legacy video export skipped.
- `flutter analyze --no-pub`: no issues found.
- Real Flutter startup renders: 360×700, 412×700, 412×892 and 700×360, at 1×/2×
  text. Half-wash, late-wash and settled home snapshots were captured.
- Tests cover cup-focused wash ordering, natural completion, audio gain, skipping, errors,
  backgrounding, reduced motion, arrival accessibility and the complete hint
  duration after arrival.
- A 24 fps preview uses actual Flutter render frames with the approved source
  video frames supplied to the media fixture. Its audio reproduces the gain
  envelope; it is a demonstration export, not a physical-device recording.
- No new APK, phone installation or push of this transition was performed.
  The remotely verified stable tag contains the pre-transition V125 backup.

Original V125 video SHA-256 (retained in the stable backup):
`7d84d7a37aadfc475a87d3467d80cede5c00fb075ea50e7a91bff7bd6e5d8a80`

Local preview and validation artifacts:
`C:/Users/exzau/Documents/Codex/2026-11-03/atlas-fairytale-transition-output/`
