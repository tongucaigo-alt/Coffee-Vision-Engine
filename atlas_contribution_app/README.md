# Atlas Katki Beta v1

Implementation candidate. AI test capability is available only with `ATLAS_AI_LAB=true` in the separate `.beta` package. Signed distribution and remote acceptance must be verified before participant rollout. See [AI setup and validation](../atlas_ai_gateway/README.md). No training, canonical Symbol release or frozen engine changes.

## Beta 8 — Sade akış ve yıldızlar

[Sürüm doğrulaması](SIMPLE_FLOW_VALIDATION.md): tek seferlik yerel kullanım kabulü, deneysel çevrimdışı fotoğraf kontrolü, 20 yıldız, manuel saklama ve sade fal akışı. [Model kaynağı](PHOTO_MODEL.md). Fotoğraf engellemesinin olumsuz örnek kabulü ve kör anlatım değerlendirmesi henüz tamamlanmadı.

## Atlas visual refresh — September 2026

The local entrypoint now uses bundled Atlas artwork and fonts, a cream/coffee/sage
theme, and Home / Records / Settings navigation. Capture and annotation run
without the bottom navigation. Three-angle capture saves each photo before opening
the next camera; cancel or a failed save stops at the missing angle. Confirmation
is tied to each exact photo and is passed to the existing linked Review before
local analysis. Saving observations does not submit an AI request.

Records retain separate clean photos and normalized annotations. The existing
single-photo gallery review remains available with its three-photo fortune
requirement explained. AI settings, research tools and export are under Settings.
Fortune presentation does not rewrite saved answers or change the AI prompt.
Credits, accounts, rituals and audio playback are not implemented by this refresh.

Build the signed test package with:

```powershell
flutter build apk --release --target lib/offline_main.dart --dart-define=ATLAS_AI_LAB=true --build-number=2
```

See [UI validation](UI_VALIDATION.md) for the tested scope and outstanding device acceptance.

## Entrypoints

- `lib/main.dart`: Android participant app. Missing configuration shows a non-uploading setup screen.
- `lib/offline_main.dart`: dedicated-phone collection and verified ZIP export. Without the AI test define it uses no network. With `ATLAS_AI_LAB=true`, explicit fortune actions send only the validated text context to the selected AI endpoint; photographs remain local.
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


### Hazır Kimi test bağlantısı

Test APK'sı isteğe bağlı `ATLAS_KIMI_TEST_KEY` derleme tanımıyla hazırlanabilir.
Anahtar kaynak dosyalara veya Git'e yazılmaz. `ATLAS_AI_LAB=true` ve bu tanım,
repo dışındaki özel JSON dosyasından `--dart-define-from-file=<private-file>` ile
alınır. Yalnız bu test derlemesinde `Atlas · Kimi Test` profili ilk sıraya eklenir;
mevcut profiller ve kayıtlar korunur. Profilin adresi, modeli ve anahtarı kullanıcı
arayüzünden düzenlenmez. Anahtar profile, fal metnine veya araştırma ZIP'ine yazılmaz.
APK içindeki anahtar teknik incelemeyle çıkarılabilir; bu yöntem yalnız izin verilen
geçici test dağıtımı içindir.

Sabit hedef: `https://api.moonshot.ai/v1`, model: `kimi-k2.6`.
Kimi isteğinde `thinking.type=disabled`, sıcaklık `0.6` kullanılır; Qwen'e özel
`/no_think` metni gönderilmez. Mevcut metinsel veri sınırı ve prompt korunur.
Telefon internet gerektirir; bilgisayarın/LM Studio'nun açık olması gerekmez.

Normal testler gerçek API çağırmaz. Bakiye gerektiren yapay örnek testi açıkça:
`flutter test test/kimi_live_test.dart --dart-define-from-file=<private-file> --dart-define=ATLAS_KIMI_LIVE_TEST=true`
ile çalıştırılır. Test iki yapay bağlamı (işaretsiz ve kullanıcıya ait kuş işareti) dener; yalnız
yapay yanıt metnini ve güvenli sonuç metadatasını `build/kimi-live-validation.json`
dosyasına yazar. Anahtar veya istek başlıkları kaydedilmez. Üretim başarısı için bu testin geçmesi gerekir; model listesinde
görünmesi yeterli değildir.


## Yerel araştırma ZIP'i ve kayıt durumu — 22 Eylül 2026

Ayarlar → Araştırma Paketini Dışa Aktar, tamamlanmış yerel katkı/galeri
kayıtlarını `atlas-katki-…zip` olarak kaydeder. İnceleme Araçları → İzinli
incelemeleri dışa aktar, Review kayıtlarını `atlas-reviews-…zip` olarak kaydeder.
Android 10 ve üstünde dosyalar telefonun **İndirilenler** klasöründedir;
eski Android sürümlerinde uygulamaya ait İndirilenler konumu kullanılır.
Fotoğraflar temizdir; işaretler JSON içindeki normalize kutular ve etiketlerdir.

