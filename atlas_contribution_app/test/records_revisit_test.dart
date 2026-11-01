import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:atlas_contribution_app/src/atlas_design.dart';
import 'package:atlas_contribution_app/src/contribution_home.dart';
import 'package:atlas_contribution_app/src/offline_contribution.dart';
import 'package:atlas_contribution_app/src/record_summary.dart';
import 'package:atlas_contribution_app/src/local_revision_cache.dart';
import 'package:atlas_contribution_app/src/tarot/tarot_models.dart';
import 'package:atlas_contribution_app/src/tarot/tarot_pages.dart';
import 'package:atlas_contribution_app/src/tarot/tarot_runtime.dart';
import 'package:atlas_contribution_app/src/tarot/tarot_store.dart';
import 'contribution_save_status_test.dart' show MemoryStore;
import 'fixtures.dart';
import 'tarot_test.dart' show fixture, catalog;

class RevisitStore extends MemoryStore {
  RevisitStore() : super(Directory('unused-revisit-fixture'), null);
  int reads = 0;
  List<String> pending = [];
  @override
  Future<List<Map<String, dynamic>>> receipts() async {
    reads++;
    return rows;
  }

  @override
  Future<List<String>> pendingDeletes() async => pending;
}

class RevisitTarotStore extends TarotStore {
  RevisitTarotStore() : super(Directory('unused-tarot-revisit-fixture'));
  int reads = 0;
  List<TarotDraw> rows = [for (var i = 0; i < 10; i++) fixture(id: 'draw$i')];
  @override
  Future<List<TarotDraw>> draws() async {
    reads++;
    return rows;
  }
}

