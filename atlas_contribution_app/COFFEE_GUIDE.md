# Atlas kahve rehberi

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
