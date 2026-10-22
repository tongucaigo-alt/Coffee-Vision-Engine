"""Evaluate a frozen two-view photo filter, without fitting or threshold changes.

Fixture rows require file, sha256, label, groupId. An optional displayCrop has
normalized x/y/width/height. Missing crops mean the gallery's full-frame default.
Development cases can be checked separately; they never satisfy release gates.
"""
import argparse
from collections import Counter, defaultdict
import hashlib
import json
from pathlib import Path

import numpy as np
import onnxruntime as ort
from PIL import Image, ImageOps


def classify(scores, reject, support):
    negatives = sum(s < reject for s in scores)
    positives = sum(s > support for s in scores)
    if negatives == 2:
        return 'unsuitable'
    if negatives:
        return 'uncertain'
    return 'supported' if positives == 2 else 'uncertain'


def summarize(rows):
    output = {}
    for label in sorted({r['label'] for r in rows}):
        subset = [r for r in rows if r['label'] == label]
        groups = defaultdict(list)
        for row in subset:
            groups[row['groupId']].append(row['status'])
        # A multi-view object only passes a gate when every view passes it.
        supported = sum(all(s == 'supported' for s in g) for g in groups.values())
        rejected = sum(all(s == 'unsuitable' for s in g) for g in groups.values())
        output[label] = dict(
            photos=len(subset), groups=len(groups),
            photoStatuses=dict(Counter(r['status'] for r in subset)),
            allViewsSupportedGroups=supported, allViewsRejectedGroups=rejected,
            anySupportedGroups=sum('supported' in g for g in groups.values()),
            anyRejectedGroups=sum('unsuitable' in g for g in groups.values()),
            supportedGroupRate=supported / len(groups),
            rejectedGroupRate=rejected / len(groups),
        )
    return output


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--model-directory', type=Path, required=True)
    parser.add_argument('--fixtures', type=Path, required=True)
    parser.add_argument('--development-cases', action='store_true')
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    model = args.model_directory / 'screen.onnx'
    parity = json.loads((args.model_directory / 'export-parity.json').read_text())
    identity = hashlib.sha256(model.read_bytes()).hexdigest()
    if identity != parity['modelSha256']:
        raise ValueError('Frozen model identity mismatch')
    decision_file = args.model_directory / 'frozen.json'
    settings = json.loads(decision_file.read_text())['selected']
    manifest_file = args.fixtures / 'manifest.json'
    sources = json.loads(manifest_file.read_text(encoding='utf-8-sig'))
    if not args.development_cases and any(r.get('split') != 'validation' for r in sources):
        raise ValueError('Evaluation must contain only locked validation groups')
    options = ort.SessionOptions()
    options.intra_op_num_threads = 2
    engine = ort.InferenceSession(str(model), options, providers=['CPUExecutionProvider'])
    mean = np.array([.485, .456, .406], dtype=np.float32)[:, None, None]
    deviation = np.array([.229, .224, .225], dtype=np.float32)[:, None, None]

    def score(image):
        rgb = image.resize((224, 224), Image.Resampling.BILINEAR)
        values = np.asarray(rgb, dtype=np.float32).transpose(2, 0, 1) / np.float32(255)
        value = float(engine.run(None, {'image': ((values - mean) / deviation)[None]})[0][0])
        if not np.isfinite(value):
            raise ValueError('Non-finite score')
        return value

    rows = []
    for source in sources:
        row = dict(source)
        try:
            path = args.fixtures / row['file']
            if hashlib.sha256(path.read_bytes()).hexdigest() != row['sha256']:
                raise ValueError('Photo checksum mismatch')
            with Image.open(path) as raw:
                image = ImageOps.exif_transpose(raw).convert('RGB')
                crop = row.get('displayCrop', dict(x=0, y=0, width=1, height=1))
                x = max(0, min(image.width - 1, int(crop['x'] * image.width)))
                y = max(0, min(image.height - 1, int(crop['y'] * image.height)))
                w = max(1, min(image.width - x, int(crop['width'] * image.width)))
                h = max(1, min(image.height - y, int(crop['height'] * image.height)))
                scores = [score(image), score(image.crop((x, y, x + w, y + h)))]
            row.update(scores=scores, status=classify(scores, settings['rejectBelow'], settings['supportAbove']))
        except Exception as error:
            row.update(status='error', errorType=type(error).__name__)
        rows.append(row)
    summary = summarize(rows)
    positive = summary.get('residue', {})
    gates = dict(
        realCupGroupCount=positive.get('groups', 0) >= 30,
        noRealCupHardRejection=positive.get('anyRejectedGroups', 1) == 0,
        realCupDirectAcceptance=positive.get('supportedGroupRate', 0) >= .9,
        noTechnicalErrors=all(r['status'] != 'error' for r in rows),
    )
    for label in ('ashtray', 'bowl'):
        group = summary.get(label, {})
        gates[label + 'GroupCount'] = group.get('groups', 0) >= 10
        gates[label + 'NoAcceptance'] = group.get('anySupportedGroups', 1) == 0
        gates[label + 'HardRejection'] = group.get('rejectedGroupRate', 0) >= .8
    result = dict(
        rows=rows, summary=summary, gates=gates,
        releaseGatePassed=not args.development_cases and all(gates.values()),
        developmentCases=args.development_cases, modelSha256=identity,
        manifestSha256=hashlib.sha256(manifest_file.read_bytes()).hexdigest(),
        decisionSettingsSha256=hashlib.sha256(decision_file.read_bytes()).hexdigest(),
        rejectBelow=settings['rejectBelow'], supportAbove=settings['supportAbove'],
        thresholdsUnchanged=True, automaticEvidenceUsed=False,
        groupPolicy='All views must pass; uncertain and errors remain in denominator',
        limitations='Desktop ONNX evaluation; older cup holdout was used in previous-model evaluation. Not a phone camera success measurement.',
    )
    args.out.write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding='utf-8')
    print(json.dumps({k: result[k] for k in ('summary', 'gates', 'releaseGatePassed')}, indent=2))


if __name__ == '__main__':
    main()
