# Çekim akışını geri bağlama — 29 Eylül 2026

## Değişiklik

GitHub `5f7e4c3` karşılaştırma referansı olarak kullanıldı. Çalışma ağacındaki Beta 7–8 düzeltmeleri geri alınmadı; push yapılmadı.

- Fincanını Tara ana ekranda taslak varken de görünür. Devam kartı ayrıca korunur.
- Fotoğraflı taslak için devam / taslağı sil ve yeni çekim / vazgeç seçimi vardır. Silme başarısızsa yeni çekim başlamaz; kaydedilmiş fallar silinmez.
- Boş taslak yeni kamera başlangıcına engel olmaz. Devam kamera taslağında ilk eksik açıya, galeri taslağında önizlemeye gider.
- Kamera/galeri meşgul durumu fal hazırlama ekranını açmaz. Bu ekran yalnız kayıt–analiz–fal işleminin aktif olduğu sırada gösterilir.
- İşaretleri Gözden Geçir geri getirildi. Alt eylemler ekranın en fazla yüzde 40'ını kullanır ve gerekirse kaydırılır.
- Yönlendirmeler, blur, eşikler, prompt ve anahtar yönetimi bu onarımda değiştirilmedi. Gerçek cihazda ortaya çıkan açılış/duraklatma çakışması için kamera denetleyicisinde dar bir yaşam döngüsü düzeltmesi yapıldı; görünüm ve hesaplar değişmedi. Yıldızlar, manuel saklama, onay ve ZIP işlevleri korunur.

## Doğrulama

- 237 Flutter testi başarılı; iki isteğe bağlı canlı test atlandı.
- Kamera testleri artık üretim uygulamasındaki FortuneProgress bağlantısını da taşır. Gerçek kamera görünümünü kanıtlamak için ayrıca fiziksel cihaz yürüyüşü gerekir.
- Yeni testler kamera ve galeri taslağında ana düğmeyi, vazgeçmeyi, başarısız taslak silmeyi ve başarılı yeni başlangıcı doğrular.
- İşaretlemeye geri dönünce kararların korunması sınanır.
- Diagnostic cihaz koşusu: 19 test başarılı; gerçek Android ZIP ve 74 görüntünün yerel model kontrolü dahil.
- Ek 10 kamera regresyon testi başarılı; askıda kamera çağrısında fal ekranı açılmaması, 360×640 ekranda 1,8 yazı ölçeği dahil. Değişen dosyaların statik analizi temiz.
- Gerçek kamera yürüyüşü ve beta kurulum sonuçları aşağıya eklenecek.

## Fotoğraf uygunluğu

Kesin engelleme kapalıdır; deneysel uyarı devam eder. Önceki 74 kahve referansında 62 desteklenen, 12 kararsız, sıfır uygunsuz sonucu vardır. 30 olumsuz / 10 klavye örneği olmadığından engelleme kabulü tamamlanmış değildir. Bu durum kamera akışının onarımından ayrıdır.

## Gerçek cihaz yürüyüşünün durumu

Ayrı `.diagnostic` uygulamasında üretim giriş noktası (`lib/offline_main.dart`) açıldı; ana ekrandaki Fincanını Tara görüldü ve basıldı. Beyanlar kullanıcı adına işaretlenmedi. Kullanıcı ilerledikten sonra ilk kamera açılışında `CameraController was used after being disposed` hatası görüldü. Tekrar denemede açıldı. İzin/uygulama yaşam döngüsü geçişlerinde initialize, pause, resume ve retry sıraya alındı; close bekleyen işlemi tamamlamadan cihazı kapatmıyor. Başlangıç sürerken duraklatma/devam ve kapanma için iki yarış testi eklendi; 95 kamera testi başarılı.

Güncellenmiş diagnostic paket veri temizlemeden kuruldu. Bir fincanlık taslak korundu; devam düğmesi doğru şekilde ikinci açıya (kulp sağda) açıldı. Yuvarlak alan ve sağ kulp kılavuzu görüldü. Canlı önizleme siyah göründüğünden kullanıcıdan telefonun hâlâ fincana dönük olup olmadığı teyidi bekleniyor. Üç açı, yeşil noktalar, tabak ve yeni fal yürüyüşü henüz tamamlanmış sayılmaz.

Android, debug APK açılırken 16 KB yerel kitaplık uyumluluk uyarısı gösterdi. Uyarının Tamam düğmesiyle devam edildi; kalıcı olarak susturulmadı. Bu onarımın parçası olarak kitaplık sürümleri değiştirilmedi; ayrı uyumluluk çalışması gerekebilir.

## Paket

Beta 9 APK: `build/atlas-beta-v9.apk`, `versionCode=9`, `versionName=1.0.0-beta.9`, paket `.beta`. Beta 8 ile imza SHA-256 eşleşmesi doğrulandı.
APK SHA-256: `F6E79BA3A7B2184E19D2CB10EB051A90EF1546AFF2F3BE318040BC2D512667B5`.


Beta 9 veri silmeden telefona kuruldu. Açılış yaşam döngüsü düzeltmesini içeren yeni paket: `build/atlas-beta-v10.apk`, `.beta`, versionCode 10, versionName 1.0.0-beta.10. Önceki paketlerle imza SHA-256 eşleşti. APK SHA-256: `DE0F76CA85FF85D1D779552083E52F830E776C4796688D2465BB20B1A352053D`. Beta 10 `adb install -r` ile başarıyla kuruldu; kaldırma ve veri temizleme yapılmadı. Gerçek kamera kabulünün tamamlanması bekleniyor.
