"""Local image-feature experiment. Never uploads images or changes app policy.

Frozen MobileNetV3 features + balanced ridge head. Hyperparameters and decision
bands use calibration group folds only. Validation is evaluated after saving
the model and settings. Images/weights/results must remain outside Git.
"""
import argparse
import hashlib
import json
from pathlib import Path
import sys
import time
import numpy as np
from PIL import Image, ImageOps
import torch
from torch import nn
from torchvision import models, transforms

sys.path.insert(0, str(Path(__file__).parent))
from report_suitability import report


class Encoder(nn.Module):
    def __init__(self, network):
        super().__init__()
        self.features = network.features
        self.pool = network.avgpool

    def forward(self, image):
        return self.pool(self.features(image)).flatten(1)


class Screen(nn.Module):
    def __init__(self, encoder, weight, bias):
        super().__init__()
        self.encoder = encoder
        self.register_buffer('weight', torch.tensor(weight, dtype=torch.float32))
        self.register_buffer('bias', torch.tensor(bias, dtype=torch.float32))

    def forward(self, image):
        feature = self.encoder(image)
        feature = feature / feature.norm(dim=1, keepdim=True).clamp(min=1e-12)
        return feature @ self.weight + self.bias


def fit(x, y, group, regularization):
    # Equal total weight per class, then per independent group in that class.
    counts = {g: int(np.sum(group == g)) for g in set(group)}
    ng = {label: len(set(group[y == label])) for label in (-1, 1)}
    sample = np.array([1 / (ng[int(label)] * counts[g]) for label, g in zip(y, group)])
    sample *= len(y) / sample.sum()
    xb = np.column_stack((x, np.ones(len(x))))
    root = np.sqrt(sample)
    scaled = xb * root[:, None]
    # Dual ridge: fewer than 60 examples, hundreds of frozen features.
    alpha = np.linalg.solve(scaled @ scaled.T + regularization * np.eye(len(x)), y * root)
    w = scaled.T @ alpha
    return w[:-1], w[-1]


def thresholds(score, y):
    # Require likeness to the negative calibration distribution for rejection,
    # not merely being below the least-positive calibration sample.
    reject = float(min(score[y == -1].max() - .03, score[y == 1].min() - .03))
    support = float(max(score[y == 1].min() + .03, score[y == -1].max() + .03))
    if reject > support:
        reject = support = (reject + support) / 2
    return reject, support


