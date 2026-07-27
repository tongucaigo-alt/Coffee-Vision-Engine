import 'dart:io';

import 'package:test/test.dart';

void main() {
  group('coffee_pattern package boundary', () {
    test('depends only on coffee_vision in production', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final dependencies = _yamlSection(pubspec, 'dependencies');

      expect(dependencies, contains('coffee_vision:'));
      for (final forbidden in [
        'flutter:',
        'image:',
        'camera:',
        'http:',
        'dio:',
        'openai:',
      ]) {
        expect(dependencies, isNot(contains(forbidden)), reason: forbidden);
      }
    });

    test('imports only the public coffee_vision barrel', () {
      final sources = _productionSources();
      final visionImports = RegExp(
        "import 'package:coffee_vision/[^']+';",
      ).allMatches(sources).map((match) => match.group(0)).toSet();

      expect(visionImports, {
        "import 'package:coffee_vision/coffee_vision.dart';",
      });
      expect(sources, isNot(contains('package:coffee_vision/src/')));
    });

    test('exposes exactly one public PatternEngine analysis method', () {
      final source = File('lib/src/pattern_engine.dart').readAsStringSync();
      final publicMethods = RegExp(
        r'^  Future<PatternAnalysisResult> ([A-Za-z]\w*)\(',
        multiLine: true,
      ).allMatches(source).map((match) => match.group(1)).toList();

      expect(publicMethods, ['analyzePatterns']);
    });

    test('keeps the PatternGeometry public state at the approved minimum', () {
      final source = File(
        'lib/src/models/pattern_geometry.dart',
      ).readAsStringSync();
      final fields = RegExp(
        r'^  final double ([A-Za-z]\w*);$',
        multiLine: true,
      ).allMatches(source).map((match) => match.group(1)).toList();
      final getters = RegExp(
        r'^  (?:double|bool) get ([A-Za-z]\w*)',
        multiLine: true,
      ).allMatches(source).map((match) => match.group(1)).toList();

      expect(fields, [
        'left',
        'top',
        'right',
        'bottom',
        'centroidX',
        'centroidY',
      ]);
      expect(getters, [
        'width',
        'height',
        'aspectRatio',
        'touchesWorkingImageBorder',
      ]);
      expect(source, isNot(contains('componentId')));
      expect(source, isNot(contains('surfaceType')));
      expect(source, isNot(contains('evidence')));
    });

    test('keeps PatternTopology at the approved scalar minimum', () {
      final source = File(
        'lib/src/models/pattern_topology.dart',
      ).readAsStringSync();
      final fields = RegExp(
        r'^  final int ([A-Za-z]\w*);$',
        multiLine: true,
      ).allMatches(source).map((match) => match.group(1)).toList();
      final getters = RegExp(
        r'^  bool get ([A-Za-z]\w*)',
        multiLine: true,
      ).allMatches(source).map((match) => match.group(1)).toList();

      expect(fields, ['nodeCount', 'directedEdgeCount']);
      expect(getters, ['isIsolated']);
      for (final forbidden in [
        'candidateId',
        'componentIds',
        'adjacency',
        'degree',
        'cycle',
        'path',
        'tree',
        'chain',
        'star',
        'ring',
        'branch',
        'meaning',
      ]) {
        expect(
          _containsIdentifier(source, forbidden),
          isFalse,
          reason: forbidden,
        );
      }
    });

    test(
      'contains only approved physical contracts and no semantic fields',
      () {
        final sources = _productionSources();
        final declarations = sources
            .split('\n')
            .where((line) => line.startsWith('  final '))
            .join('\n')
            .toLowerCase();

        for (final forbidden in [
          'score',
          'confidence',
          'quality',
          'symbol',
          'fortune',
          'meaning',
          'language',
          'density',
          'distance',
          'pixel',
        ]) {
          expect(declarations, isNot(contains(forbidden)), reason: forbidden);
        }
        for (final forbiddenGeometry in [
          'orientation',
          'majoraxis',
          'minoraxis',
          'elongation',
          'compactness',
          'convexity',
          'solidity',
          'perimeter',
          'contour',
          'symmetry',
          'curvature',
        ]) {
          expect(
            declarations,
            isNot(contains(forbiddenGeometry)),
            reason: forbiddenGeometry,
          );
        }
        for (final forbiddenType in [
          'VisionPipelineResult',
          'WorkingImage',
          'ResidueMask',
          'VisionComponentResult',
          'VisionSpatialGraph',
        ]) {
          expect(
            _containsIdentifier(sources, forbiddenType),
            isFalse,
            reason: forbiddenType,
          );
        }
      },
    );

    test(
      'does not execute Vision analysis or access forbidden Vision data',
      () {
        final sources = _productionSources();
        final executableSources = _withoutCommentsAndStrings(sources);

        for (final forbiddenType in [
          'CoffeeVisionEngine',
          'VisionPipelineResult',
          'WorkingImage',
          'ResidueMask',
        ]) {
          expect(
            _containsIdentifier(executableSources, forbiddenType),
            isFalse,
            reason: forbiddenType,
          );
        }
        for (final forbidden in [
          'analyzeFeatures(',
          'analyzeDetailed(',
          '.pixels',
          'imageBytes',
          'residuePixelCount',
          'residueShare',
          'centroidDistance',
          'boundingBoxDistance',
        ]) {
          expect(
            executableSources,
            isNot(contains(forbidden)),
            reason: forbidden,
          );
        }
      },
    );

    test('does not reconstruct or reinterpret Vision graph relationships', () {
      final source = File('lib/src/pattern_extractor.dart').readAsStringSync();
      final executableSource = _withoutCommentsAndStrings(source);

      for (final forbidden in [
        'VisionSpatialGraph',
        'VisionSpatialRelationFeature',
        'spatialRelationFeatures',
        'graphStatistics',
        'adjacency',
        'selectedRelations',
        'centroidDistance',
        'boundingBoxDistance',
        'relativeDirection',
        'ConnectedStructureAnalyzer',
        'GraphStatisticsAnalyzer',
      ]) {
        expect(executableSource, isNot(contains(forbidden)), reason: forbidden);
      }
    });

    test('keeps PatternExtractor internal', () {
      final barrel = File('lib/coffee_pattern.dart').readAsStringSync();

      expect(barrel, isNot(contains('pattern_extractor.dart')));
      expect(barrel, isNot(contains('PatternExtractor')));
    });
  });
}

String _productionSources() {
  return Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .map((file) => file.readAsStringSync())
      .join('\n');
}

String _yamlSection(String source, String section) {
  final start = source.indexOf('$section:\n');
  if (start < 0) return '';
  final rest = source.substring(start + section.length + 2);
  final nextTopLevel = RegExp(
    r'^[A-Za-z_].*:$',
    multiLine: true,
  ).firstMatch(rest);
  return nextTopLevel == null ? rest : rest.substring(0, nextTopLevel.start);
}

String _withoutCommentsAndStrings(String source) {
  return source
      .replaceAll(RegExp(r'//[^\r\n]*'), '')
      .replaceAll(RegExp(r"'(?:\\.|[^'\\])*'"), "''");
}

bool _containsIdentifier(String source, String identifier) {
  return RegExp('\\b${RegExp.escape(identifier)}\\b').hasMatch(source);
}
