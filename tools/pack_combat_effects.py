"""Registers generated complete drawings; mechanical extraction only, no new poses."""
from pathlib import Path
import json
import numpy as np
from PIL import Image
from scipy.ndimage import label, find_objects, binary_dilation
root=Path(__file__).resolve().parents[1]

def components(file,rows,threshold):
 im=Image.open(root/file).convert('RGBA');pixels=np.array(im);alpha=pixels[:,:,3]
 labels,_=label(alpha>threshold);items=[]
 for component,r in enumerate(find_objects(labels),1):
  if r is None or (labels[r]==component).sum()<1200:continue
  y,x=r;cx=(x.start+x.stop)/2;cy=(y.start+y.stop)/2
  index=min(rows-1,int(cy/(im.height/rows)))*4+min(3,int(cx/(im.width/4)))
  items.append((index,component,(x.start,y.start,x.stop,y.stop)))
 items.sort();assert [i[0] for i in items]==list(range(rows*4)),items
 return pixels,labels,items

pixels,labels,items=components('assets/source/marcelo-air-v2/air-kick.png',2,100)
packed=Image.new('RGBA',(2240,1120));frames=[]
# Register pelvis, not the lowest boot: the model owns world height and jump arc.
# Source-cell centers are not anatomical pivots: extension moves the silhouette
# far to the right. These are manually reviewed pelvis coordinates in the source.
anchors=[223,663,1063,1453,195,687,1096,1478]
pelvis_y=[263,263,263,263,675,675,675,675]
scale=300/391
for index,component,b in items:
 x,y,right,bottom=b;mask=binary_dilation(labels[y:bottom,x:right]==component,iterations=2)
 sprite=pixels[y:bottom,x:right].copy();sprite[:,:,3]=np.where(mask,sprite[:,:,3],0)
 px=index%4*560+8;py=index//4*560+8;packed.paste(Image.fromarray(sprite),(px,py))
 frames.append({'rect':[px,py,right-x,bottom-y],'x':0,'y':0,'anchor':anchors[index]-x,'bottom':pelvis_y[index]-y+145/scale,'scale':scale})
file=root/'assets/characters/marcelo/art-v2/air-kick.webp';packed.save(file,lossless=True,method=6)
manifest={'schema':1,'version':'art-v2','image':'res://assets/characters/marcelo/art-v2/air-kick.webp','scale':scale,'frames':frames}
(root/'data/characters/marcelo-air-v2.json').write_text(json.dumps(manifest,indent=2))

pixels,labels,items=components('assets/source/powers-v1/powers.png',4,30)
packed=Image.new('RGBA',(1680,1680));frames=[]
for index,component,b in items:
 # Keep nearby glow pixels while removing only neighboring components.
 x,y,right,bottom=b;x=max(0,x-8);y=max(0,y-8);right=min(pixels.shape[1],right+8);bottom=min(pixels.shape[0],bottom+8)
 mask=binary_dilation(labels[y:bottom,x:right]==component,iterations=8)
 sprite=pixels[y:bottom,x:right].copy();sprite[:,:,3]=np.where(mask,sprite[:,:,3],0)
 px=index%4*420+8;py=index//4*420+8;packed.paste(Image.fromarray(sprite),(px,py))
 w=right-x;h=bottom-y
 if index<4:anchor=[w*.82,h*.5]
 elif index<8:anchor=[[155,475,790,1100][index-4]-x,490-y]
 elif index<12:anchor=[w*.76,h*.5]
 elif index<14:anchor=[w*.80,h*.5]
 else:anchor=[w*.70,h*.5]
 frames.append({'rect':[px,py,w,h],'anchor':anchor})
file=root/'assets/effects/powers-v1/powers.webp';packed.save(file,lossless=True,method=6)
manifest={'schema':1,'image':'res://assets/effects/powers-v1/powers.webp','frames':frames,'clips':{'code':[0,1,2,3],'drone':[4,5,6,7],'smoke':[8,9,10,11],'fork':[12,13],'book':[14,15]}}
(root/'data/characters/power-effects-v1.json').write_text(json.dumps(manifest,indent=2))
print('PACKED: 8 airborne keys + 16 VFX keys')
