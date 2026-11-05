# Atlas V131 kısa kahve falı

5 Kasım 2026

V131, V130 Android test APK’sı temel alınarak hazırlandı. Telefonda kahve ana ekranının açıldığı ve kurulumdan önceki 773 kayıt dosyasının korunduğu doğrulandı.

- Kahve falı için `atlas-fortune-prompt-v24` ve `atlas-fortune-context-v5` eklendi. Tek kısa ortak prompt kullanılıyor. Aşk, İş, Para ve Genel için ayrı konu satırları var. Konu seçilmediğinde Genel kullanılıyor.
- Kısa fal testinde Kimi K3.1 Pro kullanılıyor. Android test yapısında `ATLAS_AI_LAB` ve `ATLAS_SHORT_FORTUNE_TEST` seçenekleriyle açılıyor. Gateway, V23 ve V24 istemcilerini aynı anda destekliyor.
- İsteğe bağlı hitap adı ve medeni durum kahve falı girdisine eklenebiliyor. Yaş ve medeni durum, uygun olmayan senaryoları elemek için kullanılıyor. İzinli burç bilgisi yaklaşık beş istekte bir gönderiliyor.
- Kullanıcının seçtiği semboller ile uygulamanın rastgele motifi ayrı gönderiliyor. Motif yeniden denemede korunuyor. Telve yoğunluğu ve konumu V24 model girdisinden çıkarıldı.
- V24 için kabul alt sınırı 75 kelime. 90–120 kelime yazım hedefi. Sembolü fincanda görmüş gibi anlatmak ret nedeni. Üretim en fazla iki çağrı ve ortak 180 saniye bütçesiyle çalışıyor.

Yerel uygulama AI istemcisinde dört sentetik fal ilk yanıtta kabul edildi. Süreler yalnız model yanıtını ölçüyor.

| Konu | Kelime | Süre |
|---|---:|---:|
| Genel | 93 | 11,4 sn |
| Aşk | 89 | 12,1 sn |
| İş | 92 | 12,1 sn |
| Para | 84 | 11,9 sn |

Aşk ve Para falları hedefin altında kaldı ve uzunluk uyarısıyla kabul edildi. Dört fal da isimle başladı. Cihaz doğrulaması kurulum, kayıt bütünlüğü ve açılışı kapsıyor.

Bu dal, GitHub’daki V129 dalı üzerine V24 kahve falı kaynaklarını ve yerelde V23 için doğrulanan test örneklerini ekler. Telefonda doğrulanan V131 APK’sı V130 tabanından derlendi.
