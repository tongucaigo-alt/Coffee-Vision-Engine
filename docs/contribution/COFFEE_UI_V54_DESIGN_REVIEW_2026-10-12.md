# V54 kahve arayüzü — tasarım incelemesi

Tarih: 12 Ekim 2026.

İnceleme kullanıcının gönderdiği galeri hata görüntüsü, mevcut V54 telefon testi ekran görüntüleri, normal/iki kat yazı tanılama görüntüleri ve arayüz kaynak kodu üzerinden yapıldı. Bu incelemede telefonda yeni işlem yapılmadı; çalışma kodu değiştirilmedi. Görsel değerlendirmeler kullanıcı testi sonucu değil, tasarım incelemesi bulgularıdır.

Korunacak tercihler: ana kahve sayfalarında dikey kaydırma olmaması, fotoğrafın ön planda olması, fotoğraf üzerindeki Taşı/İşaret kontrolleri, küçük sembollerle açılır seçim penceresi, krem/kahve/yumuşak yeşil palet. Tarot kapsam dışıdır. Fal sonucu kaydırılabilir kalır; mevcut düzenine müdahale kararı alınmadı.

## Ertelenen akış hatası: galeriye giriş engeli

Kullanıcı galeriden fotoğraf seçmeye çalışınca boş Fotoğraflarına Bak ekranında sürekli “Önce mevcut çalışmanı tamamla veya taslağı sil.” uyarısını görüyor; ilerleme ve kayıt düğmeleri pasif, Çekime Devam Et görünür durumda.

Kaynak kodunda `lib/src/photo_set_flow.dart` içindeki `_startSetGallery`, `_draft != null` olduğunda galeriyi açmadan mevcut akışı gösterip bu uyarıyı veriyor. Fotoğrafı olmayan taslaklar da bu koşula giriyor. Kullanıcının taslağı hangi işlemle oluşturduğu veya hangi iptal/geri dönüş dizisinin bu duruma yol açtığı bu incelemede yeniden üretilmedi; tam tetikleme sırası ayrıca doğrulanmalı.

Kullanıcı bu hatanın daha sonra düzeltilmesini istedi. Şimdilik düzeltme yapılmadı. Düzeltmede boş taslak, kameradan galeriye geçiş ve galeri iptali/yeniden deneme durumları ele alınmalı; mevcut fotoğraflar ve kayıtlar korunmalı. Taslağı otomatik silmek varsayılan çözüm olarak kabul edilmedi.

## Öncelik sırasıyla tasarım bulguları

