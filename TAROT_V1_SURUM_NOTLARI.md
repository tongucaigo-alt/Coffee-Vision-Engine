# Atlas V52 — Tarot V1

11 Ekim 2026. Kaynak temeli: V51 `4111f6f604e377e42c81f21de2de5389f2313112`.
Geliştirme dalı: `codex/atlas-tarot-v1`. V51 geri dönüş etiketi değiştirilmedi.

## Deneyim

- Alt menü: Ana Sayfa, Tarot, Kayıtlarım, Ayarlar. Kahve ana ekranı ve mevcut kahve kayıt akışı korunur.
- Tarot: ana seçenek Üç Kart; alternatif Günün Kartı. Soru/niyet giriş alanı yoktur.
- Gerçek yerel karıştırma, 78 kapalı karttan dokunarak seçim; Üç Kart pozisyonları Geçmiş, Şimdi, Olası Yön.
- Üç kart seçildikten sonra sırayla dokunarak açılır. Flutter içinde kısa taşıma, perspektifli kart dönüşü, altın halkalar ve parçacıklar bulunur.
- Düz/ters yönler yerelde karıştırma sırasında belirlenir. Seçilen kimlik, yön ve pozisyon animasyondan önce diske yazılır.
- İlk seçimden sonra karıştırma kapatılır. Çekim kapanma, geri dönüş, iptal veya açık yeniden denemede değişmez.
- Büyük yazıda üç kart dikey sıralanır. Küçük ekran, çentik, ekran okuyucu ve hareket azaltma desteklenir.
- Günün Kartı, seçimin yapıldığı cihazın yerel takvim gününde sabittir; ertesi gün yeni seçim yapılır. Bugünün kaydı silinirse yalnız günlük kilit tarihi saklanır.

## Kayıt ve AI sınırları

- Tarot kayıtları ayrı `tarot-local` dizinindedir; kendi geçmişi ve ayrı 20 yıldızı vardır. Silme manueldir.
- Tarot, kahve depolarına ve araştırma ZIP'lerine eklenmez. Kahve için veri göçü yoktur.
- Kimi bağlantı profilleri ve anahtar okuma yöntemi yeniden kullanılır. Ortak `AiTransport` kahvenin HTTP davranışını korur.
- Bağımsız metin sözleşmeleri: `atlas-tarot-context-v1`, `atlas-tarot-prompt-v1`.
- AI'ya yalnız seçili kart kimliği/adı, pozisyon, yön ve o yöne ait tema listesi gönderilir. Kart görseli veya kahve fotoğraf analizi gönderilmez.
- Üç Kart için 250–350, Günün Kartı için 100–150 kelime hedeflenir. Kelime aralığı anlatım hedefidir; anlamsal doğruluk garantisi değildir.
- Yorum üretimi yalnız Yorumunu Oluştur / Yeniden Dene ile başlar. Her açık işlem tek HTTP üretim isteğidir; otomatik yanıt onarımı veya ücretli tekrar yoktur.
- Hazır yorumu okuma yereldir. Çift dokunma, kesilen işlem, geç yanıt ve eski iptalin yeni denemeyle çakışması için koruma vardır.
- Kart seçimi/açılışı çevrimdışıdır; Kimi yorumu internet gerektirir. Bu teslim mevcut doğrudan test bağlantısını kullanır. Tarot verisi kahve gateway'ine gönderilmez; hosting hazır sayılmaz.
- Prompt kesin gelecek, gerçek kehanet veya enerji aktarımı iddiası istemez; kişisel olay ve görülmemiş çizim sembolü uydurmayı yasaklar. Bu prompt ve sınırlı biçim kontrolleri tam anlamsal denetim yerine geçmez.

## Görseller

