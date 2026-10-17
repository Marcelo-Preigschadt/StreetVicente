"""Register Gustavo's 64 complete cels without stretching or face compositing.

The per-sheet scales and roots keep anatomy/ground contacts consistent. Offensive
boxes and cast sockets follow the drawn fist, boot and palm, never a screen zone.
"""
from pathlib import Path
import json
import numpy as np
from PIL import Image
from scipy.ndimage import binary_dilation
from pack_arcade_v8 import extract, hurtboxes

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'assets/source/arcade-v11'
CONFIG = {
 'states': dict(rows=4, scale=300/268,
  roots=[208,544,910,1246,208,551,890,1240,222,551,893,1255,218,569,925,1270],
  floors=[278]*4+[543]*4+[798]*4+[1069]*4),
 'walk': dict(rows=2, scale=300/433,
  roots=[208,633,1050,1473,218,643,1059,1484], floors=[455]*4+[927]*4),
 'punch': dict(rows=2, scale=300/450,
  roots=[187,607,1026,1423,179,603,1024,1446], floors=[462]*4+[925]*4,
  hits={3:[132,-240,37,29],4:[133,-237,38,30]},
  hands={0:[30,-193],1:[57,-213],2:[110,-237],3:[151,-227],4:[152,-223],5:[108,-213],6:[62,-203],7:[32,-193]}),
 'combat': dict(rows=4, scale=300/266,
  roots=[180,530,875,1288,180,540,896,1290,174,541,898,1280,184,546,897,1280],
  floors=[275]*4+[546]*4+[816]*4+[1075]*4,
  hits={2:[190,-268,50,43],9:[59,-228,38,47],10:[23,-310,42,47]},
  hands={12:[-126,-179],13:[148,-210],14:[185,-205],15:[43,-200]}),
 'actions': dict(rows=4, scale=300/268,
  roots=[184,548,917,1285,178,548,924,1302,185,552,921,1290,187,565,928,1300],
  floors=[259]*4+[531]*4+[799]*4+[1058]*4,
  hits={2:[194,-191,48,35],6:[195,-47,48,39],10:[212,-239,48,33],14:[198,-242,59,48]})
}


def build():
 manifest = dict(schema=11, character='gustavo', sheets={})
 for key, cfg in CONFIG.items():
  pixels, labels, items = extract(SOURCE / ('gustavo_'+key+'.webp'), cfg['rows'])
  cw = ((max(b[2]-b[0] for _,_,b in items)+23)//4)*4
  ch = ((max(b[3]-b[1] for _,_,b in items)+23)//4)*4
  atlas = Image.new('RGBA', (cw*4,ch*cfg['rows'])); frames=[]
  for i, component, (x,y,r,b) in items:
   crop=pixels[y:b,x:r].copy()
   mask=binary_dilation(labels[y:b,x:r]==component,iterations=2)
   crop[:,:,3]=np.where(mask,crop[:,:,3],0)
   sprite=Image.fromarray(crop)
   px,py=i%4*cw+8,i//4*ch+8
   atlas.paste(sprite,(px,py))
   anchor,bottom=cfg['roots'][i]-x,cfg['floors'][i]-y
   collision=dict(hurt=hurtboxes(sprite,anchor,bottom,cfg['scale']))
   if i in cfg.get('hits',{}): collision['hit']=cfg['hits'][i]
   if i in cfg.get('hands',{}): collision['hand']=cfg['hands'][i]
   frames.append(dict(rect=[px,py,r-x,b-y],x=0,y=0,anchor=anchor,bottom=bottom,scale=cfg['scale'],collision=collision))
  target=ROOT/f'assets/characters/gustavo/arcade-v11/{key}.webp'
  target.parent.mkdir(parents=True,exist_ok=True)
  atlas.save(target,lossless=True,method=6)
  sheet=dict(image='res://'+str(target.relative_to(ROOT)),size=list(atlas.size),scale=cfg['scale'],frames=frames)
  if key=='actions':
   manifest['sheets']['low']=dict(sheet,frames=frames[:8])
   exposure=[0,0,1,2,2,3,3,0]
   manifest['sheets']['air_punch']=dict(sheet,frames=[frames[8+i] for i in exposure])
   manifest['sheets']['air']=dict(sheet,frames=[frames[12+i] for i in exposure])
  else: manifest['sheets'][key]=sheet
  print(key,len(frames),'cels',target.stat().st_size,'bytes')
 (ROOT/'data/characters/gustavo-arcade-v11.json').write_text(json.dumps(manifest,separators=(',',':'))+'\n')


if __name__=='__main__': build()
