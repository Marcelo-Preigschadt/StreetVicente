"""Crop/register the 12 generated VFX drawings, preserving their RGBA pixels."""
from pathlib import Path
import json
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
image = Image.open(ROOT/'assets/source/marcelo-code-v3/code.png').convert('RGBA')
assert image.size == (1448,1086), 'Review cell separators if regenerating the source'
row_bounds = [0,425,690,1086]  # Reviewed transparent gutters, not equal-height cuts.
column_bounds = [[0,362,724,1086,1448]]*2 + [[0,390,750,1086,1448]]
frames=[]
packed=Image.new('RGBA',(1792,1344))
for row in range(3):
 for col in range(4):
  left,right=column_bounds[row][col:col+2];top,bottom=row_bounds[row:row+2]
  cell=image.crop((left,top,right,bottom));bounds=cell.getbbox();assert bounds
  a,b,c,d=bounds;sprite=cell.crop(bounds);assert sprite.width<440 and sprite.height<440
  x=col*448+4;y=row*448+4;packed.paste(sprite,(x,y))
  if row==0:
   scale=.30;anchor=[181+col*362-left-a,230-top-b]
  elif row==1:
   scale=.60
   alpha=np.asarray(cell)[:,:,3];ys,xs=np.nonzero(alpha>80)
   anchor=[int(xs.max())-a-30/scale,576-top-b]
  else:
   scale=.42;anchor=[[200,543,905,1267][col]-left-a,890-top-b]
  frames.append({'rect':[x,y,sprite.width,sprite.height],'anchor':anchor,'scale':scale})
path=ROOT/'assets/effects/marcelo-code-v3/code.webp';path.parent.mkdir(parents=True,exist_ok=True)
packed.save(path,lossless=True,method=6)
manifest={'schema':1,'image':'res://assets/effects/marcelo-code-v3/code.webp',
          'frames':frames,'clips':{'charge':[0,1,2,3],'flight':[4,5,6,7],'impact':[8,9,10,11]}}
(ROOT/'data/characters/marcelo-code-v3.json').write_text(json.dumps(manifest,indent=2)+'\n')
print('Packed 4 charge + 4 flight + 4 impact keys:',path.stat().st_size,'bytes')
