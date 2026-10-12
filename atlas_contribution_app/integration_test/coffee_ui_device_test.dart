import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider/path_provider.dart';
import '../test/coffee_ui_flow_test.dart' as flow;
import '../test/fortune_research_access_test.dart' as story;
import '../test/coffee_preview_layout_test.dart' as preview;
import '../test/coffee_gallery_start_test.dart' as gallery;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  Future<void> capture(String name) async {
    // Capture the painted Flutter screen on the device. Android's integration
    // screenshot surface conversion stalls with this phone's Vulkan renderer.
    final boundary =
        find
                .byKey(const ValueKey('coffee-test-surface'))
                .evaluate()
                .single
                .renderObject!
            as RenderRepaintBoundary;
    final screen = await boundary.toImage(pixelRatio: 3);
    final pixels = await screen.toByteData(format: ui.ImageByteFormat.png);
    final bytes = pixels!.buffer.asUint8List();
    screen.dispose();
    final folder = Directory(
      '${(await getApplicationSupportDirectory()).path}/coffee-ui-screens',
    );
    await folder.create(recursive: true);
    await File('${folder.path}/$name.png').writeAsBytes(bytes, flush: true);
  }

  flow.main(
    device: true,
    photoBytes: () => File('/data/local/tmp/atlas-coffee-ui.jpg').readAsBytes(),
    capture: capture,
  );
  story.main(capture: capture);
  preview.main(
    device: true,
    capture: capture,
    photoBytes: () => File('/data/local/tmp/atlas-coffee-ui.jpg').readAsBytes(),
  );
  gallery.main(capture: capture, device: true);
}