1. **Yüksek — Boş fotoğraf ekranı yol göstermiyor.** Büyük boş alandaki fincan simgesi, henüz fotoğraf olmadığı bilgisini ve sonraki işlemi açıklamıyor. Uyarı mesajı doğrudan uygulanabilir bir seçenek sunmuyor. Boş durum açıklaması ve mevcut durumdan çıkış işlemleri görünür olmalı.
2. **Yüksek — Fotoğraf araçlarının anlamı belirsiz.** Yenileme simgesi fotoğraf değiştirme, artı simgesi tabak ekleme, eksi simgesi fotoğraf kaldırma için kullanılıyor. Çöp simgesi tüm taslağı siliyor. Gezinme düğmelerine ek olarak sıralama okları bulunuyor. Kısa etiketlerle amaç açıklanmalı; tek fotoğraf kaldırma ile taslak silme kapsamı daha açık ayrılmalı.
3. **Yüksek — Geç ve Atla ayrımı görünür değil.** Sen ne görüyorsun ekranında Geç mevcut fotoğrafın kararını, Atla kalanları atlamayı ifade ediyor. Atla'nın kapsamı yalnız araç ipucunda açıklanıyor. Göremedim ve Emin değilim ile birlikte dört benzer çıkış yolu oluşuyor. Kullanıcı işlem kapsamını basmadan anlayabilmeli.
4. **Yüksek — İki kat yazıda kelimeler parçalanıyor.** Üç fotoğraflı tabak adımı görüntüsünde Önceki sözcüğünün son harfi ve Sonraki oku ayrı satıra düşüyor. Görsel taşma olmaması tek başına okunabilirlik sağlamıyor. Büyük yazıda sözcük bütünlüğünü koruyan gezinme düzeni gerekli.
5. **Orta — Fotoğraf üzerindeki kontrol zeminleri ağır.** Taşı/İşaret ve yakınlaştırma gruplarının açık renkli panelleri fotoğraf üzerinde belirgin yer kaplıyor. Dokunma alanını en az 48 piksel koruyup görünen zemin/padding daha hafif yapılabilir. Konum fotoğraf ve işaretlerle çakışmamalı.
6. **Orta — Çok işarette isimler birbirini örtüyor.** On işaretli tanılama görüntülerinde isim kutuları üst üste geliyor; Taşı/İşaret panelinin altında kalan etiketler var. Bu görüntüler yapay yoğunluk senaryosudur. Seçili etiketi vurgulama ve diğer etiketleri çakışmayacak biçimde gösterme yaklaşımı değerlendirilmeli; kutular ve isimlere erişim korunmalı.
7. **Orta — Seçilen şekil ile düzenleme işlemlerinin bağı zayıf.** Seçili şekil şeridin solundayken Değiştir/Kaldır ayrı satırın sağında kalıyor. İsim, seçili durum ve işlemler daha yakın gruplanmalı. Yatay şeritte toplam seçim sayısı veya devam göstergesi de keşfedilebilirliği artırabilir.
8. **Orta — Açı bilgisi tekrarlanıyor.** Fincan · Açı belirtilmedi metni ile hemen altındaki açı alanı aynı bilgiyi tekrar ediyor. Özellikle büyük yazıda fotoğrafın alanını daraltıyor. Boş açı durumu daha doğal bir yönlendirmeyle, tek yerde gösterilebilir.
9. **Orta — Adımların amacı ve pasif düğmelerin nedeni yeterince açık değil.** Çekime Devam Et, Bu fotoğraflarla devam et ve Şekilleri Seç aynı yerde farklı anlamlarda ilerleme sunuyor. Aynı fincan onayı gibi ön koşullar düğmeyle daha açık ilişkilendirilmeli. Kısa adım adı ve eksik koşul mesajı değerlendirilmeli.
10. **Düşük — Sembol penceresinde hiyerarşi dengesiz.** Sembol görselleri küçülmüş, fakat pencere başlığı güçlü ve alt bölümde geniş boşluk var. Tümü kategorisi ile Diğer şekiller benzer erişim sunuyor. Pencere kalmalı; başlık, boşluklar ve tekrarlayan girişler sadeleştirilebilir.
11. **Düşük — Ana sayfanın görsel ağırlığı üstte toplanıyor.** Logo hem başlıkta hem büyük kartta tekrar ediyor. Galeri ve kamera iki farklı düğme biçimiyle sunuluyor; karttaki sıcak turunculu büyük görsel yumuşak palete göre baskın. Küçük ▶ simgesinin dairesi de simgenin kendisinden daha çok dikkat çekiyor. Tek ekran yapısını koruyarak ağırlık ve düğme tutarlılığı ayarlanabilir.

## Kanıt görüntüleri

V54 ekran görüntüsü klasörü: `C:/Users/exzau/Documents/Codex/2026-10-11/atlas-opencv-v49/outputs/coffee-ui-v54/screenshots/`.

- `preview-3-1.png`: araç simgeleri, tekrar eden açı bilgisi, aynı fincan onayı ve pasif ilerleme.
- `annotation-1-1.png`: fotoğraf üzerindeki kontroller, Göremedim/Emin değilim/Geç ve Atla.
- `many-symbols-1.png`, `many-symbols-2.png`: çok işarette etiket çakışması ve seçim/düzenleme ilişkisi. Yapay tanılama senaryosu; arka plandaki düz renk bir fotoğraf yükleme hatası bulgusu sayılmadı.
- `saucer-step-3-2.png`: iki kat yazıda kelime ve ok bölünmesi.
- `picker-1-1.png`: sembol penceresi hiyerarşisi ve boşluklar.
- `installed-v54-home-final.png`, `installed-v54-resume.png`: ana sayfa ve köşedeki devam simgesi.

Telefon testinde bazı fotoğraflar eski uygulama ekran görüntüsü içeriyor. Bu fotoğrafların içindeki eski arayüz, V54'ün güncel kontrol düzeni olarak değerlendirilmedi.
