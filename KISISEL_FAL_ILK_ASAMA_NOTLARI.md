# Atlas kişisel fal — V74 test paketi

15 Ekim 2026. Birleşik kaynak: `atlas-coffee-guide-v73`, başlangıç HEAD `3333f4c`.
Kişisel fal akışı, Bilgilerim sayfası ve örnekli kısa prompt uygulamaya entegre edildi. V74 Android test APK'sı hazırlandı ve doğrulandı. Samsung A56 (SM-A566B) bağlandıktan sonra kullanıcının açık isteğiyle **V74 telefona yüklendi**. Mevcut veriler özel konuma yedeklendi ve hash ile karşılaştırıldı. Uygulama açılışı ile telefondaki ad doğrulandı; uçtan uca yeni fal testi yapılmadı. Commit, push, sunucu dağıtımı veya mağaza yayını yapılmadı.

## İşlevler ve görünüm

- Mevcut ana sayfa kullanıcı simgesi Bilgilerim sayfasını açar; mevcut Atlas renkleri ve bileşenleri kullanılır. İsteğe bağlı hitap adı ve burç ayrı yerel dosyada kaydedilebilir veya silinebilir. Hesap/giriş sistemi eklenmedi.
- Hitap adı AI'ya gönderilmez. Eski profil burcu varsayılan kapalıdır. Açıklamadan sonra burcu seçip Kaydet kullanmak yeni isteklere burç gönderimini açar; yalnız adı kaydetmek eski burcu açmaz. Tercih kapatılınca sonraki gönderimden çıkarılır.
- Kullanıcının sembolleri önceliklidir. Sembol yoksa yedi seçenekten tek yaratıcı motif seçilir. Oturum kimliği ve kaynakla ilişkilendirilen seçim tekrar deneme, yeniden açma ve A/B sırasında sabittir; görsel tespit veya kullanıcı gözlemi diye kaydedilmez.
- İstek sınırında v3 bağlamı üretilir. ReviewSession, preparedInput, ilk gözlem ve araştırma girdisi değiştirilmez. Burç istek için geçicidir; saklanan AI bağlamından çıkarılır. Profil silmek eski fal metinlerini değiştirmez.
- V1/V2 eski sonuçları okunur. Hazır falı açmak, profil Kaydet ve Yalnız Kaydet yeni AI isteği üretmez. A/B aynı girdiyle çalışır; çift basma koruması devam eder.
- OpenCV izleri, fincan alanı, hazırlık görünümü, kahve rehberi ve Tarot için korunan altı kaynak dosyasının SHA256 değerleri ilk aşama başlangıcıyla aynıdır. Önceden var olan diğer yerel değişiklikler korunmuştur.

## Gerçek AI yolu

Üretim asset'i artık `atlas-fortune-prompt-v14`. V11'de denenen yazar rolü + tek sabit üslup örneği + kısa kaynak özeti gerçek FortunePrompt/AiClient yoluna taşındı. Tarihsel lab biçimleri yalnız varsayılan kapalı test aracında kaldı.

Dart ve Node aynı ortak örnekten aynı kaynak özetini üretir. Fincan ve tabak fiziksel ipuçları ayrı gruplarda tutulur; tekrarlı fincan görünümleri tabak ipucunu listeden düşürmez. Her mevcut yüzey için tam cümle içinde bir izinli ifade istenir. Ham koordinatlar, ölçüm alanları, fotoğraf numarası ve profil adı kısa özete konmaz. Yalnız ilgili sembol kaynağı, fiziksel ipuçları, konu/akış/kapanış ve izinli burç yer alır.

Yanıtlar dört paragraf/250–400 kelime, kaynak atfı, kesinlik, burç kişilik iddiası, fiziksel ifade ve örnek kopyalama kontrollerinden geçer. Yeni v3 için lab/Play/bestEffort kalite atlatması kapalıdır. En fazla iki model çağrısı vardır; ret sonucu hazır fal olarak saklanmaz. Kopya düzeltmesinde yalnız uygulamanın sabit örneğinden eşleşen cümleler açıklanır; önceki kullanıcı falları AI'ya gönderilmez.

Doğrudan Kimi profili `kimi-k2.6`, thinking kapalı, sıcaklık 0,6, çıktı bütçesi 1800 token olarak korundu. Gateway v3 ve aynı prompt hash desteğine güncellendi fakat dağıtılmadı. Telefon APK'sı mevcut doğrudan özel Kimi test yapılandırmasıyla derlendi.

## Testler

- Tam Flutter yerel paketi: **477 geçti, 8 isteğe bağlı test atlandı**.
- Son dar kesinlik düzeltmesinden sonra ilgili Flutter regresyonları: **25/25 geçti**. Bu testler tam paketle örtüşür; sayılar toplanmaz.
- Son Node paketi: **26/26 geçti**.
- Son `flutter analyze --no-pub`: sorun yok.
- Profil küçük ekran/klavye/büyük yazı, izin, kaydet/sil ve hata davranışları; kamera/galeri, rehber, Tarot, kayıt açma, A/B, araştırma ZIP'i ve ilk gözlem koruması testleri mevcut pakette geçti.

Canlı testler yalnız uydurma veriyle ve gerçek uygulama mesaj biçimiyle yapıldı; gerçek kullanıcı fotoğrafı veya profili gönderilmedi. Çağrılar seri ve hız sınırına uygun aralıklarla gönderildi.

| Prompt | Senaryo | Gerçek yanıt | Özgün canlı kabul |
|---|---:|---:|---:|
| V12 | 5 | 9 | 2 |
| V13 | 5 | 7 | 3 |
| V14 | 5 | 7 | 3 |

