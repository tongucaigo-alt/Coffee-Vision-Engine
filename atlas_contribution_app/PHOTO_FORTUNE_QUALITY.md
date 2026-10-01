# Fotoğraf ve fal kalitesi — 29 Eylül 2026

## İlk aşama

- Kamera geometrisi ve üç açı akışı değişmedi.
- Mevcut uygunluk uyarıları şiirsel ama açıklayıcı metinlerle güncellendi. Kararsızlık ve teknik hata ayrı anlatılır; devam ve değiştirme mevcut akışa döner.
- Deneysel uygunsuzluk sonucunda kullanıcı devam edebilir. Kesin engelleme ölçüm geçmeden açılmaz.
- Model çıkışı etiket/puan açısından doğrulanır; bozuk çıktı teknik hataya dönüşür.
- Yeni kontrol kayıtlarında `residueAssessment=notAssessed`: ImageNet fincan desteği telvenin varlığını doğrulamaz. Eski kayıtlar yeniden yazılmaz.
- Ortak prompt v6: paragraf başına kelime kotaları kaldırıldı; toplam 250–400 hedefi korunur. Ana konu ve en fazla bir doğal yan konu, farklı semboller için farklı bağlantılar, kısa ve tekrar etmeyen kapanış istenir. Beta okunabilir yanıt politikası değişmedi.
- APK ve Node aynı prompt dosyasının hash'ini hesaplar. Çalışan servis yeniden başlatılmadan yeni promptu yüklemez.

## Yerel sembol yöntemi araştırması

1. Mevcut EfficientNet-Lite0: ImageNet genel nesne sınıflandırıcısı; telve şekillerini adlandırdığı varsayılamaz. Genel fotoğraf uygunluğu için mevcut adaydır.
   https://developers.google.com/edge/mediapipe/solutions/vision/image_classifier
2. MediaPipe Image Embedder: yerel görsel benzerlik ölçebilir; anlamlı örnek kütüphanesi ve değerlendirme gerektirir. Benzerlik puanı sembol doğruluğu değildir. Şu an referans sembol verisi olmadan devreye alınmamalı.
   https://developers.google.com/edge/mediapipe/solutions/vision/image_embedder
3. SmolVLM-256M-Instruct: Apache-2.0, İngilizce görsel/metin model adayı. Model kartı tek görüntü için 1 GB altında GPU belleği bildiriyor; bu telefon belleği/hızı garantisi değildir. Android runtime, model boyutu, enerji, konumlandırma ve telve çağrışımı başarısı cihazda ayrıca ölçülmeli. Bu çalışmada indirilmedi veya uygulamaya eklenmedi.
   https://huggingface.co/HuggingFaceTB/SmolVLM-256M-Instruct

Karar: Rastgele isimlendirme veya yoğunluktan sembol çıkarma eklenmez. Başarılı yerel yöntem gösterilene kadar öneri UI'si ve araştırma ZIP değişikliği bekler. İleride ilk gözlem ayrı ve değişmez tutulacak; öneri geri bildirimi bağımsız kullanıcı etiketi sayılmayacak.

## Kabul eksikleri

- Önceki kaynak klasörlerinde 115 JPG var; önceki ölçüm 74 benzersiz kahve referansı içeriyor. Yeni olumsuz ve telvesiz örnek klasörü kullanıcıdan istendi.
- En az 30 uygun + 30 ilgisiz (10 klavye dahil) ölçümü tamamlanmadan kesin engelleme açılmaz. Boş fincan/dolu kahve/temiz tabak ayrı ölçülür.
- Yeni promptun gerçek karşılaştırması ve insan tercihi tamamlanmadan fal kalitesi iyileşti denmez.
- Fotoğraflar dış AI'ya gönderilmez; canlı fal testlerinde yalnız mevcut izinli metinsel payload kullanılabilir.
- Beta 10'da açık kalan siyah kamera önizlemesi ve gerçek üç açı yürüyüşü bu çalışmada çözülmüş sayılmaz.


## Bu çalışma sırasında doğrulama

- 243 Flutter testi başarılı; 2 isteğe bağlı canlı test normal koşuda atlandı.
- Node servisindeki 17 test başarılı. Yeni sürüm ve prompt byte hash uyumu korundu.
- Değişen Dart dosyalarının statik analizi temiz; git diff whitespace kontrolü temiz.
- Uyarı widget testleri devam/değiştirme/teknik hatadan tekrar denemeyi sınar. Gerçek karar saklama mevcut dosya tabanlı testle ayrıca doğrulanır. Bu testler sınıflandırma doğruluğunu kanıtlamaz.

### Canlı metinsel karşılaştırma

Mevcut 12 örneğin yalnız güvenli context alanları doğrulandı ve aynı Kimi modeli (kimi-k2.6), temperature 0.6, düşünme kapalı, aynı max token sınırı ile v5/v6 karşılaştırıldı. Fotoğraf dosyası açılmadı veya gönderilmedi. Her sürümden tek aday istendi; bu karşılaştırma üretimdeki düzeltme akışını sınamaz.

