# Atlas M5B-4 Baseline Report Evaluation

## Baseline Fingerprint

| Field | Value |
|---|---|
| Dataset Freeze | m5b-001 |
| Manifest SHA-256 | sha256:9b536cd84e6bbef93e70dbe4531bdc19c550de7b72e13227623dc1c2f0ff7ab4 |
| Repeat | 3 |
| Enabled records | 53 |
| Engine version | Coffee Vision Engine v0.6 Atlas |
| Validation API | analyzeDetailed() |
| Pipeline | Production |
| Deterministic | 53/53 |

## Executive Summary

- The frozen m5b-001 baseline contains 53 enabled analyses: 47 cup and 6 saucer records.
- All 53 enabled records completed successfully and produced identical results across three repeats.
- The baseline does not expose confidence, quality score, notes, or warning fields. No substitute metric is treated as confidence.
- Cup and saucer residue/component distributions differ, but the six-image saucer sample is insufficient for generalization.
- No production algorithm, threshold, configuration, or pipeline behavior was changed during this evaluation.

## Dataset Scope

| Surface | Manifest entries | Enabled and analyzed | Disabled/skipped |
|---|---:|---:|---:|
| Cup | 47 | 47 | 0 |
| Saucer | 7 | 6 | 1 |
| Total | 54 | 53 | 1 |

- m5b-saucer-004 is the frozen disabled duplicate. It has no metrics and is excluded from distributions.
- JSON and CSV both contain 54 records with matching status and metric values.

## Determinism and Execution Reliability

- Successful: 53/53 enabled records.
- Failed: 0.
- Deterministic: 53/53.
- Non-deterministic: 0.
- Run-level errors: 0; mismatched repeat indexes: 0.
- Classification: no issue detected.

## Cup Metric Distribution

| Metric | Minimum | Maximum | Average | Median | Unique values |
|---|---:|---:|---:|---:|---:|
| Working image width | 512 | 512 | 512.00 | 512.00 | 1 |
| Working image height | 512 | 512 | 512.00 | 512.00 | 1 |
| Working residue pixel count | 67502 | 131690 | 108631.79 | 109794.00 | 47 |
| Working content residue area ratio | 0.343333 | 0.732775 | 0.559443 | 0.576416 | 47 |
| Component count | 40 | 719 | 194.87 | 98.00 | 42 |
| Relation count | 1560 | 516242 | 69771.66 | 9506.00 | 42 |
| Selected edge count | 1560 | 516242 | 69771.66 | 9506.00 | 42 |
| Graph node count | 40 | 719 | 194.87 | 98.00 | 42 |
| Graph edge count | 1560 | 516242 | 69771.66 | 9506.00 | 42 |
| Structure count | 1 | 1 | 1.00 | 1.00 | 1 |
| Largest structure size | 40 | 719 | 194.87 | 98.00 | 42 |
| Isolated structure count | 0 | 0 | 0.00 | 0.00 | 1 |

- Cup residue pixels average 108631.79 with median 109794.00.
- Cup residue ratio average 0.559443 with median 0.576416.
- Cup component count average 194.87 with median 98.00; the mean is raised by high-component candidates.
- Classification: observation only.

## Saucer Metric Distribution

| Metric | Minimum | Maximum | Average | Median | Unique values |
|---|---:|---:|---:|---:|---:|
| Working image width | 512 | 512 | 512.00 | 512.00 | 1 |
| Working image height | 512 | 512 | 512.00 | 512.00 | 1 |
| Working residue pixel count | 67181 | 105752 | 90331.50 | 92448.00 | 6 |
| Working content residue area ratio | 0.457367 | 0.571635 | 0.518982 | 0.522921 | 6 |
| Component count | 189 | 1120 | 397.67 | 277.00 | 6 |
| Relation count | 35532 | 1253280 | 264858.00 | 77077.00 | 6 |
| Selected edge count | 35532 | 1253280 | 264858.00 | 77077.00 | 6 |
| Graph node count | 189 | 1120 | 397.67 | 277.00 | 6 |
| Graph edge count | 35532 | 1253280 | 264858.00 | 77077.00 | 6 |
| Structure count | 1 | 1 | 1.00 | 1.00 | 1 |
| Largest structure size | 189 | 1120 | 397.67 | 277.00 | 6 |
| Isolated structure count | 0 | 0 | 0.00 | 0.00 | 1 |

- Saucer residue pixels average 90331.50 with median 92448.00.
- Saucer residue ratio average 0.518982 with median 0.522921.
- Saucer component count average 397.67 with median 277.00; m5b-saucer-006 strongly affects the mean.
- Classification: insufficient sample size.

### All Saucer Records

Confidence ordering is unavailable. Records are listed in deterministic sourceId order without substituting another metric for confidence.

| sourceId | Residue pixels | Residue ratio | Components | Relations | Selected edges |
|---|---:|---:|---:|---:|---:|
| m5b-saucer-001 | 67181 | 0.555987 | 252 | 63252 | 63252 |
| m5b-saucer-002 | 84291 | 0.571635 | 302 | 90902 | 90902 |
| m5b-saucer-003 | 99869 | 0.507960 | 332 | 109892 | 109892 |
| m5b-saucer-005 | 94974 | 0.483063 | 189 | 35532 | 35532 |
| m5b-saucer-006 | 89922 | 0.457367 | 1120 | 1253280 | 1253280 |
| m5b-saucer-007 | 105752 | 0.537882 | 191 | 36290 | 36290 |

