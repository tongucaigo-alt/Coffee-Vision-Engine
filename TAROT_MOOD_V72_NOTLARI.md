# Atlas Tarot V72 — Ruh hâli ve ana ekran

14 Ekim 2026. Dal: `codex/atlas-tarot-mood-v71`. Başlangıç: temiz V70 `181d5ff`.

İlk V71 kurulumu sonrası gerçek cihazda duygu seçiminin ekran okuyucuda düğmeyle tek öğe olarak sunulması iyileştirildi. Aynı sürüme kurulum yapılmaması için son teslim V72'ye yükseltildi.

## Teslim edilen davranış

Üç Kart ve Günün Kartı açılışında, tüm kartlar seçildikten sonra kartların altında isteğe bağlı ruh hâli alanı görünür. “İstersen bana nasıl hissettiğini söyleyebilirsin.” başlığının altında Mutlu, Sakin, Kararsız, Gergin ve Yorgun seçenekleri bulunur. Tek seçim değiştirilebilir veya aynı seçeneğe tekrar dokunularak kaldırılabilir. Mood kaydı kart açılışını kilitlemez. Kayıt hatasında önceki seçim korunur ve kullanıcı kartlarını açabilir.

Mood yalnız ilgili Tarot açılımında yerel nottur. `TarotMood` ve isteğe bağlı `TarotDraw.mood` eklenmiştir; mevcut atomik, sıralı Tarot deposu kullanılır. Eski kayıtlarda alanın yokluğu seçimsiz duruma karşılık gelir. Diğer kayıt işlemleri mood bilgisini korur. Toplu göç ve depo sürümü değişikliği yoktur. Kimi bağlamı/promptu değişmez; mood AI isteğine gönderilmez. Tamamlanmış yorumda seçilmiş duygu kart özetinin altında gösterilir.

Tarot ana ekranı kahve referansının çerçevesini yalnız Tarot'a ait özel çiziciyle kullanır. Panel kullanılabilir yüksekliğe uzanır; 16dp dış boşluk, en fazla 460dp genişlik, küçük cihaz/büyük yazıda kaydırma vardır. Günün Kartı, geniş kahverengi Üç Kart düğmesi ve Tarot Geçmişi alt bölümde yer alır. En yeni tamamlanmamış Üç Kart açılımına devam düğmesi sağ üsttedir. Aynı açılıma devam eder; yeni çekim veya yorum çağrısı başlatmaz.

Kaynak değişiklikleri dört Tarot dosyası ve iki Tarot test dosyasıyla sınırlıdır. Bu teslim notu ayrıca eklenmiştir. Başlangıçtaki 1.114 kaynak dosyasının kalan 1.108'i V70 çalışma kopyasıyla byte düzeyinde aynıdır. Windows checkout satır sonları başlangıç kopyasıyla eşleştirilmiştir. Kahve, OpenCV, ortak tema, kamera, kart görselleri, AI istemcisi ve prompt korunmuştur. Eski çalışma ağaçları değiştirilmemiştir.

## Doğrulama

- V70 başlangıç widget testleri: 12 başarılı.
- Son Tarot model/AI/widget grubu: 41 başarılı; 7 yeni davranış testi içerir.
- Tam Flutter grubu: 433 başarılı, 7 atlanan. Gruplar örtüşür; sayılar toplanmaz.
- Flutter analizi sorunsuz; Git diff boşluk kontrolü temiz.
- 320×568, 360×700 ve 412×700; normal/iki kat yazı, çentik ve hareket azaltmada 36 önizleme incelendi. Mood seçeneklerinin tamamına kaydırılarak erişim ve en az 48dp boyut ayrıca doğrulandı.
- Mood seçmeden açılış, seçimi değiştirme/kaldırma, tekrar açılış, kayıt hatasında kartlara devam, aynı zamana yakın kayıt/açılış işlemlerinde veri koruması ve AI girdisinde mood bulunmaması test edildi.
- Önizleme yorumları test verisidir; otomatik ücretli Kimi çağrısı yapılmadı.

