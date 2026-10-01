# Atlas — Play kapalı test hazırlığı

Durum: uygulama geliştirmesi ve doğrulama devam ediyor. Bu belge yayın onayı değildir.

## Dağıtım

- Giriş: `lib/offline_main.dart`, `ATLAS_PLAY_TEST=true`; `ATLAS_AI_LAB` kapalı.
- Kimlik: `com.coffeeplatform.atlas_contribution_app`. Mevcut `.beta` ve `.diagnostic` ayrı kalır; otomatik veri aktarımı yoktur.
- Play derlemesi laboratuvar bayrağı veya dolu `ATLAS_KIMI_TEST_KEY` ile durdurulur. Özel defines dosyası Play komutuna verilmez.
- Kurulum: `tool/install_preserving_data.py` paket, sertifika ve kurulu sürümden büyük sürüm kodunu doğrular. Yalnız `adb install -r` kullanır. Başarısızlıkta kaldırma/veri temizleme yapılmaz.
- Flutter test aracının otomatik kurulumunu kullanıcı verisi taşıyan paketlerde kullanmayın. Diagnostic test APK'sını ayrı derleyip doğrulayarak kurun.
- İmzayı ve upload anahtarını özel alanda yedekleyin; Git'e koymayın. Play App Signing kurulumu hesap sahibi tarafından yapılır.

Örnek derleme (Flutter PATH üzerinde):

```powershell
flutter build appbundle --release --target lib/offline_main.dart --dart-define=ATLAS_PLAY_TEST=true --build-number=12 --build-name=1.0.0-test.12
```

## Test servisi

LM Studio'da modeli yükleyip yerel sunucuyu başlatın. Mevcut `atlas_ai_gateway/tool/run-local.ps1` ile Atlas servisini ve HTTPS tünelini açın. Her testçiye ayrı erişim kodu verin; kişisel sağlayıcı anahtarı vermeyin. APK içindeki Ayarlar → Atlas Test Bağlantısı ekranına HTTPS adresi ve testçinin kodu girilir. Model takma adı `atlas` sunucuda yapılandırılır.

Test saatlerini testçilere önceden bildirin. Bilgisayar kapanınca fal üretimi kullanılamaz; telefondaki kayıtlar silinmez. Adres değiştiğinde erişim kodu yeni adrese kendiliğinden taşınmaz. Kuyruk 1 çalışan + 9 bekleyen iş; 12 testçinin aynı anda kabul edilmesi vaat edilmez.

## İçerik bildirimleri

- `POST /api/ai/v1/reports`: kimliği doğrulanmış testçi; `version:1`, UUID `id`, `reason` (`harmful`, `misleading`, `other`), yalnız bildirilen `text`.
- Kapasite: istek başına 64 KiB, yorum başına 12.000 karakter, testçi başına saatte 30 gönderim denemesi.
- Yanıt yalnız dosya kalıcı kaydedilince `201`, `status:received` olur. Aynı testçinin aynı bildirimi tekrar göndermesi çoğaltmaz. Testçi başka testçinin raporunu okuyamaz; okuma API'si yoktur.
- Sunucu raporları özel yapılandırmanın yanındaki `content-reports` klasörüne yazar. Bu klasörü yayımlamayın veya Git'e eklemeyin. Yöneticinin yerelden incelemesi gerekir; otomatik moderasyon paneli yoktur.
- Telefonda başarısız gönderimler bekler. Ayarlar'dan açık eylemle yeniden gönderilir; başka profile veya değişen adrese otomatik gönderilmez. Gönderilen metin telefonun bildirim kuyruğundan çıkarılır. Kayıt silinince ilgili yerel bildirimler de silinir.
- Sunucuya iletilmiş şikâyet, telefon kaydı silinince uzaktan kendiliğinden silinmez. Kullanıcıya bu ayrım gizlilik açıklamasında bildirilmelidir. Sunucu bildirimleri test yöneticisi tarafından manuel yönetilir.

## Play Console hazırlığı

1. Geliştirici hesabı, kimlik/cihaz doğrulaması, yayımlanacak geliştirici adı ve destek adresi.
2. HTTPS üzerinde herkesin erişebildiği gizlilik politikası; aynı bağlantı uygulama içinde. Taslak `PLAY_PRIVACY_DRAFT.md` içindedir; eksik kimlik/iletişim bilgileri tamamlanmadan yayımlanmaz.
3. Veri Güvenliği: metinsel fal girdisi, yorum bildirimi, isteğe bağlı araştırma ZIP'i ve SDK verileri ayrı değerlendirilir. "Hiç veri toplanmıyor" işaretlenmez. Tünel/SDK ağ verileri de incelenir.
4. İçerik derecelendirmesi ve hedef kitle gerçek davranışa göre doldurulur. AI falı eğlence amaçlıdır; gerçek görsel sembol tanıma, kesin gelecek veya uzman tavsiyesi vaat edilmez.
5. Reklam yok, ödeme yok, hesap sistemi yok. Gerçek ekran görüntüleri ve açıklamalar kullanılır; prototip puan/üyelik ekranları yüklenmez.
6. İnceleyicinin hizmeti deneyebilmesi için çalışan test hizmeti ve özel inceleme erişimi sağlanır. Geçici tünel/test saatleri mağaza incelemesinde erişim riski oluşturur.
7. Yeni kişisel hesap için en az 12 testçi / kesintisiz 14 gün koşulu Console üzerinden izlenir. Gerçek katılım ve geri bildirim gerekir; otomatik yük testi bunun yerine geçmez.

## Açık kabul koşulları

- Gerçek üç açı → tabak → kayıt → fal yürüyüşü. Siyah önizlemenin lens/ortam kaynaklı mı yazılım kaynaklı mı olduğu telveli fincanla doğrulanmalı.
- 30 telveli, 30 uygunsuz (10 klavye dahil), ayrıca 20 telvesiz örnek; bağımsız doğrulama grubu. Yedi olumsuz örnek yeterli değil.
- 12 fincan setinde kör eski/yeni değerlendirme, en az sekiz tercihle iyileşme kanıtı. Önceki 429 hataları başarı değildir.
- Sakıncalı içerik değerlendirmesi ve bildirimlerin yönetici tarafından gerçekten incelenmesi. Basit dil kontrolleri tek başına moderasyon garantisi değildir.
- 16 KB ELF kontrolüne ek olarak 16 KB cihaz/emülatör ve Play ön lansman raporu.
- Paylaşılmış sağlayıcı anahtarının hesap sahibi tarafından iptal edildiğinin teyidi.

Bu koşullar tamamlanmadan "Play'e hazır" veya "herkese açık yayına hazır" denmez.
