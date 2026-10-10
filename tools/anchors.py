"""Alinea sprite sheets de WALLSHOT con su sprite base.

Para cada hoja (4 fotogramas en horizontal) calcula:
  - "src": la región de cada fotograma, cortando por los huecos transparentes reales.
  - "anchors": dónde está el sprite base dentro de cada fotograma. Se busca ajustando su silueta
    (IoU de máscaras alfa); la escala se fija con el primer fotograma de la hoja. Si un fotograma
    no contiene al personaje (IoU < THRESH, p. ej. una explosión), se ancla por su centro de masa.

Imprime los Rect2 listos para pegar en "hurt" / "death" (scripts/stages.gd) o WEAPON_ANIMATIONS
(scripts/main.gd) y guarda una vista previa preview_<hoja>.png usando la misma fórmula que
draw_sheet_frame(): el sprite base y luego cada fotograma, con la caja del sprite base en verde.

Uso (requiere numpy y Pillow):
  python tools/anchors.py <dir_assets> <dir_salida> <base.png> <hoja1.png>[,<hoja2.png>...]
Ejemplo:
  python tools/anchors.py assets /tmp level_3_boss.png level_3_boss_dolor.png,level_3_boss_muerte.png
"""
import sys, json
import numpy as np
from PIL import Image, ImageDraw

if len(sys.argv) != 5:
    sys.exit(__doc__)
ASSETS, OUT, BASE = sys.argv[1], sys.argv[2], sys.argv[3]
SHEET_NAMES = sys.argv[4].split(",")
DS = 4         # factor de reducción para la búsqueda
THRESH = 0.6   # IoU mínimo para considerar que el fotograma contiene al personaje

def load(name):
    return np.array(Image.open(f"{ASSETS}/{name}").convert("RGBA"))

