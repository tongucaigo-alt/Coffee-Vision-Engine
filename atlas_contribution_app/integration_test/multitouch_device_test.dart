import 'package:integration_test/integration_test.dart';
import '../test/annotation_multitouch_test.dart' as gestures;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // Synthetic, in-memory photos only; never open the normal app's draft store.
  gestures.main();
}
