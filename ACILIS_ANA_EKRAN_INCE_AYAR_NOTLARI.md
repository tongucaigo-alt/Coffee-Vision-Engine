# Açılış ve ana ekran ince ayarları — V116 sonrası kaynak

30 Ekim 2026: Alt menüdeki “Ana Sayfa” etiketi “Kahve” olarak değiştirildi. Rehber örneği ve gezinme testleri aynı adla eşitlendi. Kullanıcının sonraki kurulum talebiyle V118, V117 üzerine aynı paket/imzayla kuruldu. 576 dosya korundu; açılış sonrasında iş kayıtlarında beklenmeyen değişiklik yok. Kahve/Tarot gidiş-dönüşü telefonda doğrulandı. Yazı ölçeği 0,9, yoğunluk 450 ve normal Atlas paketi korundu.

GitHub arayüz kaydı: “Uİ SON karar”, dal codex/ui-son-karar, etiket ui-son-karar-v118. Kaynak tabanı V111; yereldeki ayrı AI/prompt/gateway değişiklikleri bu arayüz dalına katılmadan korunur. Bağımsız arayüz kopyasında 268 test geçti ve analiz temiz. Belgeler/görüntüler: docs/releases/ui-son-karar. Özel test APK'sı ve kullanıcı verileri GitHub'a eklenmez. Yerel teslim ve kurulum kanıtları: C:/Users/exzau/Documents/Codex/2026-10-30/atlas-ui-son-karar-output.

29 Ekim 2026. Kaynak çalışması tamamlandı. Sonraki kurulum talebiyle V117 (1.0.0-kimi-test.117), V116 üzerine aynı diagnostic paket ve imzayla kuruldu. Önceki sürüm kayıtları kendi teslim klasörlerinde korunuyor.

- Mevcut sesli video/posterler korunuyor. Hazır görüntü ve ilk raster sonrasında 1.000 ms belirme. Video buna paralel hazırlanıp oynar; ek bir saniye bekletilmez. Tam sahne orantılı içeride, ekranın kalan kenarları kendi dokularıyla doldurulur. Fiziksel soğuk başlatma ve hareketli video V117 kurulumunda kontrol edildi.
- Açıklamalar her süreçte sayfa başına ilk tamamlanan görünür ziyarette 6 saniye; 400 ms solma. Uzun basma, ayar kapalıyken de yalnız ilgili adı gösterir. Ayarlar’da “Tuş açıklamalarını göster” varsayılan açık.
- Yeni kalıcı tercih `files/home-action-hints/options.json`; yalnız anahtarı değiştirince yazılır. Eski coffee.json/tarot.json korunur ve okunmaz. Tamamlanan ziyaretler artık oturum belleğindedir. Sonraki kurulum veri kontrolü bu tercihi iş kayıtlarından ayrı değerlendirmeli; otomatik açıklamaların tamamlanması dosya yazmaz.
- Normal tuş aralığı 34 dp, büyük görsel alt açıklığı 58 dp. Büyük tuş +6 dp, küçük +12 dp. Büyük yazıya uyarlanır. V116’nın çerçeve/başlık/üst ve alt gezinme koordinatları 32 görünümde korunuyor.
- Çekirdekler ve yıldızlar başlık çevresine taşındı. Üstteki iki yapraklı dal +4 dp; orta çekirdek ve alt süsler sabit. Diğer ekranların dekorları değişmedi.

252 senaryo başarılı; analiz temiz. Video, fontlar, tuşlar, diğer medya, AI/gateway ve diğer yerel çalışmalar başlangıç özetleriyle aynı. Canlı AI/GitHub/mağaza işlemi yapılmadı.

V117 kurulumunda 556 dosya yedeklendi ve kurulumun hemen ardından birebir korundu. Açılış/ayar testlerinden sonra iş kayıtlarında değişiklik yok; yalnız yeni options.json tercihi ve Android işaretleri beklenen değişiklikler. Ayar son durumda açık. Telefonun 0,9 yazı ölçeği/450 yoğunluğu, normal Atlas paketi ve ilk kurulum tarihi korundu.

Gerçek soğuk başlatma kaydı incelendi; kademeli belirme ve hareketli video çalışıyor. Kahve/Tarot açıklamaları, ayarı kapatma/açma ve uzun basma cihazda doğrulandı. Ölümcül hata yok; uygulama Kahve ana ekranında bırakıldı. Bu kurulum için fiziksel kontrol tamamlandı.

APK: aynı teslim klasöründe Atlas-V117.apk. Kurulum kanıtları: V117_KURULUM_SONUCU.md/json; gerçek kayıt device-v117-cold-start.mp4. Onizlemeler.html telefon görüntüleriyle güncellendi. Android ekran kaydı ses içermez; uygulamanın sesli video dosyası korunmuştur.

Teslim: C:/Users/exzau/Documents/Codex/2026-10-29/atlas-home-polish-output/Onizlemeler.html ve DOGRULAMA.md. 64 ana ekran görünür/gizli görüntüsü, 20 açılış karesi, dört Ayarlar görüntüsü gerçek Flutter render’larıdır. `test/fixtures/landing-v116-metrics.json` eski gerçek render ölçümleridir; yerleşim regresyonları buna göre doğrulanır.
