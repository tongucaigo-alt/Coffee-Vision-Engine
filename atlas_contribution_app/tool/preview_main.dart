// Local UI evidence only. This entrypoint has no authentication or upload service.
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:atlas_contribution_app/src/annotation_page.dart';
import 'package:atlas_contribution_app/src/models.dart';
import 'package:atlas_contribution_app/src/theme.dart';

void main() {
  final picture = img.Image(width: 640, height: 800)
    ..clear(img.ColorRgb8(215, 225, 220));
  img.fillCircle(
    picture,
    x: 320,
    y: 400,
    radius: 270,
    color: img.ColorRgb8(249, 248, 243),
  );
  img.fillCircle(
    picture,
    x: 320,
    y: 400,
    radius: 240,
    color: img.ColorRgb8(185, 167, 135),
  );
  img.fillCircle(
    picture,
    x: 320,
    y: 400,
    radius: 218,
    color: img.ColorRgb8(248, 247, 240),
  );
  img.fillCircle(
    picture,
    x: 325,
    y: 525,
    radius: 88,
    color: img.ColorRgb8(87, 64, 45),
  );
  final photo = ContributionPhoto(
    role: CaptureRole.top,
    localName: 'test-preview.jpg',
    checksum: 'sha256:${'a' * 64}',
    originalChecksum: 'sha256:${'b' * 64}',
    width: 640,
    height: 800,
    byteLength: 100,
    capturedAt: DateTime.now().toUtc().toIso8601String(),
  );
  runApp(
    MaterialApp(
      title: 'Atlas Katkı · Yerel test',
      debugShowCheckedModeBanner: false,
      theme: contributionTheme(),
      builder: (context, child) => Column(
        children: [
          const Material(
            color: Color(0xffeff4f1),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: EdgeInsets.all(6),
                child: Text('Yerel test görseli · Gönderim yok'),
              ),
            ),
          ),
          Expanded(child: child!),
        ],
      ),
      home: AnnotationPage(
        photo: photo,
        image: MemoryImage(img.encodePng(picture)),
        onSave: (_) async {},
      ),
    ),
  );
}
