# Zengin fal girdisi ve tarama — 27 Eylül 2026

## Uygulanan davranış

- `atlas-fortune-context-v2`, mevcut genel ölçümlere sürümlü bölge özetini ekler.
  Altı analiz bandı iki ayrı eksendir; örtüşen alanlar toplanmaz. Sınırdaki
  bileşenler ve telvenin %1'inden küçük bileşenler aday listesine alınmaz.
  En büyük üç aday ve aralarındaki mevcut seçilmiş geometrik ilişkiler aktarılır.
- `atlas-regional-summary-v1` yalnız public `VisionFeatureSet` çıktısının
  projeksiyonudur. Kamera, eşikler, motor hesapları veya sembol sözlüğü değişmez.
- Kullanıcı gözlemleri ve fiziksel bulgular ayrıdır. Fal üretirken eski kayıtlar
  gerektikçe zenginleştirilir; ilk gözlemler ve eski fallar yeniden yazılmaz.
- Son beş başarılı sonuç, yerel konu/akış/kapanış seçimini etkiler. Başarısız
  isteğin tekrarında ve A/B çiftinde anlatı taslağı korunur. Geçmiş metinler
  sağlayıcıya gönderilmez; tekrar düzeltmesinde yalnız genel gerekçe gönderilir.
- Ortak prompt sürümü `atlas-fortune-prompt-v4`. Geçerli yeni sonuçlar dört
  paragraf ve 250–400 kelimedir. Desteklenen kısa fiziksel ifadeler dışında
  görsel sahne iddiası, sembol yokluğu veya kesin gelecek iddiası reddedilir.
- `Kaydet ve Falını Oluştur` önce kaydı/ilk gözlemi kalıcılaştırır. `Yalnız
  Kaydet` AI çağırmaz. Bağlantı yokken yalnız kayıt kullanılabilir.
- Tarama gerçek fotoğrafları ve kullanıcı kutularını gösterir. Kayıt, gerçek
  yerel analiz, kuyruk, üretim ve düzeltme ayrı durumlardır. Hazır analiz
  yeniden taranmış gibi gösterilmez. Hareket azaltma desteklenir.

## Servis uyumu

Gateway ve APK birlikte güncellenmelidir. Capabilities yanıtında desteklenen
context sürümleri ve `clientRepetitionRepair` ilan edilir. Yeni istemci eski
servise sessizce v1 veri göndermez; uyumsuzluğu açıklar.

`POST /api/ai/v1/jobs/:id` yalnız `{ "reason": "repetition" }` kabul eder.
Bu işlem, ilk denemede tamamlanan kendi işini bir kez düzeltmek içindir.
Tekrar gönderim aynı işi kullanır. Kalite düzeltmesi zaten yapılmışsa ikinci
bir düzeltme açılmaz. Kapasite, sahiplik ve toplam 180 saniyelik üretim sınırı
korunur. Servis yapılandırmasına yeni model adresi veya anahtar eklenmez.

## Kanıtlar ve sınırlar

- Uygulama testleri: **229 geçti**, ücretli canlı test varsayılan çalışmada
  atlandı (`build/rich-tests.log`).
- Dart analiz: **sorun yok** (`build/rich-analyze.log`).
- Node testleri: **17 geçti** (`build/rich-node-tests.log`).
- Samsung R5GL329BC0N üzerinde **13 diagnostic test geçti**
  (`build/rich-device-tests.log`). İki gerçek Android ZIP'i bilgisayara çekilip
  dosya checksum'ları doğrulandı (`build/rich-validation`).
- Ortak bölgesel dil örnekleri: gateway `regional-quality-cases.json`.
- Üç canlı yapay Kimi denemesinin kayıtları:
  `build/rich-kimi-first-validation.json`, `build/rich-kimi-second-validation.json`,
  `build/rich-kimi-final-validation.json`. Bunlar API anahtarı içermez.

Son canlı denemede işaretli örnek, tek düzeltmede 268 kelimeyle geçti.
İşaretsiz örnek 144 ve 206 kelime ürettiği için iki denemede de reddedildi.
İlk iki denemedeki başarısız sonuçlar da saklandı. Bu nedenle modelin uzunluk
uyumu veya genel anlatım kalitesi doğrulanmış kabul edilmez. Yapay örnekler,
12 gerçek fincanlık kör içerik kabulünün yerine geçmez.
Elle okumada işaretli sonuçta da soyut bekleyiş/nefes anlatımı baskındır;
otomatik kontrolden geçmesi kullanıcı açısından kalite kabulü sayılmaz.

## Beta güncellemesi

`build/atlas-rich-fortune-beta-release.apk`: `.beta`, versionCode **6**.
SHA-256: `BC87FF33BBFD030A1FC79406FB4B7A865AFF613E746186D6CA2E0DCFB6C5E6D6`.
Founder sertifikası önceki sürümle eşleşti:
`9817a87150d98b0fa5b573ec371700133e2861fe41f6d70c4064381d0bcec9b4`.

27 Eylül'de `adb install -r` başarılı oldu; paket kaldırılmadı ve veri temizliği
yapılmadı. Kurulum öncesinde Kayıtlarım'da yalnız sıfır fotoğraflı taslak
görünüyordu. Kurulum sonrasında aynı taslak korundu. Tamamlanmış kullanıcı
kaydı bulunmadığından gerçek eski kaydı açıp fal üretme yürüyüşü yapılamadı.

## Bekleyen kabul

1. Kullanımı uygun, 12 farklı fincan setiyle eski/yeni yöntem karşılaştırması.
   Altı işaretli ve altı işaretsiz örnek; aynı model/ayarlar; tüm başarısız
   yanıtlar dahil tutulmalı. Fincana bağ, tekrar ve bütünlük ayrı puanlanmalı.
   Yeni yöntem en az sekiz sette tercih edilmeden içerik iyileşmesi iddia edilmez.
2. Güncellenmiş beta üzerinde gerçek fotoğrafla kayıt–fal yürüyüşü.
   Kullanıcının yaş/araştırma izinleri onun adına işaretlenmez.

Fotoğraf seti klasörü kullanıcıdan bekleniyor. Bu kabul adımları tamamlanmadan
bu belge tam teslim onayı değildir. Diagnostic testini yeniden çalıştırmak için:
`../atlas_ai_gateway/tool/test-device.ps1 -Device <serial> -RichFortune`.
