"""Crop authored VFX exposures without repainting or synthesizing pixels."""
from pathlib import Path
import json
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
source = Image.open(ROOT/"assets/source/arcade-v8/effects.webp").convert("RGBA")
assert source.size == (1536,1024)
anchors = [(210,144),(515,140),(812,148),(1225,148),
           (205,410),(615,410),(905,410),(1310,410),
           (338,660),(718,660),(1098,660),(1482,660),
           (335,887),(718,887),(1100,887),(1480,887)]
frames = []
for i,(x,y) in enumerate(anchors):
    col,row = i%4,i//4
    # The hand-drawn rows are not perfectly uniform. Register the actual gutters
    # so a cyan guard fragment never appears above the emerald code wave.
    top,height = [(0,250),(250,305),(565,205),(780,235)][row]
    frames.append(dict(rect=[col*384,top,384,height],anchor=[x-col*384,y-top]))
target = ROOT/"assets/effects/arcade-v8/effects.webp"
target.parent.mkdir(parents=True,exist_ok=True)
source.save(target,lossless=True,method=6)
manifest = dict(schema=8,image="res://"+str(target.relative_to(ROOT)),frames=frames,
    clips=dict(hit=list(range(4)),block=list(range(4,8)),code=list(range(8,12)),scroll=list(range(12,16))))
(ROOT/"data/characters/arcade-effects-v8.json").write_text(json.dumps(manifest,indent=2)+"\n")
print("16 registered impact/guard/code/scroll exposures")
