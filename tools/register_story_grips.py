"""Read approved cel alpha silhouettes and register grip points; no pixels are edited."""
import json
from pathlib import Path
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
sources = json.loads((ROOT / '.tools/story-grip-sources.json').read_text())
images = {}
grips = {}
for key, frame in sources.items():
    image = frame['image']
    if image not in images:
        images[image] = Image.open(ROOT / image.removeprefix('res://')).convert('RGBA')
    x, y, w, h = map(int, frame['rect'])
    alpha = np.asarray(images[image].crop((x, y, x+w, y+h)))[:, :, 3]
    ys, xs = np.where(alpha > 245)
    k = frame['scale']
    height = (ys.max() - ys.min() + 1) * k
    world_y = (ys + frame['y'] - frame['bottom']) * k
    band = (world_y >= -height * .88) & (world_y <= -height * .37)
    assert band.any(), key
    bx, by = xs[band], ys[band]
    front = bx.max()
    edge = bx >= front - max(2, round(7 / k))
    px = float(np.median(bx[edge]))
    py = float(np.median(by[edge]))
    grips[key] = [round((px + frame['x'] - frame['anchor']) * k * frame['width'], 3),
                  round((py + frame['y'] - frame['bottom']) * k, 3)]
target = ROOT / 'data/story/hand-grips-v23.json'
target.write_text(json.dumps(grips, ensure_ascii=False, separators=(',', ':')) + '\n')
print('Registered grip points:', len(grips), 'bytes:', target.stat().st_size)
