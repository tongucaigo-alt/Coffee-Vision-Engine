# V125 — onaylı açılış yedeği

3 Kasım 2026. Masalımsı ekran geçişine başlamadan önce, kullanıcı tarafından beğenilen ve telefona kurulan V125 burada donduruldu.

- Geri dönüş etiketi: `v125-natural-intro-stable`.
- Dal: `codex/v125-natural-intro-backup`.
- Video: `atlas_contribution_app/assets/intro/atlas-welcome.mp4`; 1080×2400, 24 fps, 6 saniye. SHA-256: `7d84d7a37aadfc475a87d3467d80cede5c00fb075ea50e7a91bff7bd6e5d8a80`.
- Kamera sabit; doğal göl/yansıma, yukarı bakış, sakin yıldız, buhar ve yaprak hareketleri korunur. Mevcut AAC sesi ve uygulamanın düşük ses seviyesi/ses kuralları aynıdır.
- Bir saniyelik yumuşak giriş ve V125'in mevcut parşömene çıkışı bu yedekte korunur. Sonraki masalımsı geçiş bu etikete dahil değildir.

53 ilgili test geçti; bir isteğe bağlı eski video dışa aktarma testi atlandı. Flutter analyze temiz. Gerçek Android soğuk açılışı ve veri koruyan kurulum doğrulandı. Bu kaynaklar, test edilen V125 derlemesinin değişmiş dosya özetleriyle karşılaştırıldı.

V118 görsel kararını, V120 performans çalışmalarını ve V121 kamera düzeltmesini içeren tam depo tabanı kullanıldı. Yedi kardeş runtime paketinde 358 dosya V121 kaynağıyla eşleşti. İş akışları/model/gateway değişikliği yapılmadı; yalnız mevcut V125 açılış kaynakları ve tasarım belgeleri eklendi. Salt satır sonu farkları aktarılmadı.

## Geri dönme

Yeni bir temiz checkout'ta bu etiketi açın:

```sh
git switch -c codex/restore-v125 v125-natural-intro-stable
```

Yerel kirli çalışmaları reset/clean ile silmeyin. Flutter uygulaması `atlas_contribution_app` içindedir; kendi yerel özel yapılandırmanızla derlenir. Özel API anahtarları, imza dosyaları, kullanıcı kayıtları, telefon yedeği ve özel test APK'sı yayımlanmadı. Ana dal ve önceki etiketler değiştirilmedi.
