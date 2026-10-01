# Atlas — Kapalı test doğrulama durumu

Tarih: 30 Eylül 2026. **Kapalı teste hazır / herkese açık yayına hazır kabulü verilmedi.**

## Hazırlanan çıktı

- Normal paket: `com.coffeeplatform.atlas_contribution_app`, sürüm 12 (`1.0.0-test.12`). Telefonun mevcut `.beta` sürüm 10 uygulaması ayrı bırakıldı; kaldırma veya veri temizleme yapılmadı.
- Yerel çıktılar: `build/atlas-play-test-v12.aab` ve `build/atlas-play-test-v12.apk`.
- AAB SHA256: `d41d96fa3bb44a1b491bcdb9c7dd7b99004e051018087f555bccf41377b77ae1`.
- APK SHA256: `c13441374bfad776c246ef97fb2925116f0ba37d82999fcc2c3da0a3f31cb2d8`.
- 247 Flutter testi geçti; iki isteğe bağlı canlı test atlandı. 20 Node.js testi geçti. Flutter analyze hata bildirmedi.
- İmza doğrulandı. Bilinen eski sağlayıcı anahtarı çıktıda bulunmadı. Bu tarama genel güvenlik denetiminin yerine geçmez.
- 13 adet 64 bit yerel kütüphanenin ELF hizalaması ve APK'nın 16 KB ZIP hizalaması geçti. Gerçek 16 KB cihaz testi ve Play ön lansman raporu henüz yok.
- Hedef SDK 36. Mikrofon izni kaldırıldı; eski depolama izinleri Android sürümüyle sınırlandırıldı.

## Gerçek kamera

İlk kontrolde kullanıcı da Atlas önizlemesinin siyah olduğunu doğruladı. Telefonun yerleşik kamera uygulamasında ön ve arka kamera ayrı kontrol edildi. Ardından Atlas yeniden açıldığında, kod değiştirilmeden arka kamera canlı görüntü verdi. Görüntü kanıtları yerel `build/native-back.png` ve `build/atlas-after-native.png` dosyalarında tutuldu; özel ortam görüntüleri Git'e eklenmez.

Bu sonuç önceki siyah görüntünün kök nedenini kanıtlamaz. Gerçek telveli fincanla üç açı, ikinci açıda çıkıp devam etme, tekrar çekme ve kayıt–fal yürüyüşü bekliyor. Kamera sorunu çözülmüş olarak işaretlenmedi.

Sonraki telefon kontrolünde kullanıcı üç fotoğraf çektiğini bildirdi. Gerçek uygulamanın önizlemesinde tek set içinde “3 fincan”, “Serbest açı”, “Kulp sağda” ve “Kulp solda” görüldü. İsteğe bağlı tabak alanından “Tabaksız devam et” çalıştı. Aynı fincan beyanı kullanıcıya bırakıldı; işaretleme/kayıt/fal kabulü bu noktada henüz tamamlanmadı. Bu kontrol her açının canlı tarama efektlerinin gözlemlendiği anlamına gelmez.

Kullanıcı aynı fincan beyanını doğruladıktan sonra işaretleme ekranı açıldı. İşaretleme atlandı; “Kaydet ve Falını Oluştur” tek dokunuşla AI bekleme ekranına geçti. Ancak sonuç “Fal tamamlanamadı veya iptal edildi” oldu. Hata sonrasında ana ekrana dönülüp Kayıtlarım açıldı: tek kartta “3 fincan · 0 işaret / Telefona kaydedildi” doğrulandı. Fotoğraflar silinmedi; kullanıcı araştırma izni değiştirilmedi.

Ayrıca gerçek fotoğrafta yerel uygunluk kontrolü “Fotoğraf kontrolü tamamlanamadı” uyarısı verdi. Kullanıcı ilerledikten sonra akış sürdü; kontrol başarılı sayılmadı. Bu hatanın nedeni ve fal isteğinin sunucu hata ayrıntısı henüz belirlenmedi. Uçtan uca telefon kabulü **başarısız / açık** durumundadır.

