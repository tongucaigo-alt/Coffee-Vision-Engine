# Atlas Three-Angle Engine V1 Freeze

Status: **STABLE AND FROZEN**

Founder approval date: `2026-09-05`

## Frozen Identity

- Stable tag: `atlas-three-angle-engine-v1-stable-2026-09-05`
- Tagged commit: `86011b4b33df787d08a9202565649bf880361fbc`
- Architecture record:
  `THREE_ANGLE_ENGINE_INTEGRATION_ARCHITECTURE_2026-09-05.md`

The architecture record preserves its implementation-candidate status at the
time it was authored. This companion record is the later freeze authority and
does not alter the historical record.

## Frozen Behavior

- Cup captures are processed in `top`, `handleRight`, `handleLeft` order.
- Each angle independently executes Camera to Vision to Pattern to Knowledge
  to Symbol projection.
- `noMatch`, `insufficientSymbolEvidence`, `symbolCandidatesAvailable`, and
  `technicalError` remain angle-local outcomes.
- Successful angle results survive retry of a failed angle.
- Cross-angle fusion, deduplication, consensus, ranking, confidence, winner
  selection, interpretation, and AI are absent.
- Engine processing does not own or delete capture files.

## Boundary

This freeze covers app-local three-angle orchestration and its verified
diagnostic behavior. It does not make any synthetic fixture a real Symbol
release and does not claim real visual Symbol recognition.
