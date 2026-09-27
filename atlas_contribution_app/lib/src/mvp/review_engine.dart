import 'dart:convert';

import 'package:atlas_canonical_json/atlas_canonical_json.dart';
import 'package:coffee_knowledge/coffee_knowledge.dart';
import 'package:coffee_knowledge_dataset/coffee_knowledge_dataset.dart';
import 'package:coffee_pattern/coffee_pattern.dart';
import 'package:coffee_symbol/coffee_symbol.dart';
import 'package:coffee_vision/coffee_vision.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../models.dart';
import 'review_models.dart';
import 'regional_summary.dart';

const mvpKnowledgeChecksum =
    'sha256:18b65abeca6971cc98153f0c5781bcdffecb2869fc4fabb205d004f9fb372895';
const mvpKnowledgeFileChecksum = mvpKnowledgeChecksum;
const mvpKnowledgeCanonicalChecksum =
    'sha256:cdf0e6763c878956c061591631e869051da4cd90e17244dc4adc66c166c90595';
const mvpEngineBaseline = '86011b4b33df787d08a9202565649bf880361fbc';

typedef ReviewFeatureAnalyzer =
    Future<VisionFeatureSet> Function(VisionImageInput);
typedef ReviewPatternAnalyzer =
    Future<PatternAnalysisResult> Function(VisionFeatureSet);
typedef ReviewMatcher =
    List<KnowledgeMatchResult> Function({
      required PatternCandidate candidate,
      required Iterable<KnowledgeRecord> records,
    });
typedef ReviewResolver =
    List<SymbolCandidate> Function({
      required KnowledgeDatasetReleaseRef knowledgeRelease,
      required Iterable<KnowledgeMatchResult> knowledgeMatches,
      required Iterable<SymbolDefinition> definitions,
      required Iterable<SymbolEvidenceBinding> bindings,
    });

final class ReviewEngineOutput {
  ReviewEngineOutput({
    required this.features,
    required this.patterns,
    required Iterable<KnowledgeMatchResult> matches,
    required Iterable<SymbolCandidate> symbols,
    required Map<String, dynamic> document,
  }) : matches = List.unmodifiable(matches),
       symbols = List.unmodifiable(symbols),
       document = immutableDocument(document);
  final VisionFeatureSet features;
  final PatternAnalysisResult patterns;
  final List<KnowledgeMatchResult> matches;
  final List<SymbolCandidate> symbols;
  final Map<String, dynamic> document;
}

final class ReviewEngineFailure implements Exception {
  const ReviewEngineFailure(this.stage);
  final String stage;
  @override
  String toString() => 'ReviewEngineFailure($stage)';
}

final class ReviewEngine {
  ReviewEngine({
    required this.dataset,
    required this.release,
    ReviewFeatureAnalyzer? analyzeFeatures,
    ReviewPatternAnalyzer? analyzePatterns,
    ReviewMatcher? match,
    ReviewResolver? resolve,
  }) : _vision = analyzeFeatures ?? CoffeeVisionEngine().analyzeFeatures,
       _pattern = analyzePatterns ?? const PatternEngine().analyzePatterns,
       _match = match ?? const KnowledgeRecordCollectionMatcher().match,
       _resolve = resolve ?? const SymbolCandidateResolver().resolve {
    if (dataset.datasetVersion != release.releaseId) {
      throw ArgumentError('Dataset identity mismatch');
    }
  }
  final KnowledgeDatasetSnapshot dataset;
  final KnowledgeDatasetReleaseRef release;
  final ReviewFeatureAnalyzer _vision;
  final ReviewPatternAnalyzer _pattern;
  final ReviewMatcher _match;
  final ReviewResolver _resolve;

  static Future<ReviewEngine> load() async {
    final data = await rootBundle.load('assets/mvp/knowledge_dataset.json');
    return fromBaseline(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    );
  }

  static ReviewEngine fromBaseline(Uint8List bytes) {
    if ('sha256:${sha256.convert(bytes)}' != mvpKnowledgeFileChecksum) {
      throw const ReviewEngineFailure('datasetIntegrity');
    }
    final canonical = const AtlasCanonicalJson().canonicalizeUtf8(bytes);
    if (canonical.checksum != mvpKnowledgeCanonicalChecksum) {
      throw const ReviewEngineFailure('datasetIntegrity');
    }
    return ReviewEngine(
      dataset: const KnowledgeDatasetParser().parse(utf8.decode(bytes)),
      release: KnowledgeDatasetReleaseRef(
        releaseId: 'kds-001',
        checksum: mvpKnowledgeChecksum,
      ),
    );
  }

