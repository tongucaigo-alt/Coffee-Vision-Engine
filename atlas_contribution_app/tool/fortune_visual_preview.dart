import 'dart:io';
import 'package:flutter/material.dart';
import 'package:atlas_contribution_app/src/atlas_design.dart';
import 'package:atlas_contribution_app/src/fortune_progress.dart';
import 'package:atlas_contribution_app/src/models.dart';

// Isolated native rendering fixture; no stores, HTTP clients or AI runtime.
void main() {
  if (!const bool.fromEnvironment('ATLAS_UI_PREVIEW')) {
    throw StateError('Preview flag is required');
  }
  runApp(const _Preview());
}

class _Preview extends StatefulWidget {
  const _Preview();
  @override
  State<_Preview> createState() => _PreviewState();
}

class _PreviewState extends State<_Preview> {
  bool _reduced = false;
  final _photo = ContributionPhoto(
    role: CaptureRole.free,
    localName: 'atlas-coffee-ui.jpg',
    checksum: 'visual-fixture',
    originalChecksum: 'visual-fixture',
    width: 960,
    height: 1280,
    byteLength: 750064,
    capturedAt: '2026-10-12T00:00:00Z',
  );
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: atlasTheme(),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: _reduced),
      child: child!,
    ),
    home: Scaffold(
      appBar: AppBar(title: const Text('Fincanının Hikâyesi')),
      body: FortuneScan(
        progress: const FortuneProgress(FortunePhase.generating),
        photos: [_photo],
        imageFor: (_) => FileImage(File('/data/local/tmp/atlas-coffee-ui.jpg')),
        showDecorativeSymbols: true,
        onCancel: () => setState(() => _reduced = !_reduced),
      ),
    ),
  );
}
