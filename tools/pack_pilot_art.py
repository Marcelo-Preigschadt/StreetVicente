"""Mechanical atlas extraction/registration; never draws or synthesizes animation frames.
Requires Pillow, numpy, scipy; used only when preparing art, not by Godot/CI.
Input pixels and alpha are retained. Connected components isolate adjacent drawings.
"""
from pathlib import Path
import json, sys
import numpy as np
from PIL import Image
from scipy.ndimage import label, find_objects, binary_dilation
root = Path(__file__).resolve().parents[1]
source = Path(sys.argv[1])
out = root / 'assets/characters/marcelo/art-v1'
out.mkdir(parents=True, exist_ok=True)
sheets = {
 'punch': ('punch.png',2,300/391,[240,677,1114,1550,262,685,1114,1550]),
 'walk': ('walk.png',2,300/402,[255,704,1113,1570,270,700,1130,1570]),
 'states': ('states.png',4,300/286,[165,483,794,1102,164,480,795,1101,165,485,807,1110,166,467,785,1110]),
 'combat': ('combat.png',4,300/297,[174,483,787,1090,150,486,795,1101,170,490,795,1100,170,479,790,1100]),
 'low': ('low.png',2,300/391,[240,670,1112,1550,230,670,1105,1550]),
}
manifest={'schema':1,'character':'marcelo','version':'art-v1','sheets':{}}
frames_for_preview={}
for key,(name,rows,scale,anchors) in sheets.items():
 im=Image.open(source/name).convert('RGBA'); pixels=np.array(im);a=pixels[:,:,3]
 labels,n=label(a>120); objects=find_objects(labels); items=[]
 for component,r in enumerate(objects,1):
  if r is None or np.sum(labels[r]==component)<1800:continue
  y,x=r; cx=(x.start+x.stop)/2;cy=(y.start+y.stop)/2
  row=min(rows-1,int(cy/(im.height/rows)));col=min(3,int(cx/(im.width/4)))
  items.append((row*4+col,component,(x.start,y.start,x.stop,y.stop)))
 items.sort()
 assert [i[0] for i in items]==list(range(rows*4)),(key,items)
 cell=560 if rows==2 else 420
 packed=Image.new('RGBA',(cell*4,cell*rows))
 frames=[]
 # Preserve row baseline, while allowing knees to bend rather than scaling each pose.
 baselines={row:max(b[3] for index,_,b in items if index//4==row) for row in range(rows)}
 preview=[]
 for index,component,b in items:
  x,y,right,bottom=b;row=index//4
  mask=binary_dilation(labels[y:bottom,x:right]==component,iterations=2)
  sprite=pixels[y:bottom,x:right].copy();sprite[:,:,3]=np.where(mask,sprite[:,:,3],0)
  frame=Image.fromarray(sprite)
  px=(index%4)*cell+8;py=row*cell+8
  packed.paste(frame,(px,py))
  frames.append({'rect':[px,py,right-x,bottom-y], 'x':0,'y':0,
    'anchor':anchors[index]-x,'bottom':baselines[row]-y,'scale':scale})
  preview.append((frame,anchors[index]-x,baselines[row]-y,scale))
 file=out/(key+'.webp');packed.save(file,lossless=True,method=6)
 manifest['sheets'][key]={'image':'res://'+str(file.relative_to(root)),'scale':scale,'frames':frames}
 frames_for_preview[key]=preview
(root/'data/characters/marcelo-art-v1.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2))
# Encoded playback preview; no invented inbetweens, rotations or mesh deformation.
sequence=[('punch',0,500),('punch',1,67),('punch',2,50),('punch',3,50),('punch',4,50),('punch',5,67),('punch',6,67),('punch',7,400)]
gif=[];durations=[]
for key,index,duration in sequence:
 sprite,anchor,bottom,scale=frames_for_preview[key][index]
 canvas=Image.new('RGB',(640,450),(13,24,34))
 size=(round(sprite.width*scale),round(sprite.height*scale))
 display=sprite.resize(size,Image.Resampling.LANCZOS)
 canvas.paste(display,(round(300-anchor*scale),round(402-bottom*scale)),display)
 gif.append(canvas);durations.append(duration)
gif[0].save(root/'docs/previews/marcelo-punch-v1.gif',save_all=True,append_images=gif[1:],duration=durations,loop=0,disposal=2)
print('ART PACKED:',sum(len(s['frames']) for s in manifest['sheets'].values()),'complete drawings, 5 atlases')
