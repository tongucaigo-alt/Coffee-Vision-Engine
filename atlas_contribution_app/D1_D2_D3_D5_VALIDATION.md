# Atlas V82 — D1/D2/D3/D5 düzeltmeleri

19 Ekim 2026. Kaynak: `codex/atlas-v82`, HEAD `4010e10` ve önceki ZIP
kaldırma çalışmasının mevcut çalışma ağacı. Önceki değişiklikler korundu.
Kullanıcı bu aşamayı yalnız D1/D2/D3/D5 ile sınırladı; geniş araştırma
ekranı/geçmişi kaldırma maddeleri uygulanmadı.

## Tamamlanan davranışlar

**D1 — Kayıt kurtarma ve silme güvenliği**

- Receipts okuması normal, yedekten kurtarıldı, bulunamadı ve okunamadı
  durumlarını ayrı taşır. Yedekten dönen liste kesin silme listesi sayılmaz.
- Kaynak listede bulunmayan bağlı AI kayıtları açılışta otomatik silinmez.
  Silme yalnız kalıcı, açık silme isteğiyle ilerler.
- Kurtarılmış/okunamayan listede veya bağlı kayıt uyuşmazlığında yazma ve
  sahipsiz fotoğraf temizliği engellenir. Asıl dosya ve yedek yeniden yazılmaz.
- AI kaydı bulunan bir deponun eksik receipts dosyası yeni, boş depo gibi
  kabul edilmez. Eksik kayıtlar uydurulmaz veya otomatik geri yüklenmez.
- AI bağlantısı denetimi yerel AI kullanan depoya uygulanır. Aynı üst
  klasördeki ayrı çevrimiçi katkı deposu bu bağlantıları devralmaz.

**D2 — AI başlangıç hatasında kontrollü erişim**

- AI başlangıç hatası uygulamanın açılmasını engellemez. Kurtarma ekranı
  gösterilebilen fotoğraf ve manuel işaretlere salt okunur erişim sağlar.
- Bu durumda kahve kaydı değiştirme/silme ve üretim kapalıdır. Bozuk AI
  deposu boş veriyle değiştirilmez; okunamayan fallar silinmiş sayılmaz.
- Yeniden Dene aynı depoları yeniden açmayı dener; sıfırlama yapmaz.
  Sorun giderildiğinde normal arayüze dönülür. Tarot bağımsız başlatılır.
- Depolar arası silme callback'i ancak AI başlangıcı tamamen başarılı
  olduğunda yayımlanır; başarısız başlangıç yarım callback bırakmaz.

**D3 — Direct Kimi iptali**

- İptal etkin HTTP istemcisini kapatır. İstemci oluşturulurken iptal olma
  yarışı, yanıt başlığını bekleme ve yanıt gövdesini bekleme kapsanır.
- Geç yanıt kabul edilmez; iptal sonrasında onarım isteği başlamaz.
  İstek sona erdiğinde iptal callback'i temizlenir.
- Gateway'in uzaktan iptali ve tarotun mevcut transport davranışı korundu.

**D5 — Konu ve fal güncelliği**

- Yerel fal isteği kimliği oturum + fiziksel kaynak parmak izi + konuyu
  içerir. Fiziksel analiz parmak izi değiştirilmedi. Yeni sonuçlara isteğe
  bağlı `readingRequestKey` alanı eklenir; depo sürümü ve AI protokolü aynı kalır.
- Eski sonuçlar kayıtlı konudan okunur; konu alanı yoksa Genel kabul edilir.
  Hazır etiketi, basit akıştaki üretim kontrolü ve hafıza aynı kimliği kullanır.
- Fal okuma ile açık üretim ayrı eylemlerdir. Konu değiştirmek ve okumak
  çağrı başlatmaz. Tamamlanmış aynı konu tekrar açıldığında yeniden kullanılır.
  Önceki konudaki metin ve sonuç kimliğine bağlı yıldız korunur.
- Üretim sırasında konu/kaynak değişirse geç yanıt yeni güncel sonuç olmaz.
- Her farklı konuda tamamlanmış istek hafıza sayacına bir kez girer;
  başarısız deneme ve tekrar okuma sayılmaz. Eski sayaç sırası, aralık ve
  kullanılan alıntı geçmişi korunur. Aynı fiziksel kaynak başka konuda olsa
  da kendisine alıntı kaynağı yapılmaz.