- Orijinal PNG kaynakları değişmedi. 78 kart ve arka yüz, 1024×1536 çözünürlükte yerel WebP kopyaları olarak paketlenir.
- Görsel dosyaları 192.271.216 bayttan 42.348.340 bayta indi (yaklaşık %78 küçülme).
- Kalite 90 kullanıldı; PSNR 40 dB altında kalan 12 görsel kayıpsız WebP'ye geçirildi. Kayıpsız çıktılar piksel eşitliğiyle doğrulandı.
- 79 görselin PNG/WebP karşılaştırma sayfaları görsel olarak incelendi. Kart anlamlarının semantik doğruluğu tek tek denetlenmedi.
- Hazırlama aracı: `atlas_contribution_app/tool/prepare_tarot_assets.py`.

## Doğrulama

- Flutter analizi: sorun yok.
- Tam kahve/tarot test grubu: 333 başarılı, 6 atlanan test. Sonrasında eklenen küçük gezinme ve günlük tarih kontrolleri dahil son tarot widget grubu: 9 başarılı test. Bu gruplar örtüşür, sayıları toplanmaz.
- Son tarot widget önizlemeleri normal ekran, 320×568 ekran, iki kat yazı, çentik, hareket azaltma ve erişilebilir etiketleri kapsar.
- APK kimlik/imza doğrulaması teslim raporunda kayıtlıdır.
- Testler ve release build sırayla çalıştırıldı. Telefonda integration runner çalıştırılmadı.
- Sonuç ekranı önizlemesindeki yorum sabit test verisidir; canlı Kimi sonucu değildir.
- Kullanıcının sonraki isteğiyle gerçek `TarotRuntime`, `TarotAiClient` ve `AiTransport` üzerinden bilgisayarda bir ücretli `kimi-k2.6` Üç Kart çağrısı yapıldı. Eşzamanlı iki tetikleme yalnız bir HTTP isteği gönderdi; yanıt 25,461 saniyede tamamlandı. Çekim değişmedi, yorum yeniden açılışta korundu.
- Canlı içerik kontrolü: kart/pozisyon/yön/tema eşleşti, ortak hikâye ve düşünme daveti vardı. Ancak 202 kelimeyle 250–350 hedefi karşılanmadı; kişisel bilgi verilmediği halde geçmiş ve mevcut durum hakkında varsayımlar yazıldı. Bu sürümde prompt iyileştirmesi yapılmadı. Tek örnek, tüm yanıtların kalitesini doğrulamaz; günlük ve ters kart canlı çağrıları sınanmadı.

## Test dağıtımı

- Hedef giriş: `lib/offline_main.dart`; paket: `com.coffeeplatform.atlas_contribution_app`.
- V52: build adı `1.0.0-kimi-test.52`, versionCode `52`, görünen ad `Atlas Kimi Test V52`.
- `ATLAS_AI_LAB=true`, `ATLAS_KIMI_LOCAL_TEST=true`, `ATLAS_IMAGE_SCREEN=true` korunur.
- Release derlemesi testlerden sonra normal `flutter build apk --release` ile platform dosyalarını yeniden üretir. Bu SDK'da testlerin bıraktığı integration-test registrant'ını koruyabildiği için release adımında `--no-pub` kullanılmaz. Test ve build yine sıralı çalıştırılır.
- Anahtar ve kurucu imzası harici özel yapılandırmadan gelir. Bu APK sideload test içindir; GitHub veya mağazada yayınlanmaz.
- APK'nin imzası V51 ile eşleşmelidir. Sonraki telefon kurulumunda kurulu sürüm tekrar kontrol edilerek yalnız `tool/install_preserving_data.py` ile `adb install -r` kullanılır; kaldırma veya veri temizleme yapılmaz.
- Kullanıcının sonraki kurulum isteğiyle Samsung A56 üzerinde V51 doğrulandı, aynı imzalı V52 yalnız bu araçla güncellendi ve açıldı. Kaldırma/veri temizleme yapılmadı; ilk kurulum tarihi ve veri dizini inode değerleri değişmedi. Uygulama içindeki kayıtların tamamı telefonda ayrıca tek tek denetlenmedi.
- Kullanıcının sonraki GitHub isteğiyle kaynak dalı ve PR yayımlanır. APK, anahtarlar, imza dosyaları ve yerel cihaz raporları GitHub'a gönderilmez. Hosting ve iOS/mağaza hazırlığı kapsam dışındadır.
