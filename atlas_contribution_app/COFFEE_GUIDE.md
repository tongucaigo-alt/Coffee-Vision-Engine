# Atlas kahve rehberi

## V111 kaynağı üzerinde rehber güncellemesi — 27 Ekim 2026

Rehber 13 karta genişletildi. Mevcut kahve çekim/hareket anlatımları korunur; Bilgilerim, yarım kalan kahve/Tarot'a ▶ ile devam, Kayıtlarım'ın Kahve/Tarot ayrımı ve filtreleri, Tarot seçme/açma/isteğe bağlı ruh hâli ve Ayarlar'daki gizlilik/destek/bildirim yolları eklendi. Açılış videosunun dokunarak geçilebildiği ilk kartta anlatılır; hata durumundaki “Yeniden Dene” yardım kartında kısaca belirtilir.

“İlk fotoğrafın” başlıklı 2. kartta **Yeşil noktalar telve taramasını gösterir.** açıklaması bulunur. Elle çizilen noktaların yerini kameranın kendi `CameraTargetOverlay` bileşeni aldı: tarama çizgisi, parıltılar ve nokta dağıtımı aynı çizim kodundan gelir. Örnek fotoğrafın bilinen fincan sınırları kullanılarak `CoffeeRegionAnalyzer` ile önceden çıkarılan 32×32 telve maskesi rehbere özeldir. Böylece rehber çalışırken kamera, canlı analiz, kayıt veya izin isteği başlatılmaz. İlk 600ms kadraj gösterilir; ardından canlı kameradaki 1350ms geçiş hızıyla dört tarama oynatılır. Altı saniye sonunda çizim durur; Tekrar göster yeniden başlatır. Azaltılmış harekette tarama ve halka sabittir. Sembol sonucu veya çekim onayı sunulmaz; kamera yönlendirmesini izleme mesajı ve “Örnek gösterim” etiketi korunur.

Ek kartlar salt görsel anlatımdır. Profil, kayıt, Tarot veya bildirim servislerini çağırmaz; örnek Kaydet/Sil/Bildir öğeleri gerçek eylem başlatmaz. İki açılış kuralı, son kartta tekrar tercihini kaydetme ve Ayarlar'dan tekrar açma değişmedi. Önceden kaydedilmiş “Bir daha gösterme” tercihi sıfırlanmaz. Rehber sayfasının sayacı, ilerleme noktaları ve son kart işlemi yeni kart sayısını kullanır.

- 24 rehber/depo/tarama testi geçti; bunlara yeşil nokta açıklaması, ek sayfaların içeriği/eylemsizliği, 320/390/430px–1×/2× yazı kontrolleri, örnek maskenin gerçek analiz çıktısıyla eşleşmesi, gerçek çizim bileşeni/geçiş süresi, durma/tekrar oynatma ve azaltılmış hareket dahil. Ayrıca kamera paketinin mevcut telve analizi ve nokta dağılımındaki 11 test geçti. Statik analiz temiz.
- 116 ilgili regresyon testi geçti, 1 test atlandı: açılış videosu/rehber sırası, profil, gizlilik, kayıtlar, kurtarma, bildirim, Tarot ve fotoğraf hareketleri.
- Gerçek Flutter ekran çıktıları `build/guide-previews/card-1.png` … `card-13.png` altında. Tarot örnekleri mevcut kart arkası varlığını kullanır; yeni görsel veya bağımlılık eklenmedi.
- Rehber dışındaki 1.331 takipli dosyanın içerik özeti başlangıçla aynı: `96e17b9b5a0ea20434550af5f4431648b0e9d4638308702d2aa251fce49b7aa0`. Ana ekranlar, kamera/OpenCV, AI, kayıtlar, izinler, gerçek profil/Tarot sayfaları değiştirilmedi.
- Bu tur APK derleme, telefon işlemi, commit/push veya ücretli AI çağrısı yapılmadı. Aşağıdaki V73 kayıtları tarihsel geliştirme/teslim bilgisidir.

## İlk rehber — V73

14 Ekim 2026. Modern Atlas açılışına sekiz kartlık karşılama/kullanım rehberi eklendi.

