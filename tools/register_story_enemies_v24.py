"""Register existing robot bodies without changing any raster pixels.

Electric trails and isolated alpha specks cannot define the support point.
Use the largest opaque neutral/dark component, then its lower body footprint.
"""
import json
import statistics
from collections import deque
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]


def quantile(values, ratio):
    values = sorted(values)
    return values[min(len(values) - 1, int((len(values) - 1) * ratio))]


def register(cell):
    width, height = cell.size
    mask = set()
    for y in range(height):
        for x in range(width):
            r, g, b, a = cell.getpixel((x, y))
            if a >= 200 and (max(r, g, b) - min(r, g, b) <= 90 or max(r, g, b) <= 100):
                mask.add(y * width + x)
    largest = []
    while mask:
        seed = mask.pop()
        component, pending = [seed], deque([seed])
        while pending:
            value = pending.popleft()
            x, y = value % width, value // width
            for nx, ny in ((x-1, y), (x+1, y), (x, y-1), (x, y+1)):
                neighbor = ny * width + nx
                if 0 <= nx < width and 0 <= ny < height and neighbor in mask:
                    mask.remove(neighbor)
                    component.append(neighbor)
                    pending.append(neighbor)
        if len(component) > len(largest):
            largest = component
    assert len(largest) > width * height * .02
    ys = [value // width for value in largest]
    top, bottom = quantile(ys, .015), quantile(ys, .995) + 1
    foot = [value % width for value in largest if value // width >= bottom - (bottom-top) * .28]
    anchor = (quantile(foot, .04) + quantile(foot, .96)) / 2
    return {'anchorX': anchor, 'bottom': bottom, 'bodyHeight': bottom-top}


def main():
    source = json.loads((ROOT / 'data/story/enemy-animation-v23.json').read_text())
    result = {'revision': 24, 'method': 'opaque-body-support', 'enemies': {}}
    for kind, atlas in source['enemies'].items():
        if kind in ('book', 'projector'):
            continue  # Flexible pages/cables are not a rigid ground support.
        image = Image.open(ROOT / atlas['file'].removeprefix('res://')).convert('RGBA')
        frames = []
        for original in atlas['frames']:
            x, y, width, height = original['rect']
            frames.append(register(image.crop((x, y, x+width, y+height))))
        reference = statistics.median(frame['bodyHeight'] for frame in frames[:8])
        for index, frame in enumerate(frames):
            frame['scaleCorrection'] = round(max(.94, min(1.06, reference/frame['bodyHeight'])), 6) if index < 8 else 1.0
        result['enemies'][kind] = frames
        print(kind, 'body support:', [(f['anchorX'], f['bottom']) for f in frames])
    (ROOT / 'data/story/enemy-registration-v24.json').write_text(json.dumps(result, separators=(',', ':'))+'\n')


if __name__ == '__main__':
    main()
