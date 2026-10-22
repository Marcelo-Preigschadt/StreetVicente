"""Pack original complete-body drawings with reviewed anatomy and contact sockets.

No resampling, body-part deformation, face compositing or synthetic inbetweens.
The connected-component gate rejects touching figures before any atlas is written.
"""
from pathlib import Path
import json
import numpy as np
from PIL import Image
from scipy.ndimage import label, find_objects, binary_dilation
from pack_arcade_v8 import hurtboxes

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/source/ruan-v19"


def atomic_webp(image, target):
    temp = target.with_suffix(".tmp")
    image.save(temp, format="WEBP", lossless=True, exact=True, method=6)
    temp.replace(target)


def extract(file, columns=4):
    image = Image.open(file).convert("RGBA")
    pixels = np.asarray(image)
    labels, _ = label(pixels[:, :, 3] > 120)
    components = []
    fragments = []
    rows = 8 // columns
    for component, bounds in enumerate(find_objects(labels), 1):
        if bounds is None:
            continue
        size = int((labels[bounds] == component).sum())
        if size < 80:
            continue
        y, x = bounds
        if size < 4000:
            fragments.append((component, (x.start, y.start, x.stop, y.stop)))
            continue
        row = min(rows - 1, int((y.start + y.stop) / 2 / (image.height / rows)))
        col = min(columns - 1, int((x.start + x.stop) / 2 / (image.width / columns)))
        components.append((row * columns + col, [component], [x.start, y.start, x.stop, y.stop]))
    components.sort()
    assert [c[0] for c in components] == list(range(8)), (file, components)
    # Preserve small disconnected finger/cloth details if present; never discard
    # an entire detached limb or merge the next drawing to make a gate pass.
    for component, bounds in fragments:
        ax, ay, ar, ab = bounds
        distances = []
        for index, _, (bx, by, br, bb) in components:
            gap = max(bx - ar, ax - br, 0) ** 2 + max(by - ab, ay - bb, 0) ** 2
            distances.append((gap, index))
        distance, index = min(distances)
        assert distance <= 12 ** 2, (file, "Unassigned body detail", component, bounds)
        own = components[index]
        own[1].append(component)
        own[2][:] = [min(own[2][0], ax), min(own[2][1], ay),
                     max(own[2][2], ar), max(own[2][3], ab)]
    result = []
    for index, owned, (x, y, right, bottom) in components:
        x, y = max(0, x - 2), max(0, y - 2)
        right, bottom = min(image.width, right + 2), min(image.height, bottom + 2)
        local = labels[y:bottom, x:right]
        own = np.isin(local, owned)
        # Retain original edge alpha; exclude opaque pixels from neighboring cels.
        mask = binary_dilation(own, iterations=2) & ((local == 0) | own)
        cut = pixels[y:bottom, x:right].copy()
        cut[:, :, 3] = np.where(mask, cut[:, :, 3], 0)
        result.append((Image.fromarray(cut), x, y))
    return result


def fighters():
    config = json.loads((SOURCE / "registration.json").read_text())
    staged = {}
    for key, cfg in config.items():
        staged[key] = []
        for index, (sprite, x, y) in enumerate(extract(SOURCE / (key + ".webp"), cfg.get("columns", 4))):
            root, floor = cfg["roots"][index], cfg["floors"][index]
            scale = cfg.get("scales", [cfg["scale"]] * 8)[index]
            assert 0 < scale <= 1, "Native artwork is never enlarged"
            anchor, bottom = root - x, floor - y
            collision = {"hurt": hurtboxes(sprite, anchor, bottom, scale)}
            assert collision["hurt"], (key, index, "Missing visible hurtboxes")
            for field in ("hit", "hand"):
                if str(index) not in cfg.get(field, {}):
                    continue
                point = cfg[field][str(index)]
                converted = [round((point[0] - root) * scale), round((point[1] - floor) * scale)]
                if field == "hit":
                    converted += [max(1, round(point[2] * scale)), max(1, round(point[3] * scale))]
                collision[field] = converted
            staged[key].append((sprite, dict(x=0, y=0, anchor=anchor, bottom=bottom,
                                           scale=scale, collision=collision,
                                           source=key, source_cel=index, face_revision=19)))
    states = staged["states-a"] + staged["states-b"]
    states[4] = staged["low"][0]  # Exact same drawing when crouching / starting a low grip.
    sets = {"states": states, "walk": staged["walk"], "punch": staged["punch"],
            "combat": staged["kick"], "low": staged["low"], "air-actions": staged["air"],
            "pulse": staged["pulse"], "rise": staged["rise"],
            "champion": staged["champion"], "throw": staged["throw"]}
    manifest = dict(schema=19, character="ruan", face_revision=19, sheets={})
    for key, cels in sets.items():
        width = ((max(s.width for s, _ in cels) + 23) // 4) * 4
        height = ((max(s.height for s, _ in cels) + 23) // 4) * 4
        atlas = Image.new("RGBA", (width * 4, height * ((len(cels) + 3) // 4)))
        assert max(atlas.size) <= 4096, "WebGL texture limit"
        frames = []
        for index, (sprite, frame) in enumerate(cels):
            px, py = (index % 4) * width + 8, (index // 4) * height + 8
            atlas.paste(sprite, (px, py))
            frames.append(dict(frame, rect=[px, py, sprite.width, sprite.height]))
        target = ROOT / f"assets/characters/ruan/arcade-v19/{key}.webp"
        target.parent.mkdir(parents=True, exist_ok=True)
        atomic_webp(atlas, target)
        sheet = dict(image="res://" + str(target.relative_to(ROOT)), size=list(atlas.size),
                     scale=1, frames=frames)
        if key == "air-actions":
            exposure = [0, 0, 1, 2, 2, 3, 3, 0]
            manifest["sheets"]["air_punch"] = dict(sheet, frames=[frames[i] for i in exposure])
            manifest["sheets"]["air"] = dict(sheet, frames=[frames[4 + i] for i in exposure])
        else:
            manifest["sheets"][key] = sheet
        print(key, len(cels), "complete cels", target.stat().st_size, "bytes")
    (ROOT / "data/characters/ruan-arcade-v19.json").write_text(json.dumps(manifest, separators=(",", ":")) + "\n")


def effects():
    frames = []
    images = {}
    for key, rows in [("lightning-fx", 4), ("tempest-fx", 2)]:
        image = Image.open(SOURCE / (key + ".webp")).convert("RGBA")
        target = ROOT / f"assets/effects/ruan-v19/{key}.webp"
        target.parent.mkdir(parents=True, exist_ok=True)
        atomic_webp(image, target)
        path = "res://" + str(target.relative_to(ROOT))
        images[key] = path
        for i in range(4 * rows):
            x, y = round((i % 4) * image.width / 4), round((i // 4) * image.height / rows)
            right, bottom = round((i % 4 + 1) * image.width / 4), round((i // 4 + 1) * image.height / rows)
            pivot = [.65, .5] if (key == "tempest-fx" and i < 4) or (key == "lightning-fx" and 4 <= i < 8) else [.5, .5]
            frames.append(dict(image=path, rect=[x, y, right-x, bottom-y], pivot=pivot))
    data = dict(revision=19, images=images, frames=frames, clips=dict(
        charge=list(range(4)), pulse=list(range(4, 8)), rise=list(range(8, 12)),
        impact=list(range(12, 16)), champion=list(range(16, 20)), champion_hit=list(range(20, 24))))
    (ROOT / "data/characters/ruan-effects-v19.json").write_text(json.dumps(data, separators=(",", ":")) + "\n")


if __name__ == "__main__":
    fighters()
    effects()
