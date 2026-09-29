import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;

import 'local_store.dart';
import 'models.dart';
import 'mvp/review_store.dart';
import 'research_export.dart';
import 'service.dart';

class OfflineContributionService implements ContributionBackend {
  OfflineContributionService(this.store);

  final DraftStore store;

  @override
  bool get isOffline => true;

  @override
  Future<Map<String, dynamic>> call(
    String action, [
    Map<String, dynamic> data = const {},
  ]) async {
    if (action == 'cancel') return const {};
    throw const ContributionFailure('Bu işlem yerel toplama modunda yok.');
  }

  @override
  Future<void> delete(String rootId) async {}

  @override
  Future<List<Map<String, dynamic>>> list({bool admin = false}) {
    if (admin) {
      throw const ContributionFailure('Yerel toplama modunda yönetici yok.');
    }
    return store.receipts();
  }

  @override
  Future<Map<String, String>> photoUrls(String id) async => const {};

  @override
  Future<Uint8List> readPhoto(String id, ContributionPhoto photo) =>
      store.file(photo.localName).readAsBytes();

  @override
  Future<Map<String, dynamic>> submit(
    ContributionDraft draft,
    Future<Uint8List> Function(ContributionPhoto) read,
    void Function(int complete) progress,
  ) async {
    if (!draft.reviewed) {
      throw const ContributionFailure('Önce fotoğrafları gözden geçir.');
    }
    for (var i = 0; i < draft.photos.length; i++) {
      final photo = draft.photos[i];
      final bytes = await read(photo);
      if (bytes.length != photo.byteLength ||
          'sha256:${sha256.convert(bytes)}' != photo.checksum) {
        throw const ContributionFailure(
          'Fotoğraf doğrulanamadı. Kayıt telefonda korunuyor.',
        );
      }
      progress(i + 1);
    }
    final now = DateTime.now().toUtc();
    return {
      'id': draft.id,
      'root_id': draft.rootId,
      'group_id': draft.groupId,
      'submitted_at': now.toIso8601String(),
      'expires_at': null,
      'retention': 'manual',
      'local_only': true,
      if (await store.hasLocalAcceptance())
        'localUseVersion': DraftStore.localAcceptanceVersion,
      'document': draft.copy(queued: false).toJson(),
    };
  }
}

class OfflineExportResult {
  const OfflineExportResult({
    required this.fileName,
    required this.checksum,
    required this.recordCount,
    required this.location,
  });

  final String fileName;
  final String checksum;
  final int recordCount;
  final String location;
}

class OfflineContributionExporter {
  OfflineContributionExporter(
    this.store, {
    MethodChannel? channel,
    this.exposureAudit,
    ReviewStore? reviewStore,
    this.temporaryDirectory,
  }) : _channel = channel ?? const MethodChannel('atlas.contribution/export'),
       reviewStore =
           reviewStore ??
           ReviewStore(
             Directory(path.join(store.directory.parent.path, 'mvp-reviews')),
             contributionStore: store,
           );

  final DraftStore store;
  final MethodChannel _channel;
  final ReviewStore reviewStore;
  final ExportDirectoryProvider? temporaryDirectory;
  final Future<Map<String, dynamic>> Function(String groupId)? exposureAudit;

  Future<List<Map<String, dynamic>>> _currentRows() async {
    final pendingDeletes = (await store.pendingDeletes()).toSet();
    return (await store.receipts())
        .where(
          (row) =>
              row['local_only'] == true &&
              !pendingDeletes.contains(row['root_id']),
        )
        .toList()
      ..sort((a, b) => (a['id'] as String).compareTo(b['id'] as String));
  }

