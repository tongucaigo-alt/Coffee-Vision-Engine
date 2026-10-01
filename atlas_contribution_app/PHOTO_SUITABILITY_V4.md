# Atlas — Yerel fotoğraf kontrolü, 1 Ekim 2026

## Teslim durumu

**Akış entegrasyonu uygulandı; %80 fotoğraf ayırma hedefi geçilmedi. Kesin
engelleme kapalıdır.** `suitabilityBlockingValidated=false` korunur. Deneysel
olumsuz adaylar fotoğraf altında uyarı verir ve kararsız olarak devam eder.
Teknik hata ise bir otomatik tekrar sonrası fal isteğini durdurur; kayıt silinmez.

Kimi istemi, bağlantı/anahtar yönetimi, kamera paketi ve motor public sözleşmeleri
bu değişiklikte değiştirilmedi. Geçmiş çalışma değişiklikleri korunur.

## Uygulanan davranış

- Fotoğrafın kalıcı kaydından sonra arka plan kontrolü; üçlü çekim sıradaki açıyı
  bekletmez. Aynı içerik/tür/kırpma için eşzamanlı işler birleşir ve tek işçi işler.
- Mevcut motorun göreli koyuluk maskesi, bileşen büyüklükleri, ayrı yatay/dikey
  dağılımlar, sınır payı ve sabit merkez örneklemesi kullanılır. Merkez alanı
  tespit edilmiş fincan içi sayılmaz. Fotoğraf veya koordinatlar değiştirilmez.
- Nesne modelinin fincan demesi tek başına telve bulunduğu anlamına gelmez.
- Kararsız fotoğrafta yeni pencere/onay yoktur. Sistem kararı kullanıcı onayı
  gibi kaydedilmez. Kontrol hatası için eski `continuedAtUtc` geçiş sağlamaz.
- Yeniden deneme mevcut ekrandadır. Yalnız Kaydet korunur. İlk gözlemler ve
  aynı fincan beyanı teknik kontrolün başarısından ayrı tutulur.
- Yeni fal üretiminde hem sade ekran hem laboratuvar/A-B aynı kontrolü kullanır.
  Eski kullanılabilirlik onayı yeni kontrolü atlatmaz. Eski falı okumak etkilenmez.
- Önbellek: `atlas-suitability-lite0-residue-v4`, checksum, yüzey türü ve kırpma.
  Fiziksel özet: `atlas-residue-screen-v2`. Eski kayıtlar topluca yazılmaz.

## Ölçüm ve sınırlar

135 fotoğrafta Android **release** yerel sınıflandırıcı ve ilk fiziksel ölçüm
çalıştı: **0 teknik hata**, ortanca toplam ölçüm **733 ms**. Bunlar gerçek model
ölçümleridir; doğruluk yüzdesi değildir. 48 ayar ve 87 ayrı doğrulama görüntüsü
vardır. Görsellerin tamamı cihazdan dış AI'ya gönderilmeden değerlendirilmiştir.

Merkez örneklemesi aynı Dart adaptörüyle bilgisayarda yeniden hesaplandı. Eşikler
yalnız ayar grubu üzerinden sabitlendi; ardından doğrulama grubu ölçüldü. Ayar
grubunda 37 telveli, 7 kahve dışı ve sadece 4 telvesiz görüntü vardır. Bu küçük
telvesiz grubu genel başarı kanıtı sayılmaz. Fincan için yararlı, yanlış engelleme
yapmayan bir merkez eşiği bulunamadı; korumacı değer kaldı. Tabak için aday eşik
model desteği 0,15 / merkez koyuluğu en fazla 0,30 / merkez parlaklığı en az 140.

### Bağımsız doğrulama — engelleme adayları

| Grup | Görüntü | Bağımsız nesne grubu | Engelleme adayı |
|---|---:|---:|---:|
| Gerçek telveli | 35 | 26 | 0 yanlış engelleme |
| Klavye | 12 | 10 | 0 |
| Diğer kahve dışı | 20 | 20 | 3 |
| Telvesiz | 20 | 19 | 0 |

Kararsız sonuçlar olumsuz örneklerde başarı sayılmadı. Aynı nesnenin birden fazla
görünümü bağımsız örnek sayılmadı. Gerçek telveli ve telvesiz bağımsız grup sayısı
da kabul minimumunun altındadır. **Sonuç: yayın/engelleme kabulü başarısız.**

Model klavyelerin çoğunda klavye veya space bar etiketini üretse de eski korumacı
0,90 kuralı onları reddetmiyor. Eşiği bu doğrulama sonuçlarına bakıp değiştirerek
aynı grupta başarı iddia edilmedi. Toplam/merkez koyuluğu, gölge ve koyu zemin
etkisi nedeniyle telvesizliği yeterince ayıramadı. Bu rapor modelin hiçbir şekilde
iyileştirilemeyeceğini değil, mevcut kuralların hedefi sağlamadığını gösterir.

## Tekrarlanabilir kanıtlar