def cuts_for(a):
    cols = (a >= 128).any(axis=0)
    runs, s = [], None
    for i, b in enumerate(cols):
        if b and s is None: s = i
        if not b and s is not None:
            if i - s >= 5: runs.append((s, i - 1))
            s = None
    if s is not None: runs.append((s, len(cols) - 1))
    gaps = sorted(range(len(runs) - 1), key=lambda k: runs[k + 1][0] - runs[k][1], reverse=True)[:3]
    cuts = [0] + sorted((runs[k][1] + runs[k + 1][0]) // 2 for k in gaps) + [a.shape[1]]
    return cuts

def downsample(mask):
    h, w = mask.shape[0] // DS * DS, mask.shape[1] // DS * DS
    return mask[:h, :w].reshape(h // DS, DS, w // DS, DS).mean(axis=(1, 3)) > 0.5

def corr(F, T):
    """Correlación válida de F con la plantilla T vía FFT: out[y,x] = sum(F[y:y+th, x:x+tw] * T)."""
    H, W = F.shape; th, tw = T.shape
    sh = (H + th, W + tw)
    r = np.fft.irfft2(np.fft.rfft2(F, sh) * np.conj(np.fft.rfft2(T, sh)), sh)
    return np.rint(r[:H - th + 1, :W - tw + 1])

def boxsum(F, th, tw):
    I = np.pad(F.cumsum(0).cumsum(1), ((1, 0), (1, 0)))
    return I[th:, tw:] - I[:-th, tw:] - I[th:, :-tw] + I[:-th, :-tw]

def match(base_mask, frame_mask, fixed_th=None):
    PAD = 60
    F = np.pad(downsample(frame_mask).astype(float), PAD)
    ys, xs = np.nonzero(F)
    content_h = ys.max() - ys.min() + 1
    bh, bw = base_mask.shape
    best = (-1, None)
    heights = [fixed_th // DS] if fixed_th else [int(round(content_h * rel)) for rel in np.arange(0.55, 1.35, 0.02)]
    for th in heights:
        tw = int(round(bw * th / bh))
        if th >= F.shape[0] or tw >= F.shape[1] or th < 8: continue
        T = np.array(Image.fromarray(base_mask.astype(np.uint8) * 255).resize((tw, th), Image.NEAREST)) > 127
        T = T.astype(float)
        inter = corr(F, T)
        union = T.sum() + boxsum(F, th, tw) - inter
        iou = inter / np.maximum(union, 1)
        k = np.unravel_index(np.argmax(iou), iou.shape)
        if iou[k] > best[0]:
            best = (iou[k], ((k[1] - PAD) * DS, (k[0] - PAD) * DS, tw * DS, th * DS))
    return best

def centroid(mask):
    ys, xs = np.nonzero(mask)
    return xs.mean(), ys.mean()

result = {}
for base_name, sheets in [(BASE, SHEET_NAMES)]:
    base = load(base_name)
    ba = base[:, :, 3] >= 128
    ys, xs = np.nonzero(ba)
    base_mask = ba[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
    for sheet_name in sheets:
        kind = sheet_name.rsplit(".", 1)[0]
        img = load(sheet_name); a = img[:, :, 3]
        cuts = cuts_for(a)
        frames = []
        fixed = None
        for i in range(4):
            x0, x1 = cuts[i], cuts[i + 1]
            m = a[:, x0:x1] >= 128
            iou, rect = match(base_mask, m, fixed)
            if fixed is None:
                fixed = rect[3]  # el personaje mantiene su escala en toda la hoja
            cx, cy = centroid(m)
            frames.append({"src": [x0, 0, x1 - x0, a.shape[0]], "iou": float(iou),
                           "anchor": [rect[0] + x0, rect[1], rect[2], rect[3]], "centroid": [cx + x0, cy]})
        # Fotogramas sin personaje reconocible: ancla del primer fotograma desplazada por el centro de masa.
        ref = frames[0]
        for f in frames[1:]:
            if f["iou"] < THRESH:
                dx = f["centroid"][0] - ref["centroid"][0]; dy = f["centroid"][1] - ref["centroid"][1]
                f["anchor"] = [ref["anchor"][0] + dx, ref["anchor"][1] + dy, ref["anchor"][2], ref["anchor"][3]]
                f["by"] = "centroid"
            else:
                f["by"] = "match"
        frames[0]["by"] = "match"
        result[kind] = {"sheet": sheet_name, "frames": frames}
        # Vista previa con la misma fórmula que draw_sheet_frame()
        bw, bh = base_mask.shape[1], base_mask.shape[0]
        s0 = 130.0 / max(bw, bh); tw, th = bw * s0, bh * s0
        canvas = Image.new("RGBA", (5 * 240, 260), (39, 66, 92, 255))
        d = ImageDraw.Draw(canvas)
        sheet_img = Image.fromarray(img)
        for j in range(5):
            cx, cy = 120 + j * 240, 130
            tx, ty = cx - tw / 2, cy - th / 2
            if j == 0:
                crop = Image.fromarray(base[ys.min():ys.max() + 1, xs.min():xs.max() + 1])
                canvas.alpha_composite(crop.resize((round(tw), round(th)), Image.NEAREST), (round(tx), round(ty)))
            else:
                f = frames[j - 1]; sx, sy, sw, sh = f["src"]; ax, ay, aw, ah = f["anchor"]
                s = th / ah
                ox = cx - (ax + aw / 2 - sx) * s; oy = cy - (ay + ah / 2 - sy) * s
                crop = sheet_img.crop((sx, sy, sx + sw, sy + sh)).resize((max(1, round(sw * s)), max(1, round(sh * s))), Image.NEAREST)
                canvas.alpha_composite(crop, (round(ox), round(oy)))
            d.rectangle([tx, ty, tx + tw, ty + th], outline=(0, 255, 0, 255))
        canvas.save(f"{OUT}/preview_{kind}.png")

for v in result.values():
    for f in v["frames"]:
        f["anchor"] = [int(round(float(x))) for x in f["anchor"]]
        f["centroid"] = [float(x) for x in f["centroid"]]
for k, v in result.items():
    print(f"{v['sheet']}  (vista previa: {OUT}/preview_{k}.png)")
    for i, f in enumerate(v["frames"]):
        print(f"   fotograma {i}: IoU {f['iou']:.2f} ({f['by']})")
    rect = lambda r: "Rect2(%d, %d, %d, %d)" % tuple(r)
    print('   "src":[' + ", ".join(rect(f["src"]) for f in v["frames"]) + "],")
    print('   "anchors":[' + ", ".join(rect(f["anchor"]) for f in v["frames"]) + "]")
json.dump(result, open(f"{OUT}/anchors.json", "w"), indent=1)