def status(score, reject, support):
    return 'unsuitable' if score < reject else 'supported' if score > support else 'uncertain'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--fixtures', type=Path, required=True)
    parser.add_argument('--out', type=Path, required=True)
    parser.add_argument('--development-pool', action='store_true',
                        help='Use previously viewed data for development; produces NO independent validation claim.')
    args = parser.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)
    torch.set_num_threads(4)
    torch.manual_seed(42)
    torch.hub.set_dir(str(args.out / 'public-weights'))
    weights = models.MobileNet_V3_Small_Weights.IMAGENET1K_V1
    encoder = Encoder(models.mobilenet_v3_small(weights=weights)).eval()
    # Fixed whole-frame preprocessing; no user annotation/crop coordinates change.
    transform = transforms.Compose([transforms.Resize((224, 224)), transforms.ToTensor(),
                                    transforms.Normalize([.485, .456, .406], [.229, .224, .225])])
    rows = json.loads((args.fixtures / 'manifest.json').read_text(encoding='utf-8'))
    if args.development_pool:
        for row in rows:
            row['originalSplit'] = row['split']
            row['split'] = 'development'
    original_groups = {r['file']: r['groupId'] for r in rows}
    for i in range(36, 43):
        for row in rows:
            if row['file'] == f'sample-{i + 100:03}.jpg':
                row['groupId'] = original_groups[f'sample-{i:03}.jpg']
    cache = args.out / 'features.npz'
    if cache.exists():
        data = np.load(cache)
        if list(data['hashes']) != [r['sha256'] for r in rows]:
            raise ValueError('Feature cache fixture identity mismatch')
        x = data['x']
    else:
        features = []
        for start in range(0, len(rows), 16):
            batch = []
            for row in rows[start:start + 16]:
                path = args.fixtures / row['file']
                if hashlib.sha256(path.read_bytes()).hexdigest() != row['sha256']:
                    raise ValueError('Fixture checksum mismatch')
                with Image.open(path) as image:
                    batch.append(transform(ImageOps.exif_transpose(image).convert('RGB')))
            with torch.inference_mode():
                feature = encoder(torch.stack(batch))
                feature = feature / feature.norm(dim=1, keepdim=True).clamp(min=1e-12)
            features.append(feature.numpy())
            print(f'Local features: {min(start + 16, len(rows))}/{len(rows)}', flush=True)
        x = np.concatenate(features).astype(np.float64)
        np.savez(cache, x=x, hashes=[r['sha256'] for r in rows])
    indices = np.array([i for i, r in enumerate(rows) if r['split'] == 'calibration' or args.development_pool])
    y = np.array([1 if rows[i]['label'] == 'residue' else -1 for i in indices])
    groups = np.array([rows[i]['groupId'] for i in indices])
    trials = []
    fold_scores = {}
    for regularization in (.01, .1, 1, 10):
        scores = np.zeros(len(indices))
        for group in sorted(set(groups)):
            train, held = groups != group, groups == group
            w, bias = fit(x[indices[train]], y[train], groups[train], regularization)
            scores[held] = x[indices[held]] @ w + bias
        reject, support = thresholds(scores, y)
        rates = []
        for label in (-1, 1):
            correct = []
            for group in set(groups[y == label]):
                values = scores[groups == group]
                correct.append(all(status(s, reject, support) == ('supported' if label == 1 else 'unsuitable') for s in values))
            rates.append(sum(correct) / len(correct))
        trials.append(dict(regularization=regularization, rejectBelow=reject,
                           supportAbove=support, calibrationPositiveRate=rates[1],
                           calibrationNegativeRate=rates[0], balancedRate=sum(rates) / 2))
        fold_scores[regularization] = scores.copy()
    frozen = dict(max(trials, key=lambda r: r['balancedRate']))
    w, bias = fit(x[indices], y, groups, frozen['regularization'])
    frozen.update(backbone='torchvision/MobileNetV3-small/IMAGENET1K_V1',
                  preprocessing='EXIF RGB; whole-frame bilinear resize 224x224; ImageNet normalization',
                  calibrationGroups=len(set(groups)), calibrationPhotos=len(indices),
                  calibrationSha256=hashlib.sha256(json.dumps([rows[i] for i in indices], sort_keys=True).encode()).hexdigest())
    frozen['evaluationStatus'] = 'Development evaluation only; previous iteration saw these validation images.'
    frozen['trainingPool'] = 'all previously viewed development groups' if args.development_pool else 'original calibration only'
    if args.development_pool:
        cv_rows = [dict(rows[i], split='validation',
                       candidateStatus=status(fold_scores[frozen['regularization']][j], frozen['rejectBelow'], frozen['supportAbove']))
                   for j, i in enumerate(indices)]
        cv_document = dict(rows=cv_rows, complete=True, evidenceAuditPassed=False, blockingEnabled=False)
        (args.out / 'group-cross-validation.json').write_text(json.dumps(dict(
            evaluationType='Development leave-one-group-out CV; NOT independent release acceptance',
            metrics=report(cv_document), rows=cv_rows), indent=2), encoding='utf-8')
    model = Screen(encoder, w, bias).eval()
    torch.save(model.state_dict(), args.out / 'screen-state.pt')
    (args.out / 'frozen.json').write_text(json.dumps(dict(selected=frozen, trials=trials), indent=2), encoding='utf-8')
    # No validation data contributes to fitting or selecting parameters above.
    scores = x @ w + bias
    result_rows = []
    for i, row in enumerate(rows):
        if row['split'] != 'validation' and not args.development_pool:
            continue
        result_rows.append(dict(row, candidateStatus=status(scores[i], frozen['rejectBelow'], frozen['supportAbove']),
                                modelScore=float(scores[i])))
    document = dict(rows=result_rows, complete=True, blockingEnabled=False, evidenceAuditPassed=False)
    result = dict(parameters=frozen, validation=report(document), rows=result_rows,
                  limitations=['Previously viewed validation; not new independent acceptance.',
                               'No held-out lighter/portrait and insufficient cup/empty groups.',
                               'No real Android device parity/latency measurement.'])
    (args.out / 'results.json').write_text(json.dumps(result, indent=2), encoding='utf-8')
    print(json.dumps(result['validation'], indent=2), flush=True)
    # Export one identical frozen model for diagnostic Android inference.
    torch.onnx.export(model, torch.zeros(1, 3, 224, 224), str(args.out / 'screen.onnx'),
                      input_names=['image'], output_names=['score'], opset_version=17,
                      dynamo=False)
    import onnxruntime as ort
    session = ort.InferenceSession(str(args.out / 'screen.onnx'), providers=['CPUExecutionProvider'])
    rng = np.random.default_rng(42)
    image = rng.random((1, 3, 224, 224), dtype=np.float32)
    with torch.inference_mode():
        expected = model(torch.from_numpy(image)).numpy()
    actual = session.run(None, {'image': image})[0]
    error = float(np.max(np.abs(expected - actual)))
    if error > 1e-4:
        raise RuntimeError('Export parity failed')
    (args.out / 'export-parity.json').write_text(json.dumps(dict(maxAbsoluteError=error,
                                                               modelSha256=hashlib.sha256((args.out/'screen.onnx').read_bytes()).hexdigest())), encoding='utf-8')
    print('ONNX export parity:', error, flush=True)


if __name__ == '__main__':
    main()
