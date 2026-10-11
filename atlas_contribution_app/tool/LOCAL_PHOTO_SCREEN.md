# Yerel fotoğraf kontrolü · 3 Ekim 2026

Model `android/app/src/imageScreen/assets/atlas_screen_v5.onnx` içindedir.
SHA-256: `17cb073e902c459ebc04fe9b14a2ba10ec968a4c378c40fbd8199f7c5b0ff5d4`.
Tek doğrulanmış yeni modül, sabit MobileNetV3-small özellikleri üzerinde yerel
olarak eğitilen dengeli ridge başlığıdır. İnternete görüntü göndermez.

Mevcut derleme seçeneklerine `--dart-define=ATLAS_IMAGE_SCREEN=true` eklemek
modeli etkinleştirir. Kimi, laboratuvar/Play, imza ve sağlayıcı seçenekleri
değişmez. Seçenek verilmezse önceki kontrol sürümü korunur. Yeni model yalnız
fincan yüzeyine uygulanır; tabak için bağımsız doğrulama yapılmadığından mevcut
tabak kontrolü korunur.

Gerçek görüntüdeki EXIF yönü uygulanır; RGB görüntü Pillow ile aynı 22 bit
katsayılı, kenar yumuşatmalı bilinear küçültmeyle 224×224'e iner. Tam kare ve
ekranda görülen kırpma ayrı değerlendirilir. İki puan da
`-0.4117240578933279` altında ise ret adayıdır; en az bir puan
`0.27635831503150343` üzerinde ise desteklenir; diğer durumlar belirsizdir.
Bu sınırlar geliştirme grubu çapraz doğrulamasında sabitlenmiştir.

Desteklenen ve belirsiz fotoğraflar onay penceresi açmadan sessiz ilerler.
Açık olumsuz karar önizlemede mevcut fotoğraf değiştirme/kaldırma eylemleriyle
çözülür. Eski bir kayıt yeni kontrolden geçmezse fal sayfası önizlemedeki
şiirsel uyarıyı tekrar göstermez; kayda dönüş eylemini sunar. Teknik hatalar
fotoğrafın uygunsuz olduğu şeklinde yorumlanmaz; yeniden deneme korunur.
Önbellek sürüm, dosya özeti, yüzey ve kırpmaya bağlıdır.

Geliştirme: daha önce görülen 411 fotoğraf, 380 grup. Bu veri nihai başarı
iddiasında kullanılmadı. Önceki V3/V4 bağımsız gruplarında bulunan yanlış
retler geliştirme verisine taşındı; bu eski gruplar tekrar bağımsız sayılmadı.

Son bağımsız cihaz seti: 107 fotoğraf, 99 grup. 33 telveli fincanda sıfır
yanlış ret, 30 desteklenen ve 3 belirsiz; telvesizde 19/23 grup (%82,6),
çakmakta 15/17 (%88,2), klavyede 16/16 ve portrede 10/10 ret başarısı.
Hata sıfır. Aynı fincanın açıları ve olası stok kopyaları tek grupta sayıldı.
Ham fotoğraflar ve gerçek `preparePhoto` içe aktarma yolunun ürettiği
EXIF yönü düzeltilmiş, en fazla 2048 piksel, metadata içermeyen JPEG90
dosyalar telefonda ayrı ölçüldü; kararlar aynı kaldı. Hazırlanmış dosyalarda
medyan iki görünüm değerlendirmesi 243 ms, en uzun ölçüm 1202 ms oldu.
Grup bağımsızlığı görsel/kaynak ve piksel kopya kontrolüne dayanır;
fotoğrafçı tarafından doğrulanmış değildir. Bu sonuç her yeni fotoğrafta
sıfır hata garantisi değildir. Ham çevrimiçi fotoğraflar uygulamaya/Git'e
eklenmedi; kullanım lisansları varsayılmadı. Çıktıdaki kaynak manifesti yerel
değerlendirme kökenini kaydeder.

Kabul ölçütleri V5 bağımsız puanları okunmadan sabitlendi: telvelide en az
30 grup, sıfır yanlış engel, ayrıca en az %80 açık destek; telvesizde en az
20 grup, diğer her sınıfta en az 10 grup ve ayrı ayrı en az %80 ayırma;
teknik hata sıfır. Belirsiz sonuçlar açık destek olarak sayılmaz. Önceki
raporun tüm fincanlarda açık destek şartı, kullanıcı akışındaki sessiz kabul
ile karıştırıldığı için bu iki ölçü ayrı raporlanır; belirsiz-tümünü-geçir
politikasının kabulü hâlâ engellenir.

Araçlar:

- `train_image_screen.py`: yalnız geliştirme/kalibrasyon üzerinde eğitim.
- `evaluate_frozen_screen.py`: sabit model ve karar dosyası ile yerel ölçüm.
- `image_screen_benchmark.dart`: yalnız ayrı tanılama paketinde cihaz ölçümü.
- `report_suitability.py`: belirsizleri/hataları paydadan çıkarmayan grup raporu.
- `integration_test/local_screen_flow_device_test.dart`: ayrı pakette akış,
  gerçek yerel model kararı, kalıcı önbellek ve sessiz önizleme kontrolü.

Geliştirme fotoğrafları, model özellik önbellekleri ve ham doğrulama setleri
repo dışındaki çalışma klasöründe kalır. Kullanıcının kurulu ana uygulaması,
özel kayıtları, API anahtarları ve rızaları tanılama testlerinde kullanılmaz.
