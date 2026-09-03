import 'camera_capture_result.dart';

enum CoffeeCaptureStep { cup, saucer }

class CoffeeCameraCaptureResult {
  const CoffeeCameraCaptureResult({required this.cup, this.saucer});

  final CameraCaptureResult cup;
  final CameraCaptureResult? saucer;
}
