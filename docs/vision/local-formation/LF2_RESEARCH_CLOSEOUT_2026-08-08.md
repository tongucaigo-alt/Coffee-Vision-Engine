# Atlas LF-2 Deterministic Local Formation Evidence Research Closeout

Status: `RESEARCH COMPLETE - NOT A PRODUCTION VISION FREEZE`

## Scope

LF-2 tested whether deterministic circular binary closing over the frozen
public `ResidueMask` could produce useful residue and negative-space local
formations. It changed no production package and added no public API.

Baseline commit before LF-2: `450476faab6ac977bc07e7d251f40a80af6644fa`

## Dataset Evidence

- Research ID: `lfr-002`
- Source dataset: `apc-001`
- Enabled images: `37`
- Fixed profiles: `8`
- Repeats per image: `3`
- Profile observations: `296`
- Analysis failures: `0`
- Non-deterministic observations: `0`
- Residue-conservation failures: `0`

External research artifacts:

| Artifact | SHA-256 |
|---|---|
| `candidate_observations.csv` | `568cdba6f3b5ccf86e26ffdeb04127c5adc123911b3b95db31e82141e5ce0095` |
| `candidate_observations.json` | `a327d68c7c74abd0eff9750a672be0ddc0edd096bde5fff3e7ba2e81b3884cad` |
| `profile_evaluation.csv` | `ef826683863e420c71698d1381034fd59d9eeb99f58cc110e7ce8a8334c8dc94` |
| `profile_evaluation.json` | `3b2a5f6d8092676323befd38ec82bc4b6dca0e7b32ef75c4182b043a1b004aea` |
| `research_summary.md` | `42c983b12e44dc182ac4530b88f5eb4824b06b63762c5df88e3d65fbbf72cdeb` |

Artifact root:

`ATLAS_PRODUCTION_DATASET/collections/apc-001/local_formation_research/lfr-002`

The external artifacts are intentionally not copied into the repository.

## Result

All eight profiles were eliminated by a deterministic upper-bound evaluation.
No human alignment decisions were fabricated and no production profile
candidate was selected.

- `lf2-p00` through `lf2-p03` failed the candidate-budget gate.
- `lf2-p04` and `lf2-p05` could not reach required negative-space coverage.
- `lf2-p06` and `lf2-p07` could not reach required residue coverage.

Verdict:

`CURRENT BINARY RESIDUE MASK IS INSUFFICIENT FOR LOCAL FORMATION EVIDENCE`

## Verification

- LF-2 focused tests: `25/25`
- `coffee_knowledge_dataset` full tests: `81/81`
- Package analyzer: clean
- Formatter check: `34` files, `0` changes
- Frozen production and constitutional inventory: `95/95` byte-identical
- Frozen regression suites: all passed
- Pattern, Knowledge, Symbol, AI, ranking, confidence, and semantic behavior:
  unchanged

## Checkpoint Meaning

This closeout freezes the LF-2 research method and negative result only. It
does not freeze a Vision algorithm, approve a production profile, establish a
Symbol binding, or claim production dataset readiness.
