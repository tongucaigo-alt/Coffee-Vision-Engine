# UYGULAMA MİLE POİNT — Atlas V73

14 Ekim 2026. Bu kayıt, telefona kurulmuş **Atlas Fotoğraf Testi V73** uygulamasının birleşik kaynak kontrol noktasıdır: **V69 OpenCV + V72 Tarot + V73 kahve kullanım rehberi**.

## Bu sürüm

- Atlas'ın mevcut logo, font, krem/kahverengi/yeşil renkleri ve çerçeveleriyle sekiz kartlık karşılama/kullanım rehberi.
- İlk iki açılışta rehber; ikinci açılıştan itibaren son kartta “Bir daha gösterme”. Tercih yalnız “Başlayalım” ile kaydedilir. Ayarlar’dan tekrar açılır.
- Öğretici fincan örneği, yoğun telveye yönlendirme, koşula bağlı flaş kullanımı, iki parmakla yakınlaştırma, Taşı/İşaret ayrımı, kutu taşıma ve köşeden boyutlandırma.
- İşaretleme isteğe bağlıdır. Rehber kamera, AI, kullanıcı işareti veya izin işlemi başlatmaz. Fotoğraf ve animasyonlar gerçek analiz sonucu değildir.
- Mevcut V69 fincan alanı/renkli iz düzeltmeleri ve V72 Tarot tasarımı/isteğe bağlı yerel ruh hâli özellikleri korunur. Kahve akışı, kırpma, kayıtlar ve izinler korunur.

## Doğrulama

- İlk rehber kaynağında 19 rehber + 205 mevcut regresyon testi başarılı; statik analiz temiz.
- V72 üzerine hazırlanmış bu birleşik kaynakta 72 rehber/Tarot/AI/iz testi başarılı; statik analiz temiz. Bu gruplar örtüşür ve toplamları ayrı bir test sayısı değildir.
- V72'nin 1.109 korunacak kaynak/varlık dosyası aynı kaldı. Rehberin açılış/Ayarlar bağlantıları ve test fixture’ları dışında mevcut üretim kaynakları değiştirilmedi.
- Samsung A56'ya aynı paket ve imza ile, sürüm 72 → 73 yükseltilerek `adb install -r` yoluyla kuruldu. Kaldırma veya veri temizleme yapılmadı.
- Kurulumdan hemen sonra 42 mevcut uygulama dosyası byte düzeyinde korundu. Açılıştan sonra kullanıcı dosyaları yine aynı kaldı; yalnız Android çalışma işareti ve bağımsız rehber durumu değişti. Diğer normal Atlas paketi korunur.
- Gerçek cihazda “Atlas’a hoş geldin” / 1–8 rehber açılışı doğrulandı. Kullanıcı adına rehber tamamlanmadı veya tercih/izin seçilmedi; ücretli fal çağrısı yapılmadı.

## Derleme kimliği

- Paket: `com.coffeeplatform.atlas_contribution_app.diagnostic`
- Sürüm kodu: **73**; sürüm adı: `1.0.0-kimi-test.73`
- Üretim giriş noktası: `atlas_contribution_app/lib/offline_main.dart`
- Yerel APK adı: `Atlas-Kahve-Rehberi-V73.apk`
- APK SHA256: `775224302e66a1b0e5e2d843f94486dbf49c063944dce4da61fc55a8d979179e`

Bu, mevcut özel yapılandırmayla hazırlanmış yerel test sürümüdür. API anahtarı, özel yapılandırma/imza dosyaları, APK, telefon yedekleri ve kullanıcı kayıtları bu GitHub kontrol noktasına eklenmez. Derleme numarası/adı mevcut build seçenekleriyle verilir; üretim giriş noktası test entrypoint’iyle değiştirilmez.

[Rehber ayrıntıları ve öğretici görselin üretim istemi](atlas_contribution_app/COFFEE_GUIDE.md). V59'un önceki “En güvenilir sürüm” kaydı tarihsel geri dönüş noktası olarak korunur; bu not V73'ü aynı değerlendirmeyle adlandırmaz.
