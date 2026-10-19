"""Pack the new complete drawings, without resampling, repainting or face compositing.

Reviewed roots and anatomical scale are independent of each cel's bounding height.
In particular, a crouch is never normalized to standing height. Hit areas and palm
sockets are baked in the same coordinate system as the final visible drawing.
"""
from pathlib import Path
import json
import numpy as np
from PIL import Image
from scipy.ndimage import binary_dilation
from pack_arcade_v8 import hurtboxes
from pack_gelton_v13 import extract

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/source/marcelino-v15"


def atomic_webp(image, target):
    # Publish complete atlases before the editor can observe/import them.
    temp = target.with_suffix(".tmp")
    image.save(temp, format="WEBP", lossless=True, method=6)
    temp.replace(target)


def effects():
    image = Image.open(SOURCE / "kinetic-fx.webp").convert("RGBA")
    # Preserve the artist's actual gutters rather than slicing through arcs.
    cuts = [([0, 395, 780, 1175, 1536], 0, 250),
            ([0, 405, 790, 1167, 1536], 250, 510),
            ([0, 397, 794, 1182, 1536], 510, 800),
            ([0, 414, 787, 1170, 1536], 800, 1024)]
    origins = [[(351, 133), (736, 134), (1117, 135), (1494, 137)],
               [(125, 391), (479, 392), (870, 396), (1260, 397)],
               [(198, 650), (595, 650), (985, 650), (1360, 650)],
               [(207, 896), (596, 899), (858, 894), (1334, 895)]]
    atlas = Image.new("RGBA", (1760, 1216))
    frames = []
    for row, (xs, top, bottom) in enumerate(cuts):
        for col in range(4):
            sprite = image.crop((xs[col], top, xs[col + 1], bottom))
            rect = [col * 440 + 8, row * 304 + 8, sprite.width, sprite.height]
            atlas.paste(sprite, tuple(rect[:2]))
            ox, oy = origins[row][col]
            pivot = [(ox - xs[col]) / sprite.width, (oy - top) / sprite.height]
            frames.append(dict(rect=rect, pivot=pivot))
    target = ROOT / "assets/effects/marcelino-v14/kinetic.webp"
    target.parent.mkdir(parents=True, exist_ok=True)
    atomic_webp(atlas, target)
    data = dict(revision=15, image="res://" + str(target.relative_to(ROOT)), frames=frames,
                clips=dict(impulse=list(range(4)), impact=list(range(4, 8)),
                           rise=list(range(8, 12)), gather=list(range(12, 16))))
    (ROOT / "data/characters/marcelino-effects-v14.json").write_text(json.dumps(data, separators=(",", ":")) + "\n")


def fighters():
    config = json.loads((SOURCE / "registration.json").read_text())
    manifest = dict(schema=14, character="marcelino", face_revision=15, sheets={})
    staged = {}
    for key, cfg in config.items():
        pixels, labels, items = extract(SOURCE / (key + ".webp"), cfg.get("columns", 2))
        staged[key] = []
        for i, component, (x, y, r, b) in items:
            crop = pixels[y:b, x:r].copy()
            mask = binary_dilation(labels[y:b, x:r] == component, iterations=2)
            crop[:, :, 3] = np.where(mask, crop[:, :, 3], 0)
            sprite = Image.fromarray(crop)
            root, floor = cfg["roots"][i], cfg["floors"][i]
            scale = cfg.get("scales", [cfg["scale"]] * 8)[i]
            assert 0 < scale <= 1, "Source cels must never be enlarged"
            anchor, bottom = root - x, floor - y
            collision = dict(hurt=hurtboxes(sprite, anchor, bottom, scale))
            for field in ("hit", "hand"):
                if str(i) in cfg.get(field, {}):
                    point = cfg[field][str(i)]
                    converted = [round((point[0] - root) * scale), round((point[1] - floor) * scale)]
                    if field == "hit":
                        converted += [max(1, round(point[2] * scale)), max(1, round(point[3] * scale))]
                    collision[field] = converted
            frame = dict(x=0, y=0, anchor=anchor, bottom=bottom, scale=scale,
                         collision=collision, source=key, source_cel=i, face_revision=15)
            staged[key].append((sprite, frame))
    # All logical sheets share the same deterministic FighterPose API.
    states = staged["states-a"] + staged["states-b"]
    # One identical crouch drawing at rest and at both ends of the low punch.
    # Avoid a second crouch model/zoom at the exact input boundary.
    states[4] = staged["low"][0]
    states[5] = staged["low"][0]
    sets = {"states": states,
            "walk": staged["walk"], "punch": staged["punch"],
            "combat": staged["kick"] + staged["powers"], "low": staged["low"],
            "air-actions": staged["air"], "super": staged["super"]}
    for key, cels in sets.items():
        cw = ((max(s.width for s, _ in cels) + 23) // 4) * 4
        ch = ((max(s.height for s, _ in cels) + 23) // 4) * 4
        atlas = Image.new("RGBA", (cw * 4, ch * ((len(cels) + 3) // 4)))
        frames = []
        for i, (sprite, frame) in enumerate(cels):
            px, py = (i % 4) * cw + 8, (i // 4) * ch + 8
            atlas.paste(sprite, (px, py))
            frames.append(dict(frame, rect=[px, py, sprite.width, sprite.height]))
        target = ROOT / f"assets/characters/marcelino/arcade-v14/{key}.webp"
        target.parent.mkdir(parents=True, exist_ok=True)
        atomic_webp(atlas, target)
        sheet = dict(image="res://" + str(target.relative_to(ROOT)),
                     size=list(atlas.size), scale=1, frames=frames)
        if key == "air-actions":
            exposure = [0, 0, 1, 2, 2, 3, 3, 0]
            manifest["sheets"]["air_punch"] = dict(sheet, frames=[frames[i] for i in exposure])
            manifest["sheets"]["air"] = dict(sheet, frames=[frames[4 + i] for i in exposure])
        else:
            manifest["sheets"][key] = sheet
        print(key, len(cels), "new cels", target.stat().st_size, "bytes")
    (ROOT / "data/characters/marcelino-arcade-v14.json").write_text(json.dumps(manifest, separators=(",", ":")) + "\n")


if __name__ == "__main__":
    effects()
    if (SOURCE / "registration.json").exists():
        fighters()
