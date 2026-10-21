# Atlas Tarot V88 — Sıradaki kartı ışıkla gösterme

22 Ekim 2026. V87'yi üreten güncel kaynak kopyasından ayrı çalışma ağacında geliştirildi. Dal: `codex/atlas-tarot-reveal-guidance`; korunan V87 kaynak başlangıcı: `22daeef`. Eski klasörün adı V79 olsa da kaynak dalı ve yerel değişiklikleri V87'ye aittir; eski sürüme dönülmedi.

## Davranış

- Üç kart yerleştikten sonra yalnız sıradaki kapalı kart parlıyor: Geçmiş → Şimdi → Olası Yön. Günün Kartı da aynı bileşeni kullanıyor.
- Bakır kenarlık 2dp, hale kart kenarından en fazla 8dp dışarı taşabiliyor. Işık 800ms artıp 800ms azalıyor. Kartın çizimi, boyutu, konumu ve iç yüzeyinin renkleri değişmiyor.
- Kayıt ve mevcut 600ms açılma tamamlanmadan ışık sonraki karta geçmiyor. Yanlış sıraya dokunmak yalnız beklenen kartı 450ms belirginleştiriyor; tekrar dokunuşları efekt biriktirmiyor.
- Son kart açılınca yönlendirme bitiyor. Yeniden girişte kayıtlı açılma sayısı kullanılıyor; açık kartlar yeniden çevrilmiyor. Kayıt hatasında aynı kapalı karta geri dönülüyor.
- Telefon titreşimi, ses, yeni parçacık veya dış animasyon paketi eklenmedi. Ücretli sahne animasyonu bu çalışmaya dahil değil.
- Hareket azaltmada sabit çerçeve gösteriliyor. Sayfa örtüldüğünde veya uygulama arka plana geçtiğinde yönlendirme animasyonu duruyor. Ekran okuyucuda yalnız sıradaki kartın açma eylemi var; kapalı kart kimliği gizli.

## Kaynak sınırı

Başlangıçtaki 1167 dosyadan 1164 tanesi byte düzeyinde aynı. Değişen üç dosya yalnız Tarot sayfası, özel sunum bileşeni ve Tarot widget testleri. Bu not teslim belgesi olarak eklendi. Özgün çalışma klasöründeki bütün başlangıç dosyaları korundu.

Public constructor'lar, Tarot modelleri/deposu, JSON, AI bağlamı ve promptları, kahve, kamera/OpenCV, ortak tema ve görseller değişmedi. Veri göçü yok.

## Doğrulama

- Tarot model/depo/AI sözleşmesi ve widget testleri, ana ekran tutarlılığı ve mevcut Atlas tasarım testlerinden **75 test geçti**. Son kenar çizimi ve Flutter API düzeltmesinden sonra ilgili **8 test yeniden geçti**; bunlar 75'e ek farklı testler değildir.
- Tam uygulama test grubunun tamamı çalıştırılmadı. Değişiklikle ilgili dört test dosyası kullanıldı. Son Flutter analizi ve diff boşluk kontrolü temiz.
- Sıralı açılma, kartın yerleşmesini bekleme, yanlış/tekrarlı dokunma, kayıt hatası, yeniden açma, Günün Kartı, ters kart, mood ile eşzamanlı açılma, kayıtlı yorum, sıfır haptic çağrısı ve yerel ışığın kayıt/AI isteği oluşturmaması kontrol edildi.
- 320×568, 360×700, 412×700 ve 384×832 A56 ölçülerinde normal/iki kat yazı önizlemeleri alındı. Mevcut küçük ekran/büyük yazı kaydırması korunuyor; ışık yerleşime alan eklemiyor. A56 normal yazıda önceki kaydırmasız düzen ve ana eylem konumları aynı.
- Önce/sonra Flutter görüntülerinde aynı test kartları var. Gerçek telefon görüntüleri ayrı grupta. `native-past.png` üçüncü kartın taşıma geçişini içerir; galeride onun yerine yerleşmiş kartlarla yanlış dokunma anındaki Geçmiş görüntüsü gösterilir.

## APK ve telefon

`Atlas-Tarot-V88.apk`: sürüm **1.0.0-kimi-test.88**, kod **88**, ad **Atlas Fotoğraf Testi V88**. Mevcut diagnostic paket için debug test APK'sı; V87 ile aynı test imzası.

SHA-256: `37068d0b4e05521d7d4476693a15b57f35a1df7a2d86179eb5aa651e9439171d`.

122 korunan APK varlığı aynı. 30 native kütüphanenin 27'si birebir aynı; üç mimarinin `libdartjni.so` dosyaları yeni çalışma alanında yeniden derlendi. OpenCV/ONNX, kart görselleri, Lottie ve prompt varlıkları korunuyor. Özel bağlantı/build ayarları harici dosyadan kullanıldı; kaynakta anahtar veya imza dosyası eklenmedi. APK özel test yapılandırması içerdiğinden yerel teslimdir.

Samsung A56 üzerinde V87 → V88 yalnız `tool/install_preserving_data.py` üzerinden uygulandı. Kaldırma ve veri temizleme yapılmadı. **359 dosyanın özel yedeği ve yerel geri yükleme provası geçti; kurulumdan hemen sonra 359/359 dosya aynıydı.** Normal Atlas paketi ve ilk kurulum tarihi korundu.

Telefon denemesinde yanlış karta dokunmanın açılış yapmadığı, üç kartın sırayla açıldığı ve mood seçiminin gerekmediği doğrulandı. Önceki **20 Tarot kaydı** aynen kaldı. **Bir yeni, yorumu üretilmemiş Üç Kart test kaydı** eklendi. Günlük kart kilidi değişmedi. Son karşılaştırmada yalnız Tarot deposu ve Android `profileInstalled` çalışma işaretçisi değişti; beklenmeyen kullanıcı dosyası değişikliği yok.

Canlı veya ücretli Kimi çağrısı yapılmadı. Telefon son test açılımında, Yorumunu Oluştur düğmesi kullanılmadan bırakıldı. Kaynakta iOS projesi bulunmadığından iOS derleme/cihaz doğrulaması yok. GitHub push veya yayın yapılmadı; geliştirme commit kaydı yalnız yerelde tutuldu.

## Teslim dosyaları

- APK ve SHA-256 dosyası bu çıktı klasöründe.
- `Onizlemeler.html`: önce/sonra, ekran matrisi ve gerçek A56 görüntüleri.
- `Tarot-V88-Telefon.mp4`: 24.9 saniye, 1080×2340, ses kanalı olmayan gerçek telefon ekran kaydı.
- `Dogrulama-Raporu.json`: kaynak, test, APK, kurulum ve telefon kontrol özetleri.
- Ayrıntılı günlükler: `verified-tests.log`, `final-guidance-tests.log`, `analyze-final.log`, `apk-build.log`, `install.log`, `native-demo.log`.
- Özel kayıt yedekleri repository ve bu teslim klasörü dışında, yerel AppData altında tutulur.
