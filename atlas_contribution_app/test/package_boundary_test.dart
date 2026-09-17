import 'dart:io';
import 'dart:convert';
import 'package:atlas_contribution_app/src/models.dart';
import 'package:atlas_contribution_app/src/client_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android identity fails closed for generated test listener targets', () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    expect(gradle, contains('atlasProductionTargets.none'));
    expect(
      gradle,
      contains('listOf("lib/main.dart", "lib/offline_main.dart")'),
    );
    expect(gradle, contains('atlasTarget.endsWith("/\$it")'));
    expect(
      gradle,
      contains('com.coffeeplatform.atlas_contribution_app.diagnostic'),
    );
    expect(gradle, isNot(contains('contains("integration_test/")')));
  });
  test('client configuration rejects privileged keys', () {
    expect(isPublicClientKey('sb_publishable_test'), true);
    expect(isPublicClientKey('sb_secret_test'), false);
    String jwt(String role) =>
        'header.${base64Url.encode(utf8.encode(jsonEncode({'role': role})))}.signature';
    expect(isPublicClientKey(jwt('anon')), true);
    expect(isPublicClientKey(jwt('service_role')), false);
  });
  test('versioned vocabulary and mobile choices match exactly', () {
    final data = jsonDecode(
      File('assets/contribution-labels-v1.json').readAsStringSync(),
    );
    expect(data['version'], labelVersion);
    expect(
      (data['labels'] as List).map((r) => r['id']),
      contributionLabels.keys,
    );
    expect(
      (data['labels'] as List).map((r) => r['tr']),
      contributionLabels.values,
    );
  });
  test('only app-local MVP adapter imports public engine; no WIP or K6', () {
    for (final f
        in Directory('lib')
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))) {
      final text = f.readAsStringSync();
      final engineAdapter = f.path
          .replaceAll('\\', '/')
          .endsWith('/mvp/review_engine.dart');
      expect(
        text,
        isNot(matches(r"package:(coffee_source|atlas_k6)")),
        reason: f.path,
      );
      expect(
        text,
        isNot(matches(r"package:coffee_[^/]+/src/")),
        reason: f.path,
      );
      if (!engineAdapter) {
        expect(
          text,
          isNot(
            matches(
              r"package:(coffee_vision|coffee_pattern|coffee_knowledge|coffee_symbol|coffee_source|atlas_k6)",
            ),
          ),
          reason: f.path,
        );
      }
      expect(
        text,
        isNot(contains('SUPABASE_SERVICE_ROLE_KEY')),
        reason: f.path,
      );
    }
  });
  test(
    'camera uses the public one-capture API and independent app identity',
    () {
      final source = File('lib/src/contribution_home.dart').readAsStringSync();
      expect('showCoffeeCamera('.allMatches(source).length, 1);
      expect(source, isNot(contains('showCoffeeCameraFlow(')));
      expect(
        File('android/app/build.gradle.kts').readAsStringSync(),
        contains('com.coffeeplatform.atlas_contribution_app'),
      );
      expect(
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync(),
        contains('android:allowBackup="false"'),
      );
    },
  );
}
