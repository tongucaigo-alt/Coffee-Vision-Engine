# Atlas Tarot V79 — Mood boyut ve boşluk düzenlemesi

17 Ekim 2026. Dal: `codex/atlas-tarot-compact-v79`.

## Kaynak ve değişiklik

V77'yi üreten `atlas-coffee-guide-v73` çalışma kopyası, sonradan eklenen V78 fotoğraf şeridi ve diğer yerel çalışmalarla birlikte ayrı çalışma ağacına alındı. Başlangıç checkpoint'i `5a9a8c2`. Asıl çalışma kopyası değiştirilmedi.

Mood düğmelerinin renkleri, çerçevesi, köşe biçimi, yazı tipi, simge üstte/metin altta yapısı ve 3+2 sırası korundu. Simge 22dp'den 18dp'ye, iç dikey boşluk 12dp'den 4dp'ye indirildi; simge/metin aralığı 2dp oldu. Düğmenin minimum boyutu 48×48dp; büyük yazıda yüksekliği doğal olarak artar. Başlık aynı 19sp Literata ve aynı metindir. Mood alanının ve yorum düğmesinin çevresindeki dikey boşluklar azaltıldı.

Kartlar, kart adları, Düz/Ters etiketleri, kart açılışı, seçim, kayıt ve AI davranışı değiştirilmedi. Kaynak farkı yalnız iki Tarot görünüm dosyası ve ilgili widget testindedir; bu not ayrıca eklendi. Başlangıçtaki diğer 1.141 dosya byte düzeyinde aynıdır. Kahve, V78 fotoğraf şeridi, Lottie animasyonu, OpenCV, profil/kişiselleştirme ve bağlantı ayarları korunur.

## Doğrulama

- Tarot model/AI/widget grubu: 42 başarılı. Kayıt, tekrar açılış, isteğe bağlı mood, hata ve tek üretim korumaları dahil.
- Flutter analizi sorunsuz; diff boşluk kontrolü temiz.
- A56'nın 384×832dp ölçüsünde, 40dp üst / 48dp alt güvenli alanla 0,9× ve 1× yazıda kaydırma mesafesi 0dp doğrulandı. Aynı örnek kartlarla başlangıçta bu değerler 98dp ve 140dp idi.
- Tüm mood seçenekleri en az 48dp. Üç üst, ortalanmış iki alt seçenek ve simgenin metnin üstünde kalması ölçüldü. Ana düğme başlangıç görünümünde tamamen erişilebilir.
- 320×568, 360×700 ve 412×700; normal/iki kat yazı, çentik ve hareket azaltmadaki mevcut 36 önizleme kontrolü geçti. Çok küçük ekran ve büyük erişilebilirlik yazısında okunabilirliği koruyan mevcut kaydırma desteği kaldırılmadı.
- Canlı ücretli AI çağrısı yapılmadı. Tam uygulama test paketi yerine değişiklikle ilgili Tarot grubu çalıştırıldı.

## APK ve telefon

`Atlas-Tarot-V79.apk`, `com.coffeeplatform.atlas_contribution_app.diagnostic`, sürüm `1.0.0-kimi-test.79`, görünen ad `Atlas Fotoğraf Testi V79`. Önceki V78 ile aynı test imzasını kullanan debug APK'dır. Mevcut dört build ayarı ve dışarıdaki özel bağlantı dosyası korunmuştur. Gizli anahtarlar kaynakta tutulmaz.

SHA-256: `da9bccbebb7a10bd61d1be43fdf8a7b67914ab05ccc01cd017de24afbabf6228`.

V78 APK'sındaki 122 korunan varlık byte düzeyinde aynıdır; Tarot görselleri, promptlar, Lottie animasyonu ve ONNX modeli dahildir. 30 native kütüphanenin 27'si byte düzeyinde aynıdır; üç mimarideki DartJNI yardımcı kütüphaneleri yeni çalışma ağacında yeniden derlenmiştir. OpenCV kaynakları ve native OpenCV kütüphaneleri değişmemiştir.

Samsung A56, paket/imza/yükselen sürüm doğrulamasından sonra yalnız `install_preserving_data.py` ile V78'den V79'a güncellendi. Kaldırma ve veri temizleme yapılmadı. Kurulum öncesi 302 dosya özel yerel yedeğe alındı; kurulumdan hemen sonra 302/302 dosya aynı kaldı. Normal Atlas paketi ve ilk kurulum tarihi korunmuştur.

Kurulum öncesi son kopyadaki 14 Tarot açılımı ve diğer kullanıcı verileri telefon kontrolünden sonra da byte düzeyinde aynıdır. İlk inceleme ile kurulum arasında kayıt sayısı 13'ten 14'e çıktığı için son kurulum öncesi kopya karşılaştırma tabanı alınmıştır. Kontrol sırasında yeni açılım oluşturulmadı, mood değiştirilmedi, yorum üretilmedi. Android'in profil kurulum ve ActivityThread çalışma işaretleri dışında veri değişikliği yoktur.

Gerçek telefonda kartların alanları ve kahve ana ekranının metin/yerleşim sınırları önceki sürümle aynı kaldı. Mood seçimi ve 3+2 dizilim korundu; beş düğme de en az 48dp'dir. Yorumunu Oluştur düğmesinin tüm alanı `[146,1763]–[934,1909]` piksel sınırlarıyla 2205 pikselde başlayan alt sistem alanının üstünde kaldı. Dikey kaydırma hareketi sonrası içerik konumları değişmedi. Telefon, mevcut açılımın bu ekranında bırakıldı.

Teslim klasörü: `C:/Users/exzau/Documents/Codex/2026-10-16/atlas-tarot-compact-v79-output`. APK, önizlemeler ve doğrulama JSON'ları buradadır. Özel veri yedekleri `AppData/Local/AtlasAiBeta/device-backups` altında ve Git kapsamı dışındadır. GitHub yayını yapılmadı.
