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
from pack_arcade_v8 import extract, hurtboxes

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/source/gustavo-v12"


def effects():
    image = Image.open(SOURCE / "smoke-fx.webp").convert("RGBA")
    # The artist's gutters are not a mathematical grid: preserve all wisps.
    cuts = [([0, 320, 630, 945, 1254], 40, 250),
            ([0, 314, 627, 945, 1254], 270, 590),
            ([40, 345, 640, 949, 1254], 590, 950),
            ([0, 310, 605, 945, 1254], 960, 1254)]
    atlas = Image.new("RGBA", (1408, 1536))
    frames = []
    for row, (xs, top, bottom) in enumerate(cuts):
        for col in range(4):
            sprite = image.crop((xs[col], top, xs[col + 1], bottom))
            rect = [col * 352 + 8, row * 384 + 8, sprite.width, sprite.height]
            atlas.paste(sprite, tuple(rect[:2]))
            pivot = [0.80, 0.53] if row == 0 else [0.5, 0.5]
            frames.append(dict(rect=rect, pivot=pivot))
    target = ROOT / "assets/effects/gustavo-v12/smoke.webp"
    atlas.save(target, lossless=True, method=6)
    data = dict(image="res://" + str(target.relative_to(ROOT)), frames=frames,
                clips=dict(wave=list(range(4)), impact=list(range(4, 8)),
                           rise=list(range(8, 12)), gather=list(range(12, 16))))
    (ROOT / "data/characters/gustavo-effects-v12.json").write_text(json.dumps(data, separators=(",", ":")) + "\n")


def fighters():
    config = json.loads((SOURCE / "registration.json").read_text())
    manifest = dict(schema=12, character="gustavo", sheets={})
    staged = {}
    for key, cfg in config.items():
        pixels, labels, items = extract(SOURCE / (key + ".webp"), 2)
        staged[key] = []
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
                    collision[field] = cfg[field][str(i)]
            frame = dict(x=0, y=0, anchor=anchor, bottom=bottom, scale=scale,
                         collision=collision, source=key, source_cel=i)
            staged[key].append((sprite, frame))
    # All logical sheets share the same deterministic FighterPose API.
    states = staged["states-a"] + staged["states-b"]
    # One identical crouch drawing at rest and at both ends of the low punch.
    # Avoid a second crouch model/zoom at the exact input boundary.
    states[4] = staged["low"][0]
    sets = {"states": states,
            "walk": staged["walk"], "punch": staged["punch"],
            "combat": staged["kick"] + staged["powers"], "low": staged["low"],
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
        target = ROOT / f"assets/characters/gustavo/arcade-v12/{key}.webp"
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
    (ROOT / "data/characters/gustavo-arcade-v12.json").write_text(json.dumps(manifest, separators=(",", ":")) + "\n")


if __name__ == "__main__":
    effects()
    if (SOURCE / "registration.json").exists():
        fighters()
