"""Encode ImageGen cels and register their alpha baselines; never synthesize a pose."""
import argparse
import hashlib
import json
import statistics
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
IDS = ['snack', 'turnstile', 'cleaner', 'vial', 'scanner', 'book', 'projector']


def pack(source):
    catalog = json.loads((ROOT / 'data/legacy/catalog.json').read_text())['story']['enemies']
    result = {'revision': 23, 'enemies': {}}
    for kind in IDS:
        raw = source / (kind + '.png')
        image = Image.open(raw).convert('RGBA')
        frames = []
        heights = []
        for index in range(16):
            col, row = index % 4, index // 4
            x, y = round(col * image.width / 4), round(row * image.height / 4)
            right, bottom = round((col + 1) * image.width / 4), round((row + 1) * image.height / 4)
            cell = image.crop((x, y, right, bottom))
            bounds = cell.getchannel('A').point(lambda a: 255 if a >= 120 else 0).getbbox()
            assert bounds, (kind, index)
            heights.append(bounds[3] - bounds[1])
            frames.append({'rect': [x, y, right - x, bottom - y],
                           'anchorX': (right - x) / 2, 'bottom': bounds[3]})
        output = ROOT / 'assets/story/v23' / (kind + '.webp')
        output.parent.mkdir(parents=True, exist_ok=True)
        image.save(output, 'WEBP', quality=92, method=6)
        result['enemies'][kind] = {
            'file': 'res://' + output.relative_to(ROOT).as_posix(),
            'scale': catalog[kind]['h'] / statistics.median(heights[:8]),
            'frames': frames, 'source_sha256': hashlib.sha256(raw.read_bytes()).hexdigest(),
            'sequences': {'walk': list(range(8)), 'walkUnits': 'time' if kind in ['snack', 'book', 'projector'] else 'distance',
                          'walkTempo': 10 if kind in ['snack', 'book', 'projector'] else 140,
                          'windup': 8, 'acceleration': 9, 'contact': 10,
                          'recovery': 0 if kind in ['snack', 'vial'] else 11,
                          'hit': 12, 'fall': [13, 14, 15]}}
        print(kind, image.size, '16 cels', output.stat().st_size, 'bytes')
    target = ROOT / 'data/story/enemy-animation-v23.json'
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(json.dumps(result, ensure_ascii=False, separators=(',', ':')) + '\n')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('source', type=Path)
    pack(parser.parse_args().source)
