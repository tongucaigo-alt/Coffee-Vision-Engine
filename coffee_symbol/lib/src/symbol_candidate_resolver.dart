import 'package:coffee_knowledge/coffee_knowledge.dart';

import 'models/exact_references.dart';
import 'models/symbol_candidate.dart';
import 'models/symbol_definition.dart';
import 'models/symbol_evidence_binding.dart';

/// Deterministically projects physical Knowledge matches to Symbol candidates.
///
/// The resolver returns every eligible candidate. It performs no ranking,
/// confidence calculation, interpretation, or forced-winner selection.
final class SymbolCandidateResolver {
  /// Creates the stateless resolver.
  const SymbolCandidateResolver();

  /// Resolves all matched Knowledge results through exact admitted bindings.
  List<SymbolCandidate> resolve({
    required KnowledgeDatasetReleaseRef knowledgeRelease,
    required Iterable<KnowledgeMatchResult> knowledgeMatches,
    required Iterable<SymbolDefinition> definitions,
    required Iterable<SymbolEvidenceBinding> bindings,
  }) {
    final matchInput = knowledgeMatches.toList(growable: false);
    final definitionInput = definitions.toList(growable: false);
    final bindingInput = bindings.toList(growable: false);

    _validateUniqueMatches(matchInput);
    _validateUniqueDefinitions(definitionInput);
    _validateUniqueBindings(bindingInput);

    final canonicalMatches = List<KnowledgeMatchResult>.of(matchInput)
      ..sort(_compareMatches);
    final canonicalDefinitions = List<SymbolDefinition>.of(definitionInput)
      ..sort(_compareDefinitions);
    final canonicalBindings = List<SymbolEvidenceBinding>.of(bindingInput)
      ..sort(_compareBindings);

    final definitionsByIdentity = <(String, int), SymbolDefinition>{
      for (final definition in canonicalDefinitions)
        (definition.symbolId, definition.revision): definition,
    };
    final bindingsByRecordId = <String, List<SymbolEvidenceBinding>>{};
    for (final binding in canonicalBindings) {
      if (binding.knowledgeTargetRef.knowledgeRelease != knowledgeRelease) {
        throw StateError(
          'Binding ${binding.bindingId} does not target the supplied '
          'Knowledge release.',
        );
      }
      final identity = (binding.symbolRef.symbolId, binding.symbolRef.revision);
      final definition = definitionsByIdentity[identity];
      if (definition == null) {
        throw StateError(
          'Binding ${binding.bindingId} references an unknown '
          'SymbolDefinition.',
        );
      }
      if (definition.symbolRef != binding.symbolRef) {
        throw StateError(
          'Binding ${binding.bindingId} references a stale '
          'SymbolDefinition checksum.',
        );
      }
      bindingsByRecordId
          .putIfAbsent(
            binding.knowledgeTargetRef.knowledgeRecordId,
            () => <SymbolEvidenceBinding>[],
          )
          .add(binding);
    }

    final grouped = <(int, String, int), List<SymbolCandidateSupport>>{};
    for (final match in canonicalMatches) {
      if (!match.matched) continue;
      final matchingBindings = bindingsByRecordId[match.recordId];
      if (matchingBindings == null) continue;
      for (final binding in matchingBindings) {
        final key = (
          match.candidateId,
          binding.symbolRef.symbolId,
          binding.symbolRef.revision,
        );
        grouped
            .putIfAbsent(key, () => <SymbolCandidateSupport>[])
            .add(
              SymbolCandidateSupport(binding: binding, knowledgeMatch: match),
            );
      }
    }

    final candidates = <SymbolCandidate>[];
    for (final entry in grouped.entries) {
      final definition = definitionsByIdentity[(entry.key.$2, entry.key.$3)]!;
      candidates.add(
        SymbolCandidate(
          patternCandidateId: entry.key.$1,
          definition: definition,
          supports: entry.value,
        ),
      );
    }
    candidates.sort(_compareCandidates);
    return List<SymbolCandidate>.unmodifiable(candidates);
  }

  static void _validateUniqueMatches(List<KnowledgeMatchResult> matches) {
    final identities = <(int, String)>{};
    for (final match in matches) {
      final identity = (match.candidateId, match.recordId);
      if (!identities.add(identity)) {
        throw ArgumentError.value(
          identity,
          'knowledgeMatches',
          'must contain unique candidate and record identities',
        );
      }
    }
  }

  static void _validateUniqueDefinitions(List<SymbolDefinition> definitions) {
    final identities = <(String, int)>{};
    for (final definition in definitions) {
      final identity = (definition.symbolId, definition.revision);
      if (!identities.add(identity)) {
        throw ArgumentError.value(
          identity,
          'definitions',
          'must contain unique symbol revision identities',
        );
      }
    }
  }

  static void _validateUniqueBindings(List<SymbolEvidenceBinding> bindings) {
    final identities = <(String, int)>{};
    for (final binding in bindings) {
      final identity = (binding.bindingId, binding.revision);
      if (!identities.add(identity)) {
        throw ArgumentError.value(
          identity,
          'bindings',
          'must contain unique binding revision identities',
        );
      }
    }
  }

  static int _compareMatches(
    KnowledgeMatchResult first,
    KnowledgeMatchResult second,
  ) {
    final candidate = first.candidateId.compareTo(second.candidateId);
    if (candidate != 0) return candidate;
    return first.recordId.compareTo(second.recordId);
  }

  static int _compareDefinitions(
    SymbolDefinition first,
    SymbolDefinition second,
  ) {
    final id = first.symbolId.compareTo(second.symbolId);
    if (id != 0) return id;
    return first.revision.compareTo(second.revision);
  }

  static int _compareBindings(
    SymbolEvidenceBinding first,
    SymbolEvidenceBinding second,
  ) {
    final record = first.knowledgeTargetRef.knowledgeRecordId.compareTo(
      second.knowledgeTargetRef.knowledgeRecordId,
    );
    if (record != 0) return record;
    final symbol = first.symbolRef.symbolId.compareTo(
      second.symbolRef.symbolId,
    );
    if (symbol != 0) return symbol;
    final symbolRevision = first.symbolRef.revision.compareTo(
      second.symbolRef.revision,
    );
    if (symbolRevision != 0) return symbolRevision;
    final binding = first.bindingId.compareTo(second.bindingId);
    if (binding != 0) return binding;
    return first.revision.compareTo(second.revision);
  }

  static int _compareCandidates(SymbolCandidate first, SymbolCandidate second) {
    final pattern = first.patternCandidateId.compareTo(
      second.patternCandidateId,
    );
    if (pattern != 0) return pattern;
    final symbol = first.symbolId.compareTo(second.symbolId);
    if (symbol != 0) return symbol;
    return first.symbolRevision.compareTo(second.symbolRevision);
  }
}
