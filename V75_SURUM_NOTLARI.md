# V75 — OpenCV kapsamı ve hazırlık optimizasyonu

15 Ekim 2026. Birleşik kaynak: `C:/Users/exzau/Documents/Codex/2026-10-14/atlas-coffee-guide-v73`. Mevcut V74 değişiklikleri üzerine uygulandı; önceki yerel değişiklikler `before-status.txt` / `before-changes.patch` ile korundu. Commit/push veya sunucu dağıtımı yapılmadı.

## Sonuç

- Fotoğraf başına en fazla dört örtüşmeyen anlamlı iz; üç fincanda 12 iz mümkün. Başka açıdaki benzer şekil bir fotoğrafın kotasını tüketmez. Aday yetersizse iz uydurulmaz.
- Fincanın kalibre edilmiş elipsinin merkezindeki %65 ölçekli alanda aday bulunduğunda ilk yer iç bölgeye ayrılır. Kalan yerler puan ve aynı fotoğraftaki %25 kutu örtüşme sınırıyla seçilir.
- Native fincan sınırı/maske/renk/alan eşikleri değiştirilmedi. OpenCvTraceChannel.kt ve OpenCvCupDomain.kt başlangıç hash'leriyle aynı. Kahve rehberi, Tarot, orbit çizimi ve AI prompt asset'i de aynı.
- Son üç gerçek oturumun dokuz fotoğrafının tamamında dört ayrı aday seçilebildi. Kayıtlı native aday pikselleri değiştirilmedi; görüntüyle birlikte gerçek Flutter render'ı özel dizinde incelendi. Bu kontrol, yeni native duyarlılık deneyi değildir; korunmuş kalibrasyonun yeni seçimi nasıl gösterdiğini doğrular.

## Süre optimizasyonu

Fiziksel sözleşme ve bütün N×(N−1) ilişkiler korunur. Sıralı girdiler tekrar sıralanmaz. Geçerli uçlar + öz ilişki olmaması + bitişik tekillik + N×(N−1) sayısı aynı tam kapsamı kanıtladığından milyonlarca çift için tekrarlı Set tahsisi/tarama kaldırıldı. Pass-through seçim boş yere bütün kenarları yeniden gruplamaz. Doğrulanmış tam grafikte bağlı yapı sonucu aynı üyelik ve kenar sayısıyla doğrudan çıkarılır. Dışarıdan gelen sırasız, eksik, hatalı veya yinelenmiş ilişkilere yönelik doğrulamalar korunur.

Dokuz özel fotoğrafta fiziksel özellikler ve örüntü çıktılarının deterministik SHA256 karşılaştırması eşleşti. Aşağıdaki dört ağır fotoğraf her sürümde beş kez çalıştırıldı. Ölçüm Windows Dart JIT üzerinde fiziksel motor + örüntü analizini kapsar; hash üretimi, Android IO ve AI dahil değildir.

| Fotoğraf | Bileşen | V74 medyan ms | V75 medyan ms | Azalma |
|---|---:|---:|---:|---:|
| session-1-photo-1.jpg | 573 | 977.9 | 482.2 | %50.7 |
| session-1-photo-2.jpg | 707 | 1232.3 | 517.6 | %58.0 |
| session-1-photo-3.jpg | 1025 | 2764.0 | 735.6 | %73.4 |
| session-3-photo-1.jpg | 559 | 925.2 | 444.4 | %52.0 |

%30 hedefi bu bilgisayar ölçümünde geçildi. Samsung üzerinde süre kazanımı henüz ölçülmedi; bu sayılar telefon performansı diye sunulamaz.

## İlk kare ve veri akışı

Fotoğraf kaydedilip seçimi/kırpması kesinleştikçe mevcut TraceService önbelleği ısındırılır. Kimlik checksum + kırpma + native algoritmaya bağlıdır; native işler tek sırada çalışır. Fal üretiminde fiziksel analiz ile iz hazırlığı birlikte başlatılır.

Sürekli hazırlık sunumu ilk kez yalnız uygun iz ve çözümlenmiş görüntü hazır olduğunda görünür. Diğer fotoğraflar da hazır olduklarında döngüye katılır. Kullanıcının ilk gözlem kaydı kalıcı yakalanmadan OpenCV yardımı gösterilmez. İlk hazırlık mevcut butonda “Hazırlanıyor…” ile bildirilir; ek adım veya yeni tasarım eklenmedi. Aynı fotoğrafların kayıt→AI devrindeki kısmi önbellek güncellemesi hazır izleri silmez. İptal/yeni çalışma için epoch ve fotoğraf kimliği eski/geç gelen sonuçları engeller.

İz bulunmayan fotoğraflar döngüye katılmaz. Hiç iz yoksa fotoğraf olmadan açık durum bilgisi gösterilir; kullanılabilir fiziksel veri varsa AI devam eder. Belirsiz bölgeler renkli iz diye doldurulmaz. Eski hazır fallar açılırken yeniden üretilmez.

## AI ve tanılama

