"""Register complete generated cels; never paint, deform, or invent inbetweens.

Roots/scales and offensive sockets are reviewed against source anatomy. Alpha bands
are baked into immutable integer hurtboxes offline, not sampled during gameplay.
Run from the repo after keeping selected originals under assets/source/arcade-v8.
"""
from pathlib import Path
import json
import numpy as np
from PIL import Image, ImageDraw
from scipy.ndimage import label, find_objects, binary_dilation

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/source/arcade-v8"
SETTINGS = {
    # Legacy Adriano metrics apply 25/22 uniformly; register at 264px so the final
    # rendered adult is exactly 300px. Collision uses that same conversion once.
    "adriano_states": dict(character="adriano",key="states",rows=4,scale=264/315,
        roots=[170,500,820,1170,165,500,820,1140,170,495,820,1170,165,490,835,1190],
        floors=[326]*4+[647]*4+[919]*4+[1190]*4),
    "adriano_walk": dict(character="adriano",key="walk",rows=2,scale=264/419,
        roots=[210,660,1110,1550,215,660,1110,1550],floors=[433]*4+[874]*4),
    "adriano_punch": dict(character="adriano",key="punch",rows=2,scale=264/425,
        roots=[210,655,1110,1510,215,670,1110,1550],floors=[438]*4+[873]*4,
        hits={3:[137,-210,25,25],4:[103,-201,30,30]}),
    "adriano_combat": dict(character="adriano",key="combat",rows=4,scale=264/295,
        roots=[165,490,790,1110,165,490,805,1120,165,500,805,1120,160,480,800,1155],
        floors=[302]*4+[603]*4+[919]*4+[1196]*4,
        hits={3:[132,-231,40,62],4:[96,-220,38,68],9:[18,-277,38,50],10:[67,-282,32,39]},
        hands={12:[1,-130],13:[108,-198],14:[134,-193],15:[36,-175]}),
    "adriano_actions": dict(character="adriano",key="actions",rows=4,scale=264/315,
        roots=[170,530,900,1290,170,520,880,1290,170,520,895,1300,170,530,890,1290],
        floors=[277]*4+[528]*4+[842]*4+[1115]*4,
        hits={2:[151,-158,44,31],6:[176,-70,45,40],10:[147,-195,39,27],14:[154,-204,40,55]}),
    "rafael_states": dict(character="rafael", key="states", rows=4, scale=300/305,
        roots=[165,480,796,1110,175,480,800,1110,180,485,805,1110,166,470,790,1110],
        floors=[316]*4+[645]*4+[934]*4+[1244]*4),
    "rafael_walk": dict(character="rafael", key="walk", rows=2, scale=300/416,
        roots=[207,660,1107,1553,220,665,1114,1555], floors=[432]*4+[869]*4),
    "marcelo_air_punch": dict(character="marcelo", key="air_punch", rows=2, scale=.60,
        roots=[245,665,1100,1515,245,700,1110,1540], floors=[513]*4+[955]*4,
        hits={3:[105,-244,45,29],4:[118,-253,43,30]}),
    "rafael_combat": dict(character="rafael", key="combat", rows=4, scale=300/285,
        roots=[165,490,810,1085,160,490,810,1130,170,495,807,1130,160,495,805,1130],
        floors=[293]*4+[589]*4+[915]*4+[1185]*4,
        hits={3:[163,-240,46,75],4:[152,-164,49,59],9:[58,-274,46,48],10:[-18,-360,39,55]},
        hands={12:[1,-151],13:[-32,-149],14:[160,-231],15:[55,-221]}),
    "rafael_low": dict(character="rafael", key="low", rows=2, scale=.65,
        roots=[180,565,930,1350,170,560,920,1370], floors=[526]*4+[973]*4,
        hits={2:[123,-185,38,29],6:[156,-57,36,42]}),
    "rafael_air": dict(character="rafael", key="air_actions", rows=4, scale=1.0,
        roots=[200,565,910,1295,175,590,945,1330,185,575,930,1290,160,580,950,1335],
        floors=[310]*4+[566]*4+[826]*4+[1086]*4,
        hits={3:[155,-240,54,36],4:[168,-248,55,34],11:[170,-273,50,81],12:[160,-250,62,55]}),
}


