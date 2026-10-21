# Atlas kamera — marka kimliği ve sade görünüm

19 Ekim 2026. V84 çalışma ağacı üzerine yalnız kamera sunumu uygulandı.
Mevcut commit edilmemiş geliştirmeler korundu. Bu çalışma APK üretimi,
telefon kurulumu, cihaz işlemi, AI çağrısı veya Git commit/push içermiyor.

## Sonuç

- Mevcut Atlas logosu değiştirilmeden kullanılıyor. Statik filigran genişliği
  ekranın 1,35 katı, merkezi %50 yatay / %55 dikey ve opaklığı %12.
- Logo mevcut `CameraFocusRegion.clearArea` geometrisiyle çember/kulp
  açıklıklarından çıkarılıyor. Tabakta da mevcut hedef içi boş kalıyor.
  Canlı görüntü/buzlanma -> logo -> karartma/efektler -> kontroller sırası
  korunuyor. Dekorasyon dokunma ve erişilebilirlik ağacına katılmıyor;
  ayrı RepaintBoundary içinde animasyon yeniden boyamalarından ayrılıyor.
- Atlas için Fincanını Tara / Tabak Fotoğrafı başlıkları ve kısa adım
  etiketleri eklendi. Fincanın sabit tutulup kameranın hareket ettirildiği
  kısa, açıya uygun açıklamalar gösteriliyor. Alt bölümde mevcut ölçümlere
  bağlı tek dinamik yönlendirme bulunuyor.
- Atlas görünümünde debug böcek düğmesi yok. Genel paketin debug paneli
  ve sunum verilmemiş ekranların davranışı korundu.
- Otomatik · Açık/Kapalı kontrolü gerçek controller durumuna bağlı ve
  en az 48 dp dokunma alanına sahip. Çekim düğmesi 76 dp. Sayısal puan
  gizli; mevcut koşullarda Çekimi bitir eylemi erişilebilir.
- Işık ipucu, canlı görünümde iki saniye tarama yokken ve sürekli ışık
  kapalıyken açılıyor. Tarama/ışık açılması, çekim veya arka plana geçişte
  gizleniyor; zamanlayıcı yalnız sunumu etkiliyor. Tabak kendi telve
  analizini kullanıyor. Metin: Tarama görünmüyorsa ışığı açmayı dene.
- Onay düğmesinin uygulama metni Bu fotoğrafı kullan oldu. Yeniden çekim,
  onay, iptal ve kalıcı kaydetme işlemleri aynı kod yollarını kullanıyor.

## API ve uyumluluk

`CoffeeCameraConfig.presentation` isteğe bağlıdır; varsayılanı null.
`CoffeeCameraPresentation`, görüntü sağlayıcısı, başlık, kısa adım etiketi
ve isteğe bağlı açı açıklaması taşır. Mevcut constructor çağrıları çalışır.
Logo asset yolu uygulamanın capture_settings ayarlarında kalır; genel
kamera paketine Atlas varlık bağımlılığı eklenmedi. Yeni bağımlılık yok.

Sunum verilmemiş kullanım aynı kalır. V84 otomatik çekim eşikleri,
analiz/zamanlama, hedef geometrisi, buzlanma, kulp rehberleri, görüntü
boyutu, crop/EXIF dönüşümleri, kayıt şeması, ONNX, OpenCV ve AI kodları
bu çalışmada değiştirilmedi.

## Doğrulama

| Kontrol | Sonuç |
| --- | --- |
| Kamera paketinin tamamı | 130 geçti |
| Uygulamanın ilgili çekim/kırpma/kayıt/galeri testleri | 67 geçti |
| Son sunum metinleri sonrası yapılandırma/inceleme testi | 4 geçti; üstteki paketin alt kümesi |
| Kamera statik analizi | Sorun yok |
| Uygulama statik analizi | Sorun yok |
| git diff --check | Temiz |
| Başlangıçtaki 1165 dosyanın karşılaştırması | Yalnız planlanan sunum dosyaları değişti |

Yeni kamera testleri: fincan/sağ kulp/sol kulp/tabak içinde piksel eşitliği
ve dışarıda filigran varlığı; zamanlayıcının iki saniye, tarama, ışık,
arka plan ve dispose davranışı; küçük/uzun ekran ve 2x metin yerleşimi;
gerçek controller ile otomatik kontrolü, manuel çekim/onay, preview'da logo
olmaması. Aynı kaynak fotoğrafı gerçek CapturedImageProcessor üzerinden
sunumlu/sunumsuz işleyen testte crop koordinatları, boyutlar ve çıktı PNG
byte'ları aynı. V84 kamera testleri de pakete dahil ve geçiyor.

Normal boyutta kontroller dikey yerleşir. Dar ekran/büyük metinde otomatik
kontrol ve çekim düğmesi yan yana geçer. Hedefin üst/alt bölgesi ayrı
sınırlandığından metin ve kontroller çemberi örtmez. Alan yetmediğinde üst
açıklamalar kaydırılabilir; gövde açıklamaları kullanıcının metin ölçeğini
korur. Yalnız dekoratif ekran başlığı 1,4x ile sınırlanır. Hedef/önizleme
geometrisi bu uyarlamalar için değiştirilmez.

## Yerel görsel önizlemeler

Bunlar gerçek kamera görüntüsü değildir. Gerçek Flutter widget'ları,
mevcut Atlas logo/font varlığı ve yerel temsili fincan çizimiyle üretildi.
Üçlü özet: kamera-onizleme.png.

- free.png: Serbest açı, 390x844.
- handle-right.png: Kulp sağda, 390x844.
- handle-left.png: Kulp solda, 390x844.
- saucer.png: Tabak, 390x844.
- small-large-text.png: 320x568 ve 2x yazı.
- tall-large-text.png: 412x915 ve 2x yazı.

PNG'ler 2x piksel yoğunluğunda üretilmiştir. Küçük ve büyük yazılı
varyantlar dahil görsel olarak incelendi. Filigran çember ve kulp içinde
yok, normal yazıda açı talimatları ve ışık ipucu hedefin üzerinde kalıyor.

Kaynak günlükleri atlas_contribution_app/build/camera-brand altında:
camera-tests.log, app-tests.log, config-final-tests.log,
camera-analyze.log, app-analyze.log, preservation.json, before-hashes.json.
Görsel dışa aktarımı yeniden üretmek için coffee_camera klasöründe:
flutter test --no-pub --dart-define=WRITE_CAMERA_PREVIEWS=true test/camera_presentation_test.dart

Gerçek telefon performansı ve yeni görünümün cihaz kabulü bu teslimde
yapılmadı; telefondaki V84 güncellenmedi. Kullanıcı fotoğrafı kullanılmadı
ve dış hizmete görsel gönderilmedi.


## V86 — üstte sabit çekimi bitirme

İlk fotoğraftan sonra sağ/sol kulp adımlarında mevcut `onFinishSequence` eylemi, önceki krem renkli düğmesiyle flaşın sağında sabit kalır. Açıklamaları kaydırmak düğmeyi hareket ettirmez. Tek/iki fotoğrafla bitirme, kalıcı kayıt, çift dokunma koruması ve hata sonrası yeniden deneme davranışları korunur.

Doğrulama: 23 ilgili kamera testi ve 3 uygulama erken bitirme testi geçti; kamera statik analizi temiz. Küçük/büyük yazılı ekranlarda konum, görünür dokunma alanı ve hedef dışı yerleşim kontrol edildi.
