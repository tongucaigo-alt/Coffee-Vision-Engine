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
    'pixels': [id],
    'boundary': [id],
    'box': [id * 20, 100, 10, 10],
    'aspect': 1.0,
    'signature': List.generate(64, (i) => i == signatureIndex ? 10 : 0),
  },
  PhotoCrop(.2, .1, .6, .7),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('global cap is four, without filling empty results', () {
    expect(selectTraces([]), isEmpty);
    expect(selectTraces([candidate(0, 1)]), hasLength(1));
    final selected = selectTraces(
      List.generate(8, (i) => candidate(0, i + 1, score: 100 - i.toDouble())),
    );
    expect(selected, hasLength(4));
    expect(selected.first.score, 100);
  });
  test(
    'nearly identical cross-photo regions are suppressed, distinct shapes survive',
    () {
      expect(
        selectTraces([
          candidate(0, 1),
          candidate(1, 2),
          candidate(2, 3, signatureIndex: 10),
        ]),
        hasLength(2),
      );
    },
  );
  test('larger pieces cannot consume every slot before a distinct angle', () {
    final selected = selectTraces([
      candidate(0, 1, score: 100, signatureIndex: 1),
      candidate(0, 2, score: 90, signatureIndex: 2),
      candidate(0, 3, score: 80, signatureIndex: 3),
      candidate(0, 4, score: 70, signatureIndex: 4),
      candidate(1, 5, score: 20, signatureIndex: 5),
      candidate(2, 6, score: 10, signatureIndex: 6),
    ]);
    expect(selected, hasLength(4));
    expect(selected.map((c) => c.photoIndex).toSet(), {0, 1, 2});
  });
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
