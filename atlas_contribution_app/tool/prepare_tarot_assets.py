"""Create verified derived assets; source artwork remains untouched."""
import argparse
import json
import math
from pathlib import Path
from PIL import Image, ImageChops, ImageStat, ImageDraw


def prepare(source, output, report_dir):
    cards_dir = source / 'Tarot Ayrı ayrı' / 'kartlar'
    cards = json.loads((source / 'Tarot Ayrı ayrı' / 'Kütüphane' /
                        'tarot_kutuphanesi.json').read_text(encoding='utf-8'))
    manifest = json.loads((cards_dir / 'manifest.json').read_text(encoding='utf-8'))
    assert len(cards) == len({c['id'] for c in cards}) == 78
    assert len(manifest) == 79
    assert all(c['duz_temalar'] and c['ters_temalar'] for c in cards)
    assert {c['gorsel'] for c in cards} <= {c['dosya'] for c in manifest}
    output.mkdir(parents=True, exist_ok=True)
    report_dir.mkdir(parents=True, exist_ok=True)
    results, previews = [], []
    for entry in manifest:
        name = entry['dosya']
        original = Image.open(cards_dir / name).convert('RGB')
        assert original.size == (1024, 1536)
        target = output / (Path(name).stem + '.webp')
        original.save(target, 'WEBP', quality=90, method=6)
        decoded = Image.open(target).convert('RGB')
        stat = ImageStat.Stat(ImageChops.difference(original, decoded))
        mse = sum(r * r for r in stat.rms) / 3
        psnr = 10 * math.log10(255 * 255 / mse) if mse else 99.0
        lossless = psnr < 40  # Conservatively preserve line art that loses detail.
        if lossless:
            original.save(target, 'WEBP', lossless=True, method=6)
            decoded = Image.open(target).convert('RGB')
            assert ImageChops.difference(original, decoded).getbbox() is None
        results.append({'source': name, 'output': target.name, 'lossless': lossless,
                        'q90_psnr': round(psnr, 2), 'bytes': target.stat().st_size,
                        'source_bytes': (cards_dir / name).stat().st_size})
        pair = Image.new('RGB', (320, 264), '#faf7f2')
        a, b = original.copy(), decoded.copy()
        a.thumbnail((156, 234)); b.thumbnail((156, 234))
        pair.paste(a, (2, 0)); pair.paste(b, (162, 0))
        draw = ImageDraw.Draw(pair)
        draw.text((4, 236), name, fill='black')
        draw.text((4, 250), 'PNG', fill='black')
        draw.text((164, 250), 'WebP', fill='black')
        previews.append(pair)
        original.close(); decoded.close()
    for page in range(math.ceil(len(previews) / 20)):
        sheet = Image.new('RGB', (1280, 1320), '#faf7f2')
        for i, pair in enumerate(previews[page * 20:(page + 1) * 20]):
            sheet.paste(pair, ((i % 4) * 320, (i // 4) * 264))
        sheet.save(report_dir / f'comparison-{page + 1}.jpg', quality=95)
    for card in cards:
        card['gorsel'] = Path(card['gorsel']).stem + '.webp'
    (output / 'catalog-v1.json').write_text(json.dumps(cards, ensure_ascii=False,
                                                    indent=2), encoding='utf-8')
    report = {'cards': len(cards), 'images': len(results),
              'source_bytes': sum(r['source_bytes'] for r in results),
              'output_bytes': sum(r['bytes'] for r in results),
              'lossless_count': sum(r['lossless'] for r in results), 'images_detail': results}
    (report_dir / 'asset-report.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
    print(json.dumps({k: v for k, v in report.items() if k != 'images_detail'}))


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--source', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--report', type=Path, required=True)
    args = parser.parse_args()
    prepare(args.source, args.output, args.report)
