# Atlas V34 — Ana ekran ve tek hazırlık görünümü

2 Ekim 2026 tarihli kaynak kodu kontrol noktasıdır. V21 sonrasındaki mevcut geliştirmeleri ve V33 akış düzeltmelerini birlikte içerir; ayrıntılar `V33_AKIS_DUZENLEMELERI.md` dosyasındadır.

## V34 görsel düzenlemesi
- Kullanıcının B referansındaki mevcut logo korundu.
- A referansına yaklaşmak için ana ekran çerçevesi genişletildi; logo, profil simgesi, düğmeler ve boşluklar yeniden boyutlandırıldı.
- Alt bağlantıların açıklama işlevleri korunarak renkleri sakinleştirildi.
- Küçük ekran ve büyük yazıda kaydırma ve düğmelere erişim korundu.
- Bu görsel düzeltmede kamera, AI promptu, kayıt biçimi ve hazırlık akışı değiştirilmedi.

## Doğrulama ve paket
- Uygulama testleri: 281 geçti, 2 mevcut canlı test atlandı.
- Flutter analyze: sorun yok.
- V34 ana ekranı gerçek telefonda görüntülenerek kontrol edildi.
- Aynı paket/imza doğrulanarak mevcut uygulama kaldırılmadan ve veriler temizlenmeden güncellendi.
- APK: `atlas_contribution_app/build/atlas-kimi-test-v34.apk`
- Paket: `com.coffeeplatform.atlas_contribution_app`
- Sürüm: `34 / 1.0.0-kimi-test.34`
- SHA256: `d73a703284150d6309d9e72ce7789872ecac1c49780cd428bcffe5ba05ab4e52`

APK ve özel derleme ayarları Git deposuna dahil değildir. V34 doğrulaması görsel düzenlemeye yöneliktir; V33 raporundaki tamamlanmamış cihaz kontrollerini tamamlanmış saymaz.