24 aday isteğinin 5'i metin döndürdü, 19'u HTTP 429 ile reddedildi. Eksik örnekler dışlanmadı, otomatik yeniden istek yapılmadı. Tam çift sayısı yalnız 2 olduğundan 12 set kabulü tamamlanmadı. Dönen metinler 163–233 kelime arasındaydı; 250–400 hedefini sağlamadı. Beta okunabilir yanıt davranışı bundan ayrı kalır.

Manuel okuma: v6 kuş örneğinde kullanıcı sembolünün ölçülmüş leke üzerine yerleştirilmesi, ortama ilişkin varsayımlar ve yinelenen alan/yoğunluk anlatımı görüldü. İki sürümde de soyut anlatı ağırlığı sürüyor. Kalite iyileşmesi doğrulanmadı; v6 çalışma adayıdır, telefona veya çalışan servise dağıtılmadı.

Yerel ve Git dışında sonuçlar:
- `build/quality-v6-comparison.json`: tüm başarılı/başarısız adaylar ve sürüm eşlemesi.
- `build/QUALITY_V6_BLIND.md`: kimlikleri gizlenmiş metinler; tercihler henüz alınmadı.
- `build/quality-v6-tests.log`: tam Flutter koşusu.

Sonraki bağımlılıklar: olumsuz/telvesiz gerçek örnekler, servis erişimi ve insan değerlendirmesi. Kesin engelleme, telvesiz fincan tespiti, deneysel sembol önerisi ve yeni APK teslimi tamamlanmış sayılmaz. GitHub push ve cihaz kurulumu bu çalışmada yapılmadı.


## Yeni olumsuz örnekler — Uİ foto

Kullanıcının sağladığı klasörde 7 farklı JPEG görsel incelendi: 2 telvesiz fincan (beyaz ve koyu iç yüzey), 2 telvesiz tabak (desenli ve kabartmalı), 3 kahve dışı görüntü (logo ekran görüntüsü, çizim, sarı nesne). Klavye veya içi kahve dolu fincan yok.

Kaynaklar değiştirilmeden birebir test kopyaları `build/suitability-negative-20260929/device` altına alındı; checksum'lar ve insan tarafından belirlenen örnek grupları yerel manifestte kayıtlı. Kaynak dosya adları cihaz manifestine taşınmadı. Yedi örnek bağımsız checksum taşıyor; bu küçük küme yayın ölçütünü karşılamıyor.

Ayrı `integration_test/suitability_negative_device_test.dart` hazırlandı. Aynı APK modelini native kanal üzerinden çalıştırır, ham ilk üç sınıfı/puanı ve süreyi kaydeder. Başarılı test yalnız çıkarımın teknik olarak çalıştığını gösterir; uygunsuz görüntüyü engelleme başarısı değildir. Tam ve kırpılmış görünüm bu koşuda aynı tutulur. Üretim uygulaması ve kesin engelleme politikası değişmez.

Hazırlık sırasında ADB bağlı cihaz göstermedi. Gerçek cihaz sonucu alınmadan modelin bu yedi görüntüyü ayırdığı iddia edilmez.

Bu ölçüm için `.diagnostic` debug APK derlemesi başarılı; üretim beta uygulamasına kurulum yapılmadı.


## Yedi olumsuz örnek — cihaz sonucu

3 supported, 4 uncertain, 0 unsuitable, 0 teknik hata. Ortanca süre 110 ms. İki temiz tabak ve beyaz boş fincan supported çıktı; koyu boş fincan ve üç ilgisiz görüntü uncertain çıktı. Supported yalnız nesne desteğidir, telve tespiti değildir. Mevcut kontrol telvesizliği ayıramıyor. Kesin engelleme açılmadı; belirsiz görüntüde kullanıcı devam edebilir.

Yedi örnek yayın kabulü veya genel doğruluk ölçümü değildir; klavye ve dolu kahve örneği yok. Model eğitilmedi, bu örneklere göre eşik ayarlanmadı. Tüm kaynak checksum değerleri test sonunda doğrulandı; kaynak görseller değişmedi. Fotoğraflar dış AI'ya gönderilmedi.

Kurulum notu: Flutter diagnostic versionCode 10 üzerine 1 kurarken downgrade hatası aldı ve yalnız diagnostic paketi kaldırıp yeniden kurdu. Önceki diagnostic test verileri korunmuş sayılamaz. Beta paketine kurulum/kaldırma yapılmadı; Beta 10 sürümü ayrıca doğrulandı. Sonraki diagnostic koşusunda sürüm düşürülmemeli.

Ham skorlar ve rapor: `build/suitability-negative-20260929/benchmark.json`, `RESULT.md` (Git dışında).
