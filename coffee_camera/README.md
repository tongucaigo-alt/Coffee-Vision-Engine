# Coffee Camera

`coffee_camera`, kahve fincanı fotoğrafları için gömülebilir bir Flutter kamera
modülüdür. Canlı önizleme, hedef halkası, cihaz üzerinde ışık/netlik analizi,
hareket kontrolü, manuel çekim ve fotoğraf onay akışı sağlar.

## Gereksinimler

- Flutter 3.44 veya üzeri
- Android 7.0 / API 24 veya üzeri
- iOS 13 veya üzeri

## Entegrasyon

Paketi ana uygulamaya ekleyin:

```yaml
dependencies:
  coffee_camera:
    path: ../coffee_camera
```

Kamera akışını bir route olarak açın:

```dart
final result = await showCoffeeCamera(context);
if (result != null) {
  // result.filePath ana uygulamanın sorumluluğuna geçer.
}
```

Kendi navigasyonunuzu kullanmak için `CoffeeCameraScreen` widget'ını doğrudan
ekleyip `onApproved` ve `onCancelled` callback'lerini yönetin.

Fincan ve tabak çekimini tek akışta almak için birleşik API'yi kullanın:

```dart
final result = await showCoffeeCameraFlow(
  context,
  config: const CoffeeCameraConfig(requireSaucerCapture: true),
);
if (result != null) {
  final cup = result.cup;
  final saucer = result.saucer;
}
```

Tabak aşamasında çekim manuel kalır. Tabağın dış sınırı yerel olarak analiz
edilir; hedef halkası, kalite yönlendirmeleri ve otomatik crop uygulanır.
Özel navigasyonda birleşik sonuç için `CoffeeCameraScreen.flow` kullanılmalıdır.

## Platform ayarları

Android uygulamasının `AndroidManifest.xml` dosyasına kamera izni eklenmelidir:

```xml
<uses-permission android:name="android.permission.CAMERA" />
```

iOS uygulamasının `Info.plist` dosyasında aşağıdaki açıklamalar bulunmalıdır:

```xml
<key>NSCameraUsageDescription</key>
<string>Fincan fotoğrafı çekmek için kamera erişimi gerekir.</string>
<key>NSMotionUsageDescription</key>
<string>Telefonun sabitliğini değerlendirmek için hareket verisi kullanılır.</string>
```

Modül portre yerleşimi için tasarlanmıştır. Ana uygulama kamera route'u açıkken
ekran yönünü portre olarak sınırlandırmalıdır.

## Debug analiz akışı

Debug derlemede üst çubuktaki hata ayıklama simgesi analiz panelini açar. “Test
analizini kullan” etkinleştirildikten sonra fincan, merkez, boyut, ışık, netlik,
sabitlik ve açı durumları elle değiştirilebilir. Bütün koşullar uygunsa otomatik
çekim 1,2 saniyelik kesintisiz sabitlikten sonra çalışır.

Yerel açık renk fincan algılayıcısı varsayılan olarak kullanılır. Release
derlemesinde otomatik çekim ayrıca etkinleştirilmedikçe kapalıdır; manuel çekim
kullanılabilir kalır. Daha sonra eklenecek özel `CupDetector`, önizlemeye göre
normalize edilmiş `CupDetectionResult` döndürmelidir.

## Dosya ve gizlilik

- Kamera kareleri veya fotoğraflar sunucuya gönderilmez.
- Onaylanmayan geçici fotoğraflar yeniden çekme veya iptalde silinir.
- Onaylanan `CameraCaptureResult.filePath` ana uygulamanın sahipliğine geçer.
- İki aşamalı akışta iki dosyanın sahipliği yalnız son tabak onayından sonra
  `CoffeeCameraCaptureResult` ile ana uygulamaya geçer.
- Galeriye yazma ve kalıcı depolama ana uygulamanın kararıdır.

## Doğrulama

```powershell
flutter analyze
flutter test
cd example
flutter run
```

## Capture result

`CameraCaptureResult.filePath` tam kamera fotografini verir. Modul fincan ve
tabak bolgesini otomatik kirpar; basarili olursa fincan icin `croppedCupPath`,
tabak icin `croppedSaucerPath` alanini doldurur. `croppedImagePath` iki cekim
turunde de uygun crop yolunu verir. `cropRect`, `croppedWidthPixels`,
`croppedHeightPixels` ve `croppedFileSizeBytes` ortak crop bilgisidir.

Canli analiz once acik renkli dairesel fincan kenarini dogrular. Fincan
bulunmadan telve analizi ve yesil tarama efekti calismaz. Dogrulanan fincanin
icinde uretilen 32x32 maske koyu telve bolgelerini tasir; isiklar yalniz bu
maskenin aktif hucrelerinde gorunur.

Tabak adiminda ayri `SaucerDetector` ve ayri kalite esikleri kullanilir. Telve
maskesi, isik noktalari ve tarama cizgisi yalniz fincan adiminda calisir. Tabakta
otomatik fotograf cekimi yoktur; dusuk kalitede manuel cekim kullanilabilir.

`coffeePresenceScore` 0 ile 1 arasindadir ve `coffeeDetected` sonucu uc ardisik
basarili kareden sonra true olur. Iki basarisiz kare algilamayi kapatir. Bu ilk
surum beyaz/acik renk fincan ve koyu Turk kahvesi telvesi icin tasarlanmistir;
koyu, seffaf veya yogun desenli fincanlar destek kapsami disindadir.

Yerel fincan algilayici release derlemesinde de kalite ve efekt icin calisir,
ancak otomatik cekim varsayilan olarak gizlidir. Uretimde otomatik cekim ancak
`enableReleaseAutoCapture: true` ile acikca etkinlestirilir.
