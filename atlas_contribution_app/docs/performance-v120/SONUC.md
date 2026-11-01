# Atlas V120 — Kalibrasyon-Hız sonucu

30 Ekim 2026. V120 telefona, V119'un üzerine veri temizlemeden güncelleme olarak yüklendi. İlk fotoğraf uygunluk filtresi, onaylı tasarım, yerleşim, metin hedefi ve animasyonlar korundu.

## Yapılan düzeltme

**Güncellik kontrolü:** `AiBridge`, geçerli falın kaydını ararken tüm inceleme geçmişini okuyordu. `ReviewStore.session(id)` ile yalnız ilgili kaydın bütün revizyonları okunup gerçek baytları ve checksum'ları doğrulanıyor. Aynı kapsam kaydetme ve bağlı kaydı açma işlemlerinde de kullanılıyor. Kimlik önekleri birbirine karışmıyor; silinmiş kayıt, eski revizyon ve eski tarih verilerek bozulmuş dosya kontrolleri korunuyor. Önbellek sınırları artırılmadı; fotoğraf baytları saklanmıyor.

Bu kapsam ayrımı bilinçlidir: başka bir kaydın bozuk dosyası bu kaydın güncellik sorgusunda açılmaz. Genel kayıt/geçmiş sorguları ve grup maruziyet denetimi tüm tarihsel dosyaları doğrulamayı sürdürür. Yeni bir fotoğraf setinin ilk geçmiş denetimi hâlâ genel tarama içerir; her yerel aşamanın sabit süreye indiği iddia edilmiyor.

**Kabul edilen fotoğraftan sonraki metin reddi:** İlk üretim talimatı, kurgusal motifi fincan/tabak/fotoğrafta görülmüş bir şekle dönüştürmemesi için netleştirildi. Görsel iddia nedeniyle düzeltme gerektiğinde, mevcut denetimin işaretlediği en fazla iki cümle alıntı veri olarak ekleniyor. Modelden yalnız bu iddiaları düzeltmesi, geçerli bölümleri ve uzunluk hedefini koruması isteniyor. Yanıt yine tamamlanmış falın tümüdür ve bütün mevcut kalite kontrollerinden geçer. Bu alıntılar loglara, AI tanı kayıtlarına veya kalıcı fal kaydına eklenmez.

Kimi modeli, düşünmenin kapalı olması, sıcaklık, 1800 token üst sınırı, 250–400 kelime hedefi, en az 150 kelime kontrolü, en fazla iki deneme ve ortak üretim bütçesi aynı kaldı. Reddedilen gerçek aday metinler saklanmadığından önceki üç ret için yanlış pozitif teşhisi iddia edilmiyor. Yeni yönlendirmelerin canlı modelde ret oranını ne kadar azaltacağı henüz ölçülmedi.

**Bağlantı hatası:** HTTP bağlantısı kapanması `HttpException` olarak geldiğinde artık güvenli bağlantı hata koduyla sınıflanıyor. Belirsiz durumda ücretli istek otomatik yeniden gönderilmiyor. Önceki `transport_unknown` olayının tam alt nedeni saklanmadığı için aynı hata türünden kaynaklandığı iddia edilmiyor.

## Ölçümler

Aynı yapay veri ve aynı yüksek seviyeli çağrılarla V119 ve V120 bilgisayarda sırayla çalıştırıldı: 263 revizyon, 40 kayıt, 23,4 MB; etkin kayıt yedi revizyon / 0,62 MB. Dört örnek alındı. Bunlar Windows Flutter test motoru sonuçlarıdır; telefonun toplam fal süresi değildir.

| Yerel işlem | V119 | V120 |
| --- | --- | --- |
| Bir güncellik kontrolü | 1,30–1,32 sn | ilk 62 ms; sonra 17–19 ms |
| Aynı kaydı yeniden kaydetme | 1,29–1,31 sn | 18–24 ms |

[Ham yerel ölçümler](local-measurements.json).

