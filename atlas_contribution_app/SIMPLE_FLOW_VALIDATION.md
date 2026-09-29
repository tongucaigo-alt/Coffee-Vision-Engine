# Sade akış ve yıldızlar — Beta 8 doğrulama

## Uygulananlar

- Ana ekrandaki teknik veri bildirimi kaldırıldı; bilgi Ayarlar alanında tutuldu.
- Fotoğraf başına kullanılabilirlik tikleri kaldırıldı. Çoklu fotoğrafta aynı fincan beyanı sürüyor. Yerel kontrol, kullanıcı onayıymış gibi yazılmıyor.
- Sabit ve belirgin Şekilleri İncele eylemi; Kaydet ve Falını Oluştur / Yalnız Kaydet ayrımı. Mevcut güncel fal okuma, eski falın ardından başarısız yeni üretimde yeniden deneme korunur.
- Yerel kullanım kabulü sürümlü olarak bir kez hatırlanır. Yeni kayıtların araştırma izni ayrıca verilir; genel kabul bunu açmaz.
- Sonuç kimliğine bağlı en fazla 20 yıldız; filtre, kaldırma ve manuel silmede temizleme. Yeni revizyona yıldız aktarılmaz.
- Yerel 180 günlük süre dolumu kaldırıldı; eski yerel kayıtlar da korunur. Çevrimiçi kayıtların saklama politikası değişmedi. Yerel toplam 30 kayıt engeli kaldırıldı; bağımsız araştırma incelemesi sınırı ayrı kalır.
- Review v4, eski v1/v2/v3 okumaya devam eder. İlk gözlemler değişmez. Yıldızlar, profiller ve fal metinleri araştırma ZIP'ine eklenmez.
- Ortak prompt v5: dolgu cümlesini azaltma, sembole anlamlı bağ, bölüm başına farklı düşünce. Beta 7'nin okunabilir cevabı gösterme davranışı korunur.

## Doğrulananlar

- Flutter testleri: 234 başarılı, 2 isteğe bağlı canlı test atlandı (son tam koşu).
- Android diagnostic: 16 test başarılı. Üçlü kamera, tek/çok galeri, tabak adımı, yeniden çekim, kayıt hatası, 20 yıldız ve saklama, iki gerçek Android ZIP yolu ve gerçek model çıkarımı.
- Statik analiz: hata yok.
- Node servis testleri: 17 başarılı.
- Kamera paketi ve frozen motor sözleşmelerine bu çalışma kapsamında değişiklik yapılmadı.

## Fotoğraf kontrolü: deneysel

Kullanıcının sağladığı iki klasördeki 115 dosya incelendi. Birebir checksum tekrarları ayrılınca 74 kahve/fincan/tabak referansı kaldı; bunlar 74 bağımsız fincan sayılmaz. Kaynaklar değiştirilmedi. Cihaz testi için yönü düzeltilmiş, en fazla 1024 piksel kopyalar kullanıldı.

Cihaz sonucu: 62 uygunluk işareti, 12 kararsız, 0 açıkça uygunsuz. İlk ölçümde iki çıkarımın medyan süresi 89 ms. Bu ölçümde görünüm kırpması tam görüntüydü; farklı kullanıcı kırpmalarında genel başarı garantisi değildir.

Klavye veya diğer olumsuz gerçek görüntüler bu klasörlerde yok. 30 olumsuz / 10 klavye ölçümü yapılmadı. Bu yüzden **kahve dışı görüntü engellemesi tamamlanmadı** ve `suitabilityBlockingValidated=false`. Model uyarı verir, kullanıcı devam edebilir. Kontrol hatası kahve dışı olarak yorumlanmaz.

Yerel kanıtlar (Git dışında): `build/simple-device3.log`, `build/suitability/benchmark.json`, `build/suitability/device-manifest.json`.

## İçerik kabulü

12 tek fotoğraflık referans üzerinde v4/v5 aynı Kimi modeli ve ayarlarla denenir. Altı örnekte kontrollü yapay sembol girdisi kullanılır; bunlar gerçek kullanıcı etiketi veya eğitim verisi değildir. Fotoğraf kimliklerinin bağımsız fincan grupları olduğu doğrulanmamıştır. Fotoğraflar değil, yerelde hazırlanan doğrulanmış metinsel bağlam gönderilir.

24 yanıt denemesinde 12 okunabilir sonuç ve 12 sunucu meşgul hatası alındı. Okunabilir sonuçların tamamı hedef kelime uzunluğunun altında kaldı; beta davranışı gereği gösterilebilir. Kimi'nin meşgul yanıtları ve kalite uyarıları rapordan çıkarılmadı. Kör insan tercihi henüz alınmadı; 8/12 kabul koşulu sağlanmış sayılmaz. **Fal kalitesinde iyileşme doğrulanmadı.**

Rapor: `build/suitability/narrative-pairs.json`; okunabilir kör paket ayrıca hazırlanır. Tekrar ücretli çalıştırma isteğe bağlı `ATLAS_PAIRED_LIVE` bayrağı gerektirir; normal testler ağ isteği yapmaz.

## Teslim

Beta 8 (`versionCode=8`, `1.0.0-beta.8`) aynı imzayla `adb install -r` kullanılarak telefona kuruldu. Beta 7 ve Beta 8 imza sertifikası SHA-256 değerleri eşleşti. Kaldırma/veri temizleme yapılmadı.

Telefonda ana ekranın teknik kutusuz görünümü, mevcut tek/çok fincan ve tabaklı kayıtların görünmesi, Falını Oku ile kayıtlı sonucun doğrudan açılması doğrulandı. 0/20 → 1/20 yıldız, Yıldızlılar filtresinde tek kart, yeniden açmada yıldızın korunması ve kaldırınca 0/20 doğrulandı. Test yıldızı geri kaldırıldı. Yaş veya araştırma izinleri değiştirilmedi.

Yeni fotoğraftan yeni ücretli fala tam beta yürüyüşü bu son görsel kontrolde tekrarlanmadı; diagnostic akışı ve mevcut sonuç okuma kontrolü ayrı kanıtlardır. İçerik testi bilgisayarda gerçek sağlayıcıyla yapıldı. Yeni kayıt için tek seferlik yaş/yerel kullanım kabulünü kullanıcı vermelidir.

APK: `build/atlas-beta-v8.apk` (yaklaşık 100,6 MB; yerel model dahildir).
Görseller: `build/simple-home.png`, `build/simple-fortune.png`.
Kör değerlendirme: `build/suitability/KOR_KARSILASTIRMA.md`; sürüm eşlemesi ayrı `comparison-key.json` dosyasındadır.
Atlas Node servisi yeniden başlatıldığında ortak v5 prompt dosyasını yükler; çalışan eski servis süreci kendiliğinden değiştirilmedi.
