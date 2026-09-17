import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:atlas_contribution_app/src/models.dart';
import 'package:atlas_contribution_app/src/local_store.dart';
import 'fixtures.dart';

void main() {
  test('20 fixed research labels and three ordered roles', () {
    expect(contributionLabels.values.toList(), [
      'Kuş',
      'Kalp',
      'Balık',
      'Yılan',
      'Köpek',
      'Kelebek',
      'Ağaç',
      'At',
      'Göz',
      'Taç',
      'Yüzük',
      'Yol',
      'Dağ',
      'Ay',
      'Güneş',
      'Çapa',
      'Ev',
      'İnsan Figürü',
      'Uçak',
      'Çiçek',
    ]);
    expect(legacyCaptureRoles.map((r) => r.name), [
      'top',
      'handleRight',
      'handleLeft',
    ]);
    expect(
      contributionLabels.keys.any((k) => k.startsWith('symbol-')),
      isFalse,
    );
  });
  test('normalized boxes reject invalid values and clamp edits', () {
    for (final b in [
      [-0.1, 0.0, .5, .5],
      [0.0, 0.0, 0.0, .5],
      [.5, .5, .6, .6],
      [double.nan, 0.0, .5, .5],
    ]) {
      expect(() => RegionBox(b[0], b[1], b[2], b[3]), throwsArgumentError);
    }
    final b = RegionBox(.2, .2, .3, .3).move(2, -2);
    expect(b.x, .7);
    expect(b.y, 0);
    expect(b.resize(3, 3).height, 1);
  });
  test('immutable photos, regions and complete role preservation', () {
    final photos = [testPhoto(CaptureRole.top)];
    final d = testDraft(photos: photos);
    photos.clear();
    expect(d.photos.length, 1);
    expect(() => d.photos.clear(), throwsUnsupportedError);
    final second = testPhoto(CaptureRole.handleRight),
        third = testPhoto(CaptureRole.handleLeft);
    final completed = d.withPhoto(second).withPhoto(third);
    expect(completed.complete, true);
    expect(identical(completed.photos[1], second), true);
    final replacement = testPhoto(CaptureRole.handleRight);
    final retake = completed.withPhoto(replacement);
    expect(identical(retake.photos[0], completed.photos[0]), true);
    expect(identical(retake.photos[2], third), true);
    expect(identical(retake.photos[1], replacement), true);
  });
  test('abstentions remain distinct and unknown labels fail', () {
    for (final state in [
      PhotoDecision.notSeen,
      PhotoDecision.uncertain,
      PhotoDecision.skipped,
    ]) {
      final p = testPhoto(CaptureRole.top, decision: state);
      expect(p.toJson()['decision'], state.name);
      expect(p.regions, isEmpty);
    }
    expect(
      () => RegionAnnotation(
        id: 'x',
        box: RegionBox(0, 0, 1, 1),
        label: 'symbol-tree',
      ),
      throwsArgumentError,
    );
    expect(RegionAnnotation(id: 'x', box: RegionBox(0, 0, 1, 1)).label, isNull);
  });
  test('duplicate and excessive regions fail', () {
    final r = RegionAnnotation(
      id: 'x',
      box: RegionBox(0, 0, 1, 1),
      label: 'tree',
    );
    expect(
      () => testPhoto(
        CaptureRole.top,
        decision: PhotoDecision.marked,
        regions: [r, r],
      ),
      throwsArgumentError,
    );
    expect(
      () => testPhoto(
        CaptureRole.top,
        decision: PhotoDecision.marked,
        regions: List.generate(
          11,
          (i) => RegionAnnotation(id: '$i', box: r.box),
        ),
      ),
      throwsArgumentError,
    );
  });
  test('JSON round-trip retains roles, decisions, consent and queue', () {
    final d = testDraft(
      photos: [
        for (final r in legacyCaptureRoles)
          testPhoto(r, decision: PhotoDecision.skipped),
      ],
    ).copy(queued: true);
    final restored = ContributionDraft.fromJson(
      jsonDecode(jsonEncode(d.toJson())),
    );
    expect(restored.toJson(), d.toJson());
    expect(restored.reviewed, true);
    expect(
      () => ContributionDraft.fromJson({
        ...d.toJson(),
        'labelVersion': 'unknown',
      }),
      throwsFormatException,
    );
  });
  test(
    'JPEG derivative is oriented, resized, metadata-free and deterministic',
    () {
      final source = img.Image(width: 2400, height: 1600)
        ..clear(img.ColorRgb8(31, 90, 71));
      source.exif.imageIfd.orientation = 6;
      final original = img.encodeJpg(source);
      final a = preparePhoto(original), b = preparePhoto(original);
      expect(a['width'], 1365);
      expect(a['height'], 2048);
      expect(a['checksum'], b['checksum']);
      final decoded = img.decodeJpg(a['bytes'] as Uint8List)!;
      expect(decoded.exif.imageIfd.orientation, isNull);
      expect(a['checksum'], isNot(a['originalChecksum']));
    },
  );
  group('private durable store', () {
    late Directory dir;
    late DraftStore store;
    setUp(() async {
      dir = await Directory.systemTemp.createTemp('atlas-store-test-');
      store = DraftStore(dir);
      await store.initialize();
    });
    tearDown(() async {
      await dir.delete(recursive: true);
    });
    test('concurrent deletion requests cannot overwrite one another', () async {
      await Future.wait([
        store.queueDelete('root-a'),
        store.queueDelete('root-b'),
      ]);
      expect((await store.pendingDeletes()).toSet(), {'root-a', 'root-b'});
      await store.acknowledgeDelete('root-a');
      expect(await store.pendingDeletes(), ['root-b']);
    });
    test('restart and interrupted primary recover backup', () async {
      final d = testDraft();
      await store.save(d);
      await store.save(d.copy(queued: true));
      expect((await DraftStore(dir).load())!.queued, true);
      await store.file('draft.json').writeAsString('{');
      expect((await store.load())!.id, d.id);
    });
    test(
      'discard cannot resurrect backup and deletes only own orphan images',
      () async {
        final d = testDraft(photos: [testPhoto(CaptureRole.top)]);
        await store.file('top.jpg').writeAsBytes([1]);
        await store.file('unrelated.json').writeAsString('{}');
        await store.save(d);
        await store.clear();
        expect(await store.load(), isNull);
        expect(await store.file('top.jpg').exists(), false);
        expect(await store.file('unrelated.json').exists(), true);
        await store.file('draft.json').writeAsString('{');
        expect(await store.load(), isNull);
      },
    );
    test('unsafe paths and corrupt primary plus backup fail closed', () async {
      expect(() => store.file('../image.jpg'), throwsArgumentError);
      expect(() => store.file('C:\\private.jpg'), throwsArgumentError);
      await store.file('draft.json').writeAsString('{');
      await store.file('draft.bak').writeAsString('{');
      await expectLater(store.load(), throwsFormatException);
    });
    test(
      'withdrawal is queued idempotently and removes cached receipt',
      () async {
        final d = testDraft();
        await store.saveReceipt({
          'id': d.id,
          'root_id': d.rootId,
          'document': d.toJson(),
          'expires_at': DateTime.now()
              .add(const Duration(days: 1))
              .toIso8601String(),
        });
        await store.queueDelete(d.rootId);
        await store.queueDelete(d.rootId);
        expect((await store.pendingDeletes()).length, 1);
        await store.acknowledgeDelete(d.rootId);
        expect(await store.receipts(), isEmpty);
        expect(await store.pendingDeletes(), isEmpty);
      },
    );
  });
}
