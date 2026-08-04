# Coffee Symbol Dataset Adapter S3 - Freeze Record

Status: STABLE AND FROZEN

Founder approval date: `2026-08-04`

## Frozen Identity

- Package: `coffee_symbol_dataset`
- Package version: `0.0.1`
- Frozen scope: strict in-memory Symbol release adapter and three Draft
  2020-12 JSON Schemas
- Audited implementation commit:
  `3aec55f217b6c546d3ccfb7b1189f5e4bc5d125d`
- Implementation commit:
  `885189657f9540aacdfac56affc0f9c40cf4a6bd`
- Cross-platform verification correction:
  `3aec55f217b6c546d3ccfb7b1189f5e4bc5d125d`
- Freeze tag: `coffee-symbol-dataset-s3-stable-2026-08-04`

The adapter consumes only the public APIs of `coffee_symbol` and
`atlas_canonical_json`. It performs strict JSON validation and produces an
immutable `SymbolDatasetSnapshot` without file I/O or serialization.

## Canonical JSON Dependency

- Profile ID: `atlas-canonical-json`
- Revision: `1`
- Descriptor checksum:
  `sha256:16e9e10eb848828a863a7eca1c0b7e7c84e1a485065d00f938c6af356cd54ad7`
- Frozen profile tag: `atlas-canonical-json-s2-stable-2026-08-02`

Every manifest and record profile reference must match this exact identity.

## S3-C Acceptance Evidence

- Independent verification verdict:
  `S3-C VERIFICATION: PASS - READY FOR FOUNDER FREEZE APPROVAL`
- S3 package: formatter clean, analyzer clean, focused `37/37`, full `45/45`.
- GitHub Actions acceptance run: `30911086708`.
- Windows Dart VM job `91997732758`: success.
- Ubuntu Dart VM job `91997732822`: success.
- Canonical JSON regression: `44/44`.
- Symbol regression: `33/33`.
- Knowledge Dataset regression: `40/40`.
- Knowledge regression: `87/87`.
- Pattern regression: `55/55`.
- Vision regression: `357/357`.
- All analyzers: clean.
- Frozen upstream inventory: 94 files, zero missing and zero SHA-256
  differences.
- S3 scope: 16 approved files, zero paths outside `coffee_symbol_dataset/`
  and `.github/workflows/coffee_symbol_dataset_ci.yml`.
- Start and end state: clean `main`, with `HEAD == origin/main` at the audited
  implementation commit.

The first CI run, `30910747352`, exposed a Windows-only CRLF assumption in a
package-boundary test. Production code was unaffected. The test-only correction
is included in the audited commit, and the acceptance run passed on both
operating systems.

## Frozen Contract

- `SymbolDatasetParser.parse()` is the sole public behavior.
- Record documents are materialized exactly once.
- Duplicate identities are rejected before record resolution.
- Manifest and record checksums use exact canonical UTF-8 bytes.
- The root `manifestChecksum` field is excluded from its own checksum payload.
- Missing, extra, stale, duplicate, unknown, and non-canonically ordered input
  is rejected fail-closed.
- Every binding resolves to an exact Symbol definition revision and the single
  manifest Knowledge release.
- At least one Symbol definition is required; bindings remain optional.
- External Source, Governance, Policy, and Evidence references are preserved
  but not resolved.
- Snapshot and nested collections are runtime-unmodifiable.

## Frozen Constitution Hashes

- Domain Contracts Draft 0.5:
  `4cbc9fc749814705421bffe0777e307db0e5c72429291e48cbd89e75d1bf5326`
- Source Standard Draft 0.4:
  `43fd3597d54b628682ed927de5689bec65113ccda5ba733ac52ea1a315f706f8`
- Evidence Standard Draft 0.4:
  `2ec153b545b3be614c26a20a28a54d9332a96c64ca82ab1ad1651bf432d10505`

## Freeze Rules

This freeze covers only the adapter contracts, strict parser behavior, and the
three supported JSON Schemas. Any behavioral, public API, accepted-input,
rejected-input, dependency, or schema change requires a new reviewed revision
and independent verification.

This freeze creates no real Symbol dataset, Symbol definition catalog,
Evidence binding release, Interpretation, ranking, confidence, winner policy,
AI, language generation, file loader, writer, Vision, Pattern, or Knowledge
behavior.