Her iki yol app cache altında ZIP oluşturur ve Android'e aynı mevcut kanal
üzerinden verir. Bağlı katkının tüm revizyonları, bağlı Review'un güncel araştırma
iznine tabidir. İzin geri çekilmiş veya kayıt silinmişse dışa aktarılmaz.
Bu kontrol AI kapalıyken de çalışır. Hazırlık sırasında izin/silme/kayıt değişirse
paket yayımlanmadan durdurulur. İzin eksikliği ile bozuk dosya veya kaydetme
hatası ayrı mesajlarla gösterilir; hata mesajı özel dosya yolu içermez.
Araştırma izni fal almanın koşulu değildir.

Kayıt ekranı kaydetme ile yerel analiz aşamasını ayırır. Analiz hatasında
kaydedilmiş kayıt korunur; aynı kayıttan incelemeye devam edilir. `queued`
yalnız kurtarma işaretidir, tek başına “Kaydı Yeniden Dene” göstermez.

Paylaşılan `fortune-prompt-v1.json` dosyasının iç sürümü artık
`atlas-fortune-prompt-v2`'dir. Gateway de aynı dosyayı okur; dosya adı eski
entegrasyonları bozmamak için korunmuştur. Yanıt kontrolü güvenli metinsel bağlamı
kullanır. Boş işaret listesi, fincanda şekil bulunmadığının kanıtı sayılmaz.
Geçersiz yanıt için en çok bir düzeltme istenir; ikinci yanıt da geçersizse
hikâye olarak gösterilmez. Bu kontroller tüm model ifadelerini yakalama garantisi
vermez; eski kayıtlı fallar değiştirilmez.

Gerçek Android dışa aktarma testi (yalnız yapay kayıtlarla, `.diagnostic`):
`../atlas_ai_gateway/tool/test-device.ps1 -Device <adb-serial> -Export`

Betik önce APK kimliğini doğrular ve beta verisini kaldırmadan tanı testini
çalıştırır. Test iki gerçek Android indirmesini geri okuyup doğrular; tanı
uygulamasının oluşturduğu indirmeleri temizler. Yapay ZIP kanıt kopyaları yalnız
tanı uygulamasının `files/export-validation` dizininde kalır. Kullanıcı beta
kayıtları, izinleri ve indirmeleri bu test tarafından değiştirilmez.

## Galeri ve isteğe bağlı tabak — 26 Eylül 2026

Galeri 1–3 fincan fotoğrafını tek kayıtta toplar. Açı varsayılan olarak
belirtilmemiştir; kullanıcı seçebilir. Üç açı önerilir, fal için zorunlu değildir.
Kamera mevcut üç açı sırasını korur. Her iki yolun ardından bir tabak çekilebilir,
galeriden eklenebilir veya bu adım atlanabilir. Tercih taslakta saklanır.
Tek fotoğrafta yalnız kullanılabilirlik, çoklu sette ayrıca aynı fincan/tabak
teyidi istenir. İşaretleme isteğe bağlıdır; kayıt ve fal isteği ayrı eylemlerdir.

Yeni `photoSet` kayıtları ve bunları içeren katkı ZIP'leri sürüm 4 kullanır.
Fotoğrafların kalıcı kimlikleri, kaynakları, fincan/tabak türleri ve açıları
ayrıdır. Eski kayıtlar yeniden yazılmaz; düzenleme yeni revizyon üretir.
Fotoğraf ekleme/değiştirme önceki falın güncelliğini kaldırır; ilk gözlemi değiştirmez.
Fotoğraflar temiz kalır, işaretler ayrı koordinat verisidir.

Ortak prompt'un güncel iç sürümü `atlas-fortune-prompt-v3` olur. APK ve gateway
1–3 fincan + 0–1 tabak kabul eder; yalnız tabak veya kullanılabilir verisi olmayan
istek engellenir. Gateway kaynakları APK ile birlikte güncellenmelidir.
Gerçek modelin dil kontrolüne takılması bağlantı hatası değildir; uygunsuz yanıt
bir düzeltmeden sonra hâlâ geçersizse sonuç olarak gösterilmez.

Yapay kayıtlarla cihaz kabulü:
`../atlas_ai_gateway/tool/test-device.ps1 -Device <adb-serial> -PhotoSet`

Tek fincanlı canlı model denemesi için mevcut opt-in test komutuna
`--dart-define=ATLAS_KIMI_LIVE_CUPS=1` eklenebilir. Bu ücretli testi varsayılan
test çalıştırması yapmaz; anahtar özel define dosyasından okunur.

## Zengin fal girdisi ve tarama — 27 Eylül 2026

Yeni ana eylem `Kaydet ve Falını Oluştur`; `Yalnız Kaydet` seçeneği korunur.
Yerel analiz mevcut motorun bölge/bileşen verilerini `atlas-fortune-context-v2`
bağlamına aktarır. Fotoğraflar telefonda kalır. Son beş fal üzerinden yerel
anlatı çeşitlendirmesi, gerçek aşamalara bağlı tarama ekranı ve toplam bir
düzeltme sınırı uygulanır. Prompt iç sürümü `atlas-fortune-prompt-v4` olur.

Gateway kaynakları da birlikte güncellenmelidir. Teknik doğrulama, canlı model
sınırlamaları ve bekleyen telefon/12 fincan kabulü için
[RICH_FORTUNE_VALIDATION.md](RICH_FORTUNE_VALIDATION.md) dosyasına bakın.
