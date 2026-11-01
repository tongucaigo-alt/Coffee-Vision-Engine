import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:atlas_contribution_app/src/atlas_design.dart';
import 'package:atlas_contribution_app/src/contribution_home.dart';
import 'package:atlas_contribution_app/src/offline_contribution.dart';
import 'package:atlas_contribution_app/src/record_summary.dart';
import 'contribution_save_status_test.dart' show MemoryStore;
import 'fixtures.dart';
import 'package:atlas_contribution_app/src/local_revision_cache.dart';

class HistoryStore extends MemoryStore {
  HistoryStore() : super(Directory('unused-record-summary-fixture'), null);
  List<String> pending = [];
  @override
  Future<List<String>> pendingDeletes() async => pending;
}

void main() {
  late HistoryStore store;
  late Map<String, dynamic> row;
  setUp(() {
    store = HistoryStore();
    final draft = testDraft();
    row = {
      'id': draft.id,
      'root_id': draft.rootId,
      'document': draft.toJson(),
      'local_only': true,
    };
    store.rows.add(row);
  });

  Future<void> mount(WidgetTester tester, Widget home) =>
      tester.pumpWidget(MaterialApp(theme: atlasTheme(), home: home));

  testWidgets(
    'home, detail and return use batches; saved read never generates',
    (tester) async {
      tester.view.physicalSize = const Size(412, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var batches = 0, reads = 0, generations = 0;
      var state = 'Fal hazır';
      final root = row['root_id'] as String;
      await mount(
        tester,
        ContributionHome(
          modern: true,
          store: store,
          service: OfflineContributionService(store),
          recordState: (_) async {
            fail('Legacy per-record status should not run');
          },
          recordStarred: (_) async {
            fail('Legacy per-record star should not run');
          },
          loadRecordSummaries: (rows) async {
            batches++;
            expect(rows.map((r) => r['root_id']), [root]);
            return {root: RecordSummary(state: state, starred: true)};
          },
          onReadFortune: (_) async {
            reads++;
          },
          onGenerateFortune: (_) async {
            generations++;
          },
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Kayıtlarım'),
        ),
      );
      await tester.pumpAndSettle();
      expect(batches, 1);
      expect(find.text('★ · Fal hazır'), findsOneWidget);
      await tester.tap(find.text('Fincanın Hikâyesi'));
      await tester.pumpAndSettle();
      expect(batches, 1);
      await tester.tap(find.text('Falını Oku'));
      await tester.pumpAndSettle();
      expect(reads, 1);
      expect(generations, 0);
      state = 'Önceki kayda ait fal';
      markLocalDataChanged();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(batches, 2);
      expect(find.text('★ · Önceki kayda ait fal'), findsOneWidget);
      await tester.ensureVisible(find.text('Yıldızlılar'));
      await tester.tap(find.text('Yıldızlılar'));
      await tester.pumpAndSettle();
      expect(find.text('Fincanın Hikâyesi'), findsOneWidget);
      expect(generations, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'failed batch releases busy state and only offers saved reading',
    (tester) async {
      var reads = 0, generations = 0;
      await mount(
        tester,
        ContributionHistory(
          store: store,
          service: OfflineContributionService(store),
          modern: true,
          onlyRoot: row['root_id'] as String,
          canStart: false,
          onRepeat: (_) async {},
          onEdit: (_) async {},
          loadRecordSummaries: (_) async =>
              throw const FormatException('Unreadable registry'),
          onReadFortune: (_) async {
            reads++;
          },
          onGenerateFortune: (_) async {
            generations++;
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.text(RecordSummary.unreadable), findsOneWidget);
      expect(find.text('Fal Oluştur'), findsNothing);
      await tester.tap(find.text('Kayıtlı Falları Oku'));
      await tester.pumpAndSettle();
      expect(reads, 1);
      expect(generations, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('pending deletions and detail scope are filtered before batch', (
    tester,
  ) async {
    store.rows.add({...row, 'root_id': 'pending'});
    store.rows.add({...row, 'root_id': 'other'});
    store.pending = ['pending'];
    final root = row['root_id'] as String;
    await mount(
      tester,
      ContributionHistory(
        store: store,
        service: OfflineContributionService(store),
        modern: true,
        onlyRoot: root,
        canStart: false,
        onRepeat: (_) async {},
        onEdit: (_) async {},
        loadRecordSummaries: (rows) async {
          expect(rows.map((r) => r['root_id']), [root]);
          return {
            root: const RecordSummary(state: 'Fal hazır', starred: false),
          };
        },
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Fal hazır'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'leaving before batch completes cannot publish into disposed UI',
    (tester) async {
      final pending = Completer<Map<String, RecordSummary>>();
      await mount(
        tester,
        ContributionHistory(
          store: store,
          service: OfflineContributionService(store),
          modern: true,
          canStart: false,
          onRepeat: (_) async {},
          onEdit: (_) async {},
          loadRecordSummaries: (_) => pending.future,
        ),
      );
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      pending.complete({});
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
