"""Register complete painted objects/poses without cutting nominal grid cells."""
import hashlib
import json
import statistics
from pathlib import Path

import numpy as np
from PIL import Image
from pack_story_v27 import bodies

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'assets/source/story-v28'
OUTPUT = ROOT / 'assets/story/v28'
GROUPS = {
    'school': [('locker', 310), ('bench', 140), ('bin', 150),
               ('planter', 205), ('foodcart', 180), ('trophycase', 290),
               ('noticeboard', 185), ('chairstack', 175), ('barrier', 140)],
    'lab': [('cabinet', 310), ('tank', 235), ('labcart', 190),
            ('labbench', 155), ('washstation', 255), ('reagentcrate', 100),
            ('instrument', 165), ('vent', 90), ('caution', 120)],
    'library': [('shelf', 330), ('bookcart', 175), ('readingdesk', 150),
                ('armillary', 185), ('archivebox', 85), ('globe', 145),
                ('lectern', 150), ('bust', 180), ('bookstack', 65)],
    'nit': [('serverrack', 350), ('workbench', 190), ('toolcart', 180),
            ('ups', 120), ('wallmonitor', 150), ('networkcabinet', 200),
            ('cablespool', 100), ('partscrate', 85), ('coolingfan', 110)]
}


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def register_props():
    result = {'revision': 28, 'props': {}, 'sources': {}}
    for group, objects in GROUPS.items():
        source = SOURCE / (group + '.png')
        image = Image.open(source).convert('RGBA')
        boxes = bodies(image, 3)
        assert len(boxes) == 9, (group, len(boxes))
        result['sources'][group] = digest(source)
        for (kind, height), (x, y, right, bottom) in zip(objects, boxes):
            bounds = (max(0, x - 3), max(0, y - 3), min(image.width, right + 3), min(image.height, bottom + 3))
            crop = image.crop(bounds)
            target = OUTPUT / (kind + '.webp')
            crop.save(target, 'WEBP', quality=94, method=6)
            result['props'][kind] = {'file': 'res://' + target.relative_to(ROOT).as_posix(),
                                     'size': [round(crop.width * height / crop.height), height],
                                     'group': group, 'source_rect': list(bounds)}
        print(group, '9 complete registered props')
    (ROOT / 'data/story/scenery-v28.json').write_text(json.dumps(result, separators=(',', ':')) + '\n')


def register_actions():
    result = {'revision': 28, 'atlases': {}}
    for kind in ['guard', 'heavy']:
        source = SOURCE / (kind + '-actions.png')
        image = Image.open(source).convert('RGBA')
        boxes = bodies(image, 4)
        assert len(boxes) == 16, (kind, len(boxes))
        frames = []
        for x, y, right, bottom in boxes:
            x, y = max(0, x - 3), max(0, y - 3)
            right, bottom = min(image.width, right + 3), min(image.height, bottom + 3)
            crop = np.array(image.crop((x, y, right, bottom)))
            ys, xs = np.where(crop[:, :, 3] > 160)
            feet = xs[ys >= np.quantile(ys, .88)]
            anchor = (np.quantile(feet, .05) + np.quantile(feet, .95)) / 2
            frames.append({'rect': [x, y, right - x, bottom - y], 'anchorX': round(float(anchor), 3), 'bottom': bottom - y - 3})
        height = statistics.median(frames[i]['rect'][3] for i in [0, 3, 8, 10, 11, 15])
        target = OUTPUT / (kind + '-actions.webp')
        image.save(target, 'WEBP', quality=94, method=6)
        result['atlases'][kind] = {'file': 'res://' + target.relative_to(ROOT).as_posix(),
                                  'referenceHeight': height, 'frames': frames,
                                  'source_sha256': digest(source),
                                  'sequences': {'kick': [0, 1, 2, 3], 'sweep': [4, 5, 6, 7],
                                                'heavy': [8, 9, 10, 11], 'dash': [12, 13, 15],
                                                'block': 11, 'evade': 14}}
        print(kind, '16 additional action drawings; standing reference', height)
    (ROOT / 'data/story/actions-v28.json').write_text(json.dumps(result, separators=(',', ':')) + '\n')


if __name__ == '__main__':
    OUTPUT.mkdir(parents=True, exist_ok=True)
    register_props()
    register_actions()
