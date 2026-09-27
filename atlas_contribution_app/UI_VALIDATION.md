# Atlas arayüz uyarlaması — 21 Eylül 2026

## Uygulananlar

- Yerel Flutter ekranlarında krem/kahverengi/yeşil tema, APK içinde logo,
  Plus Jakarta Sans ve Literata; font lisansları aynı asset klasöründe.
- Ana Sayfa / Kayıtlarım / Ayarlar; puan, üyelik, profil ve Ritüeller yok.
- Kaydı tamamlanan üç kameranın art arda açılması; iptal ve kayıt hatasında
  durma; eksik açıdan devam; tek fotoğrafı tekrar çekme.
- Fotoğraf kimliği ve checksum'ına bağlı kullanılabilirlik teyidi ve aynı
  fincan beyanı. Değişen fotoğrafın teyidi yeniden istenir. Teyitler bağlı
  Review alanlarına aktarılır; mevcut motor ilk gözlemi mühürler ve analiz eder.
- Büyük işaretleme alanı, fotoğraf seçicisi, mevcut kutu/koordinat/çoklu dokunma
  davranışı. Atla mevcut işaret ve belirsizlik kararlarını korur.
- Gerçek kayıt kartları, ayrı işaret katmanı, fal durumu; anlatı önde,
  teknik ayrıntılar açılır bölümlerde. A/B kimlikleri tercih öncesi kapalı.

## Bilgisayarda doğrulandı

- `flutter test --no-pub --reporter expanded`: **186 test geçti**.
- `flutter analyze --no-pub`: bulgu yok.
- Yeni testler: kesintisiz üç çekim, çekimde iptalden devam, kalıcı kayıt hatası,
  yeniden çekimde teyit sıfırlama, toplu atlamada gözlemleri koruma,
  teyitlerin analize aktarımı ve ilk gözlem değişmezliği.
- 412×915 normal yazı ve 320×640 / 1.8 yazı ölçeğinde arayüz kontrolleri.
  Görsel inceleme çıktıları Git dışındaki `build/ui-previews/` altında.
- Mevcut annotation, crop, iki parmak, ZIP/izin, eski kayıt ve AI testleri geçti.
- Kamera/motor/kaynak paketleri ve docs için çalışma başlangıcındaki
  `9f6ff8257606a124f17246da9d2fafbcd984cd03` ile 168 dosya karşılaştırıldı:
  içerik farkı yok. Altı dosyada checkout kaynaklı CRLF/LF farkı bulunuyor.
- Eski `tool/check_frozen.cjs`, sabit `86011b4` tabanında daha sonra eklenen
  `camera_focus_region.dart` bulunmadığı için tamamlanamıyor. Bu betik değiştirilmedi;
  başlangıç HEAD'iyle ayrı kontrolün raporu `build/ui-boundary-check.json`.

## APK

- Dosya: `build/atlas-ui-beta-release.apk` (~62 MB).
- Paket: `com.coffeeplatform.atlas_contribution_app.beta`; versionCode **2**.
- Founder imzası `apksigner verify` ile doğrulandı.
- Sertifika SHA-256:
  `9817a87150d98b0fa5b573ec371700133e2861fe41f6d70c4064381d0bcec9b4`
- APK SHA-256:
  `92e72c88f692a2fa56dd0fca57522323e84e200be8b108855a106086642a6961`

## Telefon doğrulaması

Samsung SM-A566B bağlantısı görüldü. Telefonda mevcut K6 kamera uygulaması vardı;
katkı uygulaması ve `.beta` paketi bu kontrolde kurulu değildi. K6 APK'sı ve özel
uygulama dizini Git dışındaki `build/ui-phone-before/` altına yedeklendi.
Hiçbir mevcut uygulama kaldırılmadı veya verisi temizlenmedi.

İlk girişim USB bağlantısının kopmasıyla durdu. Telefon yeniden bağlandıktan
sonra `atlas_ai_gateway/tool/test-device.ps1` üzerinden ayrı `.diagnostic`
paketinde **8 test geçti**. Gerçek LM Studio ağ testi bu arayüz turunda
çalıştırılmadı (1 test atlandı). Üçlü çekim, iptal, kayıt hatasında durma/devam,
yeniden çekimde teyit sıfırlama, bağlı Review'a geçiş, ilk gözlem değişmezliği
ve A/B tercih/gizlilik/yeniden açma akışları cihazda doğrulandı. Bu testler
kontrollü kamera sonuçları ve yapay AI yanıtları kullanır; gerçek fincan
fotoğrafı veya gerçek model çıktısı kabulü yerine geçmez.

