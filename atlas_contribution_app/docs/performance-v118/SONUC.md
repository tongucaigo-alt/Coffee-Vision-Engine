# Atlas V118 — Kalibrasyon-Hız

30 Ekim 2026. İki sorun için teknik düzeltmeler ayrı kaynakta hazır. Telefona kurulum ve ücretli AI çağrısı yapılmadı. Gerçek telefondaki toplam fal süresinin ne kadar azalacağı henüz doğrulanmadı.

## Doğrulanan kaynak

V118, `2026-10-25/atlas-tarot-effects-v101` dizinindeki güncel yerel kaynaktan alındı. Build manifestindeki 79 girdinin 78'i eşleşti. Tek fark `ACILIS_ANA_EKRAN_INCE_AYAR_NOTLARI.md` not dosyasında; uygulama, AI ve gateway girdileri eşleşiyor. V118 APK SHA256 değeri ayrıca dosyadan doğrulandı. Ayrıntılar [kaynak doğrulamasında](source-verification.json).

Kaynak kopyası `C:/Users/exzau/Documents/Codex/2026-10-30/atlas-kalibrasyon-hiz`. Uygulama Git kökü bunun `atlas_contribution_app` alt dizini; dal `codex/kalibrasyon-hiz`, başlangıç `9d99a54`. Diğer yerel paketler aynı doğrulanmış kaynak kopyasından kullanılıyor. Özgün kaynak ve diğer chatlerin değişiklikleri değiştirilmedi. `isolated-ui-source` iş mantığı tabanı olarak kullanılmadı.

## Bulunan nedenler ve düzeltmeler

- **Fal açılışı:** Profil, konu, yıldız ve sonuçlar aynı AI dosyasını dört ayrı okumayla yüklüyordu. Her eski yanıtın görünürlük kaydı, zaten mevcut olsa bile dosyayı tekrar yazıyordu. Artık tek açılış görüntüsü okunuyor; ilk gösterimler topluca yazılıyor ve tekrar gösterimler dosyayı değiştirmiyor. Bozuk profil/konu kaydı durumunda yeni görünürlük yazısı yapılmıyor.
- **Hazır analiz:** Aynı kaynak için ilk gözlem ve güncel hazırlık mevcutken geçmiş yeniden taranıyor, gereksiz hazırlık revizyonu yazılıyordu. Kaynak parmak izi ve hazırlık sürümleri eşleşiyorsa mevcut hazırlık kullanılıyor. Fotoğraf/işaret değişikliği hazırlığı geçersiz kılıyor. Yeni fotoğraf setinin ilk gözlemi ve geçmiş incelemesi korunuyor.
- **İnceleme dosyaları:** Dosyalar her kontrolde yeniden JSON'a ve modele dönüştürülüyordu. En fazla 128 dosya / 4 MiB serileştirilmiş veri için doğrulanmış çözüm tutuluyor. Her erişimde gerçek dosya yeniden okunup SHA256 ile karşılaştırılıyor. Değişen dosyada zarf, içerik özeti ve kimlik kontrolleri yeniden çalışıyor; dosya boyutu/tarihine güvenilerek kontrol atlanmıyor.
- **Kayıtlarım:** Üst sekmeden çıkınca sayfa kaldırılıyor ve dönüşte `initState` tekrar yükleme başlatıyordu. Kahve ve Tarot için birer sınırlı veri görüntüsü tutuluyor: en fazla 200 kayıt ve 4 MiB serileştirilmiş veri. Tam ekranlar veya fotoğraf baytları önbelleğe alınmıyor. Detay aynı Kahve görüntüsünü kullanıyor; eşzamanlı yüklemeler birleşiyor. Filtre, kaydırma ve Kahve/Tarot bölümü korunuyor.

Yeni fal, silme, yıldız, konu/kaynak revizyonu ve kısmen başarısız yazılar ortak yerel değişiklik sayacını ilerletiyor. Yenile hareketi ve uygulamaya dönüş yeni okuma sağlıyor. Okuma sırasında değişiklik olursa eski görüntü yayımlanmıyor. Depo/runtime değişiminde eski oturumun satırları temizleniyor; geç tamamlanan eski Tarot yüklemesi yeni oturuma yazılamıyor. Hata/kurtarma görüntüleri başarılı önbellek olarak saklanmıyor.

Mevcut ölçümlere yalnız sayısal aşama süreleri eklendi: açılış okuması, fotoğraf uygunluğu, kaynak doğrulaması, analiz, trace, bağlam, ilk servis yanıtı, varsa düzeltme yanıtı ve yanıt kalite kontrolü. Kaydetme aşamaları mevcut sunum sayacından gelir. `operationMs`, üretim eyleminin başlangıcından başarı durumunun hazırlanmasına kadardır; son disk yazımı ve ilk sonuç karesinin tamamı değildir. Gateway ve Tarot kendi akışlarında kaldı; yeni doğrudan yanıt süreleri Kimi/doğrudan istemci içindir.

## Aynı koşullarda önce/sonra

Windows üzerinde Flutter test motoru, dört yapay örnek; V118 başlangıcı ve düzeltme sırayla çalıştırıldı. Bu rakamlar telefon veya canlı AI ölçümü değildir. İlk sütun o alt işlemin ilk örneğidir; uygulamanın temiz açılış süresi değildir. Ham değerler [measurements.json](measurements.json) içinde.

