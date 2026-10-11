# Atlas V51 — Renkli telve izleri

11 Ekim 2026. V34 GitHub kaydı üzerindeki V48–V51 yerel geliştirmeleri birleştirilmiştir. Geri dönüş etiketi: `atlas-v51-renkli-izler`.

## Kullanıcı deneyimi
- Kamera/galeri → önizleme → şekilleri incele veya atla → kaydet ve fal oluştur → tek hazırlık ekranı → sonuç akışı korunur.
- OpenCV 4.13.0, fincan görsellerinden toplam en fazla dört telve izi çıkarır. İzler artık kullanıcı şekil seçerken görünür; kullanıcı kutuları ayrı katmanda kalır. Tabak için renkli iz çıkarılmaz.
- Hazırlık ve sonuçta aynı renkli katman kullanılabilir. Sonuç fotoğrafında Orijinal / Renkli izler seçimi ve bir ize dokununca tek yakın görüntü paneli bulunur.
- Hazırlık ekranındaki yeşil noktalı çember yaklaşık %17 büyütülmüştür. Dekoratif şekiller/parlamalar izlerin turkuaz, pembe, mavi ve sarı paletini kullanır.
- İzler sembol tanıma sonucu değildir; kuş/ağaç adı atanmaz. Kaynak fotoğraf, kırpma, kullanıcı kutuları ve fal girdisi değiştirilmez. Dekoratif şekiller analiz bulgusu sayılmaz.

## Teknik ayrıntılar
- Mevcut yerel ONNX fotoğraf kontrol modeli, V48 açılış/R8 koruması ve mevcut Kimi test bağlantısı korunur.
- Native iz çıkarma sıralı ve arka planda çalışır. Önbellek fotoğraf checksum'ı, kırpma ve algoritma sürümüne bağlıdır; bozuk önbellek yenilenir, kayıt silinince temizlenir. İz hatası normal işaretlemeyi veya kullanılabilir fal akışını engellemez.
- Renkli yardımın gösterimi `coloredTraceAid` olarak ayrı geçmişe kaydedilir. Bu yardım sonrası gözlemler yardımsız bağımsız gözlem sayılmamalıdır. Önceden mühürlenmiş ilk gözlemler değiştirilmez.
- Kamera geometrisi, motor public sözleşmeleri, AI promptu ve araştırma ZIP formatı bu iz geliştirmesinde değiştirilmez.

## Doğrulama
- V49: ana test çalıştırmasında 300 başarılı, 6 atlanan; gerçek Android'de 6 entegrasyon testi ve ayrı gerçek Kimi üretim yürüyüşü başarılı.
- 12 mevcut fincan fotoğrafında iz çıkarma 178–538 ms; üç fotoğraf seti 674 ms (debug cihaz ölçümü, genel hız/doğruluk garantisi değildir).
- V50: işaretleme/çoklu dokunma/görünüm/iz kontrollerinde 74 test; ayrı AI/veri kontrol grubunda 37 test başarılı. Gruplarda ortak testler vardır, sayılar benzersiz toplam olarak toplanmaz.
- V50 renkli işaretleme ekranı gerçek telefonda görüldü; V49'un tek fotoğraflı taslağı yerinde güncellemede korundu.
- V51: 22 hazırlık/animasyon/iz regresyon testi ve Flutter analizi başarılı; aynı paket ve imzayla V50 üzerine kaldırmadan kuruldu. Bu son görsel dokunuş için yeni ücretli fal isteği başlatılmadı.
- Fotoğraf kontrolünün tüm nesnelerde başarısı, otomatik sembol tanıma, genel fal kalite artışı veya Google Play yayın hazırlığı bu sürümle tamamlanmış sayılmaz.

## Cihaz test güvenliği ve bilinen olay
V49 çalışmasında bir Flutter integration test teardown komutu normal V48 paketini yanlışlıkla kaldırdı. Bu olay nedeniyle eski özel uygulama verilerinin tümünün korunabildiği iddia edilemez; araştırma ZIP'leri yalnız kısmi kurtarma sağladı. Yedekler ve kullanıcı verileri Git'e eklenmez.

Yeni cihaz testlerinde `atlas_contribution_app/tool/run_diagnostic_test.py` kullanılmalıdır: önce diagnostic APK derlenir, paket kimliği doğrulanır, `--no-uninstall` kullanılır ve normal/beta kurulum kimlikleri önce/sonra denetlenir. Normal telefonda doğrudan varsayılan integration-test kaldırma davranışı kullanılmamalıdır. Kurulum için `tool/install_preserving_data.py`, daha yüksek sürümü ve eşleşen imzayı doğrulayıp yalnız `adb install -r` kullanır.

## V51 test APK'sını yeniden oluşturma
Bu paket yalnız izinli test dağıtımı içindir. API anahtarı ve kurucu imza dosyaları depoya eklenmez. Android `key.properties` ve özel JSON build defines dosyası ayrı, yerel olarak sağlanmalıdır. Gizli JSON içinde `ATLAS_KIMI_TEST_KEY` tanımlanır; değeri belgeye veya kaynak koduna yazılmaz.

Uygulama klasöründe:

```powershell
flutter build apk --release --target lib/offline_main.dart --build-name 1.0.0-kimi-test.51 --build-number 51 --dart-define=ATLAS_AI_LAB=true --dart-define=ATLAS_KIMI_LOCAL_TEST=true --dart-define=ATLAS_IMAGE_SCREEN=true --dart-define-from-file='<özel-defines-dosyası.json>'
```

`ATLAS_IMAGE_SCREEN=true` mevcut ONNX kontrol modelini pakete dahil eder; korunmalıdır. APK/AAB çıktıları bu kaynak kaydına dahil edilmez. APK ortak test anahtarı taşıdığı için herkese açık GitHub release varlığı olarak yayımlanmaz.

Telefona kurulan V51 APK SHA256: `359031844c33e3528b54e9a960435201d152b88a9910db4b82d558a4cd44e589`.
