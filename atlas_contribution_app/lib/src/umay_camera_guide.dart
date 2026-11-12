// The unchanged camera chrome is shown with a fixed photograph, never a camera.
import 'package:coffee_camera/coffee_camera.dart';
import 'package:coffee_camera/coffee_camera_presentation.dart';
import 'package:flutter/material.dart';
import 'capture_settings.dart';
import 'models.dart';
import 'umay_home_tour.dart';

const umayCameraSteps = [
  UmayTourStep(
    target: 'coffee-camera-brand-title',
    message:
        'Önce kamerayı tanıyalım. Fincanı sabit tut; telefonunu, fincanın içi hedef alanda görünecek şekilde yerleştir.',
  ),
  UmayTourStep(
    target: 'tooltip:Işığı aç',
    message:
        'Ortam karanlıksa ışığı buradan açabilirsin. Fincanın içinde güçlü bir parlama oluşursa ışığı kapatıp yeniden bak.',
  ),
  UmayTourStep(
    target: 'coffee-camera-auto-switch',
    message:
        'Otomatik çekim açıkken uygun görüntü yakalandığında fotoğraf çekilir. İstersen kapatıp çekim tuşunu kendin kullanabilirsin.',
  ),
  UmayTourStep(
    target: 'guide-camera-shutter',
    message:
        'Fotoğrafı kendin çekmek için bu tuşa dokunabilirsin. Görüntü kontrolünün izin vermediği durumlarda tuş hazır olmayabilir.',
  ),
  UmayTourStep(
    target: 'coffee-finish-sequence',
    message:
        'Eklemek istediğin fotoğraflar tamamlandığında Çekimi bitir’i seç. Fotoğraflarını sonraki ekranda gözden geçirebilirsin.',
  ),
];

class UmayCameraGuide extends StatelessWidget {
  const UmayCameraGuide({required this.onFinish, this.onPresented, super.key});
  final ValueChanged<bool> onFinish;
  final VoidCallback? onPresented;
  @override
  Widget build(BuildContext context) => UmayHomeTour(
    steps: umayCameraSteps,
    onFinish: onFinish,
    onPresented: onPresented,
    child: Scaffold(
      body: LayoutBuilder(
        builder: (context, box) {
          final config = cameraConfigForRole(CaptureRole.free);
          final target = TargetGeometry(
            viewportSize: box.biggest,
            center: Offset(box.maxWidth / 2, box.maxHeight * .48),
            radius: box.maxWidth * .35,
          );
          return Stack(
            fit: StackFit.expand,
            children: [
              const ColoredBox(color: Color(0xff25190f)),
              Center(
                child: Image.asset(
                  'assets/guide/example-cup.png',
                  width: box.maxWidth,
                ),
              ),
              IgnorePointer(
                child: CameraTargetOverlay(
                  config: config,
                  ringColor: config.theme.idleRing,
                  subjectDetected: true,
                  coffeeDetected: true,
                  targetGeometry: target,
                ),
              ),
              CameraPresentationChrome(
                presentation: const CoffeeCameraPresentation(
                  backgroundImage: AssetImage('assets/brand/atlas-logo.png'),
                  title: 'Kamera rehberi · Örnek',
                  stepLabel: 'Fotoğraf çekilmez',
                  instruction: 'Fincanın içini hedef alanında tut.',
                ),
                theme: config.theme,
                target: target,
                guidance: 'Telefonunu sabit tut.',
                shutter: IconButton.filled(
                  key: const ValueKey('guide-camera-shutter'),
                  onPressed: () {},
                  iconSize: 38,
                  icon: const Icon(Icons.camera_alt),
                  tooltip: 'Fotoğraf çek',
                ),
                onBack: () {},
                onFlash: () {},
                torch: false,
                showLightHint: false,
                autoVisible: true,
                autoEnabled: true,
                onAutoChanged: (_) {},
                onFinish: () {},
              ),
            ],
          );
        },
      ),
    ),
  );
}