## Fotoğraf kontrolü

### Dağıtım sürümünde teknik hata onarımı (30 Eylül, sonraki kontrol)

Gerçek kullanıcı fotoğraflarında görülen teknik uyarı, ayrı `.diagnostic` paketinde **küçültülmüş release** derlemesiyle yeniden üretildi. Yedi fixture uygulamanın özel klasörüne kopyalanarak gerçek kayıtlarla aynı dosya yolu kontrolünden geçirildi.

- Diagnostic release 13: 7/7 `inference:RuntimeException`.
- İlk koruma kuralıyla release 14 ve dar logger kuralıyla release 15: MediaPipe Graph başlangıcında Flogger `no caller found on the stack` hatası. Bu ara paketler yalnız diagnostic uygulamaya kuruldu.
- Protobuf alanları, Flogger ve MediaPipe'ın native callback girişlerini koruyan R8 kurallarıyla release 16: aynı test tamamlandı, 7/7 çıkarım hatasız; test çıktısı `All tests passed`.
- Sınıflandırma eşikleri/model dosyası değiştirilmedi. Teknik düzeltme kahve dışı veya telvesiz görüntüleri güvenilir ayırma kabulü değildir.
- Önbellek sözleşmesi `atlas-suitability-lite0-v2` olarak yenilendi; eski bozuk derlemenin hata sonuçları yeniden kullanılmaz. Fotoğraflar, ilk gözlemler ve araştırma izinleri değiştirilmez.
- Altı fotoğraf uyarı/yeniden deneme testi geçti; Flutter analyze temiz. Kamera ve motor paketlerinde değişiklik yok.
- Düzeltme normal Atlas paketinde sürüm 17 olarak, imza ve artan sürüm kontrolünden sonra `install -r` ile kuruldu. Eski `.beta` sürüm 10 yerinde kaldı. APK: `build/atlas-play-test-v17.apk`, SHA256 `335e785fe342a8231758093d552c22bb88e51a610b86d3ced611bd10f8be52e7`. Güncel AAB: `build/atlas-play-test-v17.aab`; önceki v12 çıktısı bu onarımı içermez.
- v17 APK'da 13 yerel kütüphane hizalaması, ZIP hizalaması ve bilinen sağlayıcı anahtarı bulunmaması kontrolü geçti. Kurulum sonrası telefon kilitli olduğundan kullanıcının üç fotoğrafıyla son doğrulama bekliyor.

