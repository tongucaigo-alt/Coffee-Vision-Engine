# V103 — Kahve ve Tarot arka plan atmosferi

V102 çalışma zamanı kaynakları üzerinden, yerleşim ve akış korunarak beş sahneli ortak dekor katmanı eklendi: kahve ana ekranı, kahve fotoğraf inceleme/işaretleme, fotoğraflı hazırlık, Tarot ana ekranı ve üç kart seçimi.

Kahve için hafif halkalar, buhar, adaçayı dalları ve kehribar noktalar; Tarot için takımyıldızlar, yaylar, altın tozları ve aura kullanılıyor. Zemin #F6EFE2, kart yüzeyi #FBF7EE ve mevcut metin/düğme paleti korundu. Günün Kartı ve diğer ekranlara yeni motif eklenmedi.

`AtlasAtmosphereSurface`, içerik sınırlarını yerleşim sonrasında ölçüyor. Metin, fotoğraf, kart ve kontroller 8dp payla korunuyor. Dekor yerleşim ölçüsüne katılmıyor, dokunmaları ve erişilebilirlik odağını almıyor. Sabit ve hareketli çizimler ayrıldı. Yalnız dekoru boyayan saat; gizli sekme, başka route, arka plan ve hareket azaltmada duruyor. Hareket azaltmada motifler sabit görünür kalıyor.

- Buhar: 9 saniye, en fazla 4dp yükselme.
- Yapraklar: 12 saniye, en fazla ±1dp / ±0,6°.
- Üç yıldız: 12 saniyede sırayla üçer saniye yumuşak parlama.
- Aura: 10 saniye, ana ekranda %18–25 / destede %12–19.
- V101'in kart aurası, ışık yönlendirmesi ve dönüşleri korundu.
- Yeni paket, görsel varlık, veri modeli veya API değişikliği yok.

## Doğrulama

205 ilgili test geçti; bir isteğe bağlı açılış videosu önizleme üretim testi atlandı. Kod analizi temiz. Altı ekranın 360×700, 412×700 ve 412×892 boyutlarında normal/iki kat yazıyla 36 önce/sonra ölçümünde ön plan sınırları aynı. Hareket sırasında da ölçüler değişmedi. Dekorun dokunma geçirgenliği, ön planı yeniden oluşturmaması, durma/yeniden başlama ve kaydırmayla geometri güncellemesi test edildi.

V103 ayrı tanılama APK'sı V102 ile aynı imzaya sahip. Mevcut 126 varlık ve 30 yerel kütüphane değişmedi. Önceden bulunan Play hazırlık dosyaları korundu. Kamera/OpenCV, AI, kayıtlar ve açılış videosuna müdahale edilmedi.

Teslim klasörü: `C:/Users/exzau/Documents/Codex/2026-10-26/atlas-atmosphere-v103-output`.

Klasörde APK, üç adet 12 saniyelik Flutter önizlemesi, 36 önce/sonra görüntü çifti, HTML galeri ve ayrıntılı `V103_DOGRULAMA.md` bulunur. Önizlemeler gerçek cihaz kaydı değildir. Fiziksel cihaz performansı henüz ölçülmedi. Ücretli AI çağrısı, telefon kurulumu ve GitHub yayını yapılmadı; bu iki teslim işlemi ayrıca istendiğinde gerçekleştirilecek.
