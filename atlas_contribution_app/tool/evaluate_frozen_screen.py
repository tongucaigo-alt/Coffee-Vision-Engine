"""Evaluate a frozen local model without training or changing thresholds."""
import argparse
import hashlib
import json
from pathlib import Path
import time
import numpy as np
import onnxruntime as ort
from PIL import Image, ImageOps
from report_suitability import report


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--model-directory', type=Path, required=True)
    parser.add_argument('--fixtures', type=Path, required=True)
    parser.add_argument('--decision-settings', type=Path,
                        help='Explicit frozen decision metadata for preprocessing/decision revisions')
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    model = args.model_directory/'screen.onnx'
    identity = json.loads((args.model_directory/'export-parity.json').read_text())['modelSha256']
    if hashlib.sha256(model.read_bytes()).hexdigest() != identity:
        raise ValueError('Model identity changed')
    decision_file = args.decision_settings or args.model_directory/'frozen.json'
    decision = json.loads(decision_file.read_text())
    settings = decision.get('selected', decision)
    if settings.get('modelSha256', identity) != identity:
        raise ValueError('Decision metadata/model identity mismatch')
    manifest_file = args.fixtures/'manifest.json'
    rows = json.loads(manifest_file.read_text(encoding='utf-8'))
    session = ort.InferenceSession(str(model), providers=['CPUExecutionProvider'])
    output = []
    for source in rows:
        row = dict(source)
        start = time.perf_counter()
        try:
            path = args.fixtures/row['file']
            if hashlib.sha256(path.read_bytes()).hexdigest() != row['sha256']:
                raise ValueError('Fixture checksum')
            with Image.open(path) as raw:
                image = ImageOps.exif_transpose(raw).convert('RGB').resize((224,224), Image.Resampling.BILINEAR)
                values = np.array(image, dtype=np.float32).transpose(2,0,1)/np.float32(255)
            values = (values-np.array([.485,.456,.406],dtype=np.float32)[:,None,None]) / \
                np.array([.229,.224,.225],dtype=np.float32)[:,None,None]
            score = float(session.run(None, {'image':values[None]})[0][0])
            if not np.isfinite(score):
                raise ValueError('Non-finite score')
            status = 'unsuitable' if score < settings['rejectBelow'] else 'supported' if score > settings['supportAbove'] else 'uncertain'
            row.update(candidateStatus=status, modelScore=score, modelSha256=identity)
        except Exception as error:
            row.update(candidateStatus='error', errorType=type(error).__name__)
        row['milliseconds'] = (time.perf_counter()-start)*1000
        output.append(row)
    doc = dict(rows=output, complete=True, evidenceAuditPassed=False, blockingEnabled=False,
               modelSha256=identity, manifestSha256=hashlib.sha256(manifest_file.read_bytes()).hexdigest(),
               thresholdsUnchanged=True, independentOfFitting=True,
               decisionSettingsSha256=hashlib.sha256(decision_file.read_bytes()).hexdigest())
    doc['report'] = report(doc)
    args.out.write_text(json.dumps(doc,indent=2),encoding='utf-8')
    for label, g in doc['report']['groups'].items():
        print(label, {k:g[k] for k in ('photos','independentGroups','blockedPhotos','supportedPhotos','uncertainPhotos','groupSuccessRate','errors')})


if __name__ == '__main__':
    main()
