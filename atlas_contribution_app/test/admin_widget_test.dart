import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:atlas_contribution_app/src/admin_workspace.dart';
import 'package:atlas_contribution_app/src/service.dart';
import 'package:atlas_contribution_app/src/theme.dart';
import 'package:atlas_contribution_app/src/models.dart';
import 'fixtures.dart';

class FakeReviewService extends ContributionService {
  FakeReviewService(this.row)
    : super(
        SupabaseClient(
          'https://test.invalid',
          'test-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );
  final Map<String, dynamic> row;
  final calls = <String>[];
  Map<String, dynamic>? review;
  @override
  Future<Map<String, dynamic>> call(
    String action, [
    Map<String, dynamic> data = const {},
  ]) async {
    calls.add(action);
    return switch (action) {
      'adminList' => {
        'rows': [row],
        'reviews': [],
      },
      'adminPhotoUrls' => {
        'urls': {
          for (final r in legacyCaptureRoles)
            r.name: 'https://test.invalid/${r.name}.jpg',
        },
      },
      'review' => {...review = data, 'saved': true},
      _ => throw StateError(action),
    };
  }
}

void main() {
  for (final size in [const Size(360, 800), const Size(1200, 900)]) {
    testWidgets('review workspace at ${size.width} and 200% text', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final d = testDraft(
        photos: [
          for (final r in legacyCaptureRoles)
            testPhoto(r, decision: PhotoDecision.skipped),
        ],
      );
      final service = FakeReviewService({
        'id': d.id,
        'root_id': d.rootId,
        'group_id': d.groupId,
        'revision': 1,
        'submitted_at': d.createdAt,
        'document': d.toJson(),
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: contributionTheme(),
          builder: (c, child) => MediaQuery(
            data: MediaQuery.of(
              c,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: AdminWorkspace(service: service),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Fincan 1 · rev 1'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(service.calls, ['adminList', 'adminPhotoUrls']);
      await tester.scrollUntilVisible(
        find.text('İncelemeyi kaydet'),
        300,
        scrollable: find
            .descendant(
              of: find.byKey(const ValueKey('admin-detail')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('İncelemeyi kaydet'));
      await tester.pumpAndSettle();
      expect(service.review?['outcome'], 'uncertain');
      expect(service.row['document'], d.toJson());
      expect(tester.takeException(), isNull);
    });
  }
}