  Future<ReviewEngineOutput> analyze(
    ReviewPhoto photo,
    Future<Uint8List> Function() read,
  ) async {
    var stage = 'fileRead';
    final runId = const Uuid().v4();
    final watch = Stopwatch()..start();
    try {
      final bytes = await read();
      if ('sha256:${sha256.convert(bytes)}' != photo.photo.checksum) {
        throw const ReviewEngineFailure('photoIntegrity');
      }
      stage = 'vision';
      final features = await _vision(
        VisionImageInput(
          imageBytes: bytes,
          surfaceType: photo.surface == ReviewSurface.cup
              ? VisionSurfaceType.cup
              : VisionSurfaceType.saucer,
          sourceId: photo.id,
        ),
      );
      stage = 'pattern';
      final patterns = await _pattern(features);
      stage = 'knowledge';
      final matches = <KnowledgeMatchResult>[];
      for (final candidate in patterns.candidates) {
        final next = _match(
          candidate: candidate,
          records: dataset.activeRecords,
        );
        if (next.any((m) => m.candidateId != candidate.id)) {
          throw StateError('Mismatched candidate');
        }
        matches.addAll(next);
      }
      stage = 'symbol';
      final symbols = _resolve(
        knowledgeRelease: release,
        knowledgeMatches: matches,
        definitions: const [],
        bindings: const [],
      );
      stage = 'resultAssembly';
      for (final s in symbols) {
        if (!patterns.candidates.any((c) => c.id == s.patternCandidateId) ||
            s.supports.any(
              (support) =>
                  !matches.any((m) => identical(m, support.knowledgeMatch)),
            )) {
          throw StateError('Untraceable Symbol candidate');
        }
      }
      final matched = matches.where((m) => m.matched).length;
      final outcome = matched == 0
          ? 'noMatch'
          : symbols.isEmpty
          ? 'insufficientSymbolEvidence'
          : 'symbolCandidatesAvailable';
      final provenance = features.imageProvenance;
      final global = features.globalFeatures;
      final document = <String, dynamic>{
        'version': 'atlas-local-analysis-v1',
        'runId': runId,
        'createdAtUtc': DateTime.now().toUtc().toIso8601String(),
        'photoId': photo.id,
        'photoChecksum': photo.photo.checksum,
        'surface': photo.surface.name,
        'engineBaseline': mvpEngineBaseline,
        'knowledgeRelease': {
          'releaseId': release.releaseId,
          'checksum': release.checksum,
        },
        'symbolAvailability': 'notConfigured',
        'symbolRelease': null,
        'outcome': outcome,
        'errorStage': null,
        'durationMs': watch.elapsedMilliseconds,
        'visionFeatureSetRef': {
          'runId': runId,
          'sourceId': features.sourceId,
          'photoChecksum': photo.photo.checksum,
          'engineBaseline': mvpEngineBaseline,
        },
        'provenance': {
          'sourceWidth': provenance.sourceWidth,
          'sourceHeight': provenance.sourceHeight,
          'sourceFormat': provenance.sourceFormat.name,
          'workingFormat': provenance.workingFormat.name,
          'workingWidth': provenance.workingWidth,
          'workingHeight': provenance.workingHeight,
          'workingResolution': provenance.workingResolution,
          'contentRect': {
            'left': provenance.contentRect.left,
            'top': provenance.contentRect.top,
            'right': provenance.contentRect.right,
            'bottom': provenance.contentRect.bottom,
          },
        },
        'globalPhysicalMeasurements': global == null
            ? null
            : {
                'residuePixelCount': global.residuePixelCount,
                'contentResidueRatio': global.contentResidueRatio,
                'componentCount': global.componentCount,
                'candidateRelationCount': global.candidateRelationCount,
                'selectedRelationCount': global.selectedRelationCount,
              },
        'regionalSummary': summarizeRegions(features),
        'patterns': [
          for (final p in patterns.candidates)
            {
              'id': p.id,
              'evidence': [
                for (final e in p.evidence)
                  {
                    'kind': e.kind.name,
                    'regionId': e.regionId?.name,
                    'componentId': e.componentId,
                    'sourceComponentId': e.sourceComponentId,
                    'targetComponentId': e.targetComponentId,
                    'structureId': e.structureId,
                  },
              ],
              'geometry': p.geometry == null
                  ? null
                  : {
                      'left': p.geometry!.left,
                      'top': p.geometry!.top,
                      'right': p.geometry!.right,
                      'bottom': p.geometry!.bottom,
                      'centroidX': p.geometry!.centroidX,
                      'centroidY': p.geometry!.centroidY,
                      'coordinateSpace': 'workingImage',
                    },
              'topology': p.topology == null
                  ? null
                  : {
                      'nodeCount': p.topology!.nodeCount,
                      'directedEdgeCount': p.topology!.directedEdgeCount,
                      'isIsolated': p.topology!.isIsolated,
                    },
            },
        ],
        'knowledgeMatches': matches.map(knowledgeDocument).toList(),
        'matchedCount': matched,
        'symbols': [
          for (final s in symbols) symbolDocument(s, patterns, provenance),
        ],
      };
      return ReviewEngineOutput(
        features: features,
        patterns: patterns,
        matches: matches,
        symbols: symbols,
        document: document,
      );
    } on ReviewEngineFailure {
      rethrow;
    } catch (_) {
      throw ReviewEngineFailure(stage);
    }
  }
}

