# Atlas V65 — Tuş konumları ve kullanıcı deneyimi

13 Ekim 2026. V62–V65 kahve akışı ve ekran düzeni değişikliklerinin GitHub yayını.

- **Fotoğraflarına Bak → Sen ne görüyorsun?** akışı doğrudandır. Ayrı “Tabaksız devam et” adımı kaldırıldı; **Değiştir · Tabak ekle · Kaldır** ilk inceleme ekranındadır. Tabak için Kamera/Galeri seçilir; iptal veya hata mevcut fotoğrafları korur.
- İki sayfa aynı büyük fotoğraf çerçevesini ve kadrajı kullanır. Kontrol/seçim ve yazı ölçeği değişimleri fotoğrafı küçültmez. Gezinme okları fotoğrafın kenarlarında, sayaç alt ortadadır. Diziliş araçları kaldırıldı; fotoğraf sırası korunur.
- **Açı seç** inceleme başlığı ile fotoğraf arasındaki boşluktadır. Fotoğraf üzerindeki krem kontrol yüzeyleri ve sayaç küçültüldü; dokunma alanları en az 48dp kaldı.
- Şekil sayfasında **Taşı / İşaret** başlığın altındadır ve eski birleşik kapsül görünümünü kullanır. Başlık ve fotoğraf konumu değişmedi; kontrol geri okunun dokunma alanıyla çakışmaz. Sığdır simgesi daha belirgindir; parmakla yakınlaştırma sürer.
- Şekil seçimi yatay şerittir; seçili kutu vurgulanır, düzenleme eylemleri yalnız seçim varken görünür. Ana eylemler altta görünür kalır. Normal ve büyük yazıda ana sayfalarda dikey kaydırma eklenmez.
- Aynı fincan onay kutusu kaldırıldı. Fotoğraf uygunluk değerlendirmeleri bağımsız olarak korunur.
- Üçlü kamera çekiminde ilk onaylanmış fotoğraf kaydedildikten sonra **Çekimi bitir** kullanılabilir. Bir/iki fotoğrafla devam edilir; daha sonra eksik açılar eklenebilir. Kayıt hatasında kamera kapanmaz; çift basış tek işlem çalıştırır. Kamera kaynağı ve işaretler korunur.

## Doğrulama

Son uygulama çalışmasında **421 test geçti**, 6 isteğe bağlı canlı test atlandı. Değişen kamera paketinin **97 testi geçti**. Kod analizi ve diff kontrolü temiz.

360/412 × 700 ekranlarda normal/iki kat yazı, 1–4 fotoğraf, boş/seçili/çok işaretli durumlar; fotoğraf sınırlarının eşitliği, menü ölçüleri, gezinme, dokunma alanları, şekil düzenleme, taslağa devam ve çift basışta tek kayıt/üretim doğrulandı.

Gerçek telefonda ayrı, AI çağrısı yapmayan önizleme paketinde normal/büyük yazı, Taşı/İşaret geçişleri, sığdırma, gezinme ve geri dönüş kontrol edildi. V65 kullanıcı test uygulamasına aynı imzayla kuruldu; taslak/kayıt byte hashleri ve normal uygulama bilgileri korundu. Medya ve erken bitirme akışlarının başarılı durumları dosya işleyen widget/kamera testleriyle doğrulandı; telefon önizlemesindeki kamera/galeri iptalleri test yanıtlarıdır. Ücretli AI çağrısı yapılmadı.

Taslağın isteğe bağlı `captureSequenceFinished` alanı eski kayıtlarda `false` okunur; veri göçü gerekmez. Tarot, fal sonucu, logo ve tarama animasyonu bu yayındaki çalışmanın dışında kaldı.

[V62 akış raporu](docs/contribution/COFFEE_UI_V62_2026-10-13.md), [V63 ortak düzen ve kamera raporu](docs/contribution/COFFEE_UI_V63_2026-10-13.md), [V64 kontrol ölçüleri](docs/contribution/COFFEE_UI_V64_2026-10-13.md), [V65 şekil sayfası](docs/contribution/COFFEE_UI_V65_2026-10-13.md).

## GitHub APK'sı

**Atlas-V65-GitHub-Anahtarsiz.apk** aynı kaynaklardan oluşturulan ayrı test paketidir. Hazır API/Kimi anahtarı içermez. Fal bağlantısı Ayarlar → AI Laboratuvarı bölümünde kullanıcının kendi profili ve anahtarıyla yapılandırılır. Paket `com.coffeeplatform.atlas_contribution_app.diagnostic`, sürüm `1.0.0-reference.65`, kod 65. Telefondaki özel bağlantılı V65 bu yayın sırasında değiştirilmez.

```powershell
flutter build apk --debug --no-pub --target lib/offline_main.dart --dart-define=ATLAS_AI_LAB=true --dart-define=ATLAS_DIAGNOSTIC=true --dart-define=ATLAS_IMAGE_SCREEN=true --build-name=1.0.0-reference.65 --build-number=65
```

[V65 GitHub yayını](https://github.com/tongucaigo-alt/Coffee-Vision-Engine/releases/tag/atlas-v65). Kaynak dalı `codex/atlas-coffee-ui`, etiket `atlas-v65`. API anahtarları, imzalama dosyaları ve kullanıcı kayıtları yayımlanmaz. APK debug imzalı ayrı test paketidir.

V59 **“En güvenilir sürüm”** etiketi geri dönüş için korunur: [V59 yayını](https://github.com/tongucaigo-alt/Coffee-Vision-Engine/releases/tag/atlas-v59-en-guvenilir-surum).
