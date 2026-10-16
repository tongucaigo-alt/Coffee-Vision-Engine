import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:atlas_contribution_app/src/models.dart';
import 'package:atlas_contribution_app/src/photo_crop.dart';
import 'package:atlas_contribution_app/src/opencv_traces.dart';
import 'package:atlas_contribution_app/src/trace_overlay.dart';
import 'package:atlas_contribution_app/src/fortune_progress.dart';
import 'package:atlas_contribution_app/src/fortune_preparation.dart';
import 'fixtures.dart';

Map<String, dynamic> validResult() => {
  'width': 100,
  'height': 100,
  'durationMs': 1,
  'candidates': [
    {
      'id': 1,
      'score': 10.0,
      'aspect': 1.0,
      'box': [40, 40, 10, 10],
      'pixels': [
        for (var y = 40; y < 50; y++)
          for (var x = 40; x < 50; x++) y * 100 + x,
      ],
      'boundary': [4040, 4041],
      'signature': List.filled(64, 1),
    },
  ],
};
ContributionPhoto photo({
  PhotoCrop? crop,
  PhotoSurface surface = PhotoSurface.cup,
}) {
  final j = testPhoto(
    CaptureRole.free,
    decision: PhotoDecision.marked,
    regions: [
      RegionAnnotation(
        id: 'user',
        box: RegionBox(.4, .4, .1, .1),
        label: 'bird',
      ),
    ],
  ).toJson();
  j['checksum'] = 'sha256:${sha256.convert(testImage())}';
  if (crop != null) j['displayCrop'] = crop.toJson();
  if (surface == PhotoSurface.saucer) {
    j['id'] = 'saucer';
    j['surface'] = 'saucer';
    j['declaredRole'] = null;
  }
  return ContributionPhoto.fromJson(j);
}

