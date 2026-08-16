# Atlas LF-3 Vision-Native Local Formation Evidence Research Closeout

Status: `RESEARCH COMPLETE - NO PRODUCTION VISION CHANGE APPROVED`

## Scope

LF-3 tested whether deterministic surface-support detection and graded
luminance/contrast evidence could produce useful local residue and
negative-space formations. It changed no production package and added no
public API.

Baseline commit before LF-3: `8504a2af5a4d03c74be5855f75024e1ff5024ad0`

## Dataset Evidence

- Research ID: `lfr-003`
- Source dataset: `apc-001`
- Enabled images: `37`
- Fixed profiles: `16`
- Repeats per image: `3`
- Profile observations: `592`
- Analysis failures: `0`
- Non-deterministic observations: `0`
- Residue-conservation failures: `0`
- Primary annotations: `37`
- Residue annotations: `31`
- Negative-space annotations: `6`
- Mixed diagnostic annotations: `11`
- Eligible formation groups: `2`

External research artifacts:

| Artifact | SHA-256 |
|---|---|
| `candidate_alignment_review.json` | `28b95b527457f55cf8e363574b993f8a0d4d4246fcaef17b6016f99de20f364d` |
| `candidate_observations.csv` | `eb7f8d2270da4a2a815a8663d34c2a8922e3a938328b109a07ed5656849f46d5` |
| `candidate_observations.json` | `a0319f256c089869663d9ed7b63250edca5a720144defc3a7e3a61095f5c7e1d` |
| `evidence_observations.csv` | `05af97fbcae5f209b8874d87c794448630b83e07a2f9108c7779ca3b2edad88f` |
| `evidence_observations.json` | `4f4aca0cf614f9a47bac338cf0f48daa4bb9eb415810ca09348a32e13b9f0e58` |
| `profile_evaluation.csv` | `4a165b14d1f2c093e78f8b87c5247df1f3fde2d2720299d404fc8707e1c614cc` |
| `profile_evaluation.json` | `65b7249719a100be8dc81036837ca5f6797baf4a4e6409c613f8e0c3d4546f04` |
| `research_summary.md` | `2fb5395e414df71b7137521dcf61436ce8ae94bcb22cbe200752230f3f123942` |

Artifact root:

`ATLAS_PRODUCTION_DATASET/collections/apc-001/local_formation_research/lfr-003`

The external artifacts are intentionally not copied into the repository.

## Result

Fifteen profiles were eliminated by deterministic upper-bound evaluation.
Only `lf3-p09-local-t16-r08` remained eligible for human review:

- Candidate-budget rate: `1.0`
- Maximum possible overall coverage: `0.9459459459459459`
- Maximum possible residue coverage: `0.967741935483871`
- Maximum possible negative-space coverage: `0.8333333333333334`

The completed Founder alignment review recorded:

- All profiles: `0 aligned`, `226 partial`, `2417 unrelated`
- `lf3-p09-local-t16-r08`: `0 aligned`, `19 partial`, `193 unrelated`
- Evaluation basis: `humanAlignmentReview`
- Production profile candidate: none

The final human-review coverage values for the remaining profile were all
`0.0`, and no production profile candidate passed.

Verdict:

`DETERMINISTIC SURFACE-SUPPORT AND LUMINANCE/CONTRAST EVIDENCE IS INSUFFICIENT`

## Verification

- LF-3 focused tests: `18/18`
- `coffee_knowledge_dataset` full tests: `100/100`
- Package formatter check: `50` files, `0` changes
- Package analyzer: clean
- Canonical JSON: `44/44`
- Symbol: `33/33`
- Symbol Dataset: `45/45`
- Knowledge: `87/87`
- Pattern: `55/55`
- Vision: `357/357`
- All frozen package analyzers: clean
- Frozen production and constitutional inventory: `95/95` byte-identical
- Pattern, Knowledge, Symbol, AI, ranking, confidence, and semantic behavior:
  unchanged

## Architecture Gate

LF-3 does not justify a Vision public-contract change. No local-formation
model, profile, or evidence field is promoted to production. The result does
not automatically justify AI or semantic segmentation. Any next experiment
requires a separate architecture discovery based on the three completed
negative research checkpoints: LF-1, LF-2, and LF-3.