def extract(file, rows):
    image = Image.open(file).convert("RGBA")
    pixels = np.array(image)
    labels, _ = label(pixels[:, :, 3] > 120)
    items = []
    for component, bounds in enumerate(find_objects(labels), 1):
        if bounds is None or (labels[bounds] == component).sum() < 4000:
            continue
        y, x = bounds
        row = min(rows-1, int((y.start+y.stop)/2/(image.height/rows)))
        col = min(3, int((x.start+x.stop)/2/(image.width/4)))
        items.append((row*4+col, component, (x.start,y.start,x.stop,y.stop)))
    items.sort()
    assert [i[0] for i in items] == list(range(rows*4)), (file, items)
    return pixels, labels, items


def hurtboxes(sprite, anchor, bottom, scale):
    logical = sprite.resize((round(sprite.width*scale), round(sprite.height*scale)), Image.Resampling.LANCZOS)
    alpha = np.array(logical)[:, :, 3] > 190
    left, top = round(-anchor*scale), round(-bottom*scale)
    result = []
    for start in range(0, alpha.shape[0], 14):
        band = alpha[start:start+14]
        occupied = band.mean(axis=0) >= .6
        edges = np.diff(np.r_[False,occupied,False].astype(int))
        for lo, hi in zip(np.flatnonzero(edges == 1), np.flatnonzero(edges == -1)):
            if hi-lo >= 9 and len(band) >= 4:
                result.append([int(left+lo+2),top+start+1,int(hi-lo-4),len(band)-2])
    return result


def build():
    manifests = {id:dict(schema=8,character=id,sheets={}) for id in ["marcelo","rafael","adriano"]}
    for name,cfg in SETTINGS.items():
        pixels,labels,items = extract(SOURCE / (name+".webp"), cfg["rows"])
        # Tight uniform shelves reduce transparent GPU memory, especially on Web.
        cell_w = ((max(b[2]-b[0] for _,_,b in items)+23)//4)*4
        cell_h = ((max(b[3]-b[1] for _,_,b in items)+23)//4)*4
        packed = Image.new("RGBA", (cell_w*4,cell_h*cfg["rows"]))
        frames = []
        for i,component,(x,y,right,bot) in items:
            mask = binary_dilation(labels[y:bot,x:right] == component, iterations=2)
            cut = pixels[y:bot,x:right].copy()
            cut[:,:,3] = np.where(mask,cut[:,:,3],0)
            sprite = Image.fromarray(cut)
            px,py = i%4*cell_w+8,i//4*cell_h+8
            packed.paste(sprite,(px,py))
            anchor,bottom = cfg["roots"][i]-x,cfg["floors"][i]-y
            collision = {"hurt":hurtboxes(sprite,anchor,bottom,cfg["scale"])}
            if i in cfg.get("hits",{}): collision["hit"] = cfg["hits"][i]
            if i in cfg.get("hands",{}): collision["hand"] = cfg["hands"][i]
            frames.append(dict(rect=[px,py,right-x,bot-y],x=0,y=0,anchor=anchor,bottom=bottom,
                scale=cfg["scale"],collision=collision))
        target = ROOT / f'assets/characters/{cfg["character"]}/arcade-v8/{cfg["key"]}.webp'
        target.parent.mkdir(parents=True,exist_ok=True)
        packed.save(target,lossless=True,method=6)
        sheet = dict(image="res://"+str(target.relative_to(ROOT)),size=list(packed.size),scale=cfg["scale"],frames=frames)
        if cfg["key"] == "actions":
            sheets = manifests[cfg["character"]]["sheets"]
            sheets["low"] = dict(sheet,frames=frames[:8])
            # Four unique air cels exposed with anticipation/extension/retraction
            # timing. Repeated holds are explicit; no synthetic inbetweens.
            exposure = [0,0,1,2,2,3,3,0]
            sheets["air_punch"] = dict(sheet,frames=[frames[8+i] for i in exposure])
            sheets["air"] = dict(sheet,frames=[frames[12+i] for i in exposure])
        elif cfg["key"] == "air_actions":
            manifests[cfg["character"]]["sheets"]["air_punch"] = dict(sheet,frames=frames[:8])
            manifests[cfg["character"]]["sheets"]["air"] = dict(sheet,frames=frames[8:])
        else:
            manifests[cfg["character"]]["sheets"][cfg["key"]] = sheet
        print(name,len(frames),"registered cels",target.stat().st_size,"bytes")
    for id,manifest in manifests.items():
        (ROOT/f"data/characters/{id}-arcade-v8.json").write_text(json.dumps(manifest,separators=(",",":"))+"\n")


if __name__ == "__main__":
    build()
