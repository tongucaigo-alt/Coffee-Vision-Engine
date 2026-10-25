# Atlas Tarot V101 — teslim ve doğrulama

V101, 25 Ekim 2026 tarihinde Samsung A56'ya veri koruyan güncelleme olarak kuruldu.

## Uygulanan değişiklikler

- Büyük el, DOKUN etiketi ve dokunma halkaları kaldırıldı. Sıradaki kapalı kartta 2,4 saniyelik çapraz ışık ve döngünün sonunda en fazla ±2dp / ±0,7° görsel sallanma var. Diğer kapalı kartlar %72 opaklıkta.
- Açılış yönlendirmesi kayıt ve 600ms kart dönüşünden sonra Geçmiş → Şimdi → Olası Yön sırasını izliyor. Günün Kartı aynı bileşeni kullanıyor. Yanlış karta dokunma tek 450ms ışık geçişi oluşturuyor.
- Alt deste paneli #F6EFE2 krem. Alan 220dp; kartlar 84×126dp, adım 52dp, kenarlar 12dp, kavis en fazla 6°. 360dp'de beş, 412dp'de altı tam kart görünüyor.
- Yalnız görünür aralık ve iki komşu oluşturuluyor. Örtüşmelerde üstte görünen kartın gerçek indeksi seçiliyor; seçilen kartın yeri ve komşuları sabit kalıyor.
- Görünür, seçilmemiş bir veya iki kartın arkasında rastgele sıcak altın aura var. Başlangıç aralıkları 2,5–4,5 saniye, ışık süresi 1,8 saniye; yoğunluk da rastgele. Efekt en fazla 16dp taşıyor ve bütün kart resimlerinin arkasında kalıyor.
- Parmak teması/sürüklemede yeni aura başlamıyor, mevcut ışık 200ms'de sönüyor. Arka plan, gizlenen sayfa ve tamamlanan seçimde efektler duruyor. Hareket azaltmada aura/sallanma/tarama kapalı, sıradaki kart sabit bakır çerçeveli.
- Telefon titreşimi, yeni ses, WebView ve yeni animasyon paketi eklenmedi. Mood, kart çizimleri, model/depo/JSON ve AI sözleşmeleri değişmedi.

## Kaynak korunması

Başlangıç, V100'ü üreten güncel `atlas-tarot-reveal-guidance` kaynağıdır. Commit edilmemiş çalışmalar ayrı çalışma ağacına byte karşılaştırmasıyla taşındı ve `f115b29` başlangıç kontrol noktasında korundu. Eski V93 commit'inin eksik içeriğinden geliştirme yapılmadı.

Dal: `codex/atlas-tarot-effects-v101`.

Başlangıçtaki 1214 dosyanın 1211 tanesi byte olarak aynı. Mevcut dosyalarda yalnız Tarot sayfası, Tarot görünüm bileşeni ve ilgili widget testi değişti. Yeni dosyalar Tarot efekt bileşenleri, aura testi ve bu teslim notudur. Kahve/OpenCV, ortak palet, açılış videosu/sesi, bağlantı, AI, çekim ve kayıt kaynakları aynı. Orijinal V100 çalışma kopyası da değişmedi. Git dışında tutulan açılış videosu ayrıca kopyalanıp doğrulandı.

## Doğrulama

**138 test geçti; 1 isteğe bağlı eski V97 ekran kaydı testi ortam bayrağı verilmediği için atlandı. Flutter analizi: sorun yok.**

Çalıştırılan gruplar: `tarot_aura_test`, `tarot_test`, `tarot_widget_test`, `home_consistency_test`, `atlas_design_test`, `coffee_ui_flow_test`, `atlas_intro_test`, `atlas_intro_startup_test`, `privacy_layout_test`.

Kontroller; 78 indeksin tamamına erişim, uzak indeks, örtüşme, sürükleme, tekrar dokunma, kayıt hatası/yeniden deneme, yarım açılım, sıralı açılış/yanlış sıra, ters kart, günlük kilit, mood eşzamanlılığı, kayıtlı yorum, tek üretim koruması, efektlerin kayıt/AI/haptik oluşturmaması ve arka plan/gizli sayfa davranışını kapsadı. Aura zamanları sabit tohum ve sanal saatle sınandı.