Kaynaklar: [Protobuf Lite ve R8](https://github.com/protocolbuffers/protobuf/blob/main/java/lite.md), [MediaPipe native koruma kuralları](https://github.com/google-ai-edge/mediapipe/blob/master/mediapipe/java/com/google/mediapipe/framework/proguard.pgcfg), [Flogger başlangıç hatası örneği](https://github.com/google-ai-edge/mediapipe/issues/6138). Cihazdaki tekrar testi karar için esas alındı.

Yeni MediaPipe sürümü gerçek cihazda yedi olumsuz örneğin tamamında hata vermeden çalıştı. Sınıflandırma sonucu: 3 desteklenen, 4 kararsız, 0 açıkça uygunsuz. Grupta iki boş tabak, iki boş fincan ve üç kahve dışı görüntü vardı. **Bu sonuç kesin engelleme kabulünü geçmez.**

Mevcut klasörler checksum ile sayıldı: toplam 81 farklı dosya. Bunların etiketleri insan tarafından doğrulanmış bağımsız değerlendirme grubu sayılmadı. Gereken 30 telveli, 30 uygunsuz (en az 10 farklı klavye) ve 20 telvesiz gruplar henüz tamamlanmadı. Deneysel uyarı korunur.

## Yerel fal karşılaştırması

- Qwen3-14B Q5_K_M, sıcaklık 0,6; aynı 12 metinsel bağlam için v5/v6 istemleriyle 24 yanıt alındı. Fotoğraf gönderilmedi.
- Altı sette kontrollü test sembolleri kullanıldı; bunlar bağımsız kullanıcı gözlemleri olarak sunulmaz.
- Tek yanıt ölçümü yapıldı; üretim akışındaki düzeltme denemesi bu karşılaştırmaya dahil değil.
- İki grupta da 12/12 istek tamamlandı, düşünme çıktısı dönmedi. Ortanca süre iki grupta da yaklaşık 38,7 saniye.

| Otomatik kontrol | Eski v5 | Yeni v6 |
|---|---:|---:|
| Teslim dili kontrolünü geçen | 1/12 | 3/12 |
| Desteklenmeyen görsel iddia işareti | 9/12 | 6/12 |
| Kesinlik işareti | 2/12 | 3/12 |
| Kelime aralığı | 112–210 | 164–206 |

Dil kontrolleri örüntü tabanlıdır; bu sayılar bağımsız insan değerlendirmesi veya kusursuz hata tespiti değildir. Bütün yanıtlar raporda tutuldu. Hiçbiri 250–400 kelime hedefini karşılamadı; uzunluk tek başına okunabilir sonucu engelleme nedeni yapılmadı.

Yerel ayrıntı: `build/play-local-comparison.json`; kör okuma: `build/play-local-comparison-blind.md`. Karşılaştırmadaki `promptHash`, normalize JSON'un hash'idir; dağıtım istem dosyasının ham byte hash'iyle aynı değildir.

Kör insan tercihleri henüz alınmadı. En az sekiz sette yeni anlatımın tercih edilmesi koşulu karşılanmış sayılmaz. **Kalite artışı doğrulanmadı.**

## Yayın öncesi açık işler

Canlı HTTPS test adresinden yapay bir yorum bildirimi gönderildi; servis kabulü sonrasında özel bildirim klasöründe tam bir kalıcı kayıt bulundu. Gerçek kullanıcı metni/fotoğrafı kullanılmadı. Bu sunucu kontrolü, telefondaki bildirim düğmesinin uçtan uca kabulünün yerine geçmez.

Aynı HTTPS adresinden güvenli metinsel bağlamla gerçek üretim işi de tamamlandı: Qwen3-14B, v6, sıcaklık 0,7, tek deneme, yaklaşık 9 saniye. Sonuç `build/play-live-result.json` dosyasında. Otomatik kontrolü geçmesine rağmen okumada “İçindeki şekiller” gibi gözleme dayanmayan bir ifade ve tekrar eden soyut cümleler görüldü. Bağlantının çalışması doğrulandı; metin kalite kabulü verilmedi. Bu tek istek, sıcaklığı farklı olduğundan yukarıdaki eşlenmiş karşılaştırmaya eklenmedi.

- Gerçek fincanla kamera ve uçtan uca telefon kabulü.
- Yeterli bağımsız fotoğraf grubu, telvesiz/kahve dışı kontrolünün ölçümü.
- Fal yanıtlarının görsel iddia ve kesinlik sorunları; kör insan değerlendirmesi.
- Canlı hizmet üzerinden bildirim kabulü ve yöneticinin inceleme süreci; sakıncalı içerik denetimi.
- 12 gerçek testçinin erişim ve bekleme ölçümü. Yapılandırmada 12 kod bulunması gerçek katılım değildir; kuyruk hâlâ 1 çalışan + 9 bekleyen iş kabul eder.
- Geliştirici kimliği, destek adresi, yayımlanmış gizlilik politikası ve SDK veri beyanı.
- Önceden paylaşılmış sağlayıcı anahtarının kullanıcı tarafından iptal teyidi.
- Google Play hesabı/Console işlemleri, gerçek 16 KB çalışma testi ve ön lansman raporu.

APK/AAB hazırlanmış olması mağaza onayı veya yayın kabulü değildir. Bilgisayara bağlı geçici test hizmetinin sürekli çalıştığı vaat edilmez.
