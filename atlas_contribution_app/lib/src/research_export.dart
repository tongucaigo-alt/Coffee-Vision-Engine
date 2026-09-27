import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

typedef ExportDirectoryProvider = Future<Directory> Function();

enum ExportFailureCode { noRecords, noPermission, integrity, preparation, save }

final class ExportFailure implements Exception {
  const ExportFailure(this.code);

  final ExportFailureCode code;

  String get message => switch (code) {
    ExportFailureCode.noRecords => 'Dışa aktarılacak güncel kayıt yok.',
    ExportFailureCode.noPermission =>
      'Araştırma için dışa aktarma izni olan kayıt yok. İnceleme ekranından iznini yönetebilirsin.',
    ExportFailureCode.integrity =>
      'Bir kayıt veya fotoğraf doğrulanamadı. Paket oluşturulmadı; kayıtların telefonda duruyor.',
    ExportFailureCode.preparation =>
      'Paket hazırlanamadı veya kayıtlar hazırlanırken değişti. Tekrar deneyebilirsin.',
    ExportFailureCode.save =>
      'Paket telefona kaydedilemedi. Boş alanı kontrol edip tekrar deneyebilirsin.',
  };

  @override
  String toString() => message;
}

String exportFailureMessage(Object error) => error is ExportFailure
    ? error.message
    : const ExportFailure(ExportFailureCode.preparation).message;

String exportDestinationLabel(String location) =>
    location.startsWith('content://')
    ? 'İndirilenler klasörüne'
    : 'uygulamanın İndirilenler klasörüne';

/// Converts internal errors without exposing private paths or platform details.
Future<T> guardExport<T>(Future<T> Function() operation) async {
  try {
    return await operation();
  } on ExportFailure {
    rethrow;
  } on FormatException {
    throw const ExportFailure(ExportFailureCode.integrity);
  } catch (_) {
    throw const ExportFailure(ExportFailureCode.preparation);
  }
}

/// path_provider and Android's native cache guard refer to the same directory.
Future<T> withExportStaging<T>({
  required String prefix,
  required Future<T> Function(Directory directory) operation,
  ExportDirectoryProvider? temporaryDirectory,
}) => guardExport(() async {
  Directory? staging;
  try {
    final root = await (temporaryDirectory ?? getTemporaryDirectory)();
    staging = await root.createTemp(prefix);
    return await operation(staging);
  } finally {
    if (staging != null) {
      try {
        if (await staging.exists()) await staging.delete(recursive: true);
      } catch (_) {
        // Cache cleanup must not turn a successful published export into failure.
      }
    }
  }
});

Future<String> saveResearchExport({
  required MethodChannel channel,
  required File archive,
  required String fileName,
}) async {
  try {
    final location = await channel.invokeMethod<String>('saveToDownloads', {
      'sourcePath': archive.path,
      'fileName': fileName,
    });
    if (location == null || location.isEmpty) {
      throw const ExportFailure(ExportFailureCode.save);
    }
    return location;
  } catch (_) {
    throw const ExportFailure(ExportFailureCode.save);
  }
}