- Prompt V14 ve anlatım biçimi byte düzeyinde korundu. Model, 0,6 Kimi sıcaklığı, thinking kapalı ve 1800 token bütçesi aynı.
- v3 için 250–400 kelime ve dört paragraf tercihleri `qualityWarnings` olur. Tam yanıt, en az 150 kelime ve mevcut 12000 karakter sınırı gerekir. Biçim uyarısı kaynak/atfetme/kesinlik/kişilik/kopya/teknik içerik kontrollerini atlatmaz.
- Yalnız engelleyici kalite hatası ikinci çağrıya gider. İki çağrı ve ortak 180 saniye bütçe korunur. Belirsiz taşıma hatası otomatik ek POST üretmez.
- Bağlantı, TLS, süre aşımı, geçersiz yanıt ve HTTP durumları ayrı güvenli kodlarla taşınır. Yerel tanılama yalnız aşama, süre, deneme ve izinli neden içerir. Özel profil, fotoğraf, anahtar, uzak hata gövdesi ve reddedilen fal metni tutulmaz. Tanılama olayları 100 ile sınırlıdır; araştırma ZIP'ine eklenmez.
- Gateway aynı biçim/engelleyici kuralları ve isteğe bağlı tanılama alanlarını üretir. Gateway dağıtılmadı; test APK'sı mevcut doğrudan Kimi bağlantısını kullanır.
- Üç yeni, yalnız uydurma verili gerçek Kimi senaryosu 3/3 ilk çağrıda geçti. 318, 274, 257 kelime üretildi. Bu küçük örnek bağlantı veya anlamsal kalite hatalarının tamamen bittiğini kanıtlamaz.

## Doğrulama

- Tam Flutter paketi: 485 geçti, 8 isteğe bağlı test atlandı.
- Son önbellek devri/epoch/mahrem tanılama değişikliklerinden sonra ilgili 10 regresyon testi geçti. Bu testler tam paketle örtüşür; sayılar toplanmaz.
- Coffee Vision: 357/357. Coffee Pattern: 55/55. Node gateway: 27/27.
- Son Flutter statik analiz: sorun yok.
- Dokuz gerçek özel fotoğrafın görsel iz testi: 1 toplu test geçti. Görseller kaynak deposuna veya AI'ya gönderilmedi.
- Küçük ekran taşması tam akış testiyle bulundu ve mevcut buton metni kullanılarak giderildi. Soğuk ilk kare, sıfır iz, geç/kısmi sonuç, iptal, başka fotoğraf ve tek/iki AI denemesi testleri geçti.
- Pattern paketindeki önceden var olan CRLF kaynaklı YAML sınır testi okuması satır sonlarını normalize edecek şekilde düzeltildi; üretim Pattern kodu değişmedi.

## APK ve telefona kurulum durumu

APK: `C:\Users\exzau\Documents\Codex\2026-10-15\atlas-v75-output\Atlas-Kisisel-Fal-V75.apk`

- Ad: **Atlas Fotoğraf Testi V75**; paket `com.coffeeplatform.atlas_contribution_app.diagnostic`.
- Sürüm kodu 75, ad `1.0.0-kimi-test.75`; V74 ile aynı imza doğrulandı.
- SHA256: `843bd7464f4a2b3334b5aafe365a2bfd923d8a76a265387613e5ea281379416e`.
- `lib/offline_main.dart`, diagnostic debug test derlemesi; `ATLAS_IMAGE_SCREEN=true` korunur, adaptive deney kapalıdır.
- V74'ün prompt dahil 121 varlığı ve 30 native kütüphanesi APK içinde byte düzeyinde aynı.
- **15 Ekim 2026, 22:10:45: Samsung A56 üzerinde V74 → V75 kuruldu.** Aynı paket/imza ve yükselen sürüm, korumalı `tool/install_preserving_data.py` ile doğrulandı; yalnız `adb install -r` kullanıldı. Veri temizleme veya kaldırma yapılmadı.
- 115 dosya özel konuma yedeklendi. Kurulumun hemen ardından 115/115 byte düzeyinde aynıydı. Açılıştan sonra yalnız Android çalışma dosyaları `files/profileInstalled` ve `shared_prefs/android.app.ActivityThread.IDS.xml` değişti; kullanıcı kayıtları, fotoğrafları, profili ve fal verisi korundu.
- İlk kurulum tarihi ve ayrı normal Atlas paketinin sürüm/zaman bilgileri aynı kaldı. Cihazdaki base.apk SHA256 değeri teslim APK'sıyla eşleşti.
- Android uygulama bilgileri ekranında **Atlas Fotoğraf Testi V75** adı görüldü (`v75-app-info.png`). Uygulama başarıyla açıldı ve mevcut rehberin ilk kartında bırakıldı (`v75-phone-launch.png`). Yeni AI isteği başlatılmadı veya kullanıcı tercihi değiştirilmedi. Bu açılış kontrolü, yeni fal akışının telefonda uçtan uca ölçümü değildir.
- Kurulum ve açılış doğrulamaları `after-install-verification.json` ve `after-launch-verification.json` dosyalarındadır. Özel veri yedeği kaynak ve çıktı deposunun dışında tutulur.

Tüm raporlar ve günlükler `C:/Users/exzau/Documents/Codex/2026-10-15/atlas-v75-output` dizinindedir. APK özel test yapılandırması içerir; herkese açık dağıtım yapılmadı.