320×568, 360×700, 412×700 ve A56'ya karşılık gelen 384×832 ölçülerinde normal/iki kat yazı, güvenli alanlar, hareket azaltma ve erişilebilirlik semantiği kontrol edildi. Yeni efektler kart geometrisine veya mevcut kaydırma ölçüsüne alan eklemiyor. Çok küçük ekran/iki kat yazıda V100'ün erişilebilir kaydırma davranışı korunuyor. Gerçek cihazda erişilebilir eylem sırası XML ile doğrulandı; sesli TalkBack kullanım denemesi yapılmadı.

## APK ve cihaz

- Paket: `com.coffeeplatform.atlas_contribution_app.diagnostic`; sürüm `1.0.0-kimi-test.101`, görünen ad **Atlas Fotoğraf Testi V101**.
- Mevcut diagnostic test paketiyle uyumlu **imzalı debug test APK**. V100 ile aynı sertifika: `3ff99635116fc66d42d08fb57abfbb0dd19fd611ab334803e9b89d37f0cb81ff`.
- SHA-256: `119a34fbb2bcb3316ee7ca1e0343b11bd2e140baf203a5c5242b48721f0ff8ca`.
- V100'ün üç release/test define ayarı ve harici özel bağlantı dosyası aynen kullanıldı. Gizli değerler rapora veya kaynaklara eklenmedi.
- APK içindeki 126 korunan varlık ve 27 yerel kütüphane byte olarak aynı. Üç mimarideki `libdartjni.so` yeni çalışma ağacında yeniden üretildi; yerel kaynak kodu değişmedi.
- Kurulum yalnız mevcut `install_preserving_data.py` ile yapıldı. Kaldırma/veri temizleme/Flutter otomatik kurulumu kullanılmadı. İlk kurulum zamanı aynı kaldı; normal Atlas V54 paketi korundu.
- Kurulum öncesi özel yerel yedek ve geri yükleme provası geçti. Kurulumdan hemen sonra **512 dosyanın tamamı aynıydı**; arşiv SHA-256 değerleri de eşleşti.

## Gerçek cihaz denemesi

Yeni, yalnız yerel bir Üç Kart test açılımı oluşturuldu. Deste ekranında bekleme ve manuel kaydırma kaydedildi; kayıt JSON'u byte olarak aynı kaldı, sürükleme seçim yapmadı. Gözlenen 7., 9. ve 11. kartlar gerçek deste indeksleri `[6, 8, 10]` olarak kaydedildi. Önce yanlış sırada Olası Yön'e dokunuldu ve hiçbir kart açılmadı. Ardından Geçmiş, Şimdi ve Olası Yön sırasıyla açıldı; sıradaki erişilebilir eylem ve son kartta yönlendirmenin bitmesi doğrulandı. Mood seçilmedi; yorum üretimi başlatılmadı.

Cihaz denemesinden sonra mevcut **35 Tarot kaydı**, günlük tarih işaretleri ve kahve kayıtları korundu. Yalnız **1 yeni yerel test açılımı** eklendi. Değişen dosyalar doğrulama JSON'unda listelenmiştir; açıklanamayan değişiklik yoktur.

İki gerçek cihaz kaydı: deste/aura **28.1s**, açılış **36.0s**. Her ikisi 1080×2340 ve ses kanalı içermez. Video kareleri ayrıca incelendi.

## Teslim dosyaları

- `Atlas-Tarot-V101.apk` ve SHA-256 dosyası.
- `Onizlemeler.html`: V100/V101 karşılaştırmaları, boyut matrisi, test verili Flutter önizlemeleri ve gerçek cihaz görüntüleri.
- `Tarot-V101-Deste.mp4`, `Tarot-V101-Telefon.mp4`.
- `Dogrulama.json`, test/analiz/build/kurulum günlükleri ve ayrı kanıt JSON'ları.

Canlı/ücretli AI çağrısı yapılmadı. GitHub yayını ve iOS cihaz doğrulaması yapılmadı. Özel telefon yedekleri kaynak deposunun ve teslim dosyalarının dışında tutuluyor.
