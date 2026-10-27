# V111 — Kahve / Tarot hale boşlukları

27 Ekim 2026. V110 üzerine yalnız ana ekran halesinin ölçümü düzeltildi.

## Değişiklik

- Kahve logosunun gerçek 128×128dp görüntüsü ve Tarot kartlarının dönüşler dahil görünen sınırları ölçülüyor. Tam genişlikteki yerleşim kutusu artık görünen kart boyutu gibi kabul edilmiyor.
- İki ana ekranda orta hizadaki krem çekirdeğin yan boşluğu **39dp**. Görselin üzerinde toplam **50dp**, altında **8dp** sönüm payı kullanılıyor. Aynı krem/altın geçiş durakları korunuyor.
- Orta hizada kremden altın geçişine mesafe Kahve'de yaklaşık **69,38dp**, Tarot'ta **68,67dp**. Fark, kare logo ve döndürülmüş kart siluetinden kaynaklanan **0,71dp**. Bunlar yumuşak gradyanın tasarım ölçüleridir; sert renk sınırı anlamına gelmez.
- ▶ düğmesinin görünmesi ve metin koruma alanları halenin merkezini veya ölçüsünü artık değiştirmiyor.
- Logo/kartlar, yazılar, çerçeve, başlık, düğme boyutları/konumları, dekor motifleri ve uygulama akışı değiştirilmedi. Tarot'un mevcut nefes hareketi ve paleti korunuyor; halo geometrisi ortak ölçüye bağlı.

## Doğrulama

- **56 ilgili test geçti:** atmosfer, gerçek ekran önizlemeleri ve ana ekran tutarlılığı. Tüm uygulama testlerinin tamamı çalıştırıldığı iddia edilmiyor.
- **flutter analyze --no-pub:** sorun bulunmadı.
- 360×700, 412×700 ve 412×892; 1×/2× yazı ile **36 gerçek Flutter görüntüsü** üretildi. Başlık, fotoğraf/kart, gezinme ve ana düğme sınırları V110 ile birebir aynı: `geometry-comparison.json`.
- 12 ana ekran ölçümünde yan boşluk 39dp; üst/alt paylar 50/8dp: `after/halo-metrics/` ve `halo-measurements.json`.
- Kahve ve Tarot için ayrı regresyon testlerinde ▶ eklenince hale piksellerinin değişmediği; görsel ve 48×48dp düğme ölçüsünün korunduğu doğrulandı.
- İnceleme, işaretleme ve Tarot seçiminde 18 PNG birebir aynı. Hazırlık ekranındaki altı PNG'de farklar fotoğraf içindeki mevcut rastgele işaret/efekt bölgelerinde; yerleşim ölçüleri ve bu ekranın kaynak davranışı değişmedi. Ayrıntı: `non-home-verification.json`.
- Önceki tüm dosyalar korundu. Bu tur değişen mevcut dosyalar yalnız `atlas_atmosphere.dart` ve iki atmosfer test dosyası. AI, veri, kayıt, kamera/OpenCV ve ağ arayüzlerine değişiklik yok: `source-verification.json`.

## APK ve telefon

- **Atlas Fotoğraf Testi V111** — `com.coffeeplatform.atlas_contribution_app.diagnostic`, sürüm kodu 111.
- V110 ile aynı imza. 126 varlık ve 30 yerel kitaplık birebir aynı. `apk-verification.json` ve SHA-256 dosyası teslimdedir.
- Bağlı Samsung SM-A566B'ye `adb install -r` ile kuruldu. İlk kurulum zamanı 16 Ekim 2026 10:00:33 olarak aynı kaldı. Kaldırma/veri temizleme yapılmadı. Normal Atlas paketine dokunulmadı.
- Kahve ve Tarot ekranları gerçek telefonda görsel olarak incelendi; iki ekranın cihaz görüntüleri galeriye eklendi. ▶ düğmelerinin sınırları iki ekranda da aynı: `[878,326][1013,461]`. Başlık, ana eylemler ve alt gezinme hizaları korundu. Kontrol sonunda Kahve ana ekranına dönüldü.
- Ücretli AI çağrısı yapılmadı. Kaynak ve bu doğrulama belgeleri V111 GitHub yedeğine dahil edildi. Özel test anahtarı içeren APK ve özel yapılandırma dosyaları GitHub kopyasına dahil değildir.

## Görseller

`Onizlemeler.html`: önce/sonra gerçek Flutter görüntüleri ve doğrulanmış cihaz görüntüleri. Yapay görsel veya HTML ile uygulamanın yeniden çizimi kullanılmadı. Flutter önizlemesinde sistem çubukları yok; cihaz görüntüsünde sistem çubukları ve telefonun 0,9 yazı ölçeği var.
