# Araştırma ZIP akışını kaldırma — doğrulama

19 Ekim 2026. Başlangıç dalı `codex/atlas-v82`, commit `4010e10`.
Başlangıç çalışma ağacı temizdi. Doğrulama yerel kaynak, yapay verili testler
ve Android derleme kontrolüne dayanır; telefon üzerinde kabul testi değildir.

## Yapılan değişiklik

- Katkı/galeri ve inceleme ZIP üreticileri, bunların dışa aktarma düğmeleri,
  yalnız ZIP'e ait izin kutuları, hata/izin yönlendirmeleri kaldırıldı.
- Android `atlas.contribution/export` kanalı ve ona özel tanı indirme
  okuma/silme yardımcıları kaldırıldı. OpenCV, fotoğraf uygunluğu ve yerel
  görüntü kontrolü kanalları korundu. Android izin manifesti değiştirilmedi.
- İnceleme Araçları ve yeni yerel inceleme oluşturma korundu. Yerel kullanım
  kabulü, kamera/galeri, manuel işaretleme, kayıt, analiz ve fal işlemleri kaldı.
- Veri modelleri ve eski araştırma izin alanları korundu. İlk gözlem,
  hazırlık, AI köprüsü/istemcisi/deposu, hafıza, profil ve tarot kodunda davranış
  değişikliği yapılmadı. Ortak yazma kuyrukları ve atomik kayıt işlemleri korundu.
- Veri geçişi, depo sıfırlama veya mevcut fotoğraf/işaret/fal/ZIP temizliği
  eklenmedi. Ayrı çevrimiçi katkı ve yönetici sisteminin dışa aktarımı korundu.
- ZIP cihaz testi kaldırıldı; onu çağıran dört cihaz testinden yalnız bu
  çağrı çıkarıldı. Paylaşılan bir yardımcı taşınması gerekmedi: bağımlılık
  yalnız kaldırılan testin `main()` çağrısıydı.
- Eski `test-device.ps1 -Export` seçeneği herhangi bir build/cihaz komutuna
  ulaşmadan açıklayıcı hatayla durur. Betiğin diğer modları değiştirilmedi.

## Sonuçlar

| Kontrol | Sonuç |
| --- | --- |
| Değişiklik öncesi tüm yerel testler | 532 geçti, 9 atlandı, 0 başarısız |
| Değişiklik sonrası tüm yerel testler | 523 geçti, 9 atlandı, 0 başarısız |
| `ATLAS_AI_LAB=true` ile hedefli akış testleri | 26 geçti, 0 başarısız |
| Başlangıç ve son `flutter analyze --no-pub` | Sorun yok |
| Android `:app:compileDebugKotlin --offline` | Başarılı |
| PowerShell sözdizimi ve eski `-Export` seçeneği | Erken durdurma doğrulandı |
| `git diff --check` | Temiz |

Test sayısı farkı: yalnız ZIP'e ait 10 test senaryosu kaldırıldı; bir yeni
veri koruma regresyon senaryosu eklendi. Karma testlerdeki kayıt/medya
kontrolleri yerel depodan tekrar okuma ve checksum kontrollerine dönüştürüldü.
Atlanan 9 test geçmiş sayılmadı; canlı AI testleri etkinleştirilmedi.

Yeni `research_zip_removal_test.dart`, geçici bir dizinde gerçek depo
sınıflarıyla eski işaretli fotoğraf, araştırma izni, ilk gözlem revizyonları,
fal, yıldız ve önceki ZIP'i temsil eden dosya oluşturur. Arayüzden yeni yerel
inceleme açar ve eski incelemeyi tekrar görüntüler. Eski fotoğraf, revizyon
dosyaları, AI deposu ve ZIP örneğinin byte içeriklerinin değişmediğini;
manuel işaretleme girişinin ve fal/yıldız bilgilerinin korunduğunu doğrular.

Tam paket; kamera ve galeri akışları, işaretleme/atlama, kaydetme ve analiz,
AI üretimi/yeniden okuma, yıldızlar, hafıza, profil, A/B oylaması ve tarot
testlerini içerir. AI laboratuvarı açık ek testlerde kamera/galeri, hazırlık,
konu tercihi, kayıtlı fal okuma ve aynı girdiyle A/B üretim/yeniden açma
senaryoları taklit servislerle geçti.

Android derlemesi `ATLAS_DIAGNOSTIC=true`, `ATLAS_AI_LAB=true` ve
`ATLAS_IMAGE_SCREEN=true` ile, anahtar eklenmeden yapıldı. Yalnız derleme
görevi çalıştırıldı; APK kurulmadı veya uygulama açılmadı.

## Kanıt ve sınırlar

Yerel günlükler `build/research-export-removal/` altında:

- `baseline-head.txt`, `baseline-git-status.txt`
- `baseline-tests.log`, `baseline-analyze.log`
- `after-tests.log`, `after-analyze.log`
- `preservation-test.log`, `ai-lab-flow-tests.log`, `android-compile.log`

Geliştirme sırasında yeni testin fixture ve asenkron dosya erişimi kurulumu
düzeltildi; nihai tam paket ve ek akış testleri yukarıdaki sonuçlarla geçti.
İlk hedefli çalışmanın günlüğü nihai kabul sonucu olarak kullanılmadı.

Gerçek kullanıcı verisi okunmadı veya değiştirilmedi. adb, telefon kurulumu,
veri temizleme ve ücretli AI çağrısı yapılmadı. Donanım üzerindeki kamera,
galeri ve Android çalıştırma davranışı bu çalışmada yeniden doğrulanmadı.
Yerel testlerde korunan akışlarda yeni başarısızlık görülmedi.

D1/D2/D3/D5 düzeltmeleri bu çalışmaya alınmadı; önceki denetimdeki bulgular
ayrı çalışma olarak kalır. Commit, push ve yayın yapılmadı.