| sourceId | Graph nodes | Graph edges | Structures | Largest structure | Isolated structures |
|---|---:|---:|---:|---:|---:|
| m5b-saucer-001 | 252 | 63252 | 1 | 252 | 0 |
| m5b-saucer-002 | 302 | 90902 | 1 | 302 | 0 |
| m5b-saucer-003 | 332 | 109892 | 1 | 332 | 0 |
| m5b-saucer-005 | 189 | 35532 | 1 | 189 | 0 |
| m5b-saucer-006 | 1120 | 1253280 | 1 | 1120 | 0 |
| m5b-saucer-007 | 191 | 36290 | 1 | 191 | 0 |

All six saucer working images are 512 x 512.

## Confidence Bands

Confidence is not present in validation_report.json or validation_summary.csv. Band counts are therefore not available, not zero.

| Observation band | Count |
|---|---:|
| 0.00-0.24 very low | N/A |
| 0.25-0.49 low | N/A |
| 0.50-0.74 medium | N/A |
| 0.75-1.00 high | N/A |
| Exact zero confidence | N/A |

- Lowest 10 cup confidence records: not available.
- Highest 10 cup confidence records: not available.
- Saucer confidence ranking: not available.
- These observation bands are not production thresholds.

## Notes and Warnings

- Notes field: not present in the baseline schema.
- Warnings field: not present in the baseline schema.
- Quality/score fields: not present in the baseline schema.
- Record errors: none. Run-level errors: none.
- Attention records are reported only as statistical outlier candidates below, not as warnings or failures.

## Outlier Candidates

Candidates use per-surface Tukey 1.5 x IQR bounds on residue pixels, residue ratio, and component count only. This is reporting analysis, not a production threshold.

| Surface | sourceId | Metric | Value | IQR bound crossed | Classification |
|---|---|---|---:|---:|---|
| cup | m5b-cup-001 | Working residue pixel count | 67502.00 | < 68027.50 | possible future investigation |
| cup | m5b-cup-001 | Working content residue area ratio | 0.343333 | < 0.351924 | possible future investigation |
| cup | m5b-cup-003 | Working content residue area ratio | 0.348007 | < 0.351924 | possible future investigation |
| cup | m5b-cup-026 | Component count | 644.00 | > 553.00 | possible future investigation |
| cup | m5b-cup-041 | Component count | 709.00 | > 553.00 | possible future investigation |
| cup | m5b-cup-047 | Component count | 719.00 | > 553.00 | possible future investigation |
| saucer | m5b-saucer-006 | Component count | 1120.00 | > 543.50 | insufficient sample size |

- Repeated cup component counts: 59 occurs for m5b-cup-005, m5b-cup-010, and m5b-cup-027; 81, 95, and 200 each occur twice.
- No two successful records share the same complete metric vector.

## Constant or Suspiciously Uniform Fields

| Observation across all 53 enabled records | Interpretation | Classification |
|---|---|---|
| Working image width and height are always 512 | Configured working resolution | expected behavior |
| relationCount equals selectedEdgeCount and graphEdgeCount | Pass-through edge selection and organized full relation graph | expected behavior |
| graphNodeCount equals componentCount and largestStructureSize | Full graph forms one weakly connected structure | expected behavior |
| relationCount equals componentCount x (componentCount - 1) | Full directed relation set | expected behavior |
| structureCount is always 1 | Enabled records all contain components in a full relation graph | expected behavior |
| isolatedStructureCount is always 0 | No isolated structure in the full relation graph | expected behavior |
| repeatsPerformed is always 3 and determinismStatus is deterministic | Baseline repeat contract held | no issue detected |

## Surface Differences

| Metric | Cup average | Cup median | Saucer average | Saucer median | Classification |
|---|---:|---:|---:|---:|---|
| Residue pixels | 108631.79 | 109794.00 | 90331.50 | 92448.00 | observation only |
| Residue ratio | 0.559443 | 0.576416 | 0.518982 | 0.522921 | observation only |
| Component count | 194.87 | 98.00 | 397.67 | 277.00 | insufficient sample size |

The saucer values must not be generalized because only six unique enabled saucer images are available.

## Limitations

- Saucer coverage is limited to six unique enabled images.
- Confidence, notes, warnings, and quality scores are not production metrics in this baseline.
- Full graph relation counts grow quadratically with component count, so relation averages are strongly skewed by high-component records.
- Statistical candidates do not establish defects, semantic meaning, or production acceptance thresholds.
- This evaluation does not inspect images or recompute pipeline metrics.

## Findings Requiring Future Investigation

- Increase saucer dataset size.
- Evaluate metric distributions after larger dataset.
- Compare future baselines against m5b-001.
- Do not compare confidence until confidence becomes a production metric.

These are investigation candidates only. No algorithm or pipeline work is initiated by this report.

## Finding Classification

| Classification | Finding |
|---|---|
| expected behavior | Fixed working resolution and full-relation graph invariants |
| observation only | Cup and saucer metric ranges and central tendencies |
| possible future investigation | Cup IQR outlier candidates |
| insufficient sample size | Saucer distribution comparisons and m5b-saucer-006 candidate |
| no issue detected | Execution success, repeat determinism, JSON/CSV consistency |

## Input Integrity

- validation_report.json SHA-256: 2751928f85bb611a484577a035dc6f1062d46725b696908a1ff4e14da70f6c5c
- validation_summary.csv SHA-256: 732c62fc691ab364c9a6af7b9c8355fbf9c87e8c01f752d9e48113ccaead92ab
- Both baseline inputs were read only and verified unchanged after evaluation generation.

## No Algorithm Change Confirmation

This evaluation created reporting documentation only. No production algorithm, threshold, pipeline configuration, dataset image, frozen manifest, validation report, validation CSV, or analyzeDetailed() behavior was changed. No new analysis run was executed.
