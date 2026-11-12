import 'dart:io';
import 'dart:typed_data';

import 'package:atlas_contribution_app/src/atlas_design.dart';
import 'package:atlas_contribution_app/src/atlas_home_hints.dart';
import 'package:atlas_contribution_app/src/coffee_guide_page.dart';
import 'package:atlas_contribution_app/src/contribution_home.dart';
import 'package:atlas_contribution_app/src/gallery_import.dart';
import 'package:atlas_contribution_app/src/local_store.dart';
import 'package:atlas_contribution_app/src/models.dart';
import 'package:atlas_contribution_app/src/offline_contribution.dart';
import 'package:atlas_contribution_app/src/umay_home_tour.dart';
import 'package:flutter/material.dart';

import 'umay_annotation_guide.dart';

void main() {
  if (!const bool.fromEnvironment('ATLAS_UI_PREVIEW')) {
    throw StateError(
      'This guide fixture requires the isolated preview package.',
    );
  }
  runApp(const UmayGuidePreviewApp());
}

/// No app-data directory or private runtime is opened by this fixture.
class GuidePreviewStore extends DraftStore {
  GuidePreviewStore() : super(Directory('unused-umay-guide-preview'));
  int writes = 0;
  @override
  Future<ContributionDraft?> load() async => null;
  @override
  Future<Map<String, dynamic>?> galleryPending() async => null;
  @override
  Future<void> pruneExpiredReceipts() async {}
  @override
  Future<List<String>> pendingDeletes() async => [];
  @override
  Future<List<Map<String, dynamic>>> receipts() async => [];
  @override
  Future<bool> hasLocalAcceptance() async => false;
  @override
  Future<void> save(ContributionDraft draft) async => _unexpectedWrite();
  @override
  Future<void> acceptLocalUse() async => _unexpectedWrite();
  @override
  Future<void> clear() async => _unexpectedWrite();
  Never _unexpectedWrite() {
    writes++;
    throw StateError('Guide preview cannot write app data.');
  }
}

class UmayGuidePreviewApp extends StatelessWidget {
  const UmayGuidePreviewApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Atlas · Umay Rehber',
    debugShowCheckedModeBanner: false,
    theme: atlasTheme(),
    home: const UmayGuidePreview(startWithAnnotationTour: true),
  );
}

class GuidePreviewInputs implements GalleryPicker {
  int galleryLaunches = 0, cameraLaunches = 0;
  @override
  Future<Uint8List?> recover() async => null;
  @override
  Future<Uint8List?> pick() async {
    galleryLaunches++;
    throw StateError('Preview: gallery is blocked.');
  }
}

class UmayGuidePreview extends StatefulWidget {
  const UmayGuidePreview({
    this.store,
    this.inputs,
    this.startWithAnnotationTour = false,
    super.key,
  });
  final GuidePreviewStore? store;
  final GuidePreviewInputs? inputs;
  final bool startWithAnnotationTour;
  @override
  State<UmayGuidePreview> createState() => _UmayGuidePreviewState();
}

class _UmayGuidePreviewState extends State<UmayGuidePreview> {
  late final _store = widget.store ?? GuidePreviewStore();
  late final _inputs = widget.inputs ?? GuidePreviewInputs();
  final _hints = AtlasHomeHintPreferences()..automaticEnabled = false;
  bool _tour = true, _completed = false;
  int _run = 0;
  late bool _annotation = widget.startWithAnnotationTour;

  void _finish(bool completed) => setState(() {
    _tour = false;
    _completed = completed;
  });

  void _start(bool annotation) => setState(() {
    _run++;
    _annotation = annotation;
    _tour = true;
  });

  @override
  void dispose() {
    _hints.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_tour) {
      if (_annotation) {
        return UmayAnnotationGuide(key: ValueKey(_run), onFinish: _finish);
      }
      return UmayHomeTour(
        key: ValueKey(_run),
        onFinish: _finish,
        child: AtlasHomeHintScope(
          preferences: _hints,
          child: ContributionHome(
            modern: true,
            store: _store,
            service: OfflineContributionService(_store),
            tarotPage: const SizedBox.shrink(),
            galleryPicker: _inputs,
            cameraLauncher:
                (
                  context, {
                  required config,
                  required captureTitle,
                  required captureInstruction,
                  onFinishSequence,
                }) async {
                  _inputs.cameraLaunches++;
                  throw StateError('Preview: camera is blocked.');
                },
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Atlas · Umay Rehber')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/umay/umay-calm-right.png',
                    width: 140,
                    height: 150,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _completed ? 'Tanıtım tamamlandı' : 'Tanıtımı kapattın',
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _annotation
                        ? 'Fotoğrafı incelemeyi, şekil seçmeyi ve bu ekrandaki tuşları tanıdık. İstersen yeniden gezebilir veya ana ekranı tanıyabilirsin.'
                        : 'Bu dört adımda Atlas’ın ana tuşlarını tanıdık. İstersen yeniden gezebilir veya fotoğraf işaretlemeyi öğrenebilirsin.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    key: const ValueKey('umay-tour-restart'),
                    onPressed: () => _start(_annotation),
                    child: Text(
                      _annotation
                          ? 'İşaretlemeyi yeniden göster'
                          : 'Dört adımı yeniden göster',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    key: const ValueKey('umay-tour-other'),
                    onPressed: () => _start(!_annotation),
                    child: Text(
                      _annotation
                          ? 'Ana ekranı tanı'
                          : 'Fotoğrafı işaretlemeyi öğren',
                    ),
                  ),
                  TextButton(
                    key: const ValueKey('umay-tour-detail'),
                    onPressed: () => Navigator.of(context).push<void>(
                      MaterialPageRoute(
                        builder: (routeContext) => CoffeeGuidePage(
                          allowClose: true,
                          onClose: () => Navigator.of(routeContext).pop(),
                          onComplete: (_) async =>
                              Navigator.of(routeContext).pop(),
                        ),
                      ),
                    ),
                    child: const Text('Ayrıntılı rehber'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
