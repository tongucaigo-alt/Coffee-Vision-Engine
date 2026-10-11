"""Diagnostic-only nearest-group experiment over existing local measurements.

Uses no image service, downloads or production code. All parameter selection is
leave-one-group-out on calibration. Validation is evaluated once after freezing.
Top-three ImageNet scores are incomplete features, not a residue model.
"""
import argparse
import copy
import hashlib
import json
import math
from collections import defaultdict
from pathlib import Path
from report_suitability import report


PHYSICAL = ('relativeDarkRatio', 'meanLuminance', 'borderDarkShare',
            'largestComponentRatio', 'componentCount', 'centerDarkRatio',
            'centerLuminance')
# Visually audited recompressions; original manifest is never rewritten.
ALIASES = {f'sample-{i + 100:03}.jpg': f'sample-{i:03}.jpg' for i in range(36, 43)}


def features(row):
    scores = defaultdict(float)
    for view in ('full', 'crop'):
        for item in row['scores'][view]:
            scores[item['label']] += item['score'] / 2
    physical = []
    for key in PHYSICAL:
        value = sum(row['physical'][view][key] for view in ('full', 'crop')) / 2
        if 'Luminance' in key:
            value /= 255
        elif key == 'componentCount':
            value = math.log1p(value) / 10
        physical.append(value)
    return dict(scores), physical


def distance(a, b, weight):
    sa, pa = a
    sb, pb = b
    return sum((sa.get(k, 0) - sb.get(k, 0)) ** 2 for k in sa.keys() | sb.keys()) + \
        weight * sum((x - y) ** 2 for x, y in zip(pa, pb))


def margin(row, training, weight):
    query = features(row)
    positive = [distance(query, features(r), weight) for r in training if r['label'] == 'residue']
    negative = [distance(query, features(r), weight) for r in training if r['label'] != 'residue']
    if not positive or not negative:
        raise ValueError('Both classes required in every calibration fold')
    dp, dn = min(positive), min(negative)
    return (dp - dn) / max(dp + dn, 1e-9)


def decision(value, cutoff):
    if value > cutoff:
        return 'unsuitable'
    return 'supported' if value < 0 else 'uncertain'


def fit(rows):
    trials = []
    groups = {r['groupId'] for r in rows}
    for weight in (0, .25, 1, 4):
        predictions = []
        for row in rows:
            training = [r for r in rows if r['groupId'] != row['groupId']]
            predictions.append((row, margin(row, training, weight)))
        cutoff = max(0, max(m for r, m in predictions if r['label'] == 'residue')) + .02
        successes = []
        for group in sorted(groups):
            gr = [(r, m) for r, m in predictions if r['groupId'] == group]
            successes.append(all(decision(m, cutoff) == ('supported' if r['label'] == 'residue'
                                                        else 'unsuitable') for r, m in gr))
        trials.append(dict(weight=weight, rejectMargin=cutoff,
                           calibrationSuccessfulGroups=sum(successes),
                           calibrationGroups=len(groups)))
    return max(trials, key=lambda r: r['calibrationSuccessfulGroups']), trials


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('device_results', type=Path)
    parser.add_argument('--v34-replay', type=Path, required=True)
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    document = json.loads(args.device_results.read_text(encoding='utf-8'))
    replay = json.loads(args.v34_replay.read_text(encoding='utf-8'))
    groups = {r['file']: r['groupId'] for r in document['rows']}
    for doc in (document, replay):
        for row in doc['rows']:
            if row['file'] in ALIASES:
                row['groupId'] = groups[ALIASES[row['file']]]
        # Existing internet-source grouping is not independently confirmed.
        doc['evidenceAuditPassed'] = False
    calibration = [r for r in document['rows'] if r['split'] == 'calibration'
                   and r['candidateStatus'] != 'error']
    frozen, trials = fit(calibration)
    args.out.mkdir(parents=True, exist_ok=True)
    freeze = dict(parameters=frozen, calibrationTrials=trials,
                  calibrationSha256=hashlib.sha256(json.dumps(calibration, sort_keys=True).encode()).hexdigest(),
                  notes='Diagnostic experiment only. No validation-driven threshold changes.')
    # Persist frozen settings before any validation predictions.
    (args.out / 'frozen-experiment.json').write_text(json.dumps(freeze, indent=2), encoding='utf-8')
    candidate = copy.deepcopy(document)
    for row in candidate['rows']:
        if row['split'] == 'validation' and row['candidateStatus'] != 'error':
            row['candidateStatus'] = decision(margin(row, calibration, frozen['weight']), frozen['rejectMargin'])
    result = dict(v34DecisionReplay=report(replay), v35Device=report(document),
                  localNearestGroup=report(candidate), frozen=frozen,
                  mergedRecompressions=ALIASES,
                  limitations=['Existing validation has already been used by earlier experiments.',
                               'Group independence and source labels are not fully verified.',
                               'No keyboard/lighter calibration examples; one portrait.',
                               'V34 replay uses V35 EXIF-oriented scores, not new inference.',
                               'No device UI silent-pass measurement for the new candidate.'])
    (args.out / 'comparison.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
    for method in ('v34DecisionReplay', 'v35Device', 'localNearestGroup'):
        print(method)
        for label, values in result[method]['groups'].items():
            print(label, {k: values[k] for k in ('photos', 'independentGroups', 'blockedPhotos',
                                                'supportedPhotos', 'uncertainPhotos', 'groupSuccessRate')})


if __name__ == '__main__':
    main()