- İlk gösterimde kapatma tercihi yoktur. İkinci ve sonraki gösterimlerde son karttaki “Bir daha gösterme” yalnız “Başlayalım” ile kaydedilir. Arka plandan dönüş yeni gösterim sayılmaz; yarıda sonlandırılan uygulamanın sonraki açılışı ilk karttan başlar.
- Ayarlar’daki “Kullanım Rehberi” tekrar açar; bu ziyaret sayacı veya tercihi değiştirmez.
- Rehber yalnız bağımsız `coffee-guide/state.json` dosyasına yazar. Bu klasör uygulamanın özel destek dizininde, fotoğraf/AI/izin verilerinin dışında bulunur; araştırma ZIP’ine dahil değildir.
- Görsel ve animasyonlar öğretici örnektir. Kamera, şekil işaretleme veya AI çağrısı yapmaz; gerçek kullanıcı fotoğrafı veya onayı kullanmaz.
- Fotoğraf büyütme/küçültme, Taşı modu, İşaret modu, kutu taşıma ve köşeden boyutlandırma mevcut hareketlere göre anlatılır. Animasyon bir kez oynar ve tekrar oynatılabilir; azaltılmış harekette sabit gösterim kullanılır.
- Mevcut V69 çalışma dosyalarının SHA256 değerleri başlangıçla birebir aynı kaldı. Kamera, kırpma, OpenCV, AI ve izin kaynakları değiştirilmedi. İki mevcut uygulama testinde rehber atlamak için yalnız bellek içi fixture eklendi; bu testler gerçek tercih dosyası kullanmaz.

## Kontroller

- `flutter analyze --no-pub`: temiz.
- `git diff --check`: temiz.
- 19 rehber testi: ilk/ikinci açılış, kalıcı tercih, yarıda kapatma, arka plan/rebuild, manuel erişim, dosya hataları, animasyon, azaltılmış hareket, 320/390/430 piksel ekranlar ve 1×/2× yazı.
- 23 mevcut test dosyasında 205 regresyon testi: kahve/galeri/tabak akışı, kutular/hareketler, OpenCV izleri, kayıt, fal hazırlığı, uygulama gezinmesi ve araştırma dışa aktarma.
- Gerçek Flutter widget ekran çıktıları: `build/guide-previews/card-1.png` … `card-8.png`. Görsel kontrol için Material ve Lucide ikon fontları da yüklendi.
- İlk rehber geliştirme aşamasında telefon kurulumu/derlemesi veya ücretli fal isteği yapılmadı. Sonraki V73 kurulumu aşağıda kayıtlıdır.

## Telefona kurulan birleşik sürüm ve GitHub kontrol noktası

Telefonda V72 bulunduğu için rehber, o sürümün temiz kaynağı üzerine eklenerek **V73** hazırlandı. Mevcut V69 OpenCV ve V72 Tarot geliştirmeleri korunur. Birleşik kaynakta 72 rehber/Tarot/AI/iz testi ve statik analiz başarılıdır; ilk geliştirme testleriyle örtüşür.

Samsung A56'ya aynı paket/imza ile `adb install -r` güncellemesi yapıldı. Mevcut 42 dosya kurulumdan hemen sonra aynıydı; açılış sonrasında kullanıcı dosyaları korundu. Rehber ilk kartta kullanıcıya bırakıldı. APK ve özel dosya yedekleri Git dışında tutulur.

Güncel birleşik kaynak kontrol noktası: [UYGULAMA MİLE POİNT — Atlas V73](../UYGULAMA_MILE_POINT_V73.md).

## Öğretici görselin kaynağı

`assets/guide/example-cup.png`, yerleşik **imagegen** ile üretildi. Kullanıcı fotoğrafı değildir. Referans, bu sohbet için hazırlanan üç ekranlık tasarım örneğinin ortasındaki fincandı. Logo, uygulamanın mevcut `assets/brand/atlas-logo.png` dosyasıdır.

Üretim istemi:

> Create a standalone instructional example coffee photograph for the Atlas onboarding guide, based on the CENTER screen's white Turkish coffee cup in the supplied design board. The board is only a visual reference; output ONLY a clean photographic image, no UI, no text, no brackets, arrows, symbols, logos, hands or annotations. Square 1024x1024 composition. Close overhead/slightly oblique view of a white ceramic Turkish coffee cup on warm cream linen, handle bottom-left. Entire cup rim visible with adequate margin. The inside has natural dark brown used coffee grounds, a dense interesting textured patch on the upper-right inside wall, some sparse grains on other areas and visible white ceramic. Well-lit, sharp, no glare hiding the grounds. Natural unretouched documentary photograph. This is an artificial teaching example, not a user's cup or an actual analysis. Match the warm understated cream and brown palette of the supplied board.
