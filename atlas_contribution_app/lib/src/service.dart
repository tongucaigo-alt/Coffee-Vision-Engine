import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'models.dart';

class ContributionFailure implements Exception {
  const ContributionFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

abstract interface class ContributionBackend {
  bool get isOffline;
  Future<Map<String, dynamic>> call(
    String action, [
    Map<String, dynamic> data = const {},
  ]);
  Future<List<Map<String, dynamic>>> list({bool admin = false});
  Future<Map<String, dynamic>> submit(
    ContributionDraft draft,
    Future<Uint8List> Function(ContributionPhoto) read,
    void Function(int complete) progress,
  );
  Future<void> delete(String rootId);
  Future<Map<String, String>> photoUrls(String id);
  Future<Uint8List> readPhoto(String id, ContributionPhoto photo);
}

class ContributionService implements ContributionBackend {
  ContributionService(this.client);
  final SupabaseClient client;
  @override
  bool get isOffline => false;
  @override
  Future<Uint8List> readPhoto(String id, ContributionPhoto photo) => client
      .storage
      .from('contributions')
      .download('${client.auth.currentUser!.id}/$id/${photo.fileKey}.jpg');
  @override
  Future<Map<String, dynamic>> call(
    String action, [
    Map<String, dynamic> data = const {},
  ]) async {
    try {
      final response = await client.functions.invoke(
        'contribution-api',
        body: {'action': action, ...data},
      );
      final result = Map<String, dynamic>.from(response.data as Map);
      if (result['error'] != null) {
        throw ContributionFailure(_message(result['error'].toString()));
      }
      return result;
    } on FunctionException catch (e) {
      final details = e.details;
      final code = details is Map ? details['error']?.toString() : null;
      throw ContributionFailure(_message(code ?? 'offline'));
    } on ContributionFailure {
      rethrow;
    } catch (_) {
      throw const ContributionFailure(
        'Bağlantı kurulamadı. Çalışman telefonda duruyor.',
      );
    }
  }

  static String _message(String code) => switch (code) {
    'invite_invalid' => 'Davet kodunu kontrol et veya davet eden kişiye ulaş.',
    'not_enrolled' => 'Davetin henüz etkin değil. Davet kodunu tekrar gir.',
    'quota' => 'Bu deneme için yeterli katkı toplandı. Teşekkür ederiz.',
    'conflict' => 'Bu kayıt değişmiş. Gönderdiklerim ekranını yenile.',
    'revoked' => 'Bu katkı silinmiş veya kullanım izni geri çekilmiş.',
    'invalid_payload' =>
      'Gönderim bilgileri tamamlanamadı. Fotoğrafları ve işaretleri kontrol et.',
    'incomplete' =>
      'Fotoğrafların tamamı ulaşmadı. Tekrar gönder; taslağın korundu.',
    'forbidden' => 'Bu işlem için erişimin bulunmuyor.',
    _ => 'Bağlantı kurulamadı. Çalışman telefonda duruyor.',
  };
  Future<void> enroll(String code) async {
    await call('enroll', {'code': code});
  }

  @override
  Future<List<Map<String, dynamic>>> list({bool admin = false}) async {
    final result = await call(admin ? 'adminList' : 'list');
    return (result['rows'] as List)
        .map((r) => Map<String, dynamic>.from(r as Map))
        .toList();
  }

  @override
  Future<Map<String, dynamic>> submit(
    ContributionDraft draft,
    Future<Uint8List> Function(ContributionPhoto) read,
    void Function(int complete) progress,
  ) async {
    if (draft.isGallery) {
      throw const ContributionFailure(
        'Galeri kayıtları yalnız telefonda saklanabilir.',
      );
    }
    if (draft.kind != ContributionKind.threeAngle ||
        draft.photos.any((photo) => photo.displayCrop != null)) {
      throw const ContributionFailure(
        'Bu çekim kaydı yalnız telefonda saklanabilir.',
      );
    }
    if (!draft.reviewed) {
      throw const ContributionFailure('Önce üç fotoğrafı gözden geçir.');
    }
    final result = await call('reserve', {
      'document': draft.copy(queued: false).toJson(),
    });
    if (result['submitted'] == true) {
      return Map<String, dynamic>.from(result['row'] as Map);
    }
    final uploads = result['uploads'] as List;
    for (var i = 0; i < uploads.length; i++) {
      final upload = uploads[i] as Map;
      final photo = draft.photo(
        CaptureRole.values.byName(upload['role'] as String),
      )!;
      await client.storage
          .from('contributions')
          .uploadBinaryToSignedUrl(
            upload['path'] as String,
            upload['token'] as String,
            await read(photo),
            const FileOptions(contentType: 'image/jpeg', upsert: false),
          );
      progress(i + 1);
    }
    return Map<String, dynamic>.from(
      (await call('finalize', {'id': draft.id}))['row'] as Map,
    );
  }

  @override
  Future<void> delete(String rootId) async {
    await call('withdraw', {'rootId': rootId});
  }

  @override
  Future<Map<String, String>> photoUrls(String id) async {
    final r = await call('photoUrls', {'id': id});
    return Map<String, String>.from(r['urls'] as Map);
  }
}
