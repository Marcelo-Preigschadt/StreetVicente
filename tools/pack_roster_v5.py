"""Mechanical extraction of eight full-body drawings. No painted/interpolated pixels.
Inputs retain original alpha; registration and limb rectangles are reviewed offline.
"""
from pathlib import Path
import json
import numpy as np
from PIL import Image
from scipy.ndimage import label, find_objects, binary_dilation
ROOT=Path(__file__).resolve().parents[1]
SETTINGS={
 'rafael': {'roots':[166,554,918,1279,177,563,942,1320], 'scale':300/432,
            'hit':{3:[133,-234,42,27],4:[138,-239,49,31]}},
 'gustavo': {'roots':[175,556,937,1295,181,567,949,1321], 'scale':300/424,
             'hit':{3:[132,-237,33,29],4:[137,-236,33,27]}}
}
for name, cfg in SETTINGS.items():
 pixels=np.array(Image.open(ROOT/f'assets/source/roster-v5/{name}-punch.png').convert('RGBA'))
 labels,n=label(pixels[:,:,3]>120); items=[]
 for component, sl in enumerate(find_objects(labels),1):
  if sl is None or (labels[sl]==component).sum()<10000:continue
  y,x=sl; row=min(1,int((y.start+y.stop)/2/512)); col=min(3,int((x.start+x.stop)/2/384))
  items.append((row*4+col,component,(x.start,y.start,x.stop,y.stop)))
 items.sort();assert [i for i,_,_ in items]==list(range(8)),(name,items)
 packed=Image.new('RGBA',(2048,1024)); frames=[]; profiles=[]
 baselines={row:max(b[3] for i,_,b in items if i//4==row) for row in range(2)}
 for i,component,b in items:
  x,y,r,bot=b; mask=binary_dilation(labels[y:bot,x:r]==component,iterations=2)
  cut=pixels[y:bot,x:r].copy();cut[:,:,3]=np.where(mask,cut[:,:,3],0)
  sprite=Image.fromarray(cut); px=i%4*512+16;py=i//4*512+16
  packed.paste(sprite,(px,py));anchor=cfg['roots'][i]-x;bottom=baselines[i//4]-y;k=cfg['scale']
  f={'rect':[px,py,r-x,bot-y],'x':0,'y':0,'anchor':anchor,'bottom':bottom,'scale':k}
  frames.append(f)
  logical=sprite.resize((round(sprite.width*k),round(sprite.height*k)),Image.Resampling.LANCZOS)
  a=np.array(logical)[:,:,3]>190; boxes=[];left=round(-anchor*k);top=round(-bottom*k)
  for start in range(0,a.shape[0],14):
   band=a[start:start+14];occupied=band.mean(axis=0)>=.6
   edges=np.diff(np.r_[False,occupied,False].astype(int))
   for lo,hi in zip(np.flatnonzero(edges==1),np.flatnonzero(edges==-1)):
    if hi-lo>=9 and len(band)>=4:boxes.append([int(left+lo+2),top+start+1,int(hi-lo-4),len(band)-2])
  profile={'hurt':boxes}
  if i in cfg['hit']:profile['hit']=cfg['hit'][i]
  profiles.append(profile)
 target=ROOT/f'assets/characters/{name}/art-v5/punch.webp';target.parent.mkdir(parents=True,exist_ok=True)
 packed.save(target,lossless=True,method=6)
 manifest={'schema':5,'character':name,'key':'punch_v5','image':'res://'+str(target.relative_to(ROOT)), 'scale':cfg['scale'],'frames':frames,'collision':profiles}
 (ROOT/f'data/characters/{name}-art-v5.json').write_text(json.dumps(manifest,separators=(',',':'))+'\n')
 print(name,len(frames),'drawings,',target.stat().st_size,'bytes')
