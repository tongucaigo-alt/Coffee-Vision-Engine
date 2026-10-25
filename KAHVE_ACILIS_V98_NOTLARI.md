# V98 — Başlangıç ekranını sadeleştirme

V97 yerel kaynakları üzerinden yalnız Android başlangıç kaynakları düzenlendi. Android 12+ başlangıç simgesi şeffaf bir vector drawable ile gizlendi. Açık/koyu mod ve eski Android pencere zeminlerinde videonun ilk karesine yakın sıcak parşömen (#EEDDBB) kullanıldı. Uygulamanın başlatıcı logosu korunur. Sistem başlangıç aşaması kaldırılmaz; görünür ayrı logo ekranı sadeleştirilir.

Video, Flutter kodu, ana ekranlar ve uygulama akışı değiştirilmedi. APK içindeki mevcut varlıklar ve native kütüphaneler V97 ile byte düzeyinde aynı; imza eşleşti. 19 açılış testi geçti; isteğe bağlı görsel üretim testi atlandı. Flutter analyze: No issues found. Android kaynakları derlenerek v31 ve night-v31 temaları doğrulandı.

APK: Atlas-V98.apk. Telefon kurulumu ve gerçek cihaz görsel kontrolü yapılmadı. Sistem üreticisinin başlangıç animasyonunun görünümü cihazda ayrıca kontrol edilmeli. GitHub yayını ve ücretli AI çağrısı yapılmadı.


## Telefon kurulumu — 25 Ekim 2026

V98 bağlı Samsung SM-A566B telefondaki Atlas Fotoğraf Testi uygulamasının üzerine aynı imzayla kuruldu. Sürüm 98 ve kurulu APK hash eşleşmesi doğrulandı. Kurulum öncesi/sonrası 512 dosyanın tamamı byte düzeyinde aynı; ilk kurulum zamanı ve normal Atlas paketi korundu. Kaldırma/veri temizleme yapılmadı. Özel yedek ve yerel geri yükleme doğrulaması PASS. Uygulama tarafımızca açılmadı; başlangıç görünümü cihazda henüz görsel olarak doğrulanmadı. GitHub yayını ve ücretli AI çağrısı yapılmadı.