Map<String, dynamic> knowledgeDocument(KnowledgeMatchResult m) => {
  'candidateId': m.candidateId,
  'recordId': m.recordId,
  'matched': m.matched,
  'constraintResults': [
    for (final c in m.constraintResults)
      {
        'constraint': {
          'key': c.constraint.key.name,
          'kind': c.constraint.kind.name,
          'minimumDouble': c.constraint.minimumDouble,
          'maximumDouble': c.constraint.maximumDouble,
          'minimumInteger': c.constraint.minimumInteger,
          'maximumInteger': c.constraint.maximumInteger,
          'expectedBoolean': c.constraint.expectedBoolean,
        },
        'outcome': c.outcome.name,
        'observedDouble': c.observedDouble,
        'observedInteger': c.observedInteger,
        'observedBoolean': c.observedBoolean,
        'unavailableReason': c.unavailableReason?.name,
      },
  ],
};

RegionBox? sourceBox(PatternGeometry? geometry, VisionRect content) {
  if (geometry == null) return null;
  final l = ((geometry.left - content.left) / content.width).clamp(0.0, 1.0);
  final t = ((geometry.top - content.top) / content.height).clamp(0.0, 1.0);
  final r = ((geometry.right - content.left) / content.width).clamp(0.0, 1.0);
  final b = ((geometry.bottom - content.top) / content.height).clamp(0.0, 1.0);
  return r <= l || b <= t ? null : RegionBox(l, t, r - l, b - t);
}

Map<String, dynamic> _source(SourceRef s) => {
  'sourceId': s.sourceId,
  'revision': s.revision,
  'locator': s.locator,
};
Map<String, dynamic> _profile(CanonicalJsonProfileRef p) => {
  'profileId': p.profileId,
  'revision': p.revision,
  'checksum': p.checksum,
};
Map<String, dynamic> _symbolRef(SymbolRevisionRef r) => {
  'symbolId': r.symbolId,
  'revision': r.revision,
  'checksum': r.checksum,
};
Map<String, dynamic> _text(SourcedLocalizedText t) => {
  'language': t.language,
  'value': t.value,
  'sourceRefs': t.sourceRefs.map(_source).toList(),
};

Map<String, dynamic> symbolDocument(
  SymbolCandidate s,
  PatternAnalysisResult patterns,
  VisionFeatureImageProvenance provenance,
) {
  final d = s.definition;
  final p = patterns.candidates.singleWhere(
    (p) => p.id == s.patternCandidateId,
  );
  String? name(String language) =>
      d.preferredNames.where((n) => n.language == language).firstOrNull?.value;
  return {
    'key':
        '${s.patternCandidateId}#${s.symbolId}#${s.symbolRevision}#${d.symbolRef.checksum}',
    'patternCandidateId': s.patternCandidateId,
    'name': name('tr') ?? name('en') ?? s.symbolId,
    'symbolRef': _symbolRef(d.symbolRef),
    'box': sourceBox(p.geometry, provenance.contentRect)?.toJson(),
    'definition': {
      'symbolRef': _symbolRef(d.symbolRef),
      'canonicalJsonProfileRef': _profile(d.canonicalJsonProfileRef),
      'preferredNames': d.preferredNames.map(_text).toList(),
      'aliases': d.aliases.map(_text).toList(),
      'neutralDefinitions': d.neutralDefinitions.map(_text).toList(),
    },
    'supports': [
      for (final support in s.supports)
        {
          'knowledgeMatch': knowledgeDocument(support.knowledgeMatch),
          'binding': {
            'bindingId': support.binding.bindingId,
            'revision': support.binding.revision,
            'canonicalJsonProfileRef': _profile(
              support.binding.canonicalJsonProfileRef,
            ),
            'symbolRef': _symbolRef(support.binding.symbolRef),
            'knowledgeTargetRef': {
              'knowledgeRecordId':
                  support.binding.knowledgeTargetRef.knowledgeRecordId,
              'knowledgeRelease': {
                'releaseId': support
                    .binding
                    .knowledgeTargetRef
                    .knowledgeRelease
                    .releaseId,
                'checksum': support
                    .binding
                    .knowledgeTargetRef
                    .knowledgeRelease
                    .checksum,
              },
            },
            'sourceRefs': support.binding.sourceRefs.map(_source).toList(),
            'evidenceAssessmentRefs': [
              for (final e in support.binding.evidenceAssessmentRefs)
                {
                  'assessmentId': e.assessmentId,
                  'revision': e.revision,
                  'assessmentType': e.assessmentType.name,
                  'checksum': e.checksum,
                },
            ],
          },
        },
    ],
  };
}
