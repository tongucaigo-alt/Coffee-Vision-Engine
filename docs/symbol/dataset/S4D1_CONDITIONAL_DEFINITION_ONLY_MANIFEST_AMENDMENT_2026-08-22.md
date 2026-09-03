# Atlas S4-D1 Conditional Definition-Only Manifest Amendment

Status: IMPLEMENTED CONTRACT AMENDMENT - INDEPENDENT VERIFICATION REQUIRED

Implementation date: `2026-08-22`

## Decision

`atlas.symbolReleaseManifest` version `2.0` makes physical release
dependencies conditional on manifest membership.

When the manifest contains no `atlas.symbolEvidenceBinding` record:

- `evidenceAdmissionPolicyRef` is absent;
- `evidenceAssessmentRegistryReleaseRef` is absent;
- `knowledgeDatasetReleaseRefs` is absent.

When the manifest contains one or more bindings, all three fields are
required and `knowledgeDatasetReleaseRefs` contains exactly one release.
Partial physical dependency sets are invalid.

## Preserved Contracts

- Version `1.0` manifest input retains its complete physical dependency set
  and exactly-one-Knowledge-release rule, including unbound releases.
- The frozen version 1 JSON Schema remains byte-identical.
- SymbolDefinition and SymbolEvidenceBinding documents remain schema version
  `1.0`.
- Manifest checksum calculation still excludes only the root
  `manifestChecksum` field.
- Canonical JSON Profile revision 1 remains mandatory.
- Parser behavior remains synchronous, in-memory, strict, and file-I/O free.

## Scope

This amendment enables definition-only release representation. It creates no
real SymbolDefinition, SourceRecord, SourceUseAssessment, GovernanceSnapshot,
admission policy, SymbolEvidenceBinding, Knowledge release, or production
Symbol dataset. It adds no ranking, confidence, interpretation, AI, or winner
behavior.

The implementation does not alter the existing S3 tag or freeze record. A new
independent verification and Founder freeze decision are required before the
version 2 contract can be declared stable.
