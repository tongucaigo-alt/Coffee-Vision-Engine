# Atlas V70 — Tarot tasarım yenilemesi

14 Ekim 2026. Dal: `codex/atlas-tarot-design-v2`.

## Kaynak ve kapsam

Güncel `coffee-ui` çalışma kopyası V69 kaynaklarıyla birlikte ayrı çalışma ağacına alındı. Kullanıcının commit edilmemiş 10 OpenCV/kahve dosyası değişmeden taşındı ve yalnız yerel başlangıç checkpoint'i olarak `9a58f821ed39bd47405935c6cc2883557c479cf7` commit'inde korundu. Asıl çalışma kopyası değiştirilmedi.

Başlangıç manifestinde 1.112 dosya byte hashleriyle doğrulandı. Tasarım değişikliği yalnız `tarot_pages.dart`, onun yeni özel sunum parçası `tarot_presentation.dart` ve ilgili widget testindedir. Ortak tema, kahve ekranları, kamera, OpenCV, kart kataloğu/görselleri, Tarot çekimi/deposu/AI istemcisi ve prompt değişmedi. Veri göçü ve public constructor değişikliği yoktur.

## Görünüm

- Giriş paneli açık krem; mevcut Atlas ana düğmesi kahverengi ve ortalıdır. Günün Kartı aynı genişlik bileşenini kullanır. Kart çizimleri aynıdır.
- Deste açık adaçayı zemininde 96dp kartlar, 100dp yatay adım ve en fazla 6° eğim kullanır. Kapalı kimlikler açıklanmaz; dokunulan kart indeksi aynen korunur.
- Açılışta kart adları ve Düz/Ters etiketleri belirgindir. Ters ön yüz 180° döner. Karıştırma/taşıma/açılış 500/240/600ms; iki ince halka ve sekiz hafif parçacık bulunur. Hareket azaltmada geçişler doğrudandır.
- Yorum üstünde küçük kart özeti; en fazla 600dp panel, 16sp metin ve 1,65 satır yüksekliği kullanılır. Başlık/kalın/italik işaretleri yalnız gösterimde biçimlendirilir. Kaydedilmiş yorum, AI girdisi ve metnin içeriği yeniden yazılmaz.
- Geçmişte küçük kart görselleri ve mevcut işlem durumunu anlatan etiketler vardır. Açılmamış ön yüzler gizli kalır. Okuma/devam, yıldızlama ve silme akışları aynıdır.
- Dar ekran veya 1,5 katı aşan yazı ölçeğinde üç kart dikey gösterilir. İçerik kaydırılabilir; eylemler en az 48dp dokunma alanına sahiptir.

## Doğrulama

- Başlangıç Tarot widget grubu: 9 başarılı.
- Son Tarot model/AI/widget grubu: 34 başarılı. Uzak deste indeksine seçim, kapalı geçmiş görselleri ve biçimlendirilmiş metnin depoda değişmemesi ayrıca kontrol edildi.
- Tam uygulama grubu: 426 başarılı, 7 atlanan. Gruplar örtüşür; sayıları toplanmaz. Flutter analizi sorunsuzdur.
- 320×568, 360×700, 412×700; normal/iki kat yazı, çentik ve hareket azaltmada altı ekran durumu için 36 önizleme doğrulandı. Sekiz önce/sonra karşılaştırması ayrıca incelendi.
- Önizleme yorumları test verisidir. Bu tasarım çalışmasında ücretli Kimi üretimi başlatılmadı. Canlı yorumun içerik kalitesi bu UI testleriyle kanıtlanmaz.

## APK ve kurulum

`Atlas-Tarot-Tasarim-V70.apk`; paket `com.coffeeplatform.atlas_contribution_app.diagnostic`, sürüm `1.0.0-kimi-test.70`, kod 70, görünen ad `Atlas Fotoğraf Testi V70`.

APK, mevcut V69 test uygulamasıyla eşleşen debug imzasını kullanır. Üretim giriş noktası `lib/offline_main.dart`; AI Laboratuvarı, Diagnostic, Kimi yerel test ve görsel uygunluk build ayarları korunur. Özel bağlantı dışarıdaki build tanımından gelir; anahtar dosyaları kaynakta tutulmaz. APK yerel test içindir; mağaza veya GitHub yayını yapılmadı.

SHA-256: `73f3fccbf30b634f67a9619c176fe7dffd33dcb21b8c99a2cdf1676741ab260e`.

79 WebP, 78 kartlık katalog ve ONNX modelinin paket içeriği kaynakla karşılaştırıldı. Samsung A56 üzerinde kurulu V69, `tool/install_preserving_data.py` ile kimlik/imza/yükselen sürüm doğrulamasından sonra yalnız `adb install -r` kullanılarak güncellendi. Kaldırma veya veri temizleme yapılmadı. Kurulumdan hemen sonra mevcut 40 uygulama dosyası byte düzeyinde aynıydı; ilk kurulum tarihi ve normal Atlas paketinin sürüm/kurulum bilgileri korundu.

Telefondaki seçim/açılış kontrolü gerçek, yeni bir yerel Üç Kart açılımı kullandı; sahte yorum kayıtlarına eklenmedi. Üç kart sırayla açıldı; iki ters kart ve etiketleri görsel olarak incelendi. Soğuk açılıştan sonra aynı kartlara devam edildi. Yeni açılımın yorum durumu `idle` kaldı. Geçmişteki mevcut tamamlanmış yorum yeni üretim yapmadan açıldı; eski kayıt tüm alanlarıyla korundu. Kahve ana ekranının erişilebilirlik metinleri ve yerleşim sınırları kurulum öncesiyle aynıydı.

Telefon kontrollerinden sonra 38 diğer uygulama dosyası byte düzeyinde aynı kaldı. Tarot durum dosyası yalnız gerçek test açılımının eklenmesiyle değişti; mevcut yorum ve günlük kilitler korundu. Android'in `profileInstalled` çalışma işareti yeni APK açılışından sonra güncellendi; bu kullanıcı kaydı değildir. Yorum üretimi kullanıcı işlemine bırakıldı. Bilgisayardaki yorum önizlemeleri test verileridir.

Teslim klasörü: `C:/Users/exzau/Documents/Codex/2026-10-14/atlas-tarot-design-v2-output`. APK, ekran önizlemeleri, telefon görüntüleri, test/analiz/build logları ve doğrulama raporları buradadır. Yerel kayıt yedeği Git kapsamı dışındadır.
