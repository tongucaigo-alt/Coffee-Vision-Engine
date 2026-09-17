import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;

import 'local_store.dart';
import 'models.dart';
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
    final existing = await store.receipts();
    final roots = existing.map((row) => row['root_id']).toSet();
    if (!roots.contains(draft.rootId) && roots.length >= 30) {
      throw const ContributionFailure(
        'Bu telefonda 30 kayıt tamamlandı. Yeni kayıt sınırına ulaşıldı.',
      );
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
      'expires_at': now.add(const Duration(days: 180)).toIso8601String(),
      'local_only': true,
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
  OfflineContributionExporter(this.store, {MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('atlas.contribution/export');

  final DraftStore store;
  final MethodChannel _channel;

  Future<OfflineExportResult> exportToDownloads() async {
    final rows =
        (await store.receipts())
            .where((row) => row['local_only'] == true)
            .toList()
          ..sort((a, b) => (a['id'] as String).compareTo(b['id'] as String));
    if (rows.isEmpty) {
      throw const ContributionFailure(
        'Dışa aktarılacak tamamlanmış kayıt yok.',
      );
    }

    final temporary = await Directory.systemTemp.createTemp(
      'atlas-katki-export-',
    );
    final stamp = DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');
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
        for (final photo in draft.photos) {
          final source = store.file(photo.localName);
          final bytes = await source.readAsBytes();
          final digest = 'sha256:${sha256.convert(bytes)}';
          if (bytes.length != photo.byteLength || digest != photo.checksum) {
            throw const ContributionFailure(
              'Bir fotoğraf doğrulanamadı. Paket oluşturulmadı.',
            );
          }
          final archivePath = '$folder/${photo.fileKey}.jpg';
          await encoder.addFile(source, archivePath);
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
              rows.any((row) {
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
      final location = await _channel.invokeMethod<String>('saveToDownloads', {
        'sourcePath': zip.path,
        'fileName': fileName,
      });
      if (location == null || location.isEmpty) {
        throw const ContributionFailure('Paket telefona kaydedilemedi.');
      }
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
      for (final file in metadataFiles) {
        if (await file.exists()) await file.delete();
      }
      if (await zip.exists()) await zip.delete();
      if (await temporary.exists()) await temporary.delete(recursive: true);
    }
  }
}
