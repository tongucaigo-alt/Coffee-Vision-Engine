import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:atlas_contribution_app/src/atlas_design.dart';
import 'package:atlas_contribution_app/src/contribution_home.dart';
import 'package:atlas_contribution_app/src/offline_contribution.dart';
import 'package:atlas_contribution_app/src/privacy_support.dart';
import 'contribution_save_status_test.dart' show MemoryStore;

void main() {
  setUpAll(() async {
    for (final entry in {
      'Literata': 'assets/brand/Literata.ttf',
      'Plus Jakarta Sans': 'assets/brand/PlusJakartaSans.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      await (FontLoader(
        entry.key,
      )..addFont(rootBundle.load(entry.value))).load();
    }
  });
  for (final size in [
    const Size(800, 600),
    const Size(360, 640),
    const Size(412, 700),
    const Size(640, 360),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'landing actions remain reachable without overflow at $size / $scale',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final root = (await tester.runAsync(
            () => Directory.systemTemp.createTemp('atlas-layout-'),
          ))!;
          addTearDown(() => root.delete(recursive: true));
          final store = MemoryStore(root, null);
          await tester.pumpWidget(
            MaterialApp(
              theme: atlasTheme(),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: ContributionHome(
                store: store,
                service: OfflineContributionService(store),
                modern: true,
                onReadFortune: (_) async {},
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.ensureVisible(find.text('Fincanını Tara'));
          expect(find.text('Fincanını Tara').hitTestable(), findsOneWidget);
          await tester.ensureVisible(find.text('Galeriden Seç'));
          expect(find.text('Galeriden Seç').hitTestable(), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }
  test('only validated public HTTPS/contact values produce external links', () {
    const config = SupportConfiguration(
      operatorName: 'Sentetik işletmeci',
      privacyUrl: 'https://policy.example/privacy',
      supportEmail: 'support@example.test',
    );
    expect(config.https(config.privacyUrl)!.scheme, 'https');
    expect(config.contact!.scheme, 'mailto');
    expect(config.https('http://insecure.example'), isNull);
    expect(config.https('https://user:password@example.test'), isNull);
    expect(
      const SupportConfiguration(
        supportEmail: 'mail@example.test\nBcc:other',
      ).contact,
      isNull,
    );
    expect(const SupportConfiguration().contact, isNull);
    expect(
      const SupportConfiguration(supportEmail: 'xxxx@atlas.com').contact,
      isNull,
    );
  });
  testWidgets(
    'privacy is readable offline and does not promise research export or seven-day deletion',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: PrivacySupportPage(configuration: SupportConfiguration()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Atlas — veri kullanımı ve gizlilik'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Saklama ve silme'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.textContaining('yedi günlük silme kuralı uygulanmıyor'),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.text('İzinler ve yerel kullanım'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.textContaining('Araştırma ZIP dışa aktarımı bu sürümde bulunmaz'),
        findsOneWidget,
      );
      expect(find.textContaining('henüz hazırlanıyor'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'configured support opens its actual address; native failure is visible',
    (tester) async {
      final addresses = <String>[];
      const channel = MethodChannel('atlas.app/links');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            expect(call.method, 'open');
            addresses.add(call.arguments['url'] as String);
            return false;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      await tester.pumpWidget(
        const MaterialApp(home: PrivacySupportPage(support: true)),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('xxxx@atlas.com (henüz etkin değil)'),
        findsOneWidget,
      );
      expect(find.text('Destek Kanalını Aç'), findsNothing);
      expect(addresses, isEmpty);
      await tester.pumpWidget(
        const MaterialApp(
          home: PrivacySupportPage(
            support: true,
            configuration: SupportConfiguration(
              supportUrl: 'https://support.example/help',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Destek Kanalını Aç'));
      await tester.pumpAndSettle();
      expect(addresses, ['https://support.example/help']);
      expect(find.textContaining('Bağlantı açılamadı'), findsOneWidget);
    },
  );
}
