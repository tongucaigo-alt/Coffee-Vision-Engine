# Atlas Three-Angle Engine Integration Architecture

## Status

`IMPLEMENTATION CANDIDATE - NOT FROZEN`

This record defines the app-local integration of the frozen three-angle cup
capture with the existing Atlas physical and Symbol projection chain. It does
not change any Vision, Pattern, Knowledge, Symbol, Dataset, Source, or Camera
production contract.

## Canonical Flow

Each approved capture is processed independently and sequentially:

```text
top -> handleRight -> handleLeft

CameraCaptureResult
-> VisionImageInput(surfaceType: cup)
-> VisionFeatureSet
-> PatternAnalysisResult
-> complete KnowledgeMatchResult list
-> complete SymbolCandidate list
```

The common single-surface behavior is owned by the app-local
`AtlasK6SurfaceProcessor`. The existing cup/saucer controller and the new
three-angle controller both delegate to it.

## Result Integrity

- Every angle retains its exact capture and successful surface result.
- `noMatch`, `insufficientSymbolEvidence`, `symbolCandidatesAvailable`, and
  `technicalError` remain angle-local outcomes.
- A failed angle publishes no partial surface result. Remaining angles continue.
- Retrying a failed angle reuses the same approved capture and does not recreate
  successful results from other angles.
- Local Pattern candidate IDs are scoped by capture role.
- Symbol occurrences are identified by role, Pattern candidate ID, Symbol ID,
  and Symbol revision.
- Equal Symbol revisions from different angles are not merged.
- Lists use role order and are runtime-unmodifiable.
- A setup failure is retained as a safe app-local state and blocks capture and
  analysis; raw parser or dependency details are not shown to the user.

## Explicit Non-Responsibilities

This integration does not perform image registration, geometry fusion,
cross-angle deduplication, consensus, ranking, confidence, winner selection,
interpretation, fortune generation, or AI processing. Session summaries are
technical counts only and are not a semantic outcome.

The engine integration never writes or deletes capture files. Capture ownership
and cleanup remain in the app-local capture layer.

## Runtime and Evidence Boundary

The default app continues to use the frozen Knowledge research baseline and an
explicit definition-only `test-*` Symbol fixture. A non-empty Symbol result is
therefore not a production claim. Diagnostic fixtures remain opt-in test-only
entrypoints and are never production assets.

The Android diagnostic entrypoint is disabled by default and visibly marked
`TEST ONLY`. Its synthetic mixed-outcome and retry scenarios are injected at
the app-local `processSurface` boundary after capture; they do not inspect the
captured image and cannot demonstrate real Symbol recognition.
