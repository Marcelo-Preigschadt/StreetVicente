"""Register reviewed complete cels. No stretching, face compositing or inbetweens.

V9 overlays only Adriano's walking set and João's full 64-cel revision. Previous
roster remains intact. Pixels are only extracted/packed; anatomy stays authored.
"""
from pathlib import Path
import json
import numpy as np
from PIL import Image
from scipy.ndimage import binary_dilation
from pack_arcade_v8 import extract, hurtboxes
ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'assets/source/arcade-v9'
CONFIG={
 'adriano_walk':dict(id='adriano',key='walk',rows=2,scale=264/414,roots=[209,662,1104,1558,225,674,1103,1555],floors=[435]*4+[869]*4),
 'joao_states':dict(id='joao',key='states',rows=4,scale=300/314,roots=[159,477,791,1106,155,468,784,1100,155,476,780,1105,159,470,786,1105],floors=[339]*4+[650]*4+[932]*4+[1237]*4),
 'joao_walk':dict(id='joao',key='walk',rows=2,scale=300/406,roots=[210,651,1105,1547,210,650,1098,1538],floors=[426]*4+[869]*4),
 'joao_punch':dict(id='joao',key='punch',rows=2,scale=300/386,roots=[216,660,1104,1529,212,658,1104,1544],floors=[423]*4+[861]*4,hits={3:[136,-237,40,30],4:[164,-242,42,31]}),
 'joao_combat':dict(id='joao',key='combat',rows=4,scale=300/295,roots=[165,433,685,978,184,511,802,1114,159,474,774,1092,150,415,720,1109],floors=[322]*4+[635]*4+[956]*4+[1241]*4,hits={3:[159,-268,46,52],4:[150,-176,48,43],9:[54,-225,36,55],10:[-2,-331,40,54]},hands={12:[-75,-76],13:[151,-176],14:[203,-174],15:[49,-184]}),
 'joao_actions':dict(id='joao',key='actions',rows=4,scale=300/314,roots=[151,465,766,1096,149,457,773,1119,154,480,777,1115,148,450,762,1128],floors=[333]*4+[590]*4+[937]*4+[1250]*4,hits={2:[159,-218,44,32],6:[173,-57,50,47],10:[177,-211,51,37],14:[180,-208,48,65]})
}

def build():
 manifests={id:dict(schema=9,character=id,sheets={})for id in ['adriano','joao']}
 for name,cfg in CONFIG.items():
  pixels,labels,items=extract(SOURCE/(name+'.webp'),cfg['rows'])
  cw=((max(b[2]-b[0]for _,_,b in items)+23)//4)*4
  ch=((max(b[3]-b[1]for _,_,b in items)+23)//4)*4
  atlas=Image.new('RGBA',(cw*4,ch*cfg['rows']));frames=[]
  for i,component,(x,y,r,b)in items:
   crop=pixels[y:b,x:r].copy();mask=binary_dilation(labels[y:b,x:r]==component,iterations=2)
   crop[:,:,3]=np.where(mask,crop[:,:,3],0);sprite=Image.fromarray(crop)
   px,py=i%4*cw+8,i//4*ch+8;atlas.paste(sprite,(px,py))
   anchor,bottom=cfg['roots'][i]-x,cfg['floors'][i]-y
   collision=dict(hurt=hurtboxes(sprite,anchor,bottom,cfg['scale']))
   if i in cfg.get('hits',{}):collision['hit']=cfg['hits'][i]
   if i in cfg.get('hands',{}):collision['hand']=cfg['hands'][i]
   frames.append(dict(rect=[px,py,r-x,b-y],x=0,y=0,anchor=anchor,bottom=bottom,scale=cfg['scale'],collision=collision))
  target=ROOT/f'assets/characters/{cfg["id"]}/arcade-v9/{cfg["key"]}.webp';target.parent.mkdir(parents=True,exist_ok=True)
  atlas.save(target,lossless=True,method=6)
  sheet=dict(image='res://'+str(target.relative_to(ROOT)),size=list(atlas.size),scale=cfg['scale'],frames=frames)
  sheets=manifests[cfg['id']]['sheets']
  if cfg['key']=='actions':
   sheets['low']=dict(sheet,frames=frames[:8]);exposure=[0,0,1,2,2,3,3,0]
   sheets['air_punch']=dict(sheet,frames=[frames[8+i]for i in exposure]);sheets['air']=dict(sheet,frames=[frames[12+i]for i in exposure])
  else:sheets[cfg['key']]=sheet
  print(name,len(frames),'cels')
 for id,data in manifests.items():
  (ROOT/f'data/characters/{id}-arcade-v9.json').write_text(json.dumps(data,separators=(',',':'))+'\n')
if __name__=='__main__':build()
