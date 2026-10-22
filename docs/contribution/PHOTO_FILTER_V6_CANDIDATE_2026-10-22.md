# Atlas son fotoğraf filtresi — V6 aday doğrulaması

Tarih: 2026-10-22. **Model kabul koşulları geçmedi.** İlk teslimde kurulum yapılmadı.
Ardından kullanıcı telefonu güncellemeyi yeniden istedi; V93 yerel test sürümü
olarak veri koruyan yolla kuruldu. Bu istek modelin ölçüm hedeflerini değiştirmedi.
Bu belge ilk aday değerlendirmesini anlatır. Sonraki V93 kurulumu
[V93 doğrulama raporundadır](ATLAS_V93_VERIFICATION_2026-10-23.md). Modelin gerçek
kamerada doğrulandığı anlamına gelmez.

## Uygulanan değişiklik

- Fincanda yalnız `supported` yeni fal üretimine izin verir. Kontrol sürerken,
  belirsizlikte, uygunsuzlukta ve teknik hatada üretim bekler.
- Tam görüntü ve görünür kırpma birlikte değerlendirilir. İki olumsuz sonuç
  uygunsuzdur; herhangi bir olumsuzlukla çelişki belirsizdir. İki olumlu sonuç
  uygundur. Olumlu + belirsiz yalnız geçerli otomatik çekim kanıtıyla uygundur.
  Diğer birleşimler belirsizdir. Teknik hata görsel ret değildir.
- Mevcut `CameraCaptureResult` üzerinden yalnız olumlu otomatik çekim kanıtı
  alınır. Manuel çekim, galeri ve tabak kabulü kolaylaştırmaz. Özel uygulama
  önbelleği fotoğraf/özgün dosya özetine, kırpmaya, yüzeye, çekim türüne ve
  çekim zamanına bağlıdır. Kanıtın kaydedilememesi fotoğrafı kaybetmez.
- Yeni model ve uygunluk kimliği eski uygunluk önbelleğini geçersiz kılar.
  Dosyanın gerçek özeti önbellek kullanımından önce kontrol edilir. Kanıtın
  kaybında ona bağlı eski kabul yeniden hesaplanır.
- Mevcut fotoğraf uyarısı belirsizliği açıklar ve mevcut yeniden kontrol
  eylemini kullanır. İşaretleme ve Yalnız Kaydet kullanılabilir. Yeni pencere
  veya menü eklenmedi. İşaretleme ekranının fal düğmesi de aynı politikaya bağlıdır.
- Gerçek AI isteğinden hemen önce, her denemede aynı uygunluk politikası ve
  dosya kontrolü yeniden uygulanır. Önceden tamamlanmış falların görüntülenmesi
  ve mevcut çift istek koruması korunur.
- Tabak mevcut eski değerlendirme yolunda kalır; fincan modeli uygulanmaz.

## Korunan kapsam

Başlangıçtaki 1179 dosyanın SHA-256 envanteriyle karşılaştırıldı. Kamera
paketindeki 80 dosya aynı. Kamera algoritması, eşikler, yeşil tarama, otomatik
ve manuel çekim, hedef/kırpma geometrisi değiştirilmedi. Kalıcı fotoğraf ve
kayıt modelleri değiştirilmedi. Tarot, galeri seçim uygulaması ve V92 kayıt
özeti kaynakları başlangıçtaki yerel içerikleriyle aynı. Aynı dosyalardaki
önceki V91/V92 çalışmalarının üzerine yalnız ilgili küçük eklemeler yapıldı.

## İnternet örnekleri ve veri ayrımı

Kullanıcının “İnternetten örnekler bul” yanıtıyla internet örnekleri eklendi.
Kullanıcı fotoğrafları dışarı yüklenmedi; gerçek AI üretimi başlatılmadı.

