# Atlas S4-D1 Conditional Definition-Only Manifest Freeze

Status: **STABLE AND FROZEN**

Founder approval date: `2026-09-03`

## Frozen Identity

- Package: `coffee_symbol_dataset`
- Package version: `0.1.0`
- Stable tag: `coffee-symbol-dataset-s4d1-stable-2026-09-03`
- Tagged commit: `9e612b875019b3ddee41c1c80c4d4b3f6f31a0b3`
- Amendment record:
  `S4D1_CONDITIONAL_DEFINITION_ONLY_MANIFEST_AMENDMENT_2026-08-22.md`

The amendment record preserves its implementation-time review status. This
companion record is the later freeze authority and does not rewrite that
historical state.

## Frozen Behavior

- Manifest schema version `1.0` keeps its full physical dependency set.
- Manifest schema version `2.0` permits a definition-only release only when it
  contains no `atlas.symbolEvidenceBinding` records.
- A definition-only version 2 manifest must omit Evidence Admission Policy,
  Evidence Assessment Registry, and Knowledge release dependencies.
- A version 2 manifest containing a binding must carry all three physical
  dependencies, including exactly one Knowledge release.
- Partial physical dependency sets are rejected.
- Canonical JSON Profile revision 1 and checksum determinism remain mandatory.

## Boundary

This freeze covers the conditional manifest contract, parser, schema, and
tests. It creates no real source, definition, binding, evidence assessment,
Knowledge record, or Symbol release.
