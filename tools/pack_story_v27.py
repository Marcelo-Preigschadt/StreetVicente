"""Register actual ImageGen poses by connected body, not assumed cell cuts.

Some fists cross nominal grid cells. Cropping cells would amputate those poses.
This packer preserves every painted pixel in each isolated body and encodes it;
it never fabricates, warps, recolors or rescales a pose.
"""
import hashlib
import json
import statistics
from pathlib import Path

import numpy as np
from PIL import Image
from scipy.ndimage import find_objects, label
from scipy.cluster.vq import kmeans2

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'assets/source/story-v27'
OUTPUT = ROOT / 'assets/story/v27'


def bodies(image, rows):
    pixels = np.array(image)
    labels, _ = label(pixels[:, :, 3] > 80, np.ones((3, 3)))
    found = []
    for index, region in enumerate(find_objects(labels), 1):
        if region is None:
            continue
        area = np.count_nonzero(labels[region] == index)
        if area < image.width * image.height * .003:
            continue
        y, x = region
        found.append((x.start, y.start, x.stop, y.stop))
    # Cluster by the planted baseline: prone poses have a different height but
    # still belong to their authored row. Explicit seeds make ordering repeatable.
    baseline = np.array([[box[3]] for box in found], dtype=float)
    seeds = np.array([[image.height * (i + 1) / rows] for i in range(rows)])
    centers, clusters = kmeans2(baseline, seeds, minit='matrix')
    rank = {int(index): order for order, index in enumerate(np.argsort(centers[:, 0]))}
    ordered = sorted(zip(found, clusters), key=lambda item: (rank[int(item[1])], item[0][0]))
    return [box for box, _ in ordered]


def atlas(name, rows, count):
    image = Image.open(SOURCE / (name + '.png')).convert('RGBA')
    boxes = bodies(image, rows)
    assert len(boxes) == count, (name, len(boxes), count)
    frames = []
    for x, y, right, bottom in boxes:
        x, y = max(0, x - 3), max(0, y - 3)
        right, bottom = min(image.width, right + 3), min(image.height, bottom + 3)
        crop = np.array(image.crop((x, y, right, bottom)))
        ys, xs = np.where(crop[:, :, 3] > 160)
        feet = xs[ys >= np.quantile(ys, .82)]
        anchor = float(np.quantile(feet, .05) + np.quantile(feet, .95)) / 2
        frames.append({'rect': [x, y, right - x, bottom - y],
                       'anchorX': round(anchor, 3), 'bottom': bottom - y - 3})
    heights = [frame['rect'][3] for frame in frames[:9 if count == 25 else 8]]
    output = OUTPUT / (name + '.webp')
    image.save(output, 'WEBP', quality=94, method=6)
    sequence = {
        'idle': 0, 'walk': list(range(1, 9)), 'walkUnits': 'distance', 'walkTempo': 112,
        'windup': 9, 'acceleration': 10, 'contact': 12, 'recovery': 16,
        'windupFrames': [9, 10, 11], 'contactFrames': [12, 13], 'recoveryFrames': [14, 15, 16],
        'hit': 17, 'hurtFrames': [17, 18], 'fall': [19, 20, 21], 'wake': [22, 23, 24, 0]
    }
    if name == 'heavy':
        sequence['fall'] = [19, 20, 21, 22]
        sequence['wake'] = [23, 24, 0]
    if name == 'drone':
        sequence.update({'walk': list(range(8)), 'walkUnits': 'time', 'walkTempo': 8,
                         'windup': 8, 'contact': 10, 'recovery': 11, 'hit': 12,
                         'windupFrames': [8, 9], 'contactFrames': [10], 'recoveryFrames': [11],
                         'hurtFrames': [12], 'fall': [13, 14, 15], 'wake': [14, 13, 0]})
    result = {'file': 'res://' + output.relative_to(ROOT).as_posix(), 'revision': 27,
              'referenceHeight': statistics.median(heights), 'frames': frames, 'sequences': sequence,
              'source_sha256': hashlib.sha256((SOURCE / (name + '.png')).read_bytes()).hexdigest()}
    print(name, len(frames), 'complete painted poses; gait heights', heights)
    return result


def main():
    OUTPUT.mkdir(exist_ok=True, parents=True)
    result = {'revision': 27, 'atlases': {name: atlas(name, rows, count)
              for name, rows, count in [('guard', 5, 25), ('heavy', 5, 25), ('drone', 4, 16)]},
              'props': {}}
    image = Image.open(SOURCE / 'props.png').convert('RGBA')
    boxes = bodies(image, 2)
    assert len(boxes) == 4
    for (name, height), (x, y, right, bottom) in zip(
            [('table', 136), ('chair', 172), ('medkit', 42), ('soda', 310)], boxes):
        crop = image.crop((max(0, x - 3), max(0, y - 3), min(image.width, right + 3), min(image.height, bottom + 3)))
        target = OUTPUT / (name + '.webp')
        crop.save(target, 'WEBP', quality=94, method=6)
        result['props'][name] = {'file': 'res://' + target.relative_to(ROOT).as_posix(),
                                 'size': [round(height * crop.width / crop.height), height]}
    (ROOT / 'data/story/art-v27.json').write_text(json.dumps(result, separators=(',', ':')) + '\n')


if __name__ == '__main__':
    main()
