import 'dart:io';
import 'package:image/image.dart' as img;

// Project-owned geometric A mark. No reference photo or third-party raster is used.
void main() {
  final outputs = <String, int>{
    'android/app/src/main/res/mipmap-mdpi/ic_launcher.png': 48,
    'android/app/src/main/res/mipmap-hdpi/ic_launcher.png': 72,
    'android/app/src/main/res/mipmap-xhdpi/ic_launcher.png': 96,
    'android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png': 144,
    'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png': 192,
    'web/favicon.png': 32,
    'web/icons/Icon-192.png': 192,
    'web/icons/Icon-512.png': 512,
    'web/icons/Icon-maskable-192.png': 192,
    'web/icons/Icon-maskable-512.png': 512,
  };
  for (final entry in outputs.entries) {
    final s = entry.value;
    final image = img.Image(width: s, height: s)
      ..clear(img.ColorRgb8(24, 99, 84));
    void line(double x1, double y1, double x2, double y2, img.Color color) =>
        img.drawLine(
          image,
          x1: (x1 * s).round(),
          y1: (y1 * s).round(),
          x2: (x2 * s).round(),
          y2: (y2 * s).round(),
          color: color,
          thickness: (s * .065).round(),
        );
    final white = img.ColorRgb8(251, 253, 251);
    line(.29, .74, .5, .26, white);
    line(.5, .26, .71, .74, white);
    line(.38, .58, .62, .58, img.ColorRgb8(246, 196, 92));
    File(entry.key).writeAsBytesSync(img.encodePng(image));
  }
}
