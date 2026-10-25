# V99 — Açılış animasyonu ve geçiş ekranı

## Kullanıcıya yansıyan değişiklikler

- Yerel kahve/kitap açılış videosu her soğuk açılışta sıfırdan, yaklaşık 8 saniyenin tamamıyla oynar. Arka plandan dönüşte ve sekme değişiminde yeniden başlamaz.
- Görünür Geç düğmesi ve ayrı başlık yoktur. Ekranın herhangi bir yerine dokunmak veya sistem geri eylemi açılışı hemen sonlandırır.
- Ana video 720:1280 oranını koruyarak bütünüyle gösterilir. Önceki tam ekran doldurma ayarının uzun telefon ekranında oluşturduğu yakınlaştırma ve yatay kırpma kaldırıldı.
- Kalan ekran alanı aynı oynatıcıdaki videonun bulanık uzantısıyla dolar; kenarlar yumuşatılır. İkinci oynatıcı ve beyaz çerçeve eklenmez.
- Android başlangıç simgesi şeffaflaştırıldı; açık/koyu modda sıcak parşömen zemini (#EEDDBB) kullanılır. Telefonda uygulamayı başlatan Atlas simgesi korunur. Android'in sistem başlangıç aşaması kaldırılmaz.
- Başlangıç görüntüsü sıcak zeminden 450ms içinde belirir. Oynatma, video yüzeyi ilk karede yerleştirildikten sonra başlar. Poster, oynatma ilerleyene kadar görünür kalıp 180ms içinde videoya çözülür. Video sıfırdan başlar; örtüşme ilk hareketin kısa bir kısmını yumuşatır.

## Ses, erişilebilirlik ve güvenli başlangıç

Ses en fazla %20 düzeyindedir; sessiz/titreşim/Rahatsız Etmeyin/medya sesi sıfır veya okunamayan ses durumunda kapalı kalır. Genel ses seviyesi değiştirilmez ve diğer uygulamaların müziği durdurulmaz. Arka plana geçildiğinde açılış sonlanır; hareket azaltmada video ve ses oynatılmaz. Hazırlık hatası veya iki saniyelik zaman aşımı mevcut başlangıç akışını açar. Rehber ve kayıt kurtarma işlemleri tekrar başlatılmaz.

## Birlikte yayımlanan görsel düzenlemeler

V96–V97'de hazırlanan Kahve/Tarot ana ekran dokusu, sıcak ışık, seyrek yıldız parlaması ve ortak çerçeve bu dala dahildir. Pastel adaçayı yaprakları belirginleştirildi; ortadaki geometrik motif kahve çekirdeği oldu. Başlıklar Literata 22sp, kontrol/açıklamalar Plus Jakarta Sans kullanır. Ana görsel alanları ve düğme hizaları ortak bileşende eşitlenir. Dekorlar dokunma ve ekran okuyucu odağı almaz; görünmeyen sayfalarda ve hareket azaltmada hareket durur.

## Yayın kapsamı

Bu dal, GitHub'daki V93 tabanına açılış ve ana ekran sunum değişikliklerini ekler. Yerelde paralel yürütülen AI/gateway, gizlilik ve fotoğraf algılama çalışmaları bu tasarım yayınına dahil edilmez. Veri modeli, kamera/OpenCV ve fal üretim davranışları bu yayında değiştirilmez. video_player 2.14.1 ve gerekli yerel video/poster varlıkları eklenir. Özgün açılış video dosyası korunur.

## Doğrulama

V99 açılışı için 22 ilgili test ve ayrıca Flutter'dan görüntü üretme testi geçti; kaynak videonun başı/ortası/sonu görsel olarak incelendi. 360/412×700, 412×892 (telefon oranı), 320×480 ve yatay 700×320; normal ve iki kat yazıda görüntü sınırları ölçülerek kırpılmadığı doğrulandı. Başlangıç opaklığı, poster geçişi, tek oynatma, dokunma/geriyle geçme, hata/zaman aşımı, hareket azaltma, rehber sırası ve kayıt kurtarma kontrolleri kapsandı.

Telefondaki ayrı **Atlas Fotoğraf Testi V99**, aynı imzayla kaldırma veya veri temizleme olmadan güncellendi. Kurulum öncesi/sonrası 512 dosyanın tamamı byte düzeyinde aynı; normal Atlas paketi ve ilk kurulum zamanı korundu. Kurulu APK hash eşleşmesi doğrulandı. Fiziksel cihazda açılışın son görünümü otomatik olarak test edilmedi; ekran önizlemeleri cihaz kaydı değildir. Ücretli AI çağrısı yapılmadı.

Yayımlanan dalın bağımsız test ve analiz sonucu aşağıda kaydedilir. APK, özel derleme tanımları, anahtarlar ve cihaz yedekleri GitHub'a eklenmez.

### GitHub dalının bağımsız doğrulaması

V93 tabanı üzerinde yalnız yayın kapsamındaki değişikliklerle **98 test geçti**, isteğe bağlı ekran-kare üretim testi standart koşuda atlandı. `flutter analyze --no-pub`: **No issues found**. Testler açılış, başlangıç/kayıt kurtarma, ana ekran hizaları, kahve etkileşimleri ve Tarot akışını kapsar.
