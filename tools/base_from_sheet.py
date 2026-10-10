"""Sprite base de un jefe a partir del primer fotograma de su hoja de dolor.

Las hojas de dolor empiezan con la pose neutra; cuando solo se entregan las hojas, ese fotograma,
recortado a su área opaca, sirve como sprite base (lo que dibuja el juego y la referencia de
anchors.py para alinear el resto de fotogramas).

Uso (requiere numpy y Pillow):
  python tools/base_from_sheet.py <hoja.png> <salida.png> [fotogramas=4]
Ejemplo:
  python tools/base_from_sheet.py assets/korea_dolor.png assets/korea.png 5
"""
import sys
import numpy as np
from PIL import Image
from sheet_cuts import cuts_for

if len(sys.argv) not in (3, 4):
    sys.exit(__doc__)
sheet = Image.open(sys.argv[1]).convert("RGBA")
count = int(sys.argv[3]) if len(sys.argv) == 4 else 4
alpha = np.array(sheet)[:, :, 3]
cuts = cuts_for(alpha, count)
frame = sheet.crop((cuts[0], 0, cuts[1], sheet.height))
# Área de los píxeles bien opacos: los semitransparentes sueltos (ruido del arte) no cuentan, y
# los que quedan fuera se descartan, porque el juego mide el sprite por su área no transparente.
ys, xs = np.nonzero(np.array(frame)[:, :, 3] >= 128)
box = (int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1)
frame.crop(box).save(sys.argv[2])
print("%s: fotograma 0 = x %d..%d, recortado a %s" % (sys.argv[2], cuts[0], cuts[1], box))
