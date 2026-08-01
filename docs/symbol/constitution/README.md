# Atlas Symbol Constitution

Status: Founder-approved architecture standard, locally frozen

Freeze date: 2026-08-01

Repository baseline: `03a6cc2850455e79858f530ff0d815bba8ac6a10`

VCS publication: Pending separate approval. No commit, tag, or push is created
by this freeze record.

This directory preserves the coordinated Atlas Symbol architecture standards
and their superseded review drafts. The current frozen set defines contract
boundaries only. It does not create production Symbol data, JSON Schema,
admission-policy instances, evidence records, or production release manifests.

## Current Frozen Standards

The binding freeze order is Domain, then Source, then Evidence.

| Order | Document | Revision | Pages | SHA-256 |
| ---: | --- | --- | ---: | --- |
| 1 | `Atlas_Symbol_Domain_Contracts_v1.0_DRAFT_0.5.docx` | Draft 0.5 | 21 | `4cbc9fc749814705421bffe0777e307db0e5c72429291e48cbd89e75d1bf5326` |
| 2 | `Atlas_Symbol_Source_Standard_v1.0_DRAFT_0.4.docx` | Draft 0.4 | 23 | `43fd3597d54b628682ed927de5689bec65113ccda5ba733ac52ea1a315f706f8` |
| 3 | `Atlas_Symbol_Evidence_Standard_v1.0_DRAFT_0.4.docx` | Draft 0.4 | 24 | `2ec153b545b3be614c26a20a28a54d9332a96c64ca82ab1ad1651bf432d10505` |

Exact local freeze evidence is recorded in
`SYMBOL_CONSTITUTION_FREEZE_2026-08-01.md`.

## Founder Decisions Preserved

- The first implementation package is the pure-Dart `coffee_symbol` package.
- `coffee_symbol_dataset`, JSON Schema, parsing, and serialization remain
  deferred until the Atlas Canonical JSON Profile is approved.
- `neutralDefinitions` remain source-backed, neutral, and free of fortune
  interpretation.
- Checksums use `sha256:<64-lowercase-hex>` exactly.
- Binding activation is frozen release membership; no `enabled` field exists.
- One runtime projection accepts one exact Knowledge release ID/checksum pair.
- Symbol candidate identity is `(patternCandidateId, symbolId, symbolRevision)`.
- All eligible support for one candidate identity is retained without loss.
- Runtime output is canonical and complete; ranking, confidence, and forced
  winner selection are forbidden.
- Runtime projection is derived and non-canonical.
- Fieldwork consent remains within minimal `RightsInfo` plus Governance.
- URL normalization remains owned by the future Atlas Canonical JSON Profile.

## Current K6 Boundary

K6 research baseline, deterministic observation work, and Android end-to-end
integration are complete. The current Knowledge dataset remains a research
baseline and is not declared production-ready. Real Symbol definitions,
bindings, sources, policies, and evidence assessments remain prohibited until
their production release gates are satisfied.

## Validation Evidence

- All three DOCX ZIP packages passed integrity checks.
- All required revision, boundary, package-direction, and K6 markers were
  extracted and checked.
- Word-native PDFs were generated for visual verification.
- All 68 pages were inspected; no blank pages, clipping, overflow, or broken
  tables remain.
- The previous Draft 0.4/0.3/0.3 files remain byte-identical.
- Frozen Vision, Pattern, Knowledge, and Knowledge Dataset production sources
  are verified separately during package closeout.

## Preserved Previous Review Set

| Document | Revision | Pages | SHA-256 |
| --- | --- | ---: | --- |
| `Atlas_Symbol_Domain_Contracts_v1.0_DRAFT_0.4.docx` | Draft 0.4 | 19 | `ffed7b3bb794d6b247011d16585b2df4c040d2ade4ac030476c628b79edf998f` |
| `Atlas_Symbol_Source_Standard_v1.0_DRAFT_0.3.docx` | Draft 0.3 | 22 | `93cda781089334dce84f4db9dee3d6b82717b803a596b6c4ac281aba925a9875` |
| `Atlas_Symbol_Evidence_Standard_v1.0_DRAFT_0.3.docx` | Draft 0.3 | 22 | `e651c61dec9b54d088a7c334d1dbb27a3f2599784fd11880e1da7b32d40fccd0` |

The prior published review snapshot remains available at Git tag
`atlas-symbol-constitution-draft-2026-07-28`. Do not move or rewrite that tag.

## Change Rule

Frozen documents are never edited in place. Any correction requires a new
document revision, new checksums, ordered downstream revalidation, and Founder
approval. Commit, tag, and push always require separate explicit approval.
