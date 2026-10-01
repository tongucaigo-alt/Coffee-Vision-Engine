# Atlas — Kimi yerel test APK'sı

Kullanıcının isteğiyle en son yerel Atlas kurulumu, önceki gömülü Kimi test bağlantısını kullanır. Bu paket Google Play dağıtımı değildir.

- `ATLAS_KIMI_LOCAL_TEST=true` ve `ATLAS_AI_LAB=true`: normal Atlas paket kimliğini korur; uygulama adı **Atlas Kimi Test** olur. Kurulu Atlas'ın kayıtları yerinde kalır.
- Model, sunucu, düşünmesiz kullanım ve okunabilir yanıtı gösterme davranışı mevcut `ai_bundled.dart` / laboratuvar yolundan gelir; yeni bir fal üretim yolu eklenmez.
- Hazır Kimi profili ilk sıraya yerleşir. Önceki Atlas sunucu profili veya kayıtlı geçmiş silinmez. Otomatik sağlayıcı geçişi yoktur.
- API anahtarı yalnız bilgisayardaki özel `kimi-test-defines.json` dosyasından derlemeye alınır. Kaynaklara, profil JSON'una, araştırma ZIP'ine veya Git'e yazılmaz. Test APK'sı anahtarı içerir; uygulama arayüzü anahtarı göstermez. APK içinden çıkarılamayacağı iddia edilmez.
- `ATLAS_PLAY_TEST=true` ile bu bayrak veya gömülü anahtar birlikte kullanılamaz; derleme durdurulur. Anahtarsız Play çıktıları ayrı tutulur.
- `ATLAS_KIMI_LOCAL_TEST` verilmezse mevcut laboratuvar paketi `.beta` kimliğini kullanmaya devam eder. `.diagnostic` ayrımı korunur.
- Fotoğraf kontrolündeki R8 düzeltmesi, mevcut kamera, işaretleme, kayıt ve manuel saklama davranışı bu sürümde de bulunur.

İlk çıktı: `build/atlas-kimi-test-v18.apk`, sürüm `1.0.0-kimi-test.18`. Aynı imzayla `tool/install_preserving_data.py` üzerinden kurulur; kaldırma/veri temizleme yapılmaz. Son AAB `atlas-play-test-v17.aab` Kimi anahtarı içermez ve bu test APK'sından farklıdır.

## Kurulum kontrolü

30 Eylül 2026: v18 aynı normal paket kimliği ve imzayla telefona kuruldu. APK SHA256: `52a25654ef2df3c5842d8217325241a94186022133b181f0e2270af9cd000d99`. Kayıtlarım'da üç fincanlı kayıt ve üç fotoğraflı taslak korundu; kayıtlı fal açıldı. Laboratuvar ekranında ilk sırada kilitli “Atlas · Kimi Test / kimi-k2.6” doğrulandı. Sağlayıcının model listesi özel yapılandırmadaki anahtarla başarıyla okundu ve `kimi-k2.6` bulundu. İki hazır bağlantı koruma testi geçti.

Kayıtlı bir falın açılması, o falın bu kurulumda yeniden üretildiği veya kalitesinin kabul edildiği anlamına gelmez. Fal istemi ve kalite politikası bu bağlantı değişikliğinde değiştirilmedi.

## Kimi test v21 — 1 Ekim 2026

`build/atlas-kimi-test-v21.apk` aynı imza ve normal paket kimliğiyle veriler temizlenmeden kuruldu. İki mevcut üç fincanlı kayıt korunarak görüntülendi. Kimi bağlantısı/prompt değişmedi. Yeni yerel fotoğraf kontrolü ek onay penceresi açmadan çalışır; bağımsız ölçüm hedefi geçmediği için kesin engelleme kapalıdır. Ayrıntılar: `PHOTO_SUITABILITY_V4.md`.

SHA256: `0bc0fcdb18a2a28a33ad6816f1897399861f70ea617ce093ad6f5e9c472b96a3`.
