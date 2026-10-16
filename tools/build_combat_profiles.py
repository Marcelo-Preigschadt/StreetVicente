"""Offline collision registration. Runtime reads integer rectangles, never pixels.

Rafael wears no cape: alpha bands remove the empty corners of the imported broad
boxes and preserve gaps between his legs. Offensive boxes are reviewed manually
against the actual fist/boot in each active drawing, not inferred from its size.
"""
from pathlib import Path
import json
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
catalog = json.loads((ROOT / 'data/legacy/catalog.json').read_text())
rafael = next(c for c in catalog['roster'] if c['id'] == 'rafael')
result = {'schema': 3, 'marcelo': {'push_half': 58, 'frames': {}},
          'rafael': {'push_half': 48, 'frames': {}}}
for name, sheet in rafael['atlases'].items():
    image = Image.open(ROOT / sheet['image'].removeprefix('res://')).convert('RGBA')
    frames = []
    for f in sheet['frames']:
        x, y, w, h = f['rect']; k = f.get('scale', sheet['scale'])
        sprite = image.crop((x, y, x+w, y+h)).resize((round(w*k), round(h*k)), Image.Resampling.LANCZOS)
        mask = np.asarray(sprite)[:, :, 3] > 190
        left = round((f.get('x', 0) - f['anchor']) * k)
        top = round((f.get('y', 0) - f['bottom']) * k)
        boxes = []
        for start in range(0, mask.shape[0], 14):
            band = mask[start:start+14]
            occupied = band.mean(axis=0) >= .60
            edges = np.diff(np.r_[False, occupied, False].astype(int))
            for a, b in zip(np.flatnonzero(edges == 1), np.flatnonzero(edges == -1)):
                if b-a < 9 or len(band) < 4: continue
                boxes.append([int(left+a+2), top+start+1, int(b-a-4), len(band)-2])
        frames.append({'hurt': boxes})
    result['rafael']['frames'][name] = frames

def register(character, sheet, index, hit=None, hand=None):
    frames = result[character]['frames'].setdefault(sheet, [])
    while len(frames) <= index: frames.append({})
    if hit is not None: frames[index]['hit'] = hit
    if hand is not None: frames[index]['hand'] = hand

# Coordinates in logical pixels relative to the physical root; facing is mirrored
# centrally by BoxMath. Startup/recovery never inherit an active offensive box.
for index, rect in [(3,[100,-248,57,40]), (4,[111,-244,64,43])]:
    register('marcelo','punch',index,rect)
for index, rect in [(3,[138,-224,82,62]),(4,[160,-230,78,54]),
                    (9,[47,-309,48,57]),(10,[62,-348,51,67])]:
    register('marcelo','combat',index,rect)
register('marcelo','low',2,[135,-197,58,42])
register('marcelo','low',6,[150,-86,74,65])
for index in [3,4]: register('marcelo','air',index,[174,-223,80,65])
for index, point in [(8,[76,-150]),(9,[65,-294]),(10,[88,-328]),(11,[81,-165]),
                     (12,[28,-165]),(13,[116,-220]),(14,[134,-230]),(15,[80,-222])]:
    register('marcelo','combat',index,hand=point)
for sheet, index, rect in [('strike',2,[110,-246,58,43]),('strike',6,[45,-252,62,52]),
                          ('strike',10,[108,-143,55,36]),('low',2,[102,-144,49,34]),
                          ('low',6,[90,-188,54,43]),('style',11,[106,-196,44,36]),
                          ('combat',11,[45,-325,46,54])]:
    register('rafael',sheet,index,rect)
path = ROOT / 'data/characters/combat-profiles-v3.json'
path.write_text(json.dumps(result, separators=(',', ':')) + '\n')
print('Registered Rafael silhouette bands and Marcelo/Rafael active limbs:', path.stat().st_size, 'bytes')
