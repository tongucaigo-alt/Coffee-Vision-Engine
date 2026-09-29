# Temel parça — arayüz prototipi

29 Eylül 2026 · Beta 10 · Geri dönüş referansı

Bu etiket mevcut motor, arayüz ve test akışının birlikte saklanan prototipidir. Üretim sürümü veya bütün kabul testleri tamamlanmış sürüm anlamına gelmez.

## Sabit referans

- Git etiketi: `temel-parca-arayuz-prototip-beta10`
- Çalışma dalı: `feat/atlas-contribution-beta-v1`
- Önceki GitHub referansı: `5f7e4c3`
- Android: `.beta`, versionCode `10`, versionName `1.0.0-beta.10`.

Sonraki geliştirmeler bu etiketi değiştirmemeli. Sorun durumunda bu etiketten ayrı bir onarım dalı/çalışma alanı açılarak karşılaştırma yapılabilir; mevcut çalışma veya telefon kayıtları otomatik olarak silinmez. Git etiketi kaynak kodu saklar, telefondaki kullanıcı verisinin yedeği değildir.

## Bu noktada bulunan özellikler

- Fincanını Tara, taslaktan devam ve açık seçimle yeni çekim başlatma.
- Serbest açı → kulp sağda → kulp solda; isteğe bağlı tabak ve galeri fotoğraf setleri.
- Küçük işaretleme kutuları, işaretleri gözden geçirme, yalnız kaydet / kaydet ve fal oluştur.
- Kamera/galeri işlemleriyle fal hazırlama durumlarının ayrılması.
- Kamera açılış, duraklatma, devam ve kapanış çakışması için yaşam döngüsü düzeltmesi.
- AI bağlantıları, metinsel fal girdisi, beta okunabilir yanıt davranışı.
- 20 yıldız, yıldızlılar filtresi, yerel kayıtların manuel silinene kadar tutulması.
- Tek seferlik yerel kullanım kabulü; kayıt bazında bağımsız araştırma izni ve izinli ZIP.
- APK içindeki yerel fotoğraf uygunluğu modeli; deneysel uyarı modu.

## Doğrulama ve açık noktalar

- 237 uygulama testi geçti; iki isteğe bağlı canlı test atlandı.
- 95 kamera testi geçti; başlatma sırasında duraklatma/devam ve kapanma yarışları dahil.
- Önceki diagnostic cihaz koşusunda 19 test geçti; gerçek Android ZIP ve yerel model kontrolü dahil.
- Beta 10 aynı imzayla veri temizlemeden telefona kuruldu.
- Gerçek cihazda bir fotoğraflık taslaktan ikinci açıya devam ve sağ kulp kılavuzu görüldü. Son canlı önizleme siyah göründü; telefonun yönüyle ilgili kullanıcı teyidi bekleniyor. Üç açıda yeşil noktalar/buzlanma ve yeni fala kadar tam yürüyüş henüz tamamlanmadı.
- Kahve dışı görüntü engellemesi için gerekli olumsuz örnek ölçümü eksik; kesin engelleme kapalı.
- Fal kalitesinin kör karşılaştırma kabulü tamamlanmadı.
- Diagnostic debug açılışında Android 16 KB yerel kitaplık uyumluluk uyarısı görüldü; ayrı inceleme gerekiyor.

Ayrıntılar: [kamera onarımı](atlas_contribution_app/CAMERA_FLOW_RESTORE.md), [Beta 8 kontrolleri](atlas_contribution_app/SIMPLE_FLOW_VALIDATION.md), [fal gösterimi](atlas_contribution_app/BETA_FORTUNE_DELIVERY.md).

## Paket ve özel dosyalar

Yerel APK: `atlas_contribution_app/build/atlas-beta-v10.apk`.
SHA-256: `DE0F76CA85FF85D1D779552083E52F830E776C4796688D2465BB20B1A352053D`.

APK, API anahtarları, imza anahtarı, özel yapılandırma, kullanıcı fotoğrafları ve cihaz verileri Git'e dahil değildir. Aynı imzalı APK yeniden oluşturmak için mevcut özel imza ve test yapılandırması ayrıca gereklidir. Kaynak ve uygulamanın paketlediği yerel sınıflandırma modeli bu referansta saklanır.
