# Atlas S4-A Pilot Source Research Work Order

Status: READY FOR FUTURE S4-B RESEARCH - NO AUTHORING STARTED

Work-order date: `2026-08-19`

## Purpose

This work order defines the first bounded source-research set for Atlas Symbol.
It does not perform source research, assign final Symbol IDs, author domain
records, or approve a Symbol release.

The four candidates were restored by the Founder-approved refinement review
and exist exactly once in the Master Catalog v0.2.

## Pilot Set

| Research work item | Catalog candidate | Catalog placement |
| --- | --- | --- |
| `s4a-pilot-001` | Human Figure | CAT-01 / 01.1 Human Persons, Roles, and Groups |
| `s4a-pilot-002` | Bird | CAT-01 / 01.3 Non-Human Animals |
| `s4a-pilot-003` | Tree | CAT-01 / 01.5 Plants |
| `s4a-pilot-004` | Person Holding a Child | CAT-05 / 05.1 Bodily Actions, Poses, and Non-Life-Cycle States |

The work-item IDs are temporary research identifiers. They are not
`symbolId` values and must not appear in a production Symbol release.

## Required Research Matrix

Every pilot work item must eventually provide independently reviewable
evidence for:

| Required item | Language | Initial state |
| --- | --- | --- |
| Preferred name | English (`en`) | Not started |
| Preferred name | Turkish (`tr`) | Not started |
| Neutral definition | English (`en`) | Not started |
| Neutral definition | Turkish (`tr`) | Not started |
| Supported aliases, when any | Per alias language | Not started |
| Exact `SourceRef` for every text entry | N/A | Not started |
| Source-use eligibility and independence review | N/A | Not started |
| Required context and governance resolution | N/A | Not started |

English and Turkish entries must each have verifiable source support. An
unsourced editorial translation cannot substitute for a source-backed entry.
Minimum source counts are not invented here; they remain the responsibility
of the future versioned Symbol Admission Policy.

## Source Boundary

- A `SourceRef` remains `sourceId + revision + optional locator`.
- Exact source integrity resolves through a frozen Source Catalog release.
- An LLM, search-result snippet, generated summary, or uncited webpage is not
  a source.
- Each source use must later be assessed against an exact target revision.
- Bibliographic identity, consulted manifestation, quality dimensions,
  independence, limitations, and eligibility remain distinct concerns.

## Content Boundary

Preferred names and neutral definitions may describe only the neutral concept.
They must not include:

- coffee-reading meaning or fortune interpretation;
- positive or negative prediction;
- confidence, ranking, or popularity;
- physical geometry or topology thresholds;
- claims that a Knowledge record already recognizes the symbol.

Aliases are optional and may be retained only when explicitly source-backed.
The Master Catalog alias field is a research lead, not automatic admission.

## S4-B Handoff Gate

S4-B may begin source discovery for these four work items only after explicit
Founder approval. S4-B must preserve unsuccessful searches, conflicting
terminology, source limitations, and unresolved bilingual evidence rather than
filling gaps with generated text.

No `SymbolDefinition` draft should be declared reviewable until all required
English and Turkish fields have source support and exact `SourceRef` values.
