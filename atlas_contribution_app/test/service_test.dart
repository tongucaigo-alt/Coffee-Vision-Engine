import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:atlas_contribution_app/src/models.dart';
import 'package:atlas_contribution_app/src/service.dart';
import 'fixtures.dart';

void main() {
  test('submitted reservation retry skips uploads and finalize', () async {
    final calls = <String>[];
    final client = SupabaseClient(
      'https://test.invalid',
      'test-key',
      httpClient: MockClient((request) async {
        final body = jsonDecode(request.body);
        calls.add(body['action']);
        return http.Response(
          jsonEncode({
            'submitted': true,
            'row': {'id': 'test-receipt'},
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    final service = ContributionService(client);
    final draft = testDraft(
      photos: [
        for (final r in legacyCaptureRoles)
          testPhoto(r, decision: PhotoDecision.skipped),
      ],
    );
    final result = await service.submit(
      draft,
      (_) async => throw StateError('must not read'),
      (_) {},
    );
    expect(calls, ['reserve']);
    expect(result['id'], 'test-receipt');
    await client.dispose();
  });
  test(
    'missing uploaded objects resume; only finalize yields receipt',
    () async {
      final calls = <String>[];
      final client = SupabaseClient(
        'https://test.invalid',
        'test-key',
        httpClient: MockClient((request) async {
          final body = jsonDecode(request.body);
          calls.add(body['action']);
          return http.Response(
            jsonEncode(
              body['action'] == 'reserve'
                  ? {'submitted': false, 'uploads': []}
                  : {
                      'row': {'status': 'submitted'},
                    },
            ),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      final draft = testDraft(
        photos: [
          for (final r in legacyCaptureRoles)
            testPhoto(r, decision: PhotoDecision.uncertain),
        ],
      );
      final row = await ContributionService(
        client,
      ).submit(draft, (_) async => Uint8List(0), (_) {});
      expect(calls, ['reserve', 'finalize']);
      expect(row['status'], 'submitted');
      await client.dispose();
    },
  );
  test('no consent-complete photos means no network upload', () async {
    var requests = 0;
    final client = SupabaseClient(
      'https://test.invalid',
      'test-key',
      httpClient: MockClient((request) async {
        requests++;
        return http.Response('{}', 500);
      }),
    );
    await expectLater(
      ContributionService(
        client,
      ).submit(testDraft(), (_) async => Uint8List(0), (_) {}),
      throwsA(isA<ContributionFailure>()),
    );
    expect(requests, 0);
    await client.dispose();
  });
  test('finalize failure cannot report sent', () async {
    final client = SupabaseClient(
      'https://test.invalid',
      'test-key',
      httpClient: MockClient((request) async {
        final reserve = jsonDecode(request.body)['action'] == 'reserve';
        return http.Response(
          jsonEncode(
            reserve
                ? {'submitted': false, 'uploads': []}
                : {'error': 'incomplete'},
          ),
          reserve ? 200 : 400,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    final d = testDraft(
      photos: [
        for (final r in legacyCaptureRoles)
          testPhoto(r, decision: PhotoDecision.notSeen),
      ],
    );
    await expectLater(
      ContributionService(client).submit(d, (_) async => Uint8List(0), (_) {}),
      throwsA(isA<ContributionFailure>()),
    );
    await client.dispose();
  });
}
