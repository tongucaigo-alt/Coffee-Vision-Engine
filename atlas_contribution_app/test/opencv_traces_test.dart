import 'package:atlas_contribution_app/src/opencv_traces.dart';
import 'package:atlas_contribution_app/src/photo_crop.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

TraceCandidate candidate(
  int photo,
  int id, {
  double score = 100,
  int signatureIndex = 0,
}) => TraceCandidate(
  photo,
  {'width': 512, 'height': 512},
  {
    'id': id,
    'score': score,
    'pixels': [100 * 512 + id * 20],
    'boundary': [100 * 512 + id * 20],
    'box': [id * 20, 100, 10, 10],
    'aspect': 1.0,
    'signature': List.generate(64, (i) => i == signatureIndex ? 10 : 0),
  },
  PhotoCrop(.2, .1, .6, .7),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'each photo has its own four-region cap without filling empty results',
    () {
      expect(selectTraces([]), isEmpty);
      expect(selectTraces([candidate(0, 1)]), hasLength(1));
      final selected = selectTraces(
        List.generate(8, (i) => candidate(0, i + 1, score: 100 - i.toDouble())),
      );
      expect(selected, hasLength(4));
      expect(selected.first.score, 100);
    },
  );
  test('similar regions in another photo keep independent display slots', () {
    expect(
      selectTraces([
        candidate(0, 1),
        candidate(1, 2),
        candidate(2, 3, signatureIndex: 10),
      ]),
      hasLength(3),
    );
  });
  test('larger pieces cannot consume every slot before a distinct angle', () {
    final selected = selectTraces([
      candidate(0, 1, score: 100, signatureIndex: 1),
      candidate(0, 2, score: 90, signatureIndex: 2),
      candidate(0, 3, score: 80, signatureIndex: 3),
      candidate(0, 4, score: 70, signatureIndex: 4),
      candidate(1, 5, score: 20, signatureIndex: 5),
      candidate(2, 6, score: 10, signatureIndex: 6),
    ]);
    expect(selected, hasLength(6));
    expect(selected.map((c) => c.photoIndex).toSet(), {0, 1, 2});
  });
  test('three angles can retain twelve independent regions', () {
    final selected = selectTraces([
      for (var p = 0; p < 3; p++)
        for (var i = 1; i <= 6; i++) candidate(p, i, score: 100 - i.toDouble()),
    ]);
    expect(selected, hasLength(12));
    for (var p = 0; p < 3; p++) {
      expect(selected.where((c) => c.photoIndex == p), hasLength(4));
    }
  });
  test(
    'interior candidate keeps a slot even when peripheral candidates score higher',
    () {
      final t = candidate(0, 20, score: 1);
      final inner = TraceCandidate(
        0,
        {
          'width': 512,
          'height': 512,
          'cupBoundary': [256, 256, 400, 400, 0],
        },
        {
          ...t.data,
          'box': [250, 250, 10, 10],
          'pixels': [250 * 512 + 250],
          'boundary': [250 * 512 + 250],
        },
        t.area,
      );
      final selected = selectTraces([
        for (var i = 1; i <= 5; i++) candidate(0, i),
        inner,
      ]);
      expect(selected, hasLength(4));
      expect(selected, contains(inner));
      expect(selectTraces([inner]), [inner]);
    },
  );
  test('overlapping candidates within one photo are still suppressed', () {
    final a = candidate(0, 1), b = candidate(0, 2);
    final overlapping = TraceCandidate(0, b.result, {
      ...b.data,
      'box': a.data['box'],
      'pixels': a.data['pixels'],
      'boundary': a.data['boundary'],
    }, b.area);
    expect(selectTraces([a, overlapping]), hasLength(1));
  });
  test('overlapping boxes do not suppress disjoint pixel masks', () {
    final a = candidate(0, 1), b = candidate(0, 2);
    final separate = TraceCandidate(0, b.result, {
      ...b.data,
      'box': a.data['box'],
      'pixels': [100 * 512 + 21],
      'boundary': [100 * 512 + 21],
    }, b.area);
    expect(selectTraces([a, separate]), hasLength(2));
  });
  test(
    'interior reservation never displaces a higher-scoring pixel duplicate',
    () {
      final result = {
        'width': 512,
        'height': 512,
        'cupBoundary': [256, 256, 400, 400, 0],
      };
      final low = TraceCandidate(0, result, {
        ...candidate(0, 1, score: 1).data,
        'box': [250, 250, 2, 1],
        'pixels': [250 * 512 + 250, 250 * 512 + 251],
      }, PhotoCrop.full);
      final high = TraceCandidate(0, result, {
        ...candidate(0, 2).data,
        'box': [50, 50, 202, 201],
        'pixels': [for (var x = 50; x < 80; x++) 50 * 512 + x, ...low.pixels],
      }, PhotoCrop.full);
      expect(selectTraces([low, high]), [high]);
    },
  );

  test(
    'closeups map to full original coordinates inside corrected cup area',
    () {
      final t = candidate(0, 1);
      expect(t.closeup.x, closeTo(.2 + 10 / 512 * .6, 1e-10));
      expect(t.closeup.y, closeTo(.1 + 90 / 512 * .7, 1e-10));
      expect(t.closeup.width, closeTo(30 / 512 * .6, 1e-10));
    },
  );
  test('working image is bounded, correctly cropped and aspect preserving', () {
    final source = img.Image(width: 160, height: 200)
      ..clear(img.ColorRgb8(10, 20, 30));
    final result = img.decodePng(
      prepareTraceImage({
        'bytes': img.encodePng(source),
        'area': [.2, .1, .6, .5],
      }),
    )!;
    expect(result.height, 512);
    expect(result.width, 492);
    expect(result.getPixel(20, 20).r, 10);
  });
  test('EXIF rotation is applied before interpreting normalized crop', () {
    final source = img.Image(width: 200, height: 100);
    for (var y = 0; y < 100; y++) {
      for (var x = 0; x < 200; x++) {
        source.setPixelRgb(x, y, x < 100 ? 220 : 10, 20, x < 100 ? 10 : 220);
      }
    }
    source.exif.imageIfd.orientation = 6;
    final result = img.decodePng(
      prepareTraceImage({
        'bytes': img.encodeJpg(source),
        'area': [0.0, 0.0, 1.0, .5],
      }),
    )!;
    expect(result.width, 512);
    expect(result.height, 512);
    expect(result.getPixel(250, 250).r, greaterThan(200));
    expect(result.getPixel(250, 250).b, lessThan(30));
  });
}