TraceSet setFor(ContributionPhoto p) {
  final result = validResult();
  return TraceSet(
    [p],
    [TraceCandidate(0, result, result['candidates'][0], p.visibleCrop)],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(
    () => messenger.setMockMethodCallHandler(TraceService.channel, null),
  );

  test(
    'V76 never reuses a V75 mask cached for the same photo and crop',
    () async {
      final dir = await Directory.systemTemp.createTemp('trace-v76-version-');
      addTearDown(() => dir.delete(recursive: true));
      final p = photo();
      final source = File('${dir.path}/photo.jpg')
        ..writeAsBytesSync(testImage());
      final owner = sha256.convert(utf8.encode('owner')).toString();
      final oldIdentity =
          '${p.checksum}|opencv-4.13-traces-v3-cup-domain|${jsonEncode(p.visibleCrop.toJson())}';
      final oldName = sha256.convert(utf8.encode(oldIdentity)).toString();
      final folder = Directory('${dir.path}/cache/$owner')
        ..createSync(recursive: true);
      final old = File('${folder.path}/$oldName.json')
        ..writeAsStringSync(jsonEncode(validResult()));
      final oldBytes = old.readAsBytesSync();
      var calls = 0;
      messenger.setMockMethodCallHandler(TraceService.channel, (_) async {
        calls++;
        return {...validResult(), 'candidates': []};
      });
      final service = TraceService(Directory('${dir.path}/cache'));
      expect(
        (await service.analyze('owner', source, p))['candidates'],
        isEmpty,
      );
      expect(
        (await service.analyze('owner', source, p))['candidates'],
        isEmpty,
      );
      expect(calls, 1);
      expect(old.readAsBytesSync(), oldBytes);
    },
  );

  test(
    'selective experiment is off by default and owns a separate cache',
    () async {
      expect(adaptiveTracesEnabled, isFalse);
      final dir = await Directory.systemTemp.createTemp('trace-selective-');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/original.jpg')
        ..writeAsBytesSync(testImage());
      final requests = <Map>[];
      messenger.setMockMethodCallHandler(TraceService.channel, (call) async {
        requests.add(call.arguments as Map);
        return validResult();
      });
      final cache = Directory('${dir.path}/cache');
      final baseline = TraceService(cache);
      final selective = TraceService(cache, adaptive: true);
      final p = photo();
      await baseline.analyze('same-owner', file, p);
      await selective.analyze('same-owner', file, p);
      await selective.analyze('same-owner', file, p);
      await baseline.analyze('same-owner', file, p);
      expect(requests, hasLength(2));
      expect(requests.first.containsKey('adaptive'), isFalse);
      expect(requests.last['adaptive'], isTrue);
      expect(
        requests.first['coordinateSpace'],
        requests.last['coordinateSpace'],
      );
      final files = await cache
          .list(recursive: true)
          .where((e) => e is File)
          .toList();
      expect(files, hasLength(2));
    },
  );

  test('invalid native/cache dimensions, masks and bounds are rejected', () {
    expect(validateTraceResult(validResult())['width'], 100);
    for (final change in <void Function(Map)>[
      (r) => r['width'] = 513,
      (r) => r['candidates'][0]['pixels'] = [10000],
      (r) => r['candidates'][0]['boundary'] = [5000],
      (r) => r['candidates'][0]['box'] = [95, 40, 10, 10],
      (r) => r['candidates'][0]['signature'] = [1],
      (r) => r['cupBoundary'] = [20, 20, 0, 30, 0],
      (r) => r['cupBoundary'] = [20, 20, 30, 30],
    ]) {
      final r = validResult();
      change(r);
      expect(() => validateTraceResult(r), throwsFormatException);
    }
  });

  test(
    'cache is separate, validates bytes, invalidates crop, deletes by owner',
    () async {
      final dir = await Directory.systemTemp.createTemp('trace-cache-');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/original.jpg')
        ..writeAsBytesSync(testImage());
      final p = photo();
      final before = jsonEncode(p.toJson());
      var calls = 0;
      messenger.setMockMethodCallHandler(TraceService.channel, (_) async {
        calls++;
        return validResult();
      });
      final service = TraceService(Directory('${dir.path}/cache'));
      await service.analyze('session', file, p);
      await service.analyze('session', file, p);
      expect(calls, 1);
      await service.analyze(
        'session',
        file,
        photo(crop: PhotoCrop(.1, .1, .8, .8)),
      );
      expect(calls, 2);
      final cacheFiles = await service.directory
          .list(recursive: true)
          .where((e) => e is File)
          .toList();
      expect(cacheFiles, hasLength(2));
      for (final cache in cacheFiles) {
        await (cache as File).writeAsString('{}');
      }
      await service.analyze('session', file, p);
      expect(calls, 3);
      expect(await file.readAsBytes(), testImage());
      expect(jsonEncode(p.toJson()), before);
      await service.deleteOwner('session');
      expect(await service.directory.list(recursive: true).toList(), isEmpty);
      await expectLater(
        service.analyze('session', file, p),
        throwsFormatException,
      );
      await file.writeAsBytes([1, 2, 3]);
      await expectLater(
        service.analyze('other', file, p),
        throwsFormatException,
      );
      expect(calls, 3);
    },
  );

  test(
    'pending deletion cannot recreate cache; duplicate native work is shared',
    () async {
      final dir = await Directory.systemTemp.createTemp('trace-deletion-');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/original.jpg')
        ..writeAsBytesSync(testImage());
      final service = TraceService(Directory('${dir.path}/cache'));
      final entered = Completer<void>(),
          reply = Completer<Map<String, dynamic>>();
      var calls = 0;
      messenger.setMockMethodCallHandler(TraceService.channel, (_) {
        calls++;
        entered.complete();
        return reply.future;
      });
      final first = service.analyze('deleted', file, photo());
      final assertion = expectLater(first, throwsFormatException);
      await entered.future;
      final second = service.analyze('deleted', file, photo());
      final secondAssertion = expectLater(second, throwsFormatException);
      await service.deleteOwner('deleted');
      reply.complete(validResult());
      await assertion;
      await secondAssertion;
      expect(calls, 1);
      expect(await service.directory.exists(), isFalse);
    },
  );

  test(
    'native error is optional, saucers skipped, cancellation stops further photos',
    () async {
      final dir = await Directory.systemTemp.createTemp('trace-failure-');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/original.jpg')
        ..writeAsBytesSync(testImage());
      var cancelled = false, calls = 0;
      messenger.setMockMethodCallHandler(TraceService.channel, (_) async {
        calls++;
        cancelled = true;
        throw PlatformException(code: 'failure');
      });
      final result = await TraceService(Directory('${dir.path}/cache')).loadSet(
        owner: 'test',
        photos: [
          photo(),
          photo(),
          photo(surface: PhotoSurface.saucer),
        ],
        fileFor: (_) => file,
        isCancelled: () => cancelled,
      );
      expect(calls, 1);
      expect(result.selected, isEmpty);
      expect(result.failures, 1);
    },
  );

  test(
    'a native timeout releases the caller but does not enqueue duplicate work',
    () async {
      final dir = await Directory.systemTemp.createTemp('trace-timeout-');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/original.jpg')
        ..writeAsBytesSync(testImage());
      final service = TraceService(
        Directory('${dir.path}/cache'),
        timeout: const Duration(seconds: 1),
      );
      final entered = Completer<void>(),
          reply = Completer<Map<String, dynamic>>();
      var calls = 0;
      messenger.setMockMethodCallHandler(TraceService.channel, (_) {
        calls++;
        if (!entered.isCompleted) entered.complete();
        return reply.future;
      });
      final first = service.analyze('one', file, photo());
      final timedOut = expectLater(first, throwsA(isA<TimeoutException>()));
      await entered.future.timeout(const Duration(seconds: 5));
      await timedOut;
      await expectLater(
        service.analyze('two', file, photo()),
        throwsA(isA<TimeoutException>()),
      );
      expect(calls, 1);
      reply.complete(validResult());
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await service.analyze('three', file, photo());
      expect(calls, 2);
    },
  );

  test('hit test follows mask and full-photo crop, not just bounding box', () {
    final p = photo(crop: PhotoCrop(.1, .2, .8, .6));
    final set = setFor(p);
    expect(traceAt(set, p, const Offset(.46, .47)), same(set.selected.first));
    expect(traceAt(set, p, const Offset(.1, .2)), isNull);
    expect(traceAt(set, photo(), const Offset(.46, .47)), isNull);
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'compact photo, one tap closeup and original toggle at scale $scale',
      (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final p = photo();
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: Scaffold(
              body: SingleChildScrollView(
                child: TracePhotoViewer(
                  photo: p,
                  image: MemoryImage(testImage()),
                  set: setFor(p),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(TracePhoto), findsOneWidget);
        final bounds = tester.getRect(find.byType(TracePhoto));
        await tester.tapAt(
          Offset(
            bounds.left + bounds.width * .45,
            bounds.top + bounds.height * .45,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Telve izi'), findsOneWidget);
        expect(find.byType(TracePhoto), findsNWidgets(2));
        await tester.ensureVisible(find.text('Kapat'));
        await tester.tap(find.text('Kapat'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Orijinal'));
        await tester.pumpAndSettle();
        expect(
          tester.widget<TracePhoto>(find.byType(TracePhoto)).colored,
          isFalse,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('highlighting updates preserve one preparation animation state', (
    tester,
  ) async {
    final progress = ValueNotifier(const FortuneProgress(FortunePhase.saving));
    final flow = FortunePreparationController(progress);
    final p = photo();
    await tester.pumpWidget(
      MaterialApp(
        builder: (_, child) =>
            FortunePreparationHost(controller: flow, child: child!),
        home: const Scaffold(),
      ),
    );
    flow.begin(
      photos: [p],
      imageFor: (_) => MemoryImage(testImage()),
      onCancel: () {},
    );
    await tester.pump();
    final state = tester.state(find.byType(FortuneScan));
    flow.updateTraces(setFor(p));
    progress.value = FortuneProgress(
      FortunePhase.highlighting,
      photoId: p.localName,
    );
    await tester.pump();
    expect(tester.state(find.byType(FortuneScan)), same(state));
    expect(find.byType(TraceOverlay), findsOneWidget);
    progress.value = const FortuneProgress(FortunePhase.generating);
    await tester.pump();
    expect(tester.state(find.byType(FortuneScan)), same(state));
    flow.cancel();
    flow.updateTraces(TraceSet.empty);
    expect(flow.traces.selected, hasLength(1));
    flow.finish();
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    flow.dispose();
    progress.dispose();
  });
}