## APK ve Samsung A56

`Atlas-Tarot-Mood-V72.apk`; paket `com.coffeeplatform.atlas_contribution_app.diagnostic`, sürüm kodu 72, sürüm adı `1.0.0-kimi-test.72`, görünen ad `Atlas Fotoğraf Testi V72`.

V70 ile aynı test imzası kullanılır. APK debug test derlemesidir. Giriş noktası `lib/offline_main.dart`; mevcut AI Laboratuvarı, Diagnostic, Kimi yerel test ve görsel uygunluk build ayarları korunur. Özel bağlantı dışarıdaki build tanımından gelir. Anahtar ve imza dosyaları kaynakta tutulmaz.

SHA-256: `3b15b9ce878c08839c63051c519e7865a2fe853da5414f500280240479ccca2f`.

79 WebP, Tarot kataloğu/promptu ve ONNX modelinin APK içeriği kaynakla karşılaştırılmıştır. Telefonun V70 paketi önce V71, ardından son V72 sürümüne kimlik/imza/yükselen sürüm doğrulamasından sonra yalnız `tool/install_preserving_data.py` ile güncellenmiştir. Kaldırma, veri temizleme ve Flutter otomatik kurulumu yapılmamıştır. Her iki kurulumdan hemen sonra mevcut 42 uygulama dosyasının tamamı byte düzeyinde aynıdır; ilk kurulum tarihi ve normal Atlas paketi korunmuştur.

Gerçek cihazda mevcut yarım açılım yeni sağ üst düğmeyle açılmış, değiştirilmeden geri dönülmüştür. Kontrol için yalnız bir yeni yerel Üç Kart açılımı oluşturulmuştur. Deste indeksleri 0, 1, 2 seçilmiş; ilk kart mood seçmeden açılmış; Mutlu seçilip kaldırılmış, Sakin seçilmiştir. Üç kart sırayla açılmıştır. Uygulama kapatılıp yeniden açıldıktan sonra aynı kartlar, yönler ve Sakin notuyla devam edilmiştir. Yorum üretimi başlatılmamıştır; yeni test kaydı `idle` durumundadır. Dört eski Tarot kaydı tüm alanlarıyla, günlük kilitler ve diğer kullanıcı dosyaları korunmuştur. Android'in `files/profileInstalled` çalışma işareti yeni sürüm açılışında güncellenmiştir. Kahve ekranının erişilebilirlik metinleri ve yerleşim sınırları V70 ile aynı kalmıştır.

Teslim klasörü: `C:/Users/exzau/Documents/Codex/2026-10-14/atlas-tarot-mood-v71-output`. APK, önizlemeler, telefon ekranları, test/build logları ve doğrulama raporları buradadır. Özel kayıt yedekleri Git kapsamı dışındadır. APK ve özel build dosyaları kaynak yayınına dahil değildir.

## GitHub güncellemesi — Tarot Uİ düzenlendi

Yayın dalı `codex/atlas-tarot-ui-update`, GitHub'daki `codex/atlas-coffee-ui` V65 kaynağından açılmıştır. Yerel `181d5ff` ve `2061c3a` commit'lerinin yalnız Tarot değişiklikleri taşınmıştır. Fark dört Tarot kaynak dosyası, iki ilgili test dosyası ve iki teslim notuyla sınırlıdır. Yereldeki henüz yayımlanmamış V69 OpenCV/kahve checkpoint'i bu dala dahil değildir.

Bu GitHub kaynağında tam Flutter test grubu yeniden çalıştırılmıştır: 431 başarılı, 6 atlanan. Yukarıdaki 433/7 sonucu, V69 tabanını koruyan yerel V72 telefon teslimine aittir. Telefona kurulan APK yerel teslim kaynağından üretilmiştir; bu PR yalnız Tarot değişikliklerini yayımlar.
