import 'package:integration_test/integration_test.dart';
import '../test/photo_set_widget_test.dart' as gallery;
import '../test/contribution_capture_flow_test.dart' as capture;
import 'export_device_test.dart' as exports;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  gallery.main();
  capture.main();
  exports.main();
}
