"""Recorta y reduce las piezas de interfaz de assets/interface/*.png a su tamaño de uso en el juego.

Las hojas originales están a unas 4-5 veces el tamaño de pantalla. Reducirlas aquí con buen
filtrado (BOX) da mejor resultado que dejar que Godot las escale con filtro "nearest", y permite
que los StyleBoxTexture (9-slice) dibujen sus bordes al tamaño correcto. Los originales no se
modifican; el resultado va a assets/interface/game/.

Los botones del original traen el texto "PLAY" dibujado: aquí se borra rellenando cada fila
de la placa interior con el color de la placa de esa fila, para que Godot escriba el texto.

Uso (requiere numpy y Pillow):
  python tools/ui_slice.py assets/interface
"""
import os
import sys
import numpy as np
from PIL import Image

if len(sys.argv) != 2:
    sys.exit(__doc__)
SRC = sys.argv[1]
OUT = os.path.join(SRC, "game")
os.makedirs(OUT, exist_ok=True)

menu = Image.open(os.path.join(SRC, "ui_menu_sheet.png")).convert("RGBA")
hud = Image.open(os.path.join(SRC, "ui_hud_sheet.png")).convert("RGBA")
dossier = Image.open(os.path.join(SRC, "ui_dossier_classified.png")).convert("RGBA")
bunker = Image.open(os.path.join(SRC, "ui_menu_background_bunker.png")).convert("RGBA")


def save(img, name, scale=None, size=None):
    if scale is not None:
        size = (max(1, round(img.width * scale)), max(1, round(img.height * scale)))
    if size is not None and size != img.size:
        img = img.resize(size, Image.BOX)
    img.save(os.path.join(OUT, name))
    print(f"{name:24s} {img.width}x{img.height}")


def erase_button_text(btn):
    """Borra el texto de la placa interior (coordenadas medidas sobre los botones de 344x180)."""
    a = np.array(btn).astype(float)
    x0, x1, y0, y1 = 86, 262, 58, 124          # zona del texto con su contorno
    left, right = a[:, 72:85], a[:, 263:276]    # placa limpia a ambos lados, por fila
    for y in range(y0, y1):
        l = np.median(left[y], axis=0); r = np.median(right[y], axis=0)
        t = np.linspace(0, 1, x1 - x0)[:, None]
        a[y, x0:x1] = l * (1 - t) + r * t
    return Image.fromarray(a.clip(0, 255).astype(np.uint8))


# --- Hoja de menú ---
BUTTON_SCALE = 0.25
for name, x in (("normal", 28), ("hover", 380), ("pressed", 728), ("disabled", 1076)):
    btn = erase_button_text(menu.crop((x, 372, x + 344, 552)))
    save(btn, f"button_{name}.png", BUTTON_SCALE)
save(menu.crop((204, 40, 1244, 344)), "title.png", 0.45)
save(menu.crop((28, 572, 1420, 872)), "panel_large.png", 0.4)
save(menu.crop((272, 896, 1176, 1068)), "panel_small.png", 0.4)

# --- Hoja de HUD ---
save(hud.crop((628, 832, 1396, 1036)), "hud_bar.png", 0.22)
BULLET_SCALE = 18 / 292  # la bala llena mide 18 px de alto; las demás conservan su proporción
save(hud.crop((88, 88, 204, 380)), "bullet_full.png", BULLET_SCALE)
save(hud.crop((264, 116, 384, 380)), "bullet_spent.png", BULLET_SCALE)
save(hud.crop((448, 116, 560, 380)), "bullet_silver.png", BULLET_SCALE)
for name, box in (("bronze", (660, 64, 872, 460)), ("silver", (900, 64, 1116, 460)), ("gold", (1136, 64, 1352, 460))):
    save(hud.crop(box), f"medal_{name}.png", 0.12)
    save(hud.crop(box), f"medal_{name}_small.png", 0.05)
for name, box in (("tl", (632, 488, 780, 632)), ("tr", (844, 488, 988, 632)),
                  ("bl", (632, 672, 780, 816)), ("br", (840, 672, 988, 816))):
    save(hud.crop(box), f"reticle_{name}.png", 0.17)

# --- Expediente ---
DOSSIER_SCALE = 0.452
save(dossier.crop((16, 20, 1432, 1052)), "dossier.png", DOSSIER_SCALE)

# --- Fondo del menú: cubre el escenario (1000x470), centrado en el mapa ---
w = 1000
s = w / bunker.width
scaled = bunker.resize((w, round(bunker.height * s)), Image.BOX)
cy = round(550 * s)  # centro vertical del mapa en la imagen original
save(scaled.crop((0, cy - 235, w, cy + 235)), "menu_bg.png")
