# Atlas gizlilik açıklaması — yayımlanmamış taslak

24 Ekim 2026. Bu belge güncel yerel kahve/Tarot ve bildirim akışlarının teknik açıklamasıdır; yayımlanmış nihai gizlilik politikası veya mağaza kabulü değildir. Araştırma ZIP dışa aktarımı kaldırılmıştır ve yeniden eklenmez. Yedi günlük silme politikası uygulanmıyor.

## Yayından önce gereken gerçek bilgiler

İşletmeci/şirket adı, geçerli destek iletişimi, kamuya açık HTTPS gizlilik adresi, kullanılan gerçek AI/gateway sağlayıcıları ve bunların saklama koşulları henüz doğrulanmış yayın bilgileri değildir. Kullanıcının talebiyle `xxxx@atlas.com` destek sayfasına açıkça taslak ve henüz etkin değil etiketiyle eklendi; bu örnek adres bağlantı açmaz ve gerçek destek kanalı sayılmaz. İşletmeci bu bilgileri tamamlamalı, SDK/veri güvenliği beyanlarıyla eşleştirmeli ve insan moderasyon sürecini kurmalıdır. Yerel HTTP testleri bu operasyonun kurulduğunu kanıtlamaz.

Uygulama bu herkese açık derleme değerlerini kullanır:

- `ATLAS_OPERATOR_NAME`: gerçek işletmeci/şirket adı.
- `ATLAS_PRIVACY_URL`: kamuya açık, geçerli HTTPS politika adresi.
- `ATLAS_SUPPORT_URL`: gerçek HTTPS destek adresi veya `ATLAS_SUPPORT_EMAIL`: gerçek destek e-postası.

Bu değerler anahtar değildir. Gerçek servis anahtarları bu alanlara veya gizlilik metnine eklenmemelidir. Boş yapılandırmada uygulama yerel gizlilik metnini ve destek/bildirim yönergelerini açar, eksik iletişim bilgisini açıkça belirtir. Geçerli yapılandırmada gerçek HTTPS/iletişim adresi açılır; açılış hatası görünür ve adres kopyalanabilir. Kamuya açık sayfa bu çalışmada yayımlanmadı.

## Cihazda tutulanlar

Fotoğraflar, manuel işaretler, taslaklar, inceleme revizyonları, yorumlar, yıldızlar, konu tercihleri ve hafıza seçimi bilgisi cihazın özel uygulama alanındadır. Yaş, isteğe bağlı burç/izin ve hitap adı Bilgilerim alanında saklanır. Kahve ve Tarot kayıtları için otomatik süre dolumu yoktur; yıldızsız kayıtlar da kendiliğinden silinmez. Kayıtlarım üzerinden silme ve Bilgilerim üzerinden profil temizleme mevcuttur. Yıldız kaldırmak yorumu silmez. İşletim sistemi yedeklerinin yönetimi ayrıca geçerlidir.

## Yorum oluşturmayı seçtiğinde

Kahvede fotoğraf dosyası yerine metinsel analiz özeti ve kullanıcının bildirdiği semboller/konumlar, seçilen konu gönderilir. Yaş doldurulmuşsa yaş; burcu yorumda kullanma seçeneği açıksa burç eklenebilir. Hitap adı gönderilmez. Hafıza, uygun bir yıldızlı eski yorumdan kısa bir parçayı yeni isteğe ekleyebilir; bu seçim için ek AI çağrısı yapılmaz.

Tarot'ta seçilen kartların kimliği/adı, pozisyonları, düz/ters yönleri ve o yöne ait temalar ile açılım türü gönderilir. Deste görselleri, seçilmeyen kartlar ve yerel ruh hâli tercihi bu istekte bulunmaz. Kart seçimi çevrimdışıdır.

Play test bağlantısı Atlas gateway'e, laboratuvarın doğrudan bağlantısı seçilen sağlayıcıya gider. Gateway Tarot'u ayrı Tarot bağlamı/prompt'u ile işler; kahve isteği gibi sunmaz. Gerçek sağlayıcı, barındırma ve bağlantı koşulları nihai politikada belirtilmelidir. Mevcut gateway iş bağlamlarını bellekte tutar; varsayılan bakım, bitmiş işleri 30 dakikalık bekleme sonrasında temizler ve bu ayar değişebilir. Bu, tüm uzaktaki sistemlerin kesin silme garantisi değildir. Önceki yerel bilgisayar/tünel kurulumu nihai üretim altyapısı varsayılmaz.

## İçerik bildirimi

Kahve ve Tarot yorumundaki aynı uygulama içi bildirim eylemi kullanılır. Doğrudan sağlayıcı bir moderasyon sunucusu sayılmaz; ayrıca yapılandırılmış Atlas bağlantısı gerekir. Göndermeden önce alıcı host, yorum metni ve neden kullanıcıya gösterilir ve onay alınır.

Tel üzerinden yalnız `version`, `id`, `reason`, `text` gönderilir. Fotoğraf, kart destesi ve profil alanları ayrıca eklenmez; yorumun kendi metni kişisel ifadeler içerebilir. İletilemeyen rapor yerelde bekler; ağ/disk hatası başarı gibi gösterilmez. Sunucu, yetkili test kullanıcısı bağlamında kalıcı kayıt tamamlandıktan sonra alındı teyidi verir. Tekrar aynı raporu yollamak yeni sunucu dosyası oluşturmaz. Teyitten sonra yerel kuyruktaki metin kaldırılır.

Gateway raporu kimlik/neden/metin ve alınma zamanıyla ayrı kalıcı dosyada tutar; dosya adı yetkili kullanıcı ve rapor kimliğinden türetilen özettir. Bu depoda otomatik saklama süresi yoktur. Nihai saklama, silme talepleri, erişim ve insan moderasyonu gerçek işletmeci tarafından belirlenip yayımlanmalıdır. Telefonda bir kayıt silmek sunucuya gönderilmiş raporu veya sağlayıcı kayıtlarını kendiliğinden silmez.

## İzinler ve amaç

Kamera çekim içindir; galeri sistem seçicisi kullanıcının seçtiği fotoğrafları içe aktarır. Görüntü uygunluk ve şekil analizi yereldir. Mevcut fotoğraf modeli adaydır: bağımsız saha kabulü tamamlanmamıştır. Fotoğrafların araştırmaya gönderildiği veya araştırma ZIP'i üretildiği bir akış yoktur.

Atlas yorumları eğlence ve öz değerlendirme içindir; kesin gelecek veya tıbbi/hukuki/finansal yönlendirme iddiası taşımaz. Uygulamada okunabilen metin `lib/src/privacy_support.dart` içindedir; bu taslak ile aynı veri akışını anlatmalıdır.