| Yerel işlem | Önce | Sonra |
| --- | --- | --- |
| Tek kayıtlı yanıtı açma, ilk örnek | 12,6 ms | 4,1 ms |
| Aynı işlem, sonraki üç örnek | 19,3–20,8 ms | 1,3–1,5 ms |
| Aynı oturumda 100 eski yanıtı açma, stres örneği | 1,58–1,76 sn | 1,0–1,2 ms |
| Kayıt özetini hazırlama, ilk örnek | 47,7 ms | 34,0 ms |
| Değişmeyen kayıt özetine tekrar erişme | 46,0–47,2 ms | 1 ms altında |
| Hazır analizi tekrar hazırlama | 99,0–103,2 ms | 1 ms altında |

İlk ham inceleme taraması 56,4 → 62,9 ms oldu: güvenli çözüm önbelleği ilk oluşturmada ek maliyet getiriyor. Sonraki taramalar 45,6–48,5 → 30,8–33,5 ms. Bu nedenle her ilk işlemin hızlandığı iddia edilmiyor. Trace ve analiz zaten kısmen paraleldi; yeni paralelleştirme kazanımı yazılmadı.

Ölçüm senaryolarındaki dört örnek de tamamlandı. Örneklem küçüktür; yüzde, yüzdelik gecikme veya gerçek servis başarısızlık oranı çıkarılmadı. Hazır analiz senaryosunun ilk analizi yapay yerel motorla kurulup zamanlamanın dışında bırakıldı; bu bir AI üretim hızı sonucu değildir.

## Kontroller

**207 regresyon testi geçti; Flutter analizi temiz; diff biçim kontrolü temiz.** [Kontrol kaydı](validation.json).

Testler Kahve/Tarot tekrar girişini, detaydan dönüşü, filtre/kaydırmayı, eşzamanlı okumayı, okuma sırasında silme/güncelleme yarışını, konu/yıldız değişimini, oturum/depo değişimini, kaynak değişince yeniden hazırlığı ve aynı fal için yeni çağrı oluşmamasını kapsıyor. İptal/HTTP bağlantı kapatma, AI deposu hatasında kurtarma, bağlı kayıtları koruma, geçmiş revizyon bozulması, fotoğraf kapıları, kalite/düzeltme bütçesi ve ilgili arayüz testleri de geçti. Aynı boyut ve eski tarih korunarak bozulan tarihsel dosya reddediliyor.

Model, prompt/kelime hedefi, 1800 token sınırı, kalite kontrolleri, deneme/zaman bütçeleri, animasyonlar, metinler ve tasarım değiştirilmedi. APK boyutu, eğitim, reklam/ödeme, iOS ve üretime dağıtım kapsamına girilmedi.

## Değişen dosyalar

- Fal: `lib/src/ai/ai_store.dart`, `ai_pages.dart`, `ai_client.dart`; `lib/src/mvp/review_store.dart`, `review_controller.dart`.
- Kayıtlar: `lib/src/local_revision_cache.dart`, `local_store.dart`, `record_summary.dart`, `contribution_home.dart`, `contribution_design.dart`; `lib/src/tarot/tarot_store.dart`, `tarot_runtime.dart`, `tarot_pages.dart`.
- Yeni kontroller: `test/local_revision_cache_test.dart`, `reading_snapshot_test.dart`, `verified_review_cache_test.dart`, `records_revisit_test.dart`, `generation_timing_test.dart`, `local_performance_probe_test.dart`. Mevcut AI/özet/inceleme testleri yeni davranış ve isteğe bağlı ölçüm geri çağrısıyla güncellendi.

## Açık kalan gerçek ölçüm

Kaynakta hazır Kimi profili doğrudan Moonshot yolunu kullanıyor; Kimi Instant düşünme kapatma davranışı zaten mevcut ve korundu. Telefondaki etkin profil/bağlantı, servis kuyruğu, ilk gerçek yanıt ve kalite düzeltmesi ihtiyacı okunmadı. 34 dakikalık gateway sınırı bu doğrudan yolun ölçülmüş beklemesi olarak yorumlanmadı.

Ayrı onay için somut canlı ölçüm hazır: `test/service_latency_probe_test.dart`. Yalnız kişisel veri içermeyen tek genel bağlamla, mevcut model/prompt üzerinden **en fazla iki ücretli istek** gönderir; örnek başına tek ilk yanıt ölçer. Kalite reddini sonuç koduyla kaydeder, uygulamanın kalite kurallarını değiştirmez. Yanıt metnini veya anahtarı kaydetmez; yalnız sayısal süre ve güvenli sonuç kodu yazar. Varsayılan olarak kapalıdır; kapalı çalıştırmada atlandı ve hiçbir servis çağrısı yapılmadı. Bu iki servis örneği telefonun toplam süresi veya model kalitesi için yeterli kabul edilmeyecektir. Telefon kurulumu ayrıca yetkilendirilmelidir.

Ekran durumunu tam sayfaları tutmadan saklamak için Flutter'ın [PageStorage](https://api.flutter.dev/flutter/widgets/PageStorage-class.html) ve [keepScrollOffset](https://api.flutter.dev/flutter/widgets/ScrollController/keepScrollOffset.html) sözleşmeleri esas alındı.
