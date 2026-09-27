# Atlas AI beta — 17 Eylül 2026 doğrulama durumu

Kod, yerel testler ve Founder anahtarıyla imzalanmış beta APK hazır. APK telefona ayrı kimlikle kuruldu. Aşağıdaki açık maddeler nedeniyle bütün kabul senaryolarının tamamlandığı iddia edilmez.

## Doğrulananlar

- Flutter: 179 test geçti; `flutter analyze` bulgu vermedi.
- Node.js 24: 7 test geçti. On ayrı testçi, tek aktif üretim, sahiplik ayrımı, idempotency, iptal, zaman aşımı ve bir düzeltme sınırı denetlendi.
- A/B aynı bağlamı gönderiyor; model kimlikleri oy verilene kadar gizleniyor. Sıra ve tercih yeni runtime/ekran açılışında korunuyor.
- Yapay verili gerçek Qwen3-14B çağrıları çalışıyor. Düşünmesiz çağrıda `reasoning_tokens: 0` ve düşünme içeriği bulunmadığı gözlendi.
- Samsung cihazında `.diagnostic` paketiyle üç kamera akış testi, Kayıtlarım → bağlı AI inceleme geçişi ve A/B yeniden açılış testi geçti (5 test). Son gerçek AI testi sunucuya ulaştı, fakat modelin iki yanıtı da kalite kontrolünden geçmedi. Gerçek model testi başarılı kabul edilmedi; son UI turunda açıkça atlandı.
- Son yerel on eşzamanlı testçi denemesinde 6 iş başarılı, 4 iş `quality_rejected` oldu; hepsi tek üretim sırasından geçti. Son iş 592.604 ms'de (9 dakika 53 saniye) sonuçlandı. Tamamlanan işlerin üretim/düzeltme süreleri yaklaşık 33–73 saniye, uzun toplam süreler kuyruk beklemesini de içeriyor. Bu ölçüm farklı internetten erişim veya on kullanıcıya kesintisiz başarılı fal garantisi değildir.
- Normal telefon uygulamasının 68 dosyasının SHA-256 değerleri başlangıç yedeğiyle aynı. Normal uygulama kaldırılmadı veya temizlenmedi.
- Kamera ve frozen motor paketlerinde değişiklik yok. Founder imzalı `atlas_contribution_app/build/atlas-ai-beta-release.apk` doğrulandı ve telefona `.beta` kimliğiyle kuruldu. APK SHA-256: `4e6db236773bf375d7bc1358bb64e1735380ded81d9f7b19b8acbe5f1cc66fa9`. Önceki geliştirme APK'sı dağıtılmaz. Beta ana ekranındaki eski fal verilmeyeceği yazısı düzeltildi; ilgili 5 widget/akış testi yeniden geçti, analiz temiz.
- Kalıcı kurulum kullanıcı tarafından tamamlandı; 10 ayrı testçi anahtarı, imza anahtarı ve doğrulanmış Cloudflare aracı mevcut. Anahtarlar Git dışında tutuluyor. Servis ve HTTPS tüneli başlatıldı. HTTPS üzerinden anahtarsız istek 401, yetkili yetenek sorgusu başarılı; yapay, kuş işaretli bir fal 38.324 ms'de tamamlandı.
- Araştırma ZIP'i AI profilleri, anahtarlar veya fal metni içermez. Minimal AI gösterim denetimi eklenir; silinmesi beklenen katkılar dışlanır.

## Açık kabul maddeleri

1. İmza ve tünel kurulum engeli çözüldü. Kurulum hata metni veya ek izin beklenmiyor.
2. Telefon mobil veriden gerçek HTTPS sunucusuna erişti ve model listesini aldı (`wifi_on=0`, `mobile_data=1`, USB reverse listesi boş). İlk teşhis üretimi terminal başarısız iş durumuyla döndü; imzalı beta AI Laboratuvarı üretim denemesi de başarısız döndü. Bu denemeler başarılı fal üretimi olarak sayılmadı. Özel teşhis anahtar dosyası test sonunda silindi. İmzalı beta içindeki Atlas profili kaydedildi ve APK güncellemesi sonrasında korundu. Son kontrolde eski uygulamanın 68 dosyası yine değişmemişti.
3. Qwen'in anlatımı ve uzunluğu tutarsız. Bazı yanıtlar teknik terim, kesinlik veya uydurma görsel betimleme nedeniyle reddediliyor; kabul edilen örnekler de yaklaşık 150–200 kelimede kalabiliyor. 250–400 kelime bir prompt hedefidir, doğrulanmış başarı oranı değildir. Otomatik metin kontrolü insan değerlendirmesinin yerine geçmez.
4. Gerçek ikinci sohbet modeli hazır olmadığı için iki ayrı modelle bellek boşaltma/A-B kabulü yapılmadı. Sahte sağlayıcılarla işleyiş test edildi; model indirilmedi.
5. Kamera → katkı kaydı → bağlı Review → AI bileşenleri ve Kayıtlarım geçişi otomasyonlarda denetlendi. Kullanıcının gerçek fincan fotoğraflarıyla kesintisiz kabul yürüyüşü hâlâ yapılmalı.

## Cihaz testini güvenli başlatma

Flutter mevcut debug APK'nın kimliğini dinleyici derlemesinden önce okuyabiliyor. Önceki beta derlemesi mevcutken doğrudan test çağrısının temizliği beta paketini kaldırmayı denedi; beta telefonda kurulu olmadığı için işlem gerçekleşmedi. `tool/test-device.ps1` artık önceden teşhis APK'sını derleyip `.diagnostic` kimliğini doğrular ve `--no-uninstall` ile test çalıştırır. Son telefon turu bu sarmalayıcıyla, beta kaldırma girişimi olmadan geçti. USB yönlendirmesi test sonunda kaldırıldı.

Yerel, yapay verili ölçüm raporları Git dışındaki `build/local-trial-*.json`; uygulama test kayıtları `atlas_contribution_app/build/ai-*.log` altındadır. Bunlar gerçek katılımcı fotoğrafı veya kalıcı erişim anahtarı içermez. Kurulum ve çalıştırma için README'yi kullanın.