  Future<OfflineExportResult> exportToDownloads() => guardExport(() async {
    await reviewStore.initialize();
    final rows = await store.withExportRead(
      () => reviewStore.withExportRead(() async {
        final current = await _currentRows();
        if (current.isEmpty) {
          throw const ExportFailure(ExportFailureCode.noRecords);
        }
        final blocked = await reviewStore.blockedContributionRoots();
        final allowed = current
            .where((r) => !blocked.contains(r['root_id']))
            .toList();
        if (allowed.isEmpty) {
          throw const ExportFailure(ExportFailureCode.noPermission);
        }
        return allowed;
      }),
    );
    return withExportStaging(
      prefix: 'atlas-katki-export-',
      temporaryDirectory: temporaryDirectory,
      operation: (temporary) async {
        final stamp = DateTime.now().toUtc().toIso8601String().replaceAll(
          ':',
          '-',
        );
        final fileName = 'atlas-katki-$stamp.zip';
        final zip = File(path.join(temporary.path, fileName));
        final metadataFiles = <File>[];
        final inventory = <Map<String, Object>>[];
        final encoder = ZipFileEncoder();
        var encoderClosed = false;
        try {
          encoder.create(zip.path);
          for (final row in rows) {
            final draft = ContributionDraft.fromJson(
              Map<String, dynamic>.from(row['document'] as Map),
            );
            final folder = 'records/${draft.id}';
            final record = File(path.join(temporary.path, '${draft.id}.json'));
            final recordBytes = utf8.encode(jsonEncode(row));
            await record.writeAsBytes(recordBytes, flush: true);
            metadataFiles.add(record);
            await encoder.addFile(record, '$folder/record.json');
            inventory.add({
              'path': '$folder/record.json',
              'sha256': 'sha256:${sha256.convert(recordBytes)}',
              'bytes': recordBytes.length,
            });
            if (exposureAudit != null) {
              final bytes = utf8.encode(
                jsonEncode(await exposureAudit!(draft.groupId)),
              );
              final audit = File(
                path.join(temporary.path, '${draft.id}-ai-audit.json'),
              );
              await audit.writeAsBytes(bytes, flush: true);
              metadataFiles.add(audit);
              await encoder.addFile(audit, '$folder/ai-exposure-audit.json');
              inventory.add({
                'path': '$folder/ai-exposure-audit.json',
                'sha256': 'sha256:${sha256.convert(bytes)}',
                'bytes': bytes.length,
              });
            }
            for (final photo in draft.photos) {
              final source = store.file(photo.localName);
              Uint8List bytes;
              try {
                bytes = await source.readAsBytes();
              } on FileSystemException {
                throw const ExportFailure(ExportFailureCode.integrity);
              }
              final digest = 'sha256:${sha256.convert(bytes)}';
              if (bytes.length != photo.byteLength ||
                  digest != photo.checksum) {
                throw const ExportFailure(ExportFailureCode.integrity);
              }
              final archivePath = '$folder/${photo.fileKey}.jpg';
              // Stage the verified bytes so a later source replacement cannot change the ZIP.
              final verified = File(
                path.join(temporary.path, '${draft.id}-${photo.fileKey}.jpg'),
              );
              await verified.writeAsBytes(bytes, flush: true);
              await encoder.addFile(verified, archivePath);
              inventory.add({
                'path': archivePath,
                'sha256': digest,
                'bytes': bytes.length,
              });
            }
          }
          inventory.sort(
            (a, b) => (a['path'] as String).compareTo(b['path'] as String),
          );
          final manifest = File(path.join(temporary.path, 'manifest.json'));
          final manifestBytes = utf8.encode(
            jsonEncode({
              'format': 'atlas-contribution-offline-export',
              'version':
                  rows.any(
                    (row) => (row['document'] as Map)['kind'] == 'photoSet',
                  )
                  ? 4
                  : rows.any((row) {
                      final document = row['document'] as Map;
                      return document['kind'] == 'freeThreeAngle' ||
                          (document['photos'] as List).any(
                            (photo) => (photo as Map)['displayCrop'] != null,
                          );
                    })
                  ? 3
                  : 2,
              'exportedAtUtc': DateTime.now().toUtc().toIso8601String(),
              'recordCount': rows.length,
              'labelVersion': labelVersion,
              'researchOnly': true,
              'files': inventory,
            }),
          );
          await manifest.writeAsBytes(manifestBytes, flush: true);
          metadataFiles.add(manifest);
          await encoder.addFile(manifest, 'manifest.json');
          await encoder.close();
          encoderClosed = true;
          final checksum = 'sha256:${await sha256.bind(zip.openRead()).first}';
          final location = await store.withExportRead(
            () => reviewStore.withExportRead(() async {
              final current = {
                for (final row in await _currentRows()) row['id']: row,
              };
              final blocked = await reviewStore.blockedContributionRoots();
              for (final row in rows) {
                final latest = current[row['id']];
                if (latest == null) {
                  throw const ExportFailure(ExportFailureCode.noRecords);
                }
                if (blocked.contains(row['root_id'])) {
                  throw const ExportFailure(ExportFailureCode.noPermission);
                }
                if (jsonEncode(latest) != jsonEncode(row)) {
                  throw const ExportFailure(ExportFailureCode.preparation);
                }
              }
              return saveResearchExport(
                channel: _channel,
                archive: zip,
                fileName: fileName,
              );
            }),
          );
          return OfflineExportResult(
            fileName: fileName,
            checksum: checksum,
            recordCount: rows.length,
            location: location,
          );
        } finally {
          if (!encoderClosed) {
            try {
              await encoder.close();
            } catch (_) {
              // The incomplete archive is deleted below.
            }
          }
        }
      },
    );
  });
}
