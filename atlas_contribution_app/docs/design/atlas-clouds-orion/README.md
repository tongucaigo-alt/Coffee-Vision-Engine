# Calm sky motion and a coffee-focused exit

3 November 2026. The user requested gentle cloud movement, twinkling of the
existing constellation nodes and the parchment exit centered on the coffee.

The new six-second, 1080×2400, 24 fps video starts from the accepted V125 video.
It adds local flow to broad cloud tones while retaining the fine engraving
and fixed star coordinates. Cloud drift is 9 source pixels per second (about
20 logical pixels over six seconds in the 412-pixel preview). Seven existing
constellation stars dim and brighten at staggered times over a 2.9-second cycle,
with a soft warm halo and brief narrow rays. The first scheduled peak is at
1.35 seconds, after the opening reveal. Existing water highlights receive a very
faint response. No new constellation or duplicate reflection is drawn.

The camera remains fixed. Head movement, cup, leaves, steam, landscape and moon
are preserved from V125. The original AAC packets are copied without re-encoding;
there is still one player and one audio stream. First/last posters come from the
new decoded video, keeping the same composition as playback.

The parchment wash is now centered at normalized source coordinates (0.73, 0.48),
on the coffee cup. A rendered pixel regression checks that the face is already
parchment while coffee is still visible late in the transition. Timing and the
gentle home reveal remain the same. Camera/AI/Tarot/storage flows are unchanged.

Recovery point: GitHub tag `v125-natural-intro-stable`, commit
`352bb6cbb48b25c0c3986b8ad8f022a1a7710e05`. The prior preview and local V125
assets are retained. No phone installation or APK generation is part of this edit.

Video SHA-256:
`e15f77248e438a42f702d8e8b8ba5f88bcc102ae3e89a075c4c7aa149ac8fea4`

Unchanged AAC payload SHA-256:
`1eabbae4a275c3b56a0c92d3055f3bec35fd804ecb53d05db3e2f02eed0018d3`

Render/validation artifacts and actual Flutter preview:
`C:/Users/exzau/Documents/Codex/2026-11-03/atlas-visible-sky-motion-output/`

Validation of the transition code: 105 relevant Flutter tests passed (one
optional legacy export skipped), and `flutter analyze --no-pub` reported no
issues. The stronger sky pass changes only the video/poster assets and this note;
the application Dart sources and approved cup transition are byte-for-byte
unchanged. Actual Flutter renders cover
the stronger pass as well; 54 opening/transition tests passed again (one optional
legacy export skipped). A before/after sky comparison at the actual 412-pixel
render scale is retained beside the new preview. The render matrix includes
360×700, 412×700, 412×892 and 700×360 with normal/double text. The standalone
video decodes to 144 frames. Measured peaks of the seven existing nodes occur
at different times; cloud-tone motion is present in decoded frames. Head/cup/moon
regions are identical to V125 before encoding; decoded differences are bounded
to the expected video re-encoding change. AAC payload hashes match exactly.
