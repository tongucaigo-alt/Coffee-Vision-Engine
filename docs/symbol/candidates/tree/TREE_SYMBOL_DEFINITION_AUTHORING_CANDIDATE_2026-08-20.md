# Atlas Tree SymbolDefinition Authoring Candidate

Status: **NON-CANONICAL AUTHORING CANDIDATE - NOT RELEASE-ELIGIBLE**

Authoring date: `2026-08-20`

## Purpose

This document preserves a bounded authoring proposal for the Tree candidate.
It is not a schema-valid `SymbolDefinition`, a canonical domain record, an
admission decision, or a Symbol release.

The proposal uses existing Tree research only. It does not extend the source
search or promote any research source to canonical status.

## Candidate Identity

- Research work item: `s4a-pilot-003`
- Master Catalog candidate: `Tree`
- Taxonomy backlog reference: `CAT-01 / 01.5 Plants`
- Final `symbolId`: not assigned
- Record revision: not assigned
- Canonical checksum: not assigned

The research work-item identifier is temporary. It must not be used as a
`symbolId`, release identity, or persistence key.

## Proposed Authoring Fields

| Field | Language | Proposed value | Research-local support |
| --- | --- | --- | --- |
| Preferred name | English (`en`) | `Tree` | `TREE-GAP-S01` |
| Preferred name | Turkish (`tr`) | `Ağaç` | `TREE-GAP-S02` |
| Neutral definition | English (`en`) | `A visual form identified as a tree among shapes observed in Turkish coffee grounds.` | `TREE-GAP-S01` |
| Neutral definition | Turkish (`tr`) | `Türk kahvesi telvesinde gözlenen şekiller arasında ağaç olarak tanımlanan görsel form.` | `TREE-GAP-S02` |
| Alias | N/A | None proposed | No alias is admitted by this candidate |

The neutral-definition sentences are authoring candidates, not quotations.
They preserve only the physical identity scope explicitly observed in the
research sources. They do not carry a fortune meaning or interpretation.

## Research Traceability

The identifiers in this section are local to the external research bundles.
They are not `SourceRef` values, canonical source IDs, or released source
revisions.

### TREE-GAP-S01

- Source: Suzanne Mordue, `Reading Turkish Coffee`, `Critical Muslim 16:
  Turkey`, Hurst, October 2015.
- Consulted language: English.
- Exact locator: online article paragraph beginning `The first rule is that
  you cannot read your own fortune`; that paragraph explicitly includes
  `tree` among shapes observed in Turkish coffee grounds.
- Candidate use: English preferred name and English neutral-definition scope.
- Limitation: no immutable lawful manifestation is retained, no canonical
  source revision exists, and redistribution permission is not established.

### TREE-GAP-S02

- Source: `Neyse halim, çıksın falim`, `Nestlé benimle`, issue 13,
  December 2011 / January-February 2012.
- Consulted language: Turkish.
- Exact locator: printed page 16, section `Kahve falında sembollerin anlamı`,
  entry `Ağaç`.
- Candidate use: Turkish preferred name and Turkish neutral-definition scope.
- Limitation: the article author is unnamed, the issue has a promotional
  context, no immutable lawful manifestation is retained, and capture rights
  are unresolved.

### TREE-GAP-S03

- Source: Michelle Baricevic, `Inside a Cup of Turkish Coffee, You Can Find
  Much More Than Your Fortune`, Food Network, 2021-05-01.
- Exact locator: paragraph beginning `This movement causes the grinds`.
- Observed scope: separating tree branches.
- Decision: excluded from support for the whole Tree identity.
- Preserved limitation: branch evidence must not silently resolve the
  Tree-versus-Branch identity boundary.

## Research Bundle Integrity

The authoring proposal was checked against these unchanged external inputs:

| Bundle | SHA-256 |
| --- | --- |
| `TREE_SOURCE_INTAKE_READINESS_2026-08-19.zip` | `0b865bedd46cc0e7e706082e745f9685487369bb3ab8df400039d0874f554672` |
| `TREE_STRONG_SOURCE_GAP_RESEARCH_2026-08-19.zip` | `07e81c51390379be040a13aa850cf06bb44c5489a3a541d19f5ebd90204b7fe2` |
| `TR_01_supplemental_archive.zip` | `e2797464528ce5f564c0dc9c085b65595a7f8644c5d11ea412537a821f49995e` |

The packages remain non-canonical research inputs. Their packet-level
findings do not constitute Source admission, evidence admission, or Symbol
admission.

## Release Gaps

This candidate cannot become a real `SymbolDefinition` or enter a frozen
Symbol release until all applicable gates are satisfied:

- lawful exact source manifestations;
- canonical `SourceRecord` revisions and exact `SourceRef` values;
- a frozen Source Catalog release;
- a frozen Context Registry release where required;
- an approved Governance Snapshot;
- an approved Symbol Admission Policy and completed admission review;
- final Symbol identity, positive revision, and canonical checksum;
- the frozen manifest dependencies required by the Symbol Dataset contract;
- release-manifest validation against the approved Canonical JSON Profile.

The current frozen Symbol release contract also requires exact Governance,
Source Catalog, Symbol Admission Policy, Evidence Admission Policy, Evidence
Assessment Registry, and Knowledge Dataset release references. No empty,
synthetic, or placeholder dependency is introduced here.

## Explicit Non-Claims

This candidate does not:

- create a canonical `SymbolDefinition` or JSON record;
- create a `SourceRecord`, `SourceRef`, or `SourceUseAssessment`;
- admit either source as `eligibleCore` or release-eligible;
- create a Source Catalog, Governance, Context, policy, assessment, or Symbol
  release manifest;
- create a `SymbolEvidenceBinding` or connect Tree to Knowledge evidence;
- claim detection capability, physical segmentation, confidence, score,
  ranking, interpretation, or fortune meaning;
- modify the Master Catalog or any frozen production contract.

## Authoring Verdict

The Tree candidate has sufficient bounded research support to preserve these
English and Turkish authoring proposals for later review. It remains blocked
from canonicalization and release by exact source manifestation, source
catalog, governance, context, admission, identity, and manifest dependencies.

**S4-C TREE RELEASE CANDIDATE AUTHORING COMPLETE - REAL SYMBOL RELEASE NOT READY**