Samsung Galaxy A56'da **yeni ücretli fal üretmeden**, mevcut ve güncel bir kayıt üzerinde aynı `bridge.isCurrent` yolu üç kez çalıştırıldı: **248, 190 ve 179 ms**. V119'un önceki gerçek denemelerinde dört güncellik kontrolünün toplamı 17–19 saniyeydi; kontrol başına yaklaşık 4–5 saniye. Eski veri kaydı ile yeni tek seferlik probun ölçüm yöntemleri farklıdır; bundan toplam fal hızı veya istatistiksel yüzdelik sonuç çıkarılmadı. [Telefon ölçümleri](phone-measurements.json).

Prob yalnız diagnostic debug sürümünde ve açıkça oluşturulan tek kullanımlık istek dosyası varsa çalışır. İstek tüketildi; sonraki açılışlarda tekrar çalışmaz. AI istemcisi veya ağ çağrısı içermez. Kaydettiği alanlar yalnız durum, sayısal süreler ve sıfır sağlayıcı çağrısı bilgisidir.

## Doğrulama ve kurulum

**226 uygulama testi, 40 gateway testi geçti; Flutter analizi ve diff kontrolü temiz.** Testlerde kaynak değişimi, tarihi korunarak bozulmuş eski revizyon, silme, kimlik çakışması, kapasite sınırı, kayıt ekranına dönüş, kalite reddi, iptal, HTTP bağlantısının kapanması, kurtarmada bağlı kayıt koruması ve AI deposu hatasında salt okunur kurtarma kapsandı. Ağ/AI testleri yerel taklit sağlayıcı kullandı.

Aynı paket kimliği ve imza ile V120 kuruldu: `com.coffeeplatform.atlas_contribution_app.diagnostic`, `1.0.0-kimi-test.120`. 142 varlık karşılaştırıldı; yalnız amaçlanan `fortune-prompt-v1.json` değişti. Fotoğraf modelleri ve görsel varlıklar aynı.

Kurulum ve yerel ölçüm sonrasında **41 kahve kaydı, 48 tarot kaydı, 44 AI sonuç kaydı, 10 yıldızlı fal, 146 fotoğraf ve 263 inceleme dosyası** korundu. Kayıt dosyalarının ve fotoğrafların içerik özetleri öncekiyle aynı. Kayıtlarım'a giriş, çıkış ve tekrar giriş kontrol edildi; uygulama Kahve ana ekranında bırakıldı. Telefonun yazı/ekran ayarları değiştirilmedi. Özel yapılandırma değerleri, fotoğraflar ve kişisel fal metinleri rapora/loglara alınmadı.

## Kaynak ve kalan sınırlar

Uygulama kaynak kökü: `C:/Users/exzau/Documents/Codex/2026-10-30/atlas-kalibrasyon-hiz/atlas_contribution_app`. Dal `codex/kalibrasyon-hiz-v120`; APK kaynak commit'i `449afb9`. Özgün V118 kaynak ağacı değiştirilmedi.

Değişen uygulama dosyaları: `lib/src/mvp/review_store.dart`; `lib/src/ai/ai_bridge.dart`, `ai_contract.dart`, `ai_runtime.dart`, `ai_transport.dart`, `local_performance_probe.dart`; `assets/fortune-prompt-v1.json`. Yeni hedefli testler ve 23,4 MB performans fikstürü eklendi; mevcut kısa prompt testi değişmeyen kaynak/üslup/uzunluk sözleşmesini doğrulayacak şekilde güncellendi.

İzole kaynaktaki `atlas_ai_gateway/contract.mjs` ve `test/targeted-visual-repair.test.mjs` aynı düzeltme yönlendirmesine uyumlu. Gateway bu uygulama Git kökünün kardeş dizinidir; değişiklikler [gateway yaması](gateway-contract.patch) ile de kayıt altına alındı. Sunucuya dağıtım veya eşzamanlı çalışma mimarisi değişikliği yapılmadı. Yoğun kullanıcı için kalıcı iş takibi, kotalara uygun eşzamanlı çalışma ve gerçek yük testi ayrı iş olarak duruyor.

**Canlı toplam fal süresi ve canlı ret oranı henüz doğrulanmadı.** Bu çalışmada ücretli AI çağrısı yapılmadı. Aynı kabul edilmiş fotoğrafla kullanıcı denemesi, yeni aşama süreleri üzerinden değerlendirilebilir. Yerel kontrol hızlanması, Kimi üretiminin kendisinin hızlandığı anlamına gelmez.
