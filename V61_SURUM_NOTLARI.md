# Atlas V61 — Yeni logo ve tarama halkası

13 Ekim 2026. V60 ve V61 kahve arayüzü değişikliklerinin GitHub yayını.

- Kullanıcının verdiği yeni logo uygulama içinde ve Android simgesinde kullanılır.
- Fincanının Hikâyesi ekranındaki yeşil dönen noktalar yerine kum/bakır halka, şeffaf hilal ve karşısındaki güneş bulunur. Kahve çevresindeki mevcut semboller korunur.
- Ana halka V60'a göre iki kat kalındır; ay ve güneş %25 büyütülmüştür. Yörünge çapı, mevcut fotoğraf kadrajı ve sembol ritmi korunur. Hareket azaltmada halka sabit kalır; tamamlanma, hata ve iptalde animasyon durur.
- Fotoğraflarına Bak ekranında “Fincan fotoğrafı ekle” ve “Bu fotoğraflarla devam et” düğmeleri normal yazıda aynı ortalı 280 × 48dp ölçüsündedir. Büyük yazıda eşit genişlik ve metne gereken yükseklik kullanılır.
- Kamera/OpenCV, uygunluk, kayıt, AI üretimi ve çift basış davranışları değişmez.

## Doğrulama

405 birim/widget testi başarılı; 6 isteğe bağlı canlı test atlandı. Kod analizi ve diff kontrolü temiz. Küçük ekran/büyük yazı ve düğme eşitliği doğrulandı. Gerçek telefonda animasyon ayrı, AI çağrısı yapmayan önizleme paketinde kontrol edildi. Kullanıcı test uygulaması aynı imzayla güncellendi; taslak/kayıt dosyalarının byte hashleri ve normal uygulama korundu.

[V60 logo ve halka raporu](docs/contribution/COFFEE_UI_V60_2026-10-12.md), [V61 ölçü ve telefon raporu](docs/contribution/COFFEE_UI_V61_2026-10-12.md).

## GitHub APK'sı

**Atlas-V61-GitHub-Anahtarsiz.apk** aynı kaynaklardan oluşturulan ayrı test paketidir. Hazır API/Kimi anahtarı içermez. Fal bağlantısı Ayarlar → AI Laboratuvarı bölümünden kullanıcının kendi profili ve anahtarıyla yapılandırılır. Paket `com.coffeeplatform.atlas_contribution_app.diagnostic`, sürüm `1.0.0-reference.61`, kod 61. Telefonun mevcut özel bağlantılı V61 kurulumu bu yayın sırasında değiştirilmez.

Yeniden oluşturma:

```powershell
flutter build apk --debug --target lib/offline_main.dart --dart-define=ATLAS_AI_LAB=true --dart-define=ATLAS_DIAGNOSTIC=true --dart-define=ATLAS_IMAGE_SCREEN=true --build-name=1.0.0-reference.61 --build-number=61
```

[V61 GitHub yayını](https://github.com/tongucaigo-alt/Coffee-Vision-Engine/releases/tag/atlas-v61). Kaynak dalı `codex/atlas-coffee-ui`, etiket `atlas-v61`. API anahtarları, imzalama dosyaları ve kullanıcı verileri yayımlanmaz. APK debug imzalı ayrı test paketidir.

V59 **“En güvenilir sürüm”** etiketi ve yayın dosyaları geri dönüş için korunur: [V59 yayını](https://github.com/tongucaigo-alt/Coffee-Vision-Engine/releases/tag/atlas-v59-en-guvenilir-surum).
