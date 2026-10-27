# V107 — Parşömen üzerinde görünür sıcak ışık

V106'da ortak zemin koyulaşınca Kahve/Tarot ana ekranlarındaki düşük yoğunluklu bal/şampanya halesi neredeyse görünmez kaldı. Sadece ana ekran haleleri, görselin dışına yayılan #FFF4DC sıcak ışıkla düzeltildi. Parlak kısmın opak logonun arkasında kaybolması azaltıldı. Kahve sabit, Tarot mevcut yavaş nefes hareketini koruyor.

Tek kaynak değişikliği `atlas_contribution_app/lib/src/atlas_atmosphere.dart`. #EFE1C8 zemin ve #FBF7EE kartlar; logo, fotoğraf, kart, metin ve tuş ölçüleri; çekirdek/yıldızlar; diğer ekranlar ve üç kart aurası korunuyor. Kamera/OpenCV, AI, veri/kayıt ve açılış davranışı değişmedi.

54 ilgili test geçti, kod analizi temiz. 36 ekranın ön plan sınırları V106 ile karşılaştırıldı. Kahve/Tarot logo çevresindeki piksel parlaklığının arttığı ve temel zemin renginin aynı kaldığı doğrulandı.

Teslim: `C:/Users/exzau/Documents/Codex/2026-10-27/atlas-halo-v107-output` — APK, karşılaştırmalı galeri, rapor ve ekranlar. V106 telefon görüntüsü bulguyu belgelemek için alındı; V107 görüntüleri Flutter çizimleridir. Bu tur telefon kurulumu, GitHub paylaşımı ve ücretli AI çağrısı yapılmadı.