void main() {
  Future<void> selectTab(WidgetTester tester, String name) async {
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text(name),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'coffee top tab and detail reuse data, filter and scroll; changes invalidate',
    (tester) async {
      tester.view.physicalSize = const Size(412, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = RevisitStore();
      final draft = testDraft();
      store.rows.addAll([
        for (var i = 0; i < 20; i++)
          {
            'id': 'receipt$i',
            'root_id': 'root$i',
            'local_only': true,
            'document': draft.toJson(),
          },
      ]);
      var batches = 0, generations = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: atlasTheme(),
          home: ContributionHome(
            modern: true,
            store: store,
            service: OfflineContributionService(store),
            loadRecordSummaries: (rows) async {
              batches++;
              return {
                for (final row in rows)
                  row['root_id'] as String: const RecordSummary(
                    state: 'Fal hazır',
                    starred: true,
                  ),
              };
            },
            onReadFortune: (_) async {},
            onGenerateFortune: (_) async {
              generations++;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await selectTab(tester, 'Kayıtlarım');
      await tester.ensureVisible(find.text('Yıldızlılar'));
      await tester.tap(find.text('Yıldızlılar'));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, -650));
      await tester.pumpAndSettle();
      final offset = tester
          .state<ScrollableState>(
            find
                .descendant(
                  of: find.byType(ListView),
                  matching: find.byType(Scrollable),
                )
                .first,
          )
          .position
          .pixels;
      expect(offset, greaterThan(0));
      final reads = store.reads;
      await selectTab(tester, 'Kahve');
      await selectTab(tester, 'Kayıtlarım');
      expect(batches, 1);
      expect(store.reads, reads);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      final restored = tester
          .state<ScrollableState>(
            find
                .descendant(
                  of: find.byType(ListView),
                  matching: find.byType(Scrollable),
                )
                .first,
          )
          .position
          .pixels;
      expect(restored, closeTo(offset, 1));
      final filter = tester.widget<TextButton>(
        find.ancestor(
          of: find.text('Yıldızlılar'),
          matching: find.byType(TextButton),
        ),
      );
      expect(filter.style!.backgroundColor!.resolve({}), atlasCoffee);
      await tester.tap(find.text('Fincanın Hikâyesi').hitTestable().first);
      await tester.pumpAndSettle();
      expect(batches, 1);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(batches, 1);
      expect(generations, 0);
      await selectTab(tester, 'Kahve');
      store.pending = ['root0'];
      store.rows.add({...store.rows.last, 'root_id': 'new-root'});
      markLocalDataChanged();
      await selectTab(tester, 'Kayıtlarım');
      expect(batches, 2);
      expect(store.reads, reads + 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Tarot section, filter and scroll survive leaving the records top tab',
    (tester) async {
      tester.view.physicalSize = const Size(412, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = RevisitStore();
      final tarotStore = RevisitTarotStore();
      final runtime = TarotRuntime(
        store: tarotStore,
        catalog: catalog(),
        generateReading: (_, _) async {
          fail('Revisit must not generate');
        },
        promptVersion: 'fixture',
        promptHash: 'fixture',
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: atlasTheme(),
          home: ContributionHome(
            modern: true,
            store: store,
            service: OfflineContributionService(store),
            tarotPage: const Center(child: Text('Tarot landing fixture')),
            tarotHistoryPage: TarotHistoryPage(
              runtime: runtime,
              embedded: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await selectTab(tester, 'Kayıtlarım');
      await tester.tap(
        find.descendant(
          of: find.byType(SegmentedButton<int>),
          matching: find.text('Tarot'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.drag(
        find.byKey(const PageStorageKey('atlas-tarot-history-scroll')),
        const Offset(0, -500),
      );
      await tester.pumpAndSettle();
      final scrollFinder = find.descendant(
        of: find.byKey(const PageStorageKey('atlas-tarot-history-scroll')),
        matching: find.byType(Scrollable),
      );
      final offset = tester
          .state<ScrollableState>(scrollFinder)
          .position
          .pixels;
      expect(offset, greaterThan(0));
      await selectTab(tester, 'Kahve');
      await selectTab(tester, 'Kayıtlarım');
      expect(tarotStore.reads, 1);
      expect(
        tester.state<ScrollableState>(scrollFinder).position.pixels,
        closeTo(offset, 1),
      );
      await tester.drag(
        find.byKey(const PageStorageKey('atlas-tarot-history-scroll')),
        const Offset(0, 1000),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Yıldızlılar · 0/20'));
      await tester.pumpAndSettle();
      await selectTab(tester, 'Kahve');
      await selectTab(tester, 'Kayıtlarım');
      expect(
        tester
            .widget<ChoiceChip>(
              find.ancestor(
                of: find.text('Yıldızlılar · 0/20'),
                matching: find.byType(ChoiceChip),
              ),
            )
            .selected,
        isTrue,
      );
      expect(tarotStore.reads, 1);
      await selectTab(tester, 'Kahve');
      tarotStore.rows = [];
      markLocalDataChanged();
      await selectTab(tester, 'Kayıtlarım');
      expect(tarotStore.reads, 2);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('replacing a coffee storage owner cannot retain previous rows', (
    tester,
  ) async {
    final first = RevisitStore(), second = RevisitStore();
    final draft = testDraft();
    first.rows.add({'root_id': 'old', 'document': draft.toJson()});
    second.rows.addAll([
      for (var i = 0; i < 2; i++)
        {'root_id': 'new$i', 'document': draft.toJson()},
    ]);
    Widget home(RevisitStore store) => MaterialApp(
      theme: atlasTheme(),
      home: ContributionHistory(
        store: store,
        service: OfflineContributionService(store),
        canStart: false,
        onRepeat: (_) async {},
        onEdit: (_) async {},
        modern: true,
      ),
    );
    await tester.pumpWidget(home(first));
    await tester.pumpAndSettle();
    expect(find.text('Fincanın Hikâyesi'), findsOneWidget);
    await tester.pumpWidget(home(second));
    await tester.pumpAndSettle();
    expect(find.text('Fincanın Hikâyesi'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });
  testWidgets('replacing a Tarot runtime cannot retain the previous session', (
    tester,
  ) async {
    final first = RevisitTarotStore(), second = RevisitTarotStore();
    first.rows = [fixture()];
    second.rows = [fixture(spread: TarotSpread.daily)];
    TarotRuntime runtime(RevisitTarotStore store) => TarotRuntime(
      store: store,
      catalog: catalog(),
      generateReading: (_, _) async => 'unused',
      promptVersion: 'fixture',
      promptHash: 'fixture',
    );
    Widget home(TarotRuntime runtime) => MaterialApp(
      theme: atlasTheme(),
      home: TarotHistoryPage(runtime: runtime),
    );
    await tester.pumpWidget(home(runtime(first)));
    await tester.pumpAndSettle();
    expect(find.textContaining('Üç Kart ·'), findsOneWidget);
    await tester.pumpWidget(home(runtime(second)));
    await tester.pumpAndSettle();
    expect(find.textContaining('Üç Kart ·'), findsNothing);
    expect(find.textContaining('Günün Kartı ·'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
