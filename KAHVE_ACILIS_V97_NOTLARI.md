# V97 — Tam ekran açılış ve tutarlı ana ekranlar

25 Ekim 2026. V96 yerel çalışması korunarak uygulandı.

- Her soğuk açılışta tam 8 saniyelik video; cover ile tam ekran, görünür tuş/başlık/çerçeve yok. Dokunma veya geri video ve sesi hemen kapatır.
- Kahve/Tarot ana başlıkları Literata 22sp/w500; açıklama ve kısa bilgi stilleri ortak. Mevcut logo/kart ölçüleri aynı, ortak 152dp alanda hizalı.
- Pastel yapraklar belirginleştirildi; ortadaki geometrik motif kahve çekirdeğine dönüştürüldü. Çerçeve çizimi iki ekran için ortak.
- 90 ilgili test + 1 ayrı önizleme testi geçti; analiz temiz. Başka işler ve kayıt/AI/kamera davranışları korunur.
- Yerel teslim: `C:/Users/exzau/Documents/Codex/2026-10-25/atlas-welcome-v97-output` — APK, V97_DOGRULAMA.md, Onizlemeler.html, sesli Flutter önizlemesi ve test günlükleri.
- V97 telefon kurulumu veya GitHub yayını yapılmadı. Telefonda son doğrulanan sürüm V96. Gerçek cihaz tam ekran/ses kontrolü bekliyor.


## Telefon kurulumu — 25 Ekim 2026

V97, bağlı Samsung SM-A566B telefondaki **Atlas Fotoğraf Testi** diagnostic paketinin üzerine aynı imzayla kuruldu. Kurulu sürüm 97 ve APK SHA-256 eşleşmesi doğrulandı. Kaldırma veya veri temizleme yapılmadı; ilk kurulum zamanı ve normal Atlas paketi değişmedi.

Kurulum öncesi ve sonrası özel yedekler doğrulandı: 512 dosyanın 511’i byte düzeyinde aynı; yalnız Android’in `android.app.ActivityThread.IDS.xml` dosyasındaki `IDSCount` sistem sayacı değişti. Uygulama kayıtları, fotoğrafları ve tercihleri korundu. Yedekten geri yükleme doğrulaması PASS.

Kurulumdan sonra uygulama tarafımızca açılmadı; cihazda video/ses ve tam ekran davranış testi yapılmadı. Ücretli AI çağrısı ve GitHub yayını yapılmadı.
