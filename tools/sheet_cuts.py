"""Corte de sprite sheets horizontales en fotogramas (lo usan anchors.py y base_from_sheet.py)."""
import numpy as np


def cuts_for(alpha, n):
    """Límites en x de los n fotogramas de una hoja, a partir de su canal alfa (array 2D).

    Si la hoja tiene exactamente n bloques opacos separados por huecos transparentes, corta en el
    centro de cada hueco. Si no (fotogramas pegados, o trozos sueltos como chispas), busca la
    columna menos opaca a ±20 % de un fotograma de cada división en partes iguales; dentro de un
    hueco es transparente, y entre varias igual de vacías elige la más cercana a la división.
    """
    opaque = alpha >= 128
    cols = opaque.any(axis=0)
    w = alpha.shape[1]
    runs, s = [], None
    for i, b in enumerate(cols):
        if b and s is None:
            s = i
        if not b and s is not None:
            if i - s >= 5:
                runs.append((s, i - 1))
            s = None
    if s is not None:
        runs.append((s, w - 1))
    if len(runs) == n and min(e - b for b, e in runs) > w / (3 * n):
        return [0] + [(runs[k][1] + runs[k + 1][0]) // 2 for k in range(n - 1)] + [w]
    opacity = opaque.sum(axis=0)
    cuts = [0]
    for k in range(1, n):
        c, r = w * k // n, w * 20 // (100 * n)
        window = opacity[c - r:c + r + 1]
        best = np.flatnonzero(window == window.min()) + c - r
        cuts.append(int(best[np.argmin(np.abs(best - c))]))
    return cuts + [w]
