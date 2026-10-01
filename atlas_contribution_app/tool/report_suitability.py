"""Report held-out photo screening without dropping uncertain/error results.

Input is the diagnostic benchmark JSON. This never changes production thresholds
or enables blocking. Similar views sharing groupId count as one independent unit.
"""
import argparse
import json
from collections import defaultdict
from pathlib import Path


def report(document):
    rows = document['rows']
    groups = defaultdict(list)
    fingerprints = set()
    split_by_group = {}
    for row in rows:
        if row['sha256'] in fingerprints:
            raise ValueError('Duplicate fixture checksum')
        fingerprints.add(row['sha256'])
        group = row['groupId']
        if group in split_by_group and split_by_group[group] != row['split']:
            raise ValueError('Group leaks across calibration and validation')
        split_by_group[group] = row['split']
        if row['split'] == 'validation':
            groups[row['label']].append(row)

    output = {'complete': document.get('complete', False), 'groups': {}}
    passing = output['complete']
    for label, minimum in [('residue', 30), ('keyboard', 10), ('other', 20), ('empty', 20)]:
        selected = groups[label]
        by_group = defaultdict(list)
        for row in selected:
            by_group[row['groupId']].append(row)
        blocked = lambda r: r['candidateStatus'] in ('unsuitable', 'residueFree')
        errors = sum(r['candidateStatus'] == 'error' for r in selected)
        if label == 'residue':
            successes = sum(not any(blocked(r) or r['candidateStatus'] == 'error' for r in rs)
                            for rs in by_group.values())
            threshold = .95
        else:
            # A group succeeds only if every selected view was rejected.
            successes = sum(all(blocked(r) for r in rs) for rs in by_group.values())
            threshold = .80
        rate = successes / len(by_group) if by_group else 0
        accepted = len(by_group) >= minimum and rate >= threshold and errors == 0
        passing = passing and accepted
        output['groups'][label] = {
            'photos': len(selected), 'independentGroups': len(by_group),
            'blockedPhotos': sum(blocked(r) for r in selected), 'errors': errors,
            'uncertainPhotos': sum(r['candidateStatus'] == 'uncertain' for r in selected),
            'successfulGroups': successes, 'groupSuccessRate': rate,
            'minimumGroups': minimum, 'passes': accepted,
        }
    output['releaseGatePassed'] = bool(passing)
    output['productionBlockingEnabled'] = document.get('blockingEnabled', False)
    return output


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('results', type=Path)
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    result = report(json.loads(args.results.read_text(encoding='utf-8')))
    args.out.write_text(json.dumps(result, indent=2), encoding='utf-8')
    print(json.dumps(result, indent=2))
