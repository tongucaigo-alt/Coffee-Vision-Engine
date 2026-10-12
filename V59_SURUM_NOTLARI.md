# Atlas V59 — En güvenilir sürüm

12 Ekim 2026. Kullanıcının onayladığı güncel geliştirme referansı ve önerilen geri dönüş noktasıdır.

- Geliştirme dalı: `codex/atlas-coffee-ui`.
- Geri dönüş etiketi: `atlas-v59-en-guvenilir-surum`.
- Son telefon uygulaması: **Atlas Fotoğraf Testi V59**.

## Bu noktada tamamlananlar

- Kahve ana sayfası, fotoğraf önizleme ve şekil işaretleme ana ekranları tek ekrana sığar. Fal sonucu ve sembol penceresi kaydırılabilir kalır.
- Galeri başlangıcı boş taslakta engellenmez; fotoğraflı taslakta devam etme, yeni başlama ve vazgeçme seçenekleri bulunur. Kuyruktaki taslak ve kayıtlı fallar korunur.
- Fotoğraf öne çıkar; isteğe bağlı tabak ve fotoğraf onayı adımları tutarlıdır. Değiştir, Kaldır, Tabak çek ve Galeriden seç birlikte görünür.
- Küçük semboller, fotoğraf üzerindeki Taşı/İşaret, yatay seçim şeridi ve yalnız seçili şeklin fotoğraf üstündeki adı kullanılır.
- Referanstaki krem, kahve, bakır ve adaçayı paleti; mevcut çerçeve ve ▶ korunur. Tarama ana eylemdir; galeri sade bir bağlantıdır.
- Dolu kahve düğmeleri normal yazıda en fazla 280dp genişlikte, ortalıdır. Mevcut yükseklikleri ve dokunma alanları korunur. Büyük yazıda okunabilirlik için kullanılabilir genişlik artar. İncelenmiş fotoğrafın iki ana düğmesi arasında 8dp boşluk vardır.
- Kamera/OpenCV, uygunluk, kayıt, taslağa devam ve çift basış korumaları aynı akışla çalışır. Tarot akışı korunur.

## Doğrulama

**400 test başarılı; 6 isteğe bağlı canlı test atlandı.** Dart analizi ve diff kontrolü temizdir. 360/412 × 700 ekran, normal/iki kat yazı, 1–4 fotoğraf, kamera/galeri, tabaklı/tabaksız ve çok işaretli senaryolar test edildi.

Gerçek telefonda son düğme genişlikleri 788 fiziksel piksel olarak ölçüldü; tümü ortalıdır. Ana sayfa düğmesinin yüksekliği 157, fotoğraf onay düğmelerinin yüksekliği 135 fiziksel piksel olarak korundu. Taslak ve kayıt dosyalarının byte hashleri kurulum ve son kontroller boyunca aynı kaldı. Bu UI kontrollerinde ücretli AI üretimi başlatılmadı.

[V59 ayrıntılı rapor](docs/contribution/COFFEE_UI_V59_2026-10-12.md), [V58 renk ve hizalama raporu](docs/contribution/COFFEE_UI_V58_2026-10-12.md), [V55 galeri/akış raporu](docs/contribution/COFFEE_UI_V55_2026-10-12.md).

## GitHub APK'sı

Release varlığı **Atlas-V59-GitHub-Anahtarsiz.apk**, aynı V59 kaynaklarından oluşturulan ayrı test paketidir. Hazır Kimi/API anahtarı içermez; fal bağlantısı Ayarlar içindeki AI Laboratuvarı'ndan kendi bağlantı profili ve anahtarıyla yapılandırılır. Telefondaki hazır test bağlantılı V59 kurulumu değiştirilmemiştir.

APK, kaynak Git geçmişine eklenmek yerine GitHub Release varlığı olarak sunulur. İmzalama dosyaları, API anahtarları ve kullanıcı veri dosyaları yayımlanmaz.

Anahtarsız paketi yeniden oluşturmak için uygulama dizininde:

```powershell
flutter build apk --debug --target lib/offline_main.dart --dart-define=ATLAS_AI_LAB=true --dart-define=ATLAS_DIAGNOSTIC=true --dart-define=ATLAS_IMAGE_SCREEN=true --build-name=1.0.0-reference.59 --build-number=59
```

Paket `com.coffeeplatform.atlas_contribution_app.diagnostic`, kod 59'dur. Aynı kodlu telefondaki test uygulaması üzerine bu yayın işleminde kurulum yapılmaz. Normal uygulamanın mevcut V54 kurulumu ve verileri korunmuştur.

Yayın APK'sı: 460.993.200 bayt; SHA-256 `2f05da547c19d66708226f1e0f61aff4b0870b60165cdae612dff4658ded3d72`. [GitHub Release](https://github.com/tongucaigo-alt/Coffee-Vision-Engine/releases/tag/atlas-v59-en-guvenilir-surum) APK, iki güncel telefon ekranı, doğrulama raporu ve dosya hashlerini içerir.