Yerel `build/suitability-v3/` altında (Git dışında):

- `reviewed-sources.json`: kaynaklar, lisanslar, checksum ve görsel etiketler.
- `device/manifest.json`: yönü düzeltilmiş test kopyaları; kaynaklar değişmedi.
- `results.json`: 135 fotoğrafın gerçek Android sınıfları, ölçümleri ve süreleri.
- `calibration-v4.json`, `frozen-rules.json`, `validation-v4.json`, `acceptance.json`.
- `unit-tests-final.log`: 252 geçen, mevcut 2 atlanan test.

`tool/measure_residue.dart` aynı uygulama adaptörünü kullanır; ayar/doğrulama
ayrımı zorunludur. `tool/report_suitability.py` kararsız/hatalı sonuçları dışlamaz,
checksum tekrarını ve grupların iki bölüme sızmasını reddeder. Otomatik olarak
üretim engellemesini açmaz.

Açık kaynak görseller Wikimedia Commons'tan dosya bazında CC veya Public Domain
lisansı kontrol edilerek alınmıştır. Lisans bağlantısı ve yazar bilgisi manifestte
korunur. Arama etiketleri doğrudan doğru etiket sayılmadı; kitap kapakları, çizimler
ve içi görünmeyen görüntüler uygun telvesiz örnek gibi kullanılmadı. Örnek görseller
APK'ya veya Git'e eklenmedi.

## Koruma testleri

Testler; sabit siyah görüntünün telve kanıtı olmaması, kırpma/koordinat değişmezliği,
tek otomatik tekrar, önbellek yüzey ayrımı, yeni onay penceresi açılmaması, büyük
yazıda hata düğmesi, üç kamera açısının kontrol beklemeden ilerlemesi, kayıt/analiz
hatalarının ayrımı, laboratuvarın engeli atlatmaması ve A/B eşit girdisini kapsar.
Kamera/motor paketlerinde Git farkı yoktur.

## 1 Ekim 2026 cihaz ve teslim kaydı

- Son v4 ölçümleri sekiz örnekte gerçek Android cihazında tekrar çalıştırıldı: sıfır teknik hata; fiziksel alanlar masaüstündeki aynı adaptörün sonuçlarıyla birebir eşleşti (`device-v4-smoke.json`).
- Tam test grubu: 252 başarılı, iki mevcut canlı API testi atlandı. Son bekleme metni değişikliğinden sonra ilgili 13 test tekrar geçti; `flutter analyze` temiz.
- Kimi test v21 (`1.0.0-kimi-test.21`) paket/imza/sürüm doğrulamasından sonra kaldırma veya veri temizleme olmadan kuruldu.
- APK: `build/atlas-kimi-test-v21.apk`; SHA256: `0bc0fcdb18a2a28a33ad6816f1897399861f70ea617ce093ad6f5e9c472b96a3`.
- Güncellemeden önce ve sonra Kayıtlarım'daki iki adet üç fincanlı, falı hazır kayıt aynı işaret sayılarıyla (1 ve 0) görüldü. İlk kaydın fotoğraf ve At işareti açıldı.
- Ana kamera girişi açıldı; 1/3 yönlendirmesi, canlı önizleme, yuvarlak alan ve dış buzlanma görüldü. Kamera kumaşa baktığından fincan üzerindeki yeşil noktalar ve gerçek üçlü çekim bu kontrolde henüz doğrulanmadı.
- Kimi bağlantısı ve prompt bu değişiklikte değiştirilmedi; bu kurulumda yeni ücretli fal üretilmedi. Kesin fotoğraf engellemesi kapalıdır; yüzde 80 kabulü sağlanmadı.

### Kullanıcının üç çekimi sonrası kontrol

Kullanıcı üç açıyı çektiğini bildirdi. Telefonda tek taslakta `3 fincan`, Serbest açı, Kulp sağda ve Kulp solda önizlemeleri görüldü; ilk iki önizleme görsel olarak telveli fincan içeriyordu. Ekranlarda fotoğraf kontrol hatası veya ek uygunluk onayı çıkmadı. İsteğe bağlı tabak adımı tabaksız geçildi; mevcut aynı-fincan beyanı işaretlenmeden bırakıldı ve kullanıcıdan doğrulaması istendi. Gerçek çekimler sırasında yeşil noktalar ve kulp çizgileri bu kontrolde doğrudan izlenmedi; yalnız çekim sonrası üç açı kaydı doğrulandı. Yeni fal üretimi henüz sınanmadı.

### Kullanıcı kabul geri bildirimi

1 Ekim 2026: kullanıcı üç fotoğraflı akışta şekil işaretlemeden devam ettiğini,
falın çıktığını ve sonucu beğendiğini bildirdi. Bu tek kullanım, akış için olumlu
kullanıcı geri bildirimidir; genel fal kalitesi veya fotoğraf ayırma kabulünün
geçtiği anlamına gelmez. Anlatım ve Kimi ayarları bu geri bildirim sonrası korunur.
