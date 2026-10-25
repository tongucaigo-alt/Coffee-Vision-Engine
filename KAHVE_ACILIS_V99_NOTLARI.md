# V99 — Kırpılmayan ve yumuşak başlayan açılış

V98 kaynakları korundu. Yalnız `atlas_intro.dart` ve ilgili test güncellendi. Tam ekranı dolduran cover yerine, ana video contain ile kendi 720:1280 oranında bütünüyle gösterilir. 1080×2340 telefonda eski ayar yaklaşık %18 yatay kırpma oluşturuyordu. Artık kaynak görüntünün sınırları ekran içinde kalır. Boş alanlar aynı oynatıcı/aynı zaman çizgisindeki videonun bulanık uzantısıyla dolar; kenar birleşimi hafifçe yumuşatılır. İkinci video oynatıcısı eklenmedi.

Başlangıç, Android zeminiyle aynı #EEDDBB üzerinden 450ms içinde belirir. Video texture'ı yerleşmeden zaman çizgisi başlatılmaz; hazır poster gerçek oynatma ilerleyene kadar tutulup 180ms içinde çözülür. Bu örtüşme ilk hareketin az bir kısmını yumuşatır; video yine sıfırdan oynar. Dokunarak/geriyle anında geçme, ses politikası, 8 saniyelik kaynak, hareket azaltma ve başlangıç kurtarması korunur.

22 ilgili test ve ayrıca 1 Flutter görsel üretim testi geçti. Flutter analyze: No issues found. 360/412×700, 412×892 (telefon oranı), 320×480 ve yatay 700×320; normal/iki kat yazıda kaynak görüntü sınırları ölçülerek kırpılmadığı doğrulandı. Geçiş opaklığı, texture yerleşiminden sonra oynama, poster değişimi ve mevcut iptal senaryoları test edildi. Başlangıç/orta/son kareleri görsel olarak incelendi.

APK sürüm99 diagnostic; V98 ile aynı imza. Kaynak video ve diğer varlıklar/native kütüphaneler değişmedi. `Onizleme.html` Flutter'dan üretilmiş sessiz kare animasyonunu gösterir; fiziksel cihaz kaydı değildir ve Android sistem başlangıç geçişini göstermez. Telefon kurulumu ve fiziksel cihaz testi henüz yapılmadı. Android üreticisinin sistem geçişi ayrıca cihazda kontrol edilmeli. AI çağrısı ve GitHub yayını yapılmadı.


## Telefon kurulumu — 25 Ekim 2026

V99, bağlı Samsung SM-A566B telefondaki Atlas Fotoğraf Testi diagnostic paketinin üzerine aynı imzayla kuruldu. Sürüm99 ve kurulu APK SHA-256 eşleşmesi doğrulandı. Önce/sonra 512 dosyanın tamamı byte düzeyinde aynı; normal Atlas paketi ve ilk kurulum zamanı korundu. Kaldırma veya veri temizleme yapılmadı. Özel yedek ve yerel geri yükleme doğrulaması PASS. Uygulama tarafımızca açılmadı; fiziksel cihazda açılışın görsel testi yapılmadı. GitHub yayını ve AI çağrısı yapılmadı.


## GitHub güncellemesi — 25 Ekim 2026

Açılış ve ana ekran sunum değişiklikleri `codex/atlas-v99` dalına gönderildi. Commit: `5cb7f9e1faaabe8a2f889ca780317050ffdb9fa1`. Yayımlanan kapsamda 98 test geçti, kod analizi temiz. Sürüm notları animasyon ve geçiş davranışlarını, testleri ve telefon kurulumunu içerir. Yereldeki diğer çalışmalar korundu; APK, özel yapılandırma ve cihaz yedekleri yayımlanmadı. Ana dal değiştirilmedi.
