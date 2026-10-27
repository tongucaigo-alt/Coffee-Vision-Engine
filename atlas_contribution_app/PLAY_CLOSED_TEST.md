# Atlas — mevcut deneyimi koruyarak Play hazırlığı

26 Ekim 2026. V101 (`49d4b57`) tabanı. Bu belge yerel hazırlıktır; mağaza veya canlı hizmet kabulü değildir. Önceki V12/V93 test/kurulum belgeleri tarihsel kanıttır.

## Güncel kapsam

Kullanıcı mevcut fotoğraf filtresini yeterli kabul etti. Yeniden eğitim/veri hazırlığı veya eski %90/%80 kalite hedefleri yayın ön koşulu olarak açılmaz. Model, eşikler, `suitabilityBlockingValidated`, ön işleme ve yeni üretim öncesi yeniden kontrol değişmez. 29/33 (%87,9) yalnız ilgili tarihsel fincan ölçümüdür; genel doğruluk iddiası değildir.

Kahve/Tarot arayüzü, efektler, ses/video, kamera/galeri ve kayıt davranışı korunur. Araştırma ZIP'i ve yedi günlük otomatik silme yoktur. Kullanıcı onayı olmadan görünür metin veya yeni adım eklenmez.

## Release hazırlığı

- Giriş: `lib/offline_main.dart`; `ATLAS_PLAY_TEST=true` ve mevcut filtre için **`ATLAS_IMAGE_SCREEN=true`**.
- Kimlik: `com.coffeeplatform.atlas_contribution_app`; diagnostic/beta kimlikleri ayrı. Kullanıcı verisi taşıma veya telefon kurulumu bu hazırlığın kapsamında değil.
- Laboratuvar, gömülü sağlayıcı anahtarı, diagnostic/önizleme kimliği Play release için kabul edilmez. Özel Kimi defines dosyası build girdisi değildir.
- Mevcut imza kullanılır. `ATLAS_SIGNING_PROPERTIES` Gradle proje özelliği harici özel properties dosyasına işaret edebilir; değerler komut satırına basılmaz. Yerel `android/key.properties` desteği de sürer. Anahtar oluşturma/sıfırlama veya debug imzaya dönüş yoktur.
- `tool/build_play_candidate.ps1` yalnız yerel imzalı AAB adayı üretir. Sürüm numarası açıkça verilir; çıktı klasörü yeni olmalıdır. PublicConfig yalnız işletmeci/gizlilik/destek metinlerini kabul eder. Gerçek bilgiler uygulamaya yansıtılmadan görünür içerik etkisi kullanıcıya onaylatılmalı.
- Flutter release hazırlığı dev-only `integration_test` kaydını doğru üretmelidir; stale debug registrant yüzünden `--no-pub` ile build yapılmaz. Üretim bağımlılığı veya kullanıcı akışı değişmez.

Yerel aday örneği (nihai mağaza sürümü tahsisi değildir):

```powershell
./tool/build_play_candidate.ps1 -Flutter flutter -BuildNumber 101 `
  -BuildName 1.0.0-play-prep.101 `
  -SigningProperties "$env:LOCALAPPDATA/AtlasAiBeta/key.properties.backup" `
  -OutputDirectory C:/AtlasLocalOutput/new-play-preparation
```

## Önceden var olan Play bağlantı akışı

Play profili mevcut Ayarlar → Atlas Test Bağlantısı ekranını kullanır: HTTPS adresi ve kişiye özel erişim kodu. V101 diagnostic paketindeki hazır Kimi profiliyle aynı bağlantı deneyimi değildir. Bu fark kullanıcıya bildirildi; yeni giriş veya otomatik token edinme tasarlanmadı. Mevcut adımla kapalı test veya başka yayın hizmeti kararı kullanıcıda. Mağazadaki genel kullanıcı deneyimi onaylanmış sayılmaz.

## Gateway ve bildirimler

Kahve/Tarot ayrı sözleşmelerle aynı yetkili kuyruğu kullanır. Rapor yalnız açık onayla `version/id/reason/text` içerir; sunucu kalıcı kaydı teyit eder. Ağ/disk hatası teslim sayılmaz. Doğrudan sağlayıcı rapor alıcısı değildir. Gerçek Atlas alıcısı, kalıcı HTTPS, insan incelemesi, saklama/silme ve destek sorumluları işletmeci tarafından kurulmalı. Yerel testler canlı dağıtımı kanıtlamaz.

## Bekleyen gerçek bilgiler ve kabul

Kullanıcı 26 Ekim'de Play hesabı ile gerçek işletmeci/destek/politika bilgilerinin olmadığını, sağlayıcı/hosting'i seçmediğini ve ücretlendirmeyi düşündüğünü bildirdi. Ücretsiz/reklamsız/ücretli varsayımıyla yeni özellik eklenmedi. `xxxx@atlas.com` taslaktır.

Nihai Console paket/sürüm/sertifika eşleştirmesi, kamuya açık politika/Data Safety, inceleyici erişimi, moderasyon, fiyat/yaş/derecelendirme kararları bekliyor. Mevcut API 36 hedefi nihai artefaktta kontrol edilir. Yeni AAB üzerinde ELF ve paket 16 KB kontrolleri/indirme tahmini yapılır; gerçek 16 KB çalışma zamanı, küçültülmüş native modelin cihazda çalışması ve Play ön lansmanı ayrı kabul bekler.

Test/cihaz işlemleri gerçek kullanıcı paketinde `flutter test` otomatik kurulumu, kaldırma veya veri temizlemeyle yapılmaz. Bu işte telefon, gerçek kullanıcı verisi, canlı/ücretli AI, hosting satın alma, push/release veya mağaza gönderimi yoktur.

Tüm güncel çıktı ve taslaklar kullanıcı çalışma alanındaki `GOOGLE_PLAY_HAZIRLIK` klasöründedir. Resmî kaynaklar: [API koşulları](https://support.google.com/googleplay/android-developer/answer/11926878?hl=en), [Data Safety](https://support.google.com/googleplay/android-developer/answer/10787469?hl=en), [AI bildirimi](https://support.google.com/googleplay/android-developer/answer/13985936?hl=en), [16 KB denetimi](https://developer.android.com/guide/practices/page-sizes).
