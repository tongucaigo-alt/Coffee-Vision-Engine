# Atlas V111 — GitHub kaynak yedeği

27 Ekim 2026. Telefonda onaylanan V111 çalışmasının kaynak kopyasıdır.

- Dal: `codex/atlas-v111`
- Sürüm etiketi: `atlas-v111`
- Temel: V100 kaynakları, V101 Tarot efektleri ve V102–V111 yerel görsel geliştirmelerinin tamamı.
- Güncel zemin: `#EFE1C8`. Kahve ve Tarot ana ekran haleleri görünen logo/kart kenarlarına göre ölçülür; orta hizada yan krem boşluk 39dp, üst sönüm 50dp, alt sönüm 8dp. ▶ düğmesi halenin boyutunu/merkezini etkilemez.
- Logo, kartlar, başlıklar ve düğme konumları korunur. V111 değişikliği AI, veri modeli, kayıt, kamera/OpenCV ve fal akışını değiştirmez.
- Yerelde önceden bulunan Play hazırlık dokümanı, Gradle güvenlik kontrolleri ve derleme aracı da mevcut halleriyle bu kaynak anlık görüntüsünde korunmuştur. Mağazaya gönderim yapılmamıştır.

## Doğrulama

56 ilgili test geçti; kod analizi temiz. 36 görünümün ön plan sınırları V110 ile aynı. Kahve ve Tarot, Samsung SM-A566B üzerindeki Atlas Fotoğraf Testi V111 uygulamasında incelendi. Aynı imzayla güncelleme yapıldı; veri temizlenmedi.

[Gerçek Flutter / telefon karşılaştırması](Onizlemeler.html) · [Doğrulama raporu](V111_DOGRULAMA.md)

Bu klasörde önce/sonra ana ekran görselleri, gerçek telefon görselleri, 36 ekranın yerleşim ölçüleri, 12 ana ekranın hale ölçümleri ve test sonuçları bulunur. Görseller yapay görüntü değildir.

## Geri yükleme

```powershell
git clone --branch atlas-v111 https://github.com/tongucaigo-alt/Coffee-Vision-Engine.git Atlas-V111
cd Atlas-V111/atlas_contribution_app
flutter pub get
```

`atlas_contribution_app/assets/intro/atlas-welcome.mp4` dahil gerekli uygulama varlıkları kaynak ağacındadır. Video genel MP4 dışlama kuralından etkilenmeden bu sürüme açıkça eklenmiştir.

Flutter 3.44.6 / Dart 3.12.2 ve yerel Android SDK/JDK gereklidir. V111 test paketi `lib/offline_main.dart` üzerinden sürüm kodu 111 ve `1.0.0-kimi-test.111` adıyla derlenmiştir. `pubspec.yaml` ortak temel sürümde tutulur; derleme sürümü komutla verilir.

İmzalama anahtarları, özel test/servis anahtarları, kullanıcı kayıtları ve derlenmiş özel test APK'sı bu GitHub yedeğine dahil değildir. Özel yapılandırma yerel olarak korunur. `Atlas-V111.apk.sha256` telefonda kurulu yerel APK'nın kimliğini kaydeder.
