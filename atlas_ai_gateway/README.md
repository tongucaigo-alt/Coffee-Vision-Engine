# Atlas AI test bağlantısı

Bu servis falı kendisi hesaplamaz; kimlik doğrulama ve sırayı yönetip LM Studio'ya yalnız izinli metinsel bağlamı iletir. Fotoğraf kabul etmez. İlk model `qwen3-14b`; protokol uyumlu modeller yapılandırmadan değiştirilebilir. Node.js 24 gerekir; npm bağımlılığı yoktur.

## Yerel kurulum ve başlatma

PowerShell **7** içinde, bu klasörden:

```powershell
./tool/setup-local.ps1
./tool/run-local.ps1
```

Kurulum dosyası 10 testçinin ayrı erişim anahtarını, Android imza anahtarını ve resmî SHA-256 değeri doğrulanan Cloudflare aracını hazırlar. Var olan anahtarları değiştirmez. Özel dosyalar `%LOCALAPPDATA%/AtlasAiBeta` altında kalır. Android `key.properties` Git tarafından dışlanır. `key.properties.backup` ve keystore birlikte, özel bir yedek olarak korunmalıdır.

LM Studio'da sunucu açık ve model hazır olmalıdır. Varsayılan bağlantı `http://127.0.0.1:1234/v1`; LM Studio'yu internete açmak gerekmez. Yalnız bağlantı servisi tünellenir. Model/API anahtarı gerekiyorsa özel `gateway.json` içindeki ilgili modelin `apiKey` alanına eklenir; APK'ya gönderilmez.

`run-local.ps1` arka planda yalnız Atlas servisini ve tünelini başlatır. Üretilen HTTPS adresini gösterir ve `test-address.txt` dosyasına yazar. Adres tünel yeniden başladığında değişebilir. Durdurmak için:

```powershell
./tool/run-local.ps1 -Stop
```

LM Studio açık bırakılır. Quick Tunnel test amaçlıdır; kalıcı adres ve kesintisiz erişim garantisi yoktur. HTTP istekleri kısa tutulur; üretim işi durum sorgusuyla izlenir, SSE kullanılmaz.

## APK

Uygulama klasöründen:

```powershell
flutter build apk --release --target lib/offline_main.dart --dart-define=ATLAS_AI_LAB=true
```

Paket kimliği `com.coffeeplatform.atlas_contribution_app.beta` olur. Mevcut uygulama ve verileri korunur. Release derlemesi Founder imza anahtarı olmadan durur; debug imzası dağıtım imzası sayılmaz. Debug beta ile release beta farklı imzalıysa veri kaybını göze alarak kaldırıp kurmayın; önce veriyi koruyun. Dağıtılacak ilk sürüm release olmalıdır.

Testçi AI Laboratuvarında **Atlas servisi**, güncel HTTPS adresi, `atlas` model takma adı ve **yalnız kendisine ait** token'ı girer. `tester-credentials.json` dosyasının tamamı paylaşılmaz. Kurucu bir arkadaşına tek anahtarı kendisi iletir; uygulama otomatik davet göndermez.

Model eklemek: özel `gateway.json` içindeki `models` haritasına başka bir takma ad ekleyin. Kuyruğa girmiş işler kabul edildikleri model ile tamamlanır. Aynı bilgisayar tek üretim sırasını paylaşır. A/B için ikinci gerçek sohbet modeli gerekir; embedding modeli kullanılamaz. Aynı GPU'da iki model tutmamak için LM Studio'nun tek-model/JIT boşaltma davranışını model değişiminde doğrulayın. Servis kendi başına model indirmez veya yüklenmiş modeli zorla boşaltmaz.

Kişisel sunucu kullanıcısı **Kendi AI sunucum** seçer; `/v1` ile biten adresini, sohbet modelini ve gerekiyorsa anahtarını girer. İnternet üzerinde HTTPS gerekir. Yalnız test APK'sında `10.x`, `172.16–31.x`, `192.168.x` özel IPv4 adreslerine HTTP açılır. `localhost` telefondur. Kişisel sunucunun erişilebilirliğini ve kaynaklarını sahibi yönetir; Atlas kuyruğu bu bağlantıya uygulanmaz. Sunucu adresi değişince kimlik bilgisi otomatik taşınmaz.

## Davranış ve sınırlar