Yukarıdaki Founder imzalı APK `adb install -r` ile başarıyla kuruldu ve açıldı.
Kurulu `.beta` paketinin versionCode değeri 2 olarak doğrulandı. Ana ekran ve
ayarların cihaz görüntüleri `build/ui-phone/` altında. Mevcut K6 uygulamasının
kalıcı dosyaları önceki yedekle aynı SHA-256 değerlerine sahip; hiçbir uygulama
kaldırılmadı veya temizlenmedi.

Gerçek fincanla üç açının, sağ/sol kulp ve buzlanmanın kullanıcı tarafından
kontrolü istendi; bu fiziksel kabul yürüyüşünün sonucu henüz bekleniyor.

Gerçek LM Studio kalitesi ve dış ağdaki AI başarı oranı bu görsel değişiklikle
yeniden doğrulanmadı veya düzeltilmiş sayılmadı. Önceki AI kabul notları geçerlidir.


## Kimi hazır test profili — 21 Eylül 2026

- Dışarıdaki özel derleme tanımıyla Kimi K2.6 profili eklenir. Normal derlemelere
  otomatik anahtar eklenmez. Hazır profil düzenleme ekranını açmaz; başka bir
  adres/model/profil için gömülü kimlik bilgisi verilmez.
- Gerçek API model sorgusu HTTP 200: `kimi-k2.6` erişilebilir.
- Gerçek yapay fal denemesi HTTP 429 `exceeded_current_quota_error` ile engellendi;
  sağlayıcı yetersiz bakiye bildirdi. Gerçek fal üretimi henüz doğrulanmış değildir.
- 189 otomatik test geçti; canlı Kimi testi standart koşuda bilerek atlandı.
  `flutter analyze --no-pub`: sorun yok.
- Etkin derleme tanımlarıyla kilitli profil ekranı ve değiştirilen hedef/modelin
  anahtara erişememesi ayrıca doğrulandı.
- Kaynak/izlenmeyen dağıtım-dışı dosyalarda gerçek anahtar taraması: 0 eşleşme.
- Cihaz kontrolünde USB bağlantısı yok; telefon kurulum/kabulü bekliyor.

- Dağıtım APK'sı: `build/atlas-kimi-beta-release.apk`, `.beta`, versionCode 3.
  Founder imzası önceki sürümle aynı ve doğrulandı.
  SHA-256: `6A116A0126655BA9E36B0E91457EF2E5FC50D6949BA73930E1A98AD5AD50B7EC`.


### Bakiye açıldıktan sonraki canlı Kimi denemesi

Kullanıcının limit açıldığını bildirmesinin ardından mevcut `AiClient.probe`
akışı gerçek Kimi API'siyle tekrar çalıştırıldı. Test geçti: `kimi-k2.6`,
ilk denemede 14.194 ms, 152 kelime. Mevcut uygulama kalite kontrolleri geçti;
ancak prompttaki 250–400 kelime hedefine ulaşmadı (kontrol alt sınırı 150).
Önceki bakiye engeli bu denemede görülmedi. Gerçek kullanıcı fotoğrafları veya
kayıtları gönderilmedi; üç fotoğrafı temsil eden yapay metinsel ölçümler kullanıldı.
Bu, bilgisayarda uygulamanın AI istemcisiyle yapılan testtir; telefon kabul testi değildir.
Kanıt: `build/kimi-live-tests.log`, `build/kimi-live-validation.json`.

### Kimi APK cihaz kurulumu

Kullanıcının isteğiyle R5GL329BC0N cihazına imzalı Kimi beta APK versionCode 3, `adb install -r` ile kuruldu; sonuç Success. Kurulum öncesinde cihazda yalnız eski K6 uygulaması vardı, beta paketi yoktu. Kurulum sonrası iki paket de mevcut. Beta ana aktivitesi açıldı; kaldırma veya veri temizleme yapılmadı. Bu adım gerçek fincanla fal kabul testi içermez.
