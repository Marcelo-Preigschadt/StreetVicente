"""Register unmodified hand-drawn VFX cels; no synthesized inbetweens or paint."""
from pathlib import Path
from PIL import Image
import json, shutil
root = Path(__file__).resolve().parents[1]
source = root / 'assets/source/powers-v10/energy-cels.webp'
target = root / 'assets/effects/powers-v10/energy-cels.webp'
target.parent.mkdir(parents=True, exist_ok=True)
shutil.copyfile(source, target)
# The authored sheet has unequal row heights. Explicit crop rectangles preserve
# each complete drawing, instead of guessing a uniform grid or stretching art.
xs = [0, 337, 674, 1011, 1346]
ys = [0, 334, 672, 997, 1168]
frames = []
for row in range(4):
    for col in range(4):
        frames.append(dict(rect=[xs[col], ys[row], xs[col+1]-xs[col], ys[row+1]-ys[row]],
                           anchor=[50, 400] if row < 2 else [168, 160] if row == 2 else [90, 85]))
manifest = dict(schema=10, image='res://' + str(target.relative_to(root)),
                size=list(Image.open(source).size), frames=frames,
                clips=dict(upper=list(range(8)), ring=list(range(8,12)), cast=list(range(12,16))))
(root / 'data/characters/power-cels-v10.json').write_text(json.dumps(manifest, separators=(',', ':')) + '\n')
print('Registered 16 authored energy cels')
