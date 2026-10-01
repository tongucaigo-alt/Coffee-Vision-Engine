import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:atlas_contribution_app/src/models.dart';
import 'package:atlas_contribution_app/src/photo_crop.dart';
import 'package:atlas_contribution_app/src/photo_suitability.dart';
import 'fixtures.dart';

class _Checker extends PhotoSuitability {
  _Checker(this.status) : super(Directory.systemTemp);
  final String status;
  @override
  Future<Map<String, dynamic>> assess(
    File file,
    ContributionPhoto p, {
    bool retry = false,
  }) async => {
    'version': suitabilityVersion,
    'checksum': p.checksum,
    'surface': p.surface.name,
    'cropKey': jsonEncode((p.displayCrop ?? PhotoCrop.full).toJson()),
    'status': status,
  };
}

void main() {
  for (final status in [
    'supported',
    'uncertain',
    'unsuitable',
    'residueFree',
    'error',
  ]) {
    testWidgets('$status preflight does not open a modal or invent consent', (
      tester,
    ) async {
      Map<String, dynamic>? result;
      PhotoSuitabilityFailure? failure;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  try {
                    result = await ensurePhotoSuitability(
                      context,
                      _Checker(status),
                      File('unused'),
                      testPhoto(CaptureRole.free),
                    );
                  } on PhotoSuitabilityFailure catch (e) {
                    failure = e;
                  }
                },
                child: const Text('Start'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Start'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      if (['supported', 'uncertain'].contains(status)) {
        expect(result?['status'], status);
        expect(result?['continuedAtUtc'], isNull);
      } else {
        expect(failure?.assessment['status'], status);
        expect(result, isNull);
      }
    });
  }
  testWidgets('technical failure renders an inline retry at large text', (
    tester,
  ) async {
    var retried = false;
    final p = testPhoto(CaptureRole.free);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: SingleChildScrollView(
              child: PhotoSuitabilityNotice(
                photo: p,
                value: {'status': 'error'},
                onRetry: () => retried = true,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.ensureVisible(find.text('Kontrolü Yeniden Dene'));
    await tester.tap(find.text('Kontrolü Yeniden Dene'));
    expect(retried, isTrue);
    expect(tester.takeException(), isNull);
  });
  test('malformed native output is never a visual decision', () {
    for (final bad in <Map<dynamic, dynamic>>[
      {},
      {'full': [], 'crop': []},
      {
        'full': [
          {'label': 'cup', 'score': double.nan},
        ],
        'crop': [],
      },
    ]) {
      expect(() => classifySuitability(bad), throwsFormatException);
    }
  });
}
