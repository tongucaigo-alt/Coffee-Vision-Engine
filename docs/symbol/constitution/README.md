# Atlas Symbol Constitution Draft Set

Status: Founder Review Candidate, not frozen

Snapshot date: 2026-07-28

Git tag: `atlas-symbol-constitution-draft-2026-07-28`

This directory preserves the coordinated Atlas Symbol architecture drafts as
one reviewable and restorable version. It contains documentation only. It does
not introduce production code, JSON Schema, datasets, runtime behavior, or
public API changes.

## Included Documents

| Document | Revision | Pages | SHA-256 |
| --- | --- | ---: | --- |
| `Atlas_Symbol_Domain_Contracts_v1.0_DRAFT_0.4.docx` | Draft 0.4 | 19 | `FFED7B3BB794D6B247011D16585B2DF4C040D2ADE4AC030476C628B79EDF998F` |
| `Atlas_Symbol_Source_Standard_v1.0_DRAFT_0.3.docx` | Draft 0.3 | 22 | `93CDA781089334DCE84F4DB9DEE3D6B82717B803A596B6C4AC281ABA925A9875` |
| `Atlas_Symbol_Evidence_Standard_v1.0_DRAFT_0.3.docx` | Draft 0.3 | 22 | `E651C61DEC9B54D088A7C334D1DBB27A3F2599784FD11880E1DA7B32D40FCCD0` |

## Decisions Preserved

- `SymbolEvidenceBinding` uses exact `SymbolRevisionRef` and
  `KnowledgeTargetRef` identities.
- Binding-level assessment references remain mandatory and resolve through an
  exact Evidence Assessment Registry release.
- Symbol and Evidence admission policies remain separate exact dependencies.
- `SourceRef` remains compact; source integrity resolves through the exact
  Source Catalog release.
- Context-using release manifests carry an exact Context Registry release
  reference when required by their contracts.
- One versioned Atlas Canonical JSON Profile owns canonicalization for all
  related records and release manifests.
- Release manifests use one technical field vocabulary and never carry record
  revisions.
- `ReviewEvent` is append-only. Exact Governance Snapshot identity and checksum
  freeze the approved governance state.
- Binding freeze order is Domain, then Source, then Evidence.

## Validation Evidence

- DOCX ZIP/package integrity passed for all three files.
- Required contract markers and cross-document terminology checks passed.
- All 63 pages were inspected through Word-native pagination.
- No blank page, clipping, overflow, or broken table was found.
- The previous Draft 0.3/0.2/0.2 source documents remained byte-identical.
- The Atlas production repository was not changed by document generation.

## Boundaries

These documents remain drafts. Founder approval, K6 completion, exact policy
releases, and the Atlas Canonical JSON Profile are still required before
schema implementation, symbol dataset authoring, or freeze.

## Restore Reference

To inspect this exact version later:

```text
git show atlas-symbol-constitution-draft-2026-07-28
```

To create a temporary branch from it:

```text
git switch -c restore-symbol-constitution \
  atlas-symbol-constitution-draft-2026-07-28
```

Do not rewrite or move this tag after publication. A future revision must use a
new commit, tag, and release note.