V14 canlı turu **3/5** kabul edildi; bütün senaryoların geçmesini isteyen canlı test başarısız kapandı. Bir Anahtar/Terazi yanıtı iki denemede de üslup örneğinden cümle kopyaladı; bu ret halen geçerlidir. Kalp/Oğlak yanıtındaki “ne olacağını şimdiden bilmeyi gerektirmiyor” ifadesinin kesinlik sayılması dar bir yanlış retti. Bu olumsuz ifade için regresyon düzeltildi; aynı cümledeki gerçek gelecek vaadi yine reddedilir. Son ortak dil kontrolüyle çevrimdışı tekrar bakıldığında 4/5 senaryoda uygun bir yanıt vardır. Bu **yeni canlı tur veya geçmiş hikâyelerle tekrar karşılaştırması değildir**; özgün 3/5 sonuç değiştirilmedi.

Metin kontrolleri anlamsal doğruluk garantisi vermez. Soyutluk, aynı örneğin iskeletine yaklaşma ve diğer kişilik/ortam çıkarımları tamamen çözülmüş değildir. **V74 telefon üzerinde denenebilir bir test paketidir; ticari yayın için anlatı kalitesi ve gerçek cihaz kabulü onaylanmış değildir.**

## APK ve kurulum

- Dosya: `Atlas-Kisisel-Fal-V74.apk`.
- Paket: `com.coffeeplatform.atlas_contribution_app.diagnostic`.
- Sürüm: `1.0.0-kimi-test.74`, kod 74. Önceki V73 ile aynı imza doğrulandı.
- SHA256: `d3da1bb99857ee3e749f7906903035d75cec2cb2106d484b5631c705a65da461`.
- Giriş: `lib/offline_main.dart`, debug sideload test derlemesi.
- `ATLAS_DIAGNOSTIC=true`, `ATLAS_AI_LAB=true`, `ATLAS_IMAGE_SCREEN=true`; OpenCV izleri açık, adaptive deney kapalı.
- V73'ün 120 mevcut prompt dışı varlığı ve 30 native kütüphanesi byte düzeyinde aynıdır. ONNX fotoğraf uygunluk modeli korunur. Yeni prompt asset'i kaynakla birebir eşleşir.
- Özel derleme anahtarı harici yapılandırmadan okundu; kaynak/raporlara kopyalanmadı. Bu özel test APK'sı herkese açık dağıtılmadı.
- Telefon bağlandığında cihazdaki paket/sürüm/imza yeniden kontrol edilmelidir. Yükleme yalnız `tool/install_preserving_data.py` ile yükselen sürüm doğrulaması sonrası `adb install -r` kullanır. Önce kullanıcı dosyalarının özel yedeği ve hash kaydı alınır; kurulum sonrası hash'ler karşılaştırılır. Kaldırma/veri temizleme veya cihaz integration test kurulumu yapılmaz.

Çıktı dizini: `C:/Users/exzau/Documents/Codex/2026-10-15/atlas-personalized-v74-output`.
`apk-verification.json`, `source-verification.json`, analiz/test günlükleri, özgün `live-production-v12/v13/v14.json`, `live-v14-language-recheck.json` ve gerçek uydurma veri yanıtlarını içeren `LIVE_EXAMPLES.md` burada saklanır. Eski notlar `notes-before-v74.md` olarak korundu.

## Telefona kurulum tamamlandı — 15 Ekim 2026

- Samsung A56 üzerinde V73 → V74, aynı paket/imza ve yükselen sürüm doğrulamasıyla yalnız korumalı `adb install -r` kullanılarak kuruldu.
- Telefonda görünen ad **Atlas Fotoğraf Testi V74**. Android uygulama bilgileri ekranında açıkça görüldü ve ekran görüntüsü `v74-app-info.png` olarak saklandı.
- 55 dosya kurulum öncesi özel konuma yedeklendi. Kurulumdan hemen sonra 55/55 byte düzeyinde aynıydı. Açılıştan sonra 53/55 aynı kaldı; yalnız Android çalışma dosyaları `files/profileInstalled` ve `shared_prefs/android.app.ActivityThread.IDS.xml` değişti. Kullanıcı kayıtları, fotoğrafları, profilleri ve fal verisi değişmedi.
- Diagnostic uygulamanın ilk kurulum tarihi ve ayrı normal Atlas paketinin bütün sürüm/zaman bilgileri korundu. Cihazdaki base.apk hash'i hazırlanan APK ile aynı.
- Uygulama başarıyla açıldı; rehber ilk kartta bırakıldı. Rehber ilerletilmedi, kullanıcı tercihi/izin kutusu işaretlenmedi ve AI isteği başlatılmadı. `v74-phone-launch.png` açılış kanıtıdır.
- Kurulum, açılış ve hash kontrolleri `after-install-verification.json` ve `after-launch-verification.json` içindedir. Özel veri yedeği kaynak ve çıktı deposu dışında tutulur.

## V75 güncellemesi

İz seçimi, hazırlık, fiziksel analiz performansı ve esnek biçim kontrolleri uygulandı. Son durum V75_SURUM_NOTLARI.md içindedir. V75, 15 Ekim 2026 saat 22:10:45'te Samsung A56'ya aynı paket/imza doğrulanarak ve veri silmeden yüklendi. Telefonda görünen ad Atlas Fotoğraf Testi V75. Yedeklenen 115 dosyanın tamamı kurulumda aynı kaldı; açılışta yalnız iki Android çalışma dosyası değişti. Kullanıcı verileri ve ayrı normal Atlas paketi korundu. Açılış doğrulandı; yeni fal üretimi başlatılmadı.
