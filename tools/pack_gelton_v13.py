"""Pack the new complete drawings, without resampling, repainting or face compositing.

Reviewed roots and anatomical scale are independent of each cel's bounding height.
In particular, a crouch is never normalized to standing height. Hit areas and palm
sockets are baked in the same coordinate system as the final visible drawing.
"""
from pathlib import Path
import json
import numpy as np
from PIL import Image
from scipy.ndimage import binary_dilation, label, find_objects
from pack_arcade_v8 import hurtboxes

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/source/gelton-v13"


def extract(file, columns=4, skip=()):
    image = Image.open(file).convert("RGBA")
    pixels = np.array(image)
    labels, _ = label(pixels[:, :, 3] > 120)
    items = []
    rows = 8 // columns
    for component, bounds in enumerate(find_objects(labels), 1):
        if bounds is None or (labels[bounds] == component).sum() < 4000:
            continue
        y, x = bounds
        row = min(rows - 1, int((y.start + y.stop) / 2 / (image.height / rows)))
        col = min(columns - 1, int((x.start + x.stop) / 2 / (image.width / columns)))
        index = row * columns + col
        if index in skip:
            continue
        items.append((index, component, (x.start, y.start, x.stop, y.stop)))
    items.sort()
    assert [i[0] for i in items] == [i for i in range(8) if i not in skip], (file, items)
    return pixels, labels, items


def effects():
    image = Image.open(SOURCE / "paint-fx.webp").convert("RGBA")
    # The artist's gutters are not a mathematical grid: preserve all wisps.
    cuts = [([0, 320, 630, 945, 1254], 40, 250),
            ([0, 320, 630, 945, 1254], 270, 550),
            ([0, 320, 630, 945, 1254], 550, 940),
            ([0, 320, 630, 945, 1254], 940, 1254)]
    atlas = Image.new("RGBA", (1408, 1664))
    frames = []
    for row, (xs, top, bottom) in enumerate(cuts):
        for col in range(4):
            sprite = image.crop((xs[col], top, xs[col + 1], bottom))
            rect = [col * 352 + 8, row * 416 + 8, sprite.width, sprite.height]
            atlas.paste(sprite, tuple(rect[:2]))
            pivot = [0.84, 0.53] if row == 0 else [0.5, 0.5]
            frames.append(dict(rect=rect, pivot=pivot))
    target = ROOT / "assets/effects/gelton-v13/paint.webp"
    target.parent.mkdir(parents=True, exist_ok=True)
    atlas.save(target, lossless=True, method=6)
    data = dict(image="res://" + str(target.relative_to(ROOT)), frames=frames,
                clips=dict(stroke=list(range(4)), splash=list(range(4, 8)),
                           arc=list(range(8, 12)), charge=list(range(12, 16))))
    (ROOT / "data/characters/gelton-effects-v13.json").write_text(json.dumps(data, separators=(",", ":")) + "\n")


def fighters():
    config = json.loads((SOURCE / "registration.json").read_text())
    manifest = dict(schema=13, character="gelton", sheets={})
    staged = {}
    for key, cfg in config.items():
        pixels, labels, items = extract(SOURCE / (key + ".webp"), cfg.get("columns", 4), [int(i) for i in cfg.get("reuse", {})])
        staged[key] = [None] * 8
        for i, component, (x, y, r, b) in items:
            crop = pixels[y:b, x:r].copy()
            mask = binary_dilation(labels[y:b, x:r] == component, iterations=2)
            crop[:, :, 3] = np.where(mask, crop[:, :, 3], 0)
            sprite = Image.fromarray(crop)
            root, floor = cfg["roots"][i], cfg["floors"][i]
            scale = cfg["scale"]
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
                         collision=collision, source=key, source_cel=i)
            staged[key][i] = (sprite, frame)
    for key, cfg in config.items():
        for index, source in cfg.get("reuse", {}).items():
            staged[key][int(index)] = staged[source[0]][source[1]]
    # All logical sheets share the same deterministic FighterPose API.
    states = staged["states-a"] + staged["states-b"]
    # One identical crouch drawing at rest and at both ends of the low punch.
    # Avoid a second crouch model/zoom at the exact input boundary.
    states[4] = staged["low"][0]
    sets = {"states": states,
            "walk": staged["walk"], "punch": staged["punch"],
            "combat": staged["kick"], "low": staged["low"],
            "cast": staged["cast"], "rise": staged["rise"], "wheel": staged["wheel"],
            "air-actions": staged["air"]}
    for key, cels in sets.items():
        cw = ((max(s.width for s, _ in cels) + 23) // 4) * 4
        ch = ((max(s.height for s, _ in cels) + 23) // 4) * 4
        atlas = Image.new("RGBA", (cw * 4, ch * ((len(cels) + 3) // 4)))
        frames = []
        for i, (sprite, frame) in enumerate(cels):
            px, py = (i % 4) * cw + 8, (i // 4) * ch + 8
            atlas.paste(sprite, (px, py))
            frames.append(dict(frame, rect=[px, py, sprite.width, sprite.height]))
        target = ROOT / f"assets/characters/gelton/arcade-v13/{key}.webp"
        target.parent.mkdir(parents=True, exist_ok=True)
        atlas.save(target, lossless=True, method=6)
        sheet = dict(image="res://" + str(target.relative_to(ROOT)),
                     size=list(atlas.size), scale=1, frames=frames)
        if key == "air-actions":
            exposure = [0, 0, 1, 2, 2, 3, 3, 0]
            manifest["sheets"]["air_punch"] = dict(sheet, frames=[frames[i] for i in exposure])
            manifest["sheets"]["air"] = dict(sheet, frames=[frames[4 + i] for i in exposure])
        else:
            manifest["sheets"][key] = sheet
        print(key, len(cels), "new cels", target.stat().st_size, "bytes")
    (ROOT / "data/characters/gelton-arcade-v13.json").write_text(json.dumps(manifest, separators=(",", ":")) + "\n")


if __name__ == "__main__":
    effects()
    if (SOURCE / "registration.json").exists():
        fighters()