Wikimedia Commons'tan açık lisans bilgisi bulunan 47 fotoğraf indirildi;
görsel incelemede 5 kapsam dışı/çizim/karışık örnek çıkarıldı. Kalan 42 fotoğrafın
lisans, yazar ve kaynakları [kaynak envanterinde](PHOTO_FILTER_V6_SOURCES_2026-10-22.json).
Örnek kaynaklar arasında [seramik kül tablası](https://commons.wikimedia.org/wiki/File:Chivas_Regal_ceramic_ashtray.jpg)
ve [kullanılmış kül tablası](https://commons.wikimedia.org/wiki/File:An_ashtray_holding_used_cigarette_butts_sits.jpg) bulunur.
Fotoğraflar uygulamaya veya Git'e eklenmedi.

- Yeni olumsuz geliştirme verisi: 21 fotoğraf, 20 nesne grubu.
- Yeni ayrı değerlendirme: 21 fotoğraf, 10 kül tablası + 10 kase/kap grubu.
- Önceki geliştirme verisiyle toplam eğitim: 438 fotoğraf, 401 grup.
- Bilinen kullanıcı kül tablasının 3 görünümü ve bunların 3 kırpması aynı
  **tek geliştirme grubunda** tutuldu.
- Önceki ayrı fincan/diğer nesne verisiyle toplam değerlendirme: 128 fotoğraf.
  Bunların 33'ü gerçek telveli fincan grubudur. Önceki model değerlendirmelerinde
  görülmüş bu fincanlar V6 eğitimine alınmadı; tamamen yeni saha testi sayılmaz.
- Gruplar aday değerlendirmesinden önce kilitlendi. Eğitim ve değerlendirme
  arasında ortak grup veya aynı dosya özeti yok. Yeni olumsuz örneklerin eğitim
  verisiyle algısal benzerlik taramasında belirlenen yakın kopya yok.

Örnekleme küçüktür ve internet fotoğrafları telefonun gerçek ışık/çekim
dağılımını temsil etmez. Nesne gruplaması görsel inceleme ve kaynak metadata'sına
dayanır; kimliği belirsiz örneklerde aynı nesne ihtimali muhafazakâr ele alındı.

## Sabit model ve ölçüm

Mevcut MobileNetV3-small özellik çıkarıcısı ve ridge yöntemi korundu.
Yalnız başlık ve geliştirme verisinden seçilen karar eşikleri yenilendi.

- Model SHA-256: `73becef6afcea56138cff83acc8645dc6674fc3e9a7d33441002e18cb4a400f7`
- Uygunluk sürümü: `atlas-diagnostic-mobilenet-73becef6-strict-v6`
- Ridge: `0.1`; olumsuz eşik `< -0.34994039923472275`;
  olumlu eşik `> 0.30238871786915555`.
- ONNX dışa aktarımı en büyük mutlak farkı: `3.5762786865234375e-07`.
- Değerlendirme fotoğrafları uygulamanın gerçek `preparePhoto` yolundan geçti.
  Ardından masaüstü ONNX ile tam kare/kırpma kararı ölçüldü; galeri örneklerine
  kamera kanıtı verilmedi. Çok açılı grupta bütün görünümler ilgili koşulu
  sağlamadıkça grup başarılı sayılmadı. Belirsizlikler paydada kaldı.

| Ayrı değerlendirme | Sonuç | Gerekli koşul | Karar |
|---|---|---|---|
| Gerçek fincan | 29/33 doğrudan kabul, 4 belirsiz | En az %90 kabul | **Başarısız: %87,9** |
| Gerçek fincanda açık yanlış ret | 0/33 | 0 | Geçti |
| Yeni kül tablası | 6/10 açık ret, 4 belirsiz, 0 kabul | En az %80 açık ret; 0 kabul | **Başarısız: %60 ret** |
| Yeni kase/kap | 7/10 grupta tüm açılar açık ret; 0 kabul | En az %80 açık ret; 0 kabul | **Başarısız: %70 ret** |
| Teknik hata | 0/128 fotoğraf | 0 | Geçti |

Kase/kapta fotoğraf düzeyinde 8 ret ve 3 belirsizlik vardır; bir grubun iki
görünümü olduğundan grup başarısı 7/10'dur. Diğer eski olumsuz gruplarda da
kabul görülmedi: boş fincan 20/23, klavye 16/16, çakmak 15/17 ve portre
10/10 grupta bütün görünümler açık reddedildi.

Bilinen kül tablasının üç görünümü: 1 uygunsuz, 2 belirsiz; üçü de yeni üretimi
durdurur. Her görünümün tam karesi olumsuzdur; otomatik çekim kanıtı bunları
kabul ettiremez. Bu nesne eğitimde bulunduğu için bağımsız başarı ölçümü değildir.

Bu sonuçlar görüldükten sonra eşikler, bölünme veya model değiştirilmedi.
`suitabilityBlockingValidated` adayın doğrulanmadığını belirtmek için `false`.
Modeli kullanan yerel testler kabul mantığını çalıştırır; bu kurulum izni değildir.

## Yazılım doğrulaması

- Kamera paketi: **132 test geçti**.
- Model açıkken ilgili 21 uygulama test dosyası: **155 test geçti**. Karar
  tablosu, eski önbellek, eşzamanlı kontrol, dosya/kırpma değişimi, teknik hata,
  manuel/otomatik kanıt, opsiyonel önbellek hatası, üretim engeli, kaydetme,
  galeri sınırları, üç açı/erken bitirme/tabak, kayıt ve V92 özet regresyonları dahil.
- Standart tam uygulama koşusu: **588 geçti, 15 atlandı, 9 başarısız**.
  Atlananlar canlı/opsiyonel ve model açık yapılandırmasına ait testlerdir.
- Kalan 9 hata kapsam dışıdır: `coffee_ui_flow_test` içinde büyük yazıda
  ana ekranda dikey kaydırma olmaması beklentisinin 8 varyantı ve
  `ai_widget_test` içinde 800×600 boyutta 16 piksel taşma. Aynı 9 hata
  değiştirilmemiş Git HEAD `eb1f6a27` kaynaklarının ayrı kopyasında yeniden
  üretildi. Bu ekranlar düzeltilmedi.
- Uygulama ve kamera statik analizi: **sorun yok**.
- Yeni nesil istek sınırı kontrolünde istemci taklit edildi; dış AI çağrısı yok.

## Kurulum kararı ve kalan iş

İlk teslimde planın ölçüm eşiği sağlanmadığı için APK hazırlanmadı ve telefona kurulmadı.
İlk teslimde yeni APK özeti, güncelleme yedeği/veri karşılaştırması, imza/sürüm
kontrolü veya cihazda yeni model/kamera kontrolü henüz yapılmamıştı.
İlk teslim anında son doğrulanan kurulum V92 idi; o aşamada yeniden sorgulanmadı.
İlk teslimde kurulum yapılmadı. Sonraki kullanıcı isteğiyle V93 kuruldu; silme veya
veri temizleme yapılmadı. Daha sonra kullanıcı GitHub kaynak güncellemesini
istedi; bu adayın durumunu değiştirmeyen kaynak kaydı ayrı V93 raporunda yer alır.

Devam için daha çeşitli geliştirme örnekleri ve artık görülmüş bu olumsuz
değerlendirmeden ayrı yeni bir değerlendirme grubu gerekir. Bu raporun eşiklerini
sonuçlara göre gevşetmek adayın kabul edildiği anlamına gelmez.

Repo dışında tutulan yerel çalışma çıktılarında
`evaluation.json`, `known-ashtray-evaluation.json`, `split-lock.json`,
`perceptual-leakage-audit.json`, test ve analiz günlükleri burada bulunur.

Yeniden ölçüm aracı: `atlas_contribution_app/tool/evaluate_photo_filter.py`.
`--model-directory`, `--fixtures`, `--out` parametreleri sabit model, fotoğraf
ve manifest özetlerini doğrular. Eğitim yapmaz ve eşikleri değiştirmez.
