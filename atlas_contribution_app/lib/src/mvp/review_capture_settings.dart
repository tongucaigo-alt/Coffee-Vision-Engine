import 'package:coffee_camera/coffee_camera.dart';
import '../capture_settings.dart';
import '../models.dart';

const reviewCaptureRoles = freeCaptureRoles;

CaptureRole nextReviewCaptureRole(Iterable<CaptureRole?> used) {
  final occupied = used
      .map((r) => r == CaptureRole.top ? CaptureRole.free : r)
      .toSet();
  return reviewCaptureRoles.firstWhere((role) => !occupied.contains(role));
}

String reviewCaptureTitle(CaptureRole role) => cameraCaptureTitle(role);

String reviewCaptureInstruction(CaptureRole role) =>
    cameraCaptureInstruction(role);

CoffeeCameraConfig reviewCameraConfig(CaptureRole role) =>
    cameraConfigForRole(role);
