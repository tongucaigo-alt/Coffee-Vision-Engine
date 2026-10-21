# Atlas Tarot V89 — Belirgin dokunma yönlendirmesi

22 Ekim 2026. Kapalı kartın kenarındaki hafif ışık, sıradaki açma eylemini yeterince belli etmiyordu. Sıradaki kapalı kart artık büyük bir dokunma simgesi, açık renkli etiket ve hareketli halkalarla gösteriliyor.

## Değişiklik

- Yalnız sıradaki kapalı kartın ortasında 56–68dp krem daire üzerinde büyük el/dokunma simgesi ve **DOKUN** etiketi görünür. Diğer kartlarda bu işaret yoktur.
- Simge 1,6 saniyelik döngünün başında kısa bir basma hareketi yapar; iki açık renkli halka dışarı yayılıp söner. Bakır kenarlık 3dp, düşük parlaklığı da belirgin olacak şekilde ayarlanmıştır.
- İşaret kart açıldıktan sonra sıradaki karta geçer. Günün Kartı da aynı gösterimi kullanır. Son kart açılınca işaret sona erer. Yanlış kartta beklenen kart kısa süre daha belirginleşir.
- İşaret ve etiket dokunmayı engellemez: simgenin üzerine basmak alttaki kartın açma eylemine ulaşır. Kartlar ve mood alanı hareket etmez; boyutlar/boşluklar aynı kalır.
- Hareket azaltmada el simgesi, etiket ve belirgin çerçeve sabit kalır; hareket ve halkalar çalışmaz. El/etiket dekoratiftir; ekran okuyucu mevcut kart açma eylemini bir kez okur. Dekoratif etiket sabit 12sp kullanır, esas metinlerin yazı ölçeği korunur.
- Telefon titreşimi, ses, ücretli animasyon veya yeni paket eklenmedi. Kart görsel dosyaları aynı.

## Kaynak ve test

Başlangıç V88 commit'i `3a96b7fb5e532118c32c3311888e343566657ed1`. Mevcut ayrı çalışma ağacı ve `codex/atlas-tarot-reveal-guidance` dalı kullanıldı. 1168 başlangıç dosyasının 1166 tanesi byte düzeyinde aynı. Yalnız Tarot sunum dosyası ve ilgili widget testi değişti; bu not ayrıca eklendi. V88 notu ve özgün V87 çalışma klasörü korundu.

Kart seçimi/açılması ve kayıt mantığı, modeller, JSON, Kimi, kahve/kamera/OpenCV, ortak tema ve public constructor'lar değişmedi. Veri göçü yok.

**76 ilgili test geçti; Flutter analizi ve diff kontrolü temiz.** Tarot model/depo/AI ve widget, ana ekran tutarlılığı ve mevcut Atlas tasarım testleri çalıştırıldı. Tam uygulamanın bütün test grubu çalıştırılmadı.

Dokunma simgesinin görünürlüğü ve dokunuşu karta geçirmesi, sırayla aktarılması, yanlış/çift dokunma, kayıt hatası, yarım açılıma dönüş, günlük kart, ters kart, mood işlemi, çevrimdışı okuma, arka plan/gizli sayfada durma ve sıfır haptic çağrısı kontrol edildi. 320×568, 360×700, 412×700 ve A56 384×832 için normal/iki kat yazı kontrolleri korundu. A56 normal yazıda kaydırmasız düzen ve ana eylem konumları aynı; küçük ekran/büyük yazıda mevcut erişilebilirlik kaydırması kullanılır.

## APK ve telefon

`Atlas-Tarot-V89.apk`: **1.0.0-kimi-test.89**, kod **89**, ad **Atlas Fotoğraf Testi V89**. Mevcut diagnostic paket için debug test APK'sı; V88 ile aynı test imzası. **122 korunan varlık ve 30 native kütüphane** V88 ile birebir aynı.

SHA-256: `f8f2577731f218fd86acbb1bc6572d1819e52335f1cc1798b3c98896e6e24b58`.

Samsung A56, V88 → V89 olarak yalnız `tool/install_preserving_data.py` ile güncellendi. Kaldırma/veri temizleme yapılmadı. Özel yedek ve yerel geri yükleme provası geçti. **Kurulumdan hemen sonra 359/359 dosya aynıydı.** Normal Atlas paketi ve ilk kurulum tarihi korundu.

Gerçek telefonda simgeli kartı açma, yanlış karta dokunmanın kart açmaması, üç kartın sırayla açılması ve mood seçmeden devam doğrulandı. Önceki **23 Tarot kaydı** aynen korundu; **bir yeni Üç Kart test açılımı** eklendi. Günlük kart kilidi aynı. Denemede yorum üretilmedi ve canlı/ücretli Kimi çağrısı yapılmadı. Kullanıcı dosyalarında beklenmeyen değişiklik yok; ayrıntılar `after-ui-verification.json` içinde.

## Teslim

- `Onizlemeler.html`: V88/V89 aynı test kartlarıyla önce/sonra; cihaz/yazı matrisi; gerçek A56 görüntüleri.
- `Tarot-V89-Telefon.mp4`: 24.6 saniyelik, ses kanalı olmayan gerçek cihaz ekran kaydı.
- `Dogrulama-Raporu.json`, `verified-tests.log`, `analyze.log`, `apk-build.log`, `install.log`, `native-demo.log`.
- Özel yedekler ve bağlantı anahtarları kaynak/teslim klasörünün dışında tutulur. APK mevcut özel test yapılandırmasıyla yalnız yerel teslimdir.

Kaynakta iOS projesi yok; iOS cihaz doğrulaması yapılmadı. GitHub push veya yayın yapılmadı. Geliştirme commit kaydı yalnız yerelde tutuldu.
