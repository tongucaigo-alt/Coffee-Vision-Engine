# Atlas — Yalnız arayüz geliştirme kuralları

## Amaç ve çalışma temeli

1 Ekim 2026: çalışan Kimi test v21 üzerine yalnız görsel iyileştirmeler yapılacak.
Uygulama yeniden yazılmayacak, HTML/WebView prototipiyle değiştirilmeyecek.
Depo: https://github.com/tongucaigo-alt/Coffee-Vision-Engine
Dal: `feat/atlas-contribution-beta-v1`. Eski geri dönüş etiketi:
`temel-parca-arayuz-prototip-beta10`; yeni temel: `atlas-kimi-v21-ui-baseline`.
Yerel proje: `C:/Users/exzau/OneDrive/Belgeler/Atlas Katki Beta`.
Flutter uygulaması: `atlas_contribution_app`.

Önce Git durumu, bu belge ve mevcut ekranlar okunmalı. Uzak sürümle yerel
değişiklikler karşılaştırılmalı; reset, clean veya toplu eski sürüme dönüş yapılmamalı.
Yeni chat ilk olarak görsel önerileri hazırlamalı; kullanıcı tasarım yönünü
belirtmeden dosyaları değiştirmemeli. Sonraki açık UI uygulama istekleri bu sınırlar
içinde uygulanabilir.

## Değiştirilemeyecek kullanıcı akışı

Fincanını Tara → Serbest açı → Kulp sağda → Kulp solda → isteğe bağlı tabak →
önizleme → işaretleme veya atlama → Kaydet ve Falını Oluştur → sonuç.

- Ana kamera düğmesi taslak varken de görünür. Devam kartı ve mevcut taslağı
  koruyan devam/yeni çekim/vazgeç seçenekleri kaybolamaz.
- Galeriden 1–3 fincan ve en fazla bir tabak aynı kayıt akışına katılır.
- Tabaksız devam, yeniden çekme/değiştirme/kaldırma korunur.
- Aynı fincan beyanı korunur; kullanıcı adına işaretlenmez. Fotoğraf başına
  kaldırılmış kullanılabilirlik tikleri geri getirilmez.
- İşaretleme isteğe bağlıdır; %15 kutu, taşıma, köşe boyutlandırma, iki parmak
  yakınlaştırma, 20 etiket ve fotoğraf başına 10 kutu sınırı korunur.
- İşaretleri Gözden Geçir, Kaydet ve Falını Oluştur, Yalnız Kaydet erişilebilir kalır.
- Kayıtlarım, mevcut falı okuma, 20 yıldız, yalnız manuel silme, araştırma izni ve
  izinli ZIP korunur. Otomatik silme veya yeni kredi/üyelik/ödeme sistemi eklenmez.
- Ana gezinme Ana Sayfa / Kayıtlarım / Ayarlar. Kamera ve işaretleme tam ekrandır.

## Görsel çalışma sınırı

Renk, tipografi, ikon, yüzey, kenarlık, boşluk, hizalama ve işlevi değiştirmeyen
hafif animasyonlar düzenlenebilir. Eylem isimlerinin anlamı korunmalıdır.
Krem #FAF7F2, kahverengi #2C1810, yeşil #4A7C59 mevcut temeldir; yeni görsel yön
kullanıcıyla netleştirilir. Yerel logo/font dosyaları kullanılmalı, internet bağımlılığı
eklenmemeli. Küçük ekran, büyük yazı, ekran çentiği ve azaltılmış hareket desteklenmeli.
Dokunma hedefleri en az 48 mantıksal piksel olmalı; önemli eylemler gizlenmemeli.

Kamera yuvarlak alanı, yeşil noktalar, buzlanma, kulp çizgileri, eşikler, odak ve
kırpma hesabı değiştirilemez. Kamera önizlemesinin geometrisini değiştiren padding,
kart veya ölçek uygulanamaz. `coffee_camera` ve motor paketleri değiştirilmez.

Controller, repository/store, model, platform kanalı, kayıt şeması, koordinat,
checksum, ilk gözlem, araştırma izni, fotoğraf uygunluk kuralı, AI promptu, istek,
sağlayıcı, kuyruk, anahtar yönetimi ve Node servisi UI çalışmasının dışındadır.
Görünüm dosyaları iş mantığı da içerir: dosyanın UI adı taşıması tüm içeriğini
değiştirme yetkisi vermez. Callback bağlantıları, koşullar, gezinme ve işlem sırası
korunur. Gerekli görülen işlev değişikliği önce kullanıcıya ayrı açıklanır.

Teknik açıklamalar ana akışa geri eklenmez. Sahte başarı, rastgele sembol,
sahte yüzde, yapay bekletme veya otomatik ücretli tekrar eklenmez.
Kullanıcı verileri, izinleri ve cihaz uygulamaları silinmez. Git push, kurulum ve
yayın ayrı açık kullanıcı isteği olmadan yapılmaz. Anahtar ve imza dosyaları
okunup çıktıya basılmaz; kaynak/Git içine eklenmez.

## Mevcut durum ve dürüst kabul

Kullanıcı v21'de üç fincan çekti, işaretleme yapmadan fal oluşturdu ve falı beğendi.
Kimi bağlantısı ve anlatım ayarları korunacak. Bu tek olumlu deneme genel kalite
garantisi değildir. Fotoğraf ayrımı %80 hedefini geçmedi; kesin engelleme kapalı,
deneysel uyarı aktiftir. UI çalışması bunu düzeltmiş veya tamamlanmış gibi sunamaz.
`atlas_contribution_app/PHOTO_SUITABILITY_V4.md`, `KIMI_LOCAL_TEST.md` ve mevcut
Play belgeleri okunmalı. Kimi test APK'sı Play yayın paketi olarak sunulmamalı.

## Her görsel teslimin kontrolü

Önce değişecek ekranlar ve görsel fark açıklanır. Küçük, incelenebilir değişiklikler
yapılır. İlgili widget/akış testleri ve Flutter analyze çalıştırılır. Önce/sonra
gerçek ekran görüntüleri incelenir; test geçsin diye işlev beklentileri gevşetilmez.
Kamera düğmesi, üç açı, galeri, tabak, atlama, işaretlere geri dönüş, kayıt/fal,
hata/yeniden deneme ve mevcut kayıtlar görünür kalmalıdır.
Görsel test ile gerçek kamera testinin farkı açıkça raporlanır. Taklit kamera testi
gerçek yeşil noktaları/kulp çizgilerini kanıtlamaz. Cihaz testi gerekirse aynı imza
ve artan sürümle veri koruyan güncelleme yapılır; uninstall/clear kullanılmaz.