- Laboratuvardaki açık A/B karşılaştırması korunur; aynı konu isteğinin
  karşılaştırılması hafıza sayacını tekrar artırmaz.

## Doğrulama

| Kontrol | Sonuç |
| --- | --- |
| Başlangıç tam paketi | 522 geçti, 9 atlandı, 1 A/B zaman aşımı |
| Değişiklik öncesi A/B dosyasını tek başına tekrar | 2 geçti |
| Son tam yerel paket | **538 geçti, 9 atlandı, 0 başarısız** |
| `ATLAS_AI_LAB=true` hedefli paket | **64 geçti, 0 başarısız** |
| Son statik analiz | Sorun yok |
| Android `:app:compileDebugKotlin --offline` | Başarılı |
| `git diff --check` | Temiz |

523 senaryoluk önceki ZIP-sonrası pakete 15 regresyon senaryosu eklendi:
4 kayıt kurtarma/ayrı depo, 2 başlangıç hatası ve yeniden deneme, 3 HTTP
iptal, 2 gerçek AI sayfasında konu değişimi ve 4 kimlik/hafıza senaryosu.
Yeni testler uydurma veriler, geçici dizinler, taklit istemciler ve yerel HTTP
sunucusu kullanır. Atlanan 9 test geçmiş sayılmadı.

Başlıca kanıtlar:

- Bozuk A+B listesi ve yalnız A içeren yedekte B'nin kaynak fotoğrafı,
  işaretleri, incelemesi, falı ve yıldızı korunur; iki registry dosyası değişmez.
- İki liste dosyasının kaybı/bozulması boş depo kabul edilmez. Sağlıklı
  listede yokluk silmeye dönüşmez; açık silme isteği normal çalışır.
- Bozuk AI JSON'u ve yazma hatasında kurtarma görünümü açılır; veri korunur.
  Sentetik sorun giderilip yeniden denendiğinde normal arayüz açılır.
- Başlık/gövde yanıtı verilmeyen HTTP testlerinde iptal iki saniyelik sınır
  içinde sonlanır. İstemci oluşturma yarışında istek hiç başlamaz.
- Tamamlanmış ve yıldızlı Genel/Aşk falından Para'ya yalnız açık eylemle
  tek üretim yapılır; aynı kaynak parmak izi ve eski sonuç/yıldız korunur.
  Okuma ve tamamlanmış konuya dönüş ek çağrı yapmaz. Üretim sırasında konu
  değişirse yeni tamamlanmış fal/sayaç kaydı oluşmaz.

Başlangıç A/B zaman aşımı tek başına tekrarda ve sonraki tam koşularda
tekrarlanmadı; bunun için uygulama davranışı veya test beklentisi gevşetilmedi.
İlk ek AI modu koşusunda eski transport kalite testleri laboratuvarın
`bestEffort` varsayılanından etkilendi. Test fixture'ları bekledikleri sıkı
modu açıkça seçer hale getirildi; uygulamanın kalite varsayılanı değiştirilmedi.
Son AI modu koşusunda bu testler de geçti.

## Kapsam ve kanıt sınırı

İnceleme Araçları, yeni yerel inceleme, manuel işaretleme, kamera/galeri,
ilk gözlem modeli/hazırlığı, profil ve tarot kaynakları bu adımda değiştirilmedi.
Önceki ZIP kaldırma korundu. Prompt, cihaz izin manifesti, bağımlılıklar,
çevrimiçi giriş ve yönetici uygulaması değiştirilmedi. Korunan dosyalar
başlangıç çalışma ağacıyla karşılaştırıldı.

Yerel günlükler `build/audit-fixes/` altında: `before-tests.log`,
`before-ai-recheck.log`, `final-tests.log`, `final-ai-lab-tests.log`,
`final-analyze.log`, `final-android-compile.log`. Başlangıç diff'i
`before-fixes.patch` ve durum listesi `before-status.txt` olarak saklandı.

Android derleme kontrolü diagnostic/laboratuvar/yerel görüntü kontrolü
ayarlarıyla ve özel anahtar eklenmeden yapıldı. Telefon kurulumu, adb,
uygulamayı cihazda çalıştırma, gerçek kullanıcı verisi üzerinde test,
veri temizleme veya ücretli AI çağrısı yapılmadı. Cihaz üzerindeki kabul
bu çalışmanın kanıtı değildir. Commit, push veya yayın yapılmadı.
