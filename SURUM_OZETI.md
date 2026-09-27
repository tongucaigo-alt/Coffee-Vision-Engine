# Atlas — 28 Eylül 2026 sürüm özeti

Bu kayıt, telefona kurulan beta 6'ya kadar yapılan geliştirmeleri bir araya getirir.

## Neler eklendi?

- Krem, kahverengi ve yeşil tasarım; Ana Sayfa, Kayıtlarım ve Ayarlar ekranları. Logo ve yazı tipleri çevrimdışı kullanılabilir.
- Mevcut yeşil noktalı, yuvarlak fincan kamerası korundu. Üç açılı çekime ve galeriden 1–3 fincana isteğe bağlı bir tabak eklenebilir; hepsi tek kayıt altında tutulur.
- Küçük işaretleme kutuları, temiz fotoğraflardan ayrı saklanan semboller, değişmeyen ilk gözlem geçmişi ve kayıt revizyonları.
- Araştırma iznine bağlı ZIP dışa aktarma, Android'e kaydetme ve dosya doğrulama düzeltmeleri.
- Değiştirilebilir AI bağlantıları, test AI Laboratuvarı, yerel fal geçmişi ve kör A/B karşılaştırması. Atlas servisi istekleri sıraya alır ve testçi erişimlerini ayırır.
- Mevcut motor çıktılarından bölgesel telve özeti, yerelde çeşitlenen anlatı taslağı ve tekrar/dil kontrolleri. AI'ya yalnız metinsel bağlam gönderilir; fotoğraflar gönderilmez.
- “Kaydet ve Falını Oluştur” ve “Yalnız Kaydet” seçenekleri. Gerçek fotoğraflarla, işlemin gerçek aşamasını gösteren tarama/bekleme ekranı.

## Doğrulama

Son geliştirme doğrulamasında 229 uygulama, 17 servis ve ayrı diagnostic uygulamasında 13 cihaz testi geçti; Dart analizinde sorun bulunmadı. İki Android ZIP çıktısının dosya checksum'ları doğrulandı. Beta 6, uygulama kaldırılmadan kuruldu; mevcut taslak korundu.

## Henüz tamamlanmayanlar

Gerçek fotoğrafla son beta yürüyüşü ve 12 fincan setinde kör içerik karşılaştırması bekliyor. Son canlı Kimi denemesinde işaretli örnek düzeltmeden sonra geçti; işaretsiz örnek kısa kaldığı için reddedildi. Bu nedenle anlatım kalitesinin iyileştiği henüz doğrulanmış sayılmaz.

Otomatik sembol tanıma, model eğitimi, puan/üyelik ve üretim ortamı hazırlığı bu sürüme dahil değildir. API anahtarları, imzalama dosyaları ve APK çıktıları kaynak deposuna eklenmez. APK ile Atlas servisinin bağlam/prompt sürümleri birlikte güncellenmelidir.

Ayrıntılar: [zengin fal doğrulama raporu](atlas_contribution_app/RICH_FORTUNE_VALIDATION.md), [uygulama yönergeleri](atlas_contribution_app/README.md), [servis yönergeleri](atlas_ai_gateway/README.md).
