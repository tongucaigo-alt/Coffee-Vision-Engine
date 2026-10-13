import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:atlas_contribution_app/src/atlas_design.dart';
import 'package:atlas_contribution_app/src/contribution_home.dart';
import 'package:atlas_contribution_app/src/gallery_import.dart';
import 'package:atlas_contribution_app/src/local_store.dart';
import 'package:atlas_contribution_app/src/models.dart';
import 'package:atlas_contribution_app/src/offline_contribution.dart';
import 'package:atlas_contribution_app/src/photo_crop.dart';
import 'package:atlas_contribution_app/src/photo_suitability.dart';

// Native UI fixture in the dedicated preview package. No AI or user stores.
Future<void> main() async {
  if (!const bool.fromEnvironment('ATLAS_UI_PREVIEW')) {
    throw StateError('Preview flag is required');
  }
  WidgetsFlutterBinding.ensureInitialized();
  final root = await Directory.systemTemp.createTemp('atlas-v63-preview-');
  final store = DraftStore(root);
  final imported = await store.importGallery(
    await File('/data/local/tmp/atlas-coffee-ui.jpg').readAsBytes(),
  );
  final now = DateTime.now().toUtc().toIso8601String();
  // Two independent fixture files show navigation without accessing user media.
  final second = await store.importGallery(
    await File('/data/local/tmp/atlas-coffee-ui.jpg').readAsBytes(),
  );
  await store.save(
    ContributionDraft(
      id: 'visual-fixture',
      rootId: 'visual-fixture',
      groupId: 'visual-fixture',
      createdAt: now,
      consentedAt: now,
      kind: ContributionKind.photoSet,
      galleryStart: true,
      photos: [
        imported.asSetPhoto(photoId: 'visual-cup'),
        second.asSetPhoto(photoId: 'visual-cup-2'),
      ],
    ),
  );
  await store.acceptLocalUse();
  final scale = ValueNotifier<double>(1);
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: atlasTheme(),
      builder: (context, child) => ValueListenableBuilder<double>(
        valueListenable: scale,
        builder: (context, value, _) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(value)),
          child: Stack(
            children: [
              child!,
              Positioned(
                top: MediaQuery.paddingOf(context).top,
                right: 0,
                child: Material(
                  color: atlasCard,
                  child: TextButton(
                    onPressed: () => scale.value = value == 1 ? 2 : 1,
                    child: Text(value == 1 ? '2×' : '1×'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      home: ContributionHome(
        modern: true,
        store: store,
        service: _PreviewBackend(store),
        photoSuitability: _PreviewSuitability(),
        galleryPicker: _CancelledPicker(),
        saucerLauncher: (_) async => null,
      ),
    ),
  );
}

class _PreviewBackend extends OfflineContributionService {
  _PreviewBackend(super.store);
  @override
  Future<Map<String, dynamic>> submit(
    ContributionDraft draft,
    Future<Uint8List> Function(ContributionPhoto) read,
    void Function(int) progress,
  ) async => throw StateError(
    'Saving and generation are disabled in this visual fixture',
  );
}

class _CancelledPicker implements GalleryPicker {
  @override
  Future<Uint8List?> pick() async => null;
  @override
  Future<Uint8List?> recover() async => null;
}

class _PreviewSuitability extends PhotoSuitability {
  _PreviewSuitability() : super(Directory.systemTemp);
  @override
  Future<Map<String, dynamic>> assess(
    File file,
    ContributionPhoto photo, {
    bool retry = false,
  }) async => {
    'version': suitabilityVersion,
    'checksum': photo.checksum,
    'surface': photo.surface.name,
    'cropKey': jsonEncode((photo.displayCrop ?? PhotoCrop.full).toJson()),
    'status': 'supported',
  };
}