- Ana üçlü çekim ve Kayıtlarım aynı aktarım katmanını kullanır; fotoğraflar tekrar kodlanmaz. Gözlemler AI gösterilmeden mühürlenir.
- Üç fotoğraf aynı fincanın açılarıdır. Kullanıcı sembol seçmeden de kullanılabilir fiziksel ölçümlerle fal deneyebilir. Tamamen boş veya bekleyen analiz gönderilmez.
- 1 çalışan + 9 bekleyen iş; kişi başına tek açık iş. Üretim/düzeltme bütçesi 180 saniye, kuyruk bütçesi 30 dakika. Bu süre beklenen hız değildir.
- İptal edilen veya zaman aşımına uğrayan aktif iş upstream tamamlanana kadar GPU yuvasını tutar. Bağlantı kesilip upstream durumu bilinemezse yeni üretim duraklatılır. LM Studio'nun artık boşta olduğunu doğruladıktan sonra servisi yeniden başlatın.
- İşler ve sonuçlar serviste yalnız RAM'de tutulur; biten sonuç 30 dakika sonra silinir. Yeniden başlatma eski işi otomatik tekrar çalıştırmaz. Telefon fal geçmişini saklar.
- Aynı istek kimliği aynı iş döndürür; başka içerikle kullanılırsa reddedilir. Anahtar iptali bir sonraki istekte geçerlidir. Genel proxy, araç/MCP, görsel giriş ve serbest upstream adresi bulunmaz.
- Prompt ve kalite kuralları sürümlüdür. Belirgin kesinlik, görsel tespit iddiası, teknik ölçüm tekrarı, düşünce veya kesilme durumunda bir düzeltme denenir; uygun yanıt yoksa hata gösterilir. Kural denetimi dilin tamamına ilişkin matematiksel garanti değildir. Qwen'in dil kalitesi ve uzunluğu ayrıca insan tarafından değerlendirilmelidir.
- A/B aynı metinsel bağlamı/prompt sürümünü kullanır. Sıra telefonda rastgeleleştirilip kalıcılaşır; tercih öncesi sonuçların model kimliği gösterilmez. Farklı düşünme talimatlarıyla üretilmiş yanıtlar geçerli karşılaştırma sayılmaz.
- Anahtarlar, profiller, fal metni ve oylar araştırma ZIP'ine girmez. Yalnız minimal AI gösterim zamanı/audit eklenir; güncel işaretler AI etkisi taşıyabilir. Eğitim için mühürlü ilk gözlemler ve gösterim geçmişi kullanılmalıdır.

## Testler

```powershell
node --test
node tool/local-trial.mjs 1
node tool/local-trial.mjs 10
```

`local-trial` geçici ve yalnız loopback üzerinden, yapay metinle gerçek Qwen'i çalıştırır. Hiçbir kalıcı testçi anahtarı oluşturmaz. Raporlar Git dışındaki `build` klasörüne yazılır.

Canlı Atlas/tünel denemesi (yalnız özel anahtar dosyasının yolu komuta girer):

```powershell
node tool/smoke.mjs https://TEST.trycloudflare.com "$env:LOCALAPPDATA/AtlasAiBeta/tester-credentials.json" build/remote-trial.json 10
```

Uygulama klasöründe `flutter test` ve `flutter analyze` çalıştırılır. Gerçek telefonun yalnız teşhis paketiyle USB üzerinden LM Studio'ya ulaşma testi:

```powershell
adb reverse tcp:1234 tcp:1234
& ../atlas_ai_gateway/tool/test-device.ps1 -Device TELEFON -RealAi
adb reverse --remove tcp:1234
```

Test için bu sarmalayıcıyı kullanın: önce `.diagnostic` APK derler ve kimliğini doğrular, ardından `ATLAS_DIAGNOSTIC=true` ve `--no-uninstall` ile testi çalıştırır. Flutter mevcut APK'nın kimliğini test derlemesinden önce okuduğu için doğrudan `flutter test` çağrısı önceki beta APK'nın kimliğini temizleme işleminde kullanabilir. Dağıtım beta APK'sını testler için kaldırmayın. USB testi, farklı internet bağlantısındaki telefon kabulünün yerine geçmez. Bunun için çalışan tünel adresiyle Wi‑Fi dışındaki bir bağlantıdan ayrıca deneme yapılır.

Mobil internet teşhisi için `test-device.ps1 -Device TELEFON -RemoteAi` kullanılır. Operatör önceden yalnız `.diagnostic` uygulamasının özel `files/remote-ai-test.json` dosyasına `url` ve kendisine ayrılmış `token` alanlarını yerleştirir. Bu dosya APK'ya derlenmez; test sonunda silinir. Test, gerçek `AiClient` ile HTTPS kullanır; socket yönlendirmesi yapmaz. Öncesinde `adb reverse --list` boş olmalı, telefon Wi‑Fi yerine mobil veri kullanmalıdır. Gerçek kullanıcı fotoğrafı gönderilmez.
