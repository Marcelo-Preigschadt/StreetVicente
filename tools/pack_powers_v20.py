"""Preserve generated pixels/alpha; register equal VFX cells without repainting."""
from pathlib import Path
import json, hashlib
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'assets/source/powers-v20'
DEST=ROOT/'assets/effects/powers-v20'
DEST.mkdir(parents=True,exist_ok=True)
mapping={'marcelo':'marcelo-code','adriano':'adriano-imperial',
         'rafael':'rafael-chronicles','joao':'joao-electric',
         'gustavo':'gustavo-ultimate','gelton':'gelton-ultimate',
         'marcelino':'marcelino-ultimate','marcos':'marcos-ultimate'}
provenance={'tool':'builtin image_gen.imagegen','mode':'generate',
            'scope':'VFX only; no character/face assets modified','files':{}}
for char,name in mapping.items():
    art={'revision':20,'images':{},'frames':[],'clips':{}}
    sheets=[(name,4,{'charge':(0,.5),'wave':(1,.81),'rise':(2,.5),'impact':(3,.5)})]
    if char in ['gustavo','gelton','marcelino','marcos']:
        version={'gustavo':12,'gelton':13,'marcelino':14,'marcos':16}[char]
        art=json.loads((ROOT/f'data/characters/{char}-effects-v{version}.json').read_text())
        art['revision']=20
        art['images']={'approved':art['image']}
        for frame in art['frames']:frame['image']=art['image']
        sheets=[(name,2,{'ultimate':(0,.81),'ultimate_hit':(1,.5)})]
    if char=='joao':sheets[0][2]['roll']=sheets[0][2].pop('impact')
    if char=='marcelo':sheets.append(('marcelo-fleet',2,{'drone':(0,.5),'laser_hit':(1,.5)}))
    for file,rows,clips in sheets:
        source=SOURCE/(file+'.webp'); image=Image.open(source).convert('RGBA')
        assert image.getextrema()[3][0]==0 and image.getextrema()[3][1]>=250
        target=DEST/source.name;image.save(target,format='WEBP',lossless=True,exact=True,method=6)
        uri='res://'+str(target.relative_to(ROOT));art['images'][file]=uri
        offset=len(art['frames'])
        for y in range(rows):
            for x in range(4):
                a,b,c,d=round(x*image.width/4),round(y*image.height/rows),round((x+1)*image.width/4),round((y+1)*image.height/rows)
                pivot=next(v[1] for v in clips.values() if v[0]==y)
                anchor=[.734,.493] if file=='marcelo-fleet' and y==0 else [pivot,.5]
                if char=='marcos' and y==0:anchor=[.5,.82]
                art['frames'].append({'image':uri,'rect':[a,b,c-a,d-b],'pivot':anchor})
        for clip,(row,_) in clips.items():art['clips'][clip]=list(range(offset+row*4,offset+row*4+4))
        provenance['files'][source.name]={'sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'size':list(image.size),'cells':rows*4}
    (ROOT/f'data/characters/{char}-effects-v20.json').write_text(json.dumps(art,separators=(',',':'))+'\n')
(SOURCE/'provenance.json').write_text(json.dumps(provenance,indent=2)+'\n')
