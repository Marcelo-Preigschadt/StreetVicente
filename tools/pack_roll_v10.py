"""Extract whole hand-drawn roll cels; register rotation centers without deformation."""
from pathlib import Path
import json,numpy as np
from PIL import Image
from scipy.ndimage import binary_dilation
from pack_arcade_v8 import extract,hurtboxes
root=Path(__file__).resolve().parents[1]
pixels,labels,items=extract(root/'assets/source/powers-v10/joao-roll.webp',2)
scale=300/412
roots=[235,684,1086,1546,250,672,1105,1544]
# The four rotating cels share the same center at y=-130 in model coordinates.
floors=[442,211+130/scale,231+130/scale,224+130/scale,645+130/scale,638+130/scale,842,854]
w=((max(b[2]-b[0]for _,_,b in items)+23)//4)*4
h=((max(b[3]-b[1]for _,_,b in items)+23)//4)*4
atlas=Image.new('RGBA',(w*4,h*2));frames=[]
for i,component,(x,y,r,b)in items:
 crop=pixels[y:b,x:r].copy();mask=binary_dilation(labels[y:b,x:r]==component,iterations=2)
 crop[:,:,3]=np.where(mask,crop[:,:,3],0);sprite=Image.fromarray(crop)
 px,py=i%4*w+8,i//4*h+8;atlas.paste(sprite,(px,py))
 anchor,bottom=roots[i]-x,round(floors[i]-y)
 frames.append(dict(rect=[px,py,r-x,b-y],x=0,y=0,anchor=anchor,bottom=bottom,scale=scale,collision=dict(hurt=hurtboxes(sprite,anchor,bottom,scale))))
target=root/'assets/characters/joao/powers-v10/roll.webp';target.parent.mkdir(parents=True,exist_ok=True);atlas.save(target,lossless=True,method=6)
sheet=dict(image='res://'+str(target.relative_to(root)),size=list(atlas.size),scale=scale,frames=frames)
(root/'data/characters/joao-powers-v10.json').write_text(json.dumps(dict(schema=10,character='joao',sheets=dict(roll=sheet)),separators=(',',':'))+'\n')
print('8 whole-body roll cels registered',atlas.size)
