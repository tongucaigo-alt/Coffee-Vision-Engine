# Atlas V121 — otomatik çekimde kısa kesintilere tolerans

2 Kasım 2026. V120 üzerine otomatik çekim rahatlığı düzenlendi. Bu kaynak kaydı, GitHub'daki V118 görsel kararını, V119/V120 yerel performans düzeltmelerini ve V121 otomatik çekim değişikliğini birlikte korur. Ana dal ve mevcut çalışma ağaçları değiştirilmedi.

## Kamera davranışı

1,2 saniyelik uygun görüntü toplamı korunur. Kısa hareket, kadraj/açı veya sınırdaki ışık/netlik dalgalanmalarında en fazla 500 ms duraklanır. Uygunsuz aralık ve normale dönen ilk kareye kadar geçen süre sayılmaz. Uzun kesinti, belirgin bulanıklık/karanlık, fincan/telve kaybı veya ekran kenarında kesilme birikimi sıfırlar.

Çekim anında güncel bir analizde bütün normal kalite koşulları sağlanmalıdır. Duraklama ışık/netlik sınıflandırmasındaki %90 marj, fotoğraf kabul eşiğini düşürmez. Eski/aynı kare, 750 ms güncellik koruması, kapalı otomatik anahtar ve çift çekim engeli korunur.

Yeşil taramanın kalıcı kaybolmasıyla ilgili analiz akışı toparlanması değiştirilmedi. Bu konu gerçek fincanla sonraki kontrol aşamasına bırakıldı. Fincan olmayanları eleyen son fotoğraf filtresi, model/eşikleri, otomatik kanıt sınırları, menüler, hedef, kırpma ve tabak davranışı V120 ile aynı.

## Doğrulama

- 164 kamera testi ve 70 ilgili uygulama testi geçti; iki statik analiz temiz.
- Kısa/uzun hareket, 500/501 ms sınırı, geç geri dönüş, uygunsuz zamanın sayılmaması, eski kare, kapalı anahtar, manuel çekim ve çift tetikleme sınandı.
- Son uygunluk ve gerçek üretim öncesi kapı, kamera kanıtı, fotoğraf değişimi, galeri sınırları, üç açı/onay ve kırpma testleri geçti.
- Testler bilgisayar ve yapay kamera kareleri üzerindedir. Gerçek telveli fincanda rahatlık ve yeşil taramanın devamlılığı henüz doğrulanmadı.

## Telefon güncellemesi

Aynı paket ve imzayla V120 → V121, yalnız `install_preserving_data.py` üzerinden `adb install -r` kullanılarak kuruldu. Özel yerel yedek açılarak dosya özetleri doğrulandı. Uygulama açılmadan önce 648/648 dosya aynıydı; açılış sonrasında kullanıcı dosyalarında fark yoktu. İlk kurulum tarihi ve ayrı normal Atlas paketi korundu. Açılış ve Kahve ana ekranı kontrol edildi; fatal/işlenmeyen hata görülmedi.

141 varlık ve 30 native kütüphane aynı. APK SHA-256: `51c839e9ffdb23b11d578f2aead6205d00abb3dd590ae9f5f613f5e6f9efa3ff`. Bu özet APK'yı veya derleme anahtarını yayımlamaz. APK ve telefon yedeği yalnız özel yerel konumda tutulur. Gerçek fotoğraf yüklemesi veya ajan tarafından ücretli AI üretimi yapılmadı.

## Kaynak ve derleme

V120 uygulama tabanı `5d925c1` (çalışan uygulama kaynak commit'i `449afb9`, sonraki commit yalnız sonuç belgeleri). V121 değişikliği kardeş `coffee_camera` paketinde otomatik süre/sınıflandırma ve testlerle sınırlıdır. Uygulama kaynakları V120 ile aynıdır. V120 gateway sözleşmesi bu kaynak yedeğine dahildir; çalışan sunucuya dağıtım yapılmadı.

Yerel test derlemesi: hedef `atlas_contribution_app/lib/offline_main.dart`, debug, `--build-number=121`, `--build-name=1.0.0-kimi-test.121`; V120'nin `ATLAS_AI_LAB`, `ATLAS_DIAGNOSTIC`, `ATLAS_IMAGE_SCREEN` bayrakları korunur. Özel derleme değerleri depoya konulmaz. Bu kayıt mağaza dağıtımı veya modelin önceki bağımsız kabul hedeflerinin geçtiği iddiası değildir.

Yapılandırılmış doğrulama: [validation.json](validation.json). Önceki performans gerekçeleri: [V120 sonuçları](../../../atlas_contribution_app/docs/performance-v120/SONUC.md).
