"""Genera los efectos de sonido retro (8 bits) de WALLSHOT en assets/sfx/*.wav.

Son sonidos sintetizados (ondas cuadradas, ruido y barridos de frecuencia), pensados como base:
para cambiar uno basta con reemplazar el .wav con el mismo nombre por otro sonido.

Uso (requiere numpy):
  python tools/sfx.py assets/sfx
"""
import sys, wave
import numpy as np

RATE = 22050
rng = np.random.default_rng(7)  # semilla fija: el resultado es siempre el mismo


def t_axis(dur):
    return np.arange(int(RATE * dur)) / RATE


def sweep(f0, f1, dur, wave_type="square", curve=1.0):
    """Tono con frecuencia que va de f0 a f1 (curve > 1 cae rápido al principio)."""
    t = t_axis(dur)
    k = (t / dur) ** curve
    freq = f0 + (f1 - f0) * k
    phase = 2 * np.pi * np.cumsum(freq) / RATE
    if wave_type == "square":
        return np.sign(np.sin(phase))
    if wave_type == "triangle":
        return 2 / np.pi * np.arcsin(np.sin(phase))
    return np.sin(phase)


def noise(dur, lowpass=1.0):
    """Ruido blanco; lowpass < 1 lo suaviza (media móvil exponencial)."""
    n = rng.uniform(-1, 1, int(RATE * dur))
    if lowpass < 1.0:
        out = np.empty_like(n)
        acc = 0.0
        for i, v in enumerate(n):
            acc += lowpass * (v - acc)
            out[i] = acc
        n = out / max(1e-9, np.abs(out).max())
    return n


def env(n, attack=0.004, decay_pow=1.0):
    """Envolvente: ataque corto y caída hasta 0."""
    t = np.linspace(0, 1, n)
    a = np.clip(t * (n / RATE) / max(attack, 1e-6), 0, 1)
    return a * (1 - t) ** decay_pow


def mix(*parts):
    n = max(len(p) for p in parts)
    out = np.zeros(n)
    for p in parts:
        out[:len(p)] += p
    return out


def at(sound, offset):
    return np.concatenate([np.zeros(int(RATE * offset)), sound])


def notes(freqs, note_dur, wave_type="square", gap=0.0, decay_pow=1.2):
    out = []
    for f in freqs:
        s = sweep(f, f, note_dur, wave_type)
        out.append(s * env(len(s), decay_pow=decay_pow))
        out.append(np.zeros(int(RATE * gap)))
    return np.concatenate(out)


def make_sounds():
    s = {}
    # Disparos (uno por sprite de arma)
    p = sweep(950, 180, 0.13, "square", 0.5); s["shot_pistol"] = mix(p * env(len(p), decay_pow=2) * 0.5, noise(0.06) * env(int(RATE * 0.06), decay_pow=2) * 0.6)
    p = sweep(420, 60, 0.26, "square", 0.4); s["shot_rifle"] = mix(p * env(len(p), decay_pow=2.5) * 0.5, noise(0.22, 0.35) * env(int(RATE * 0.22), decay_pow=2) * 0.9)
    p = sweep(300, 1500, 0.08, "sine") ; q = sweep(1500, 200, 0.22, "triangle", 0.6)
    vib = 1 + 0.25 * np.sin(2 * np.pi * 40 * t_axis(0.22))
    s["shot_plasma"] = np.concatenate([p * env(len(p), decay_pow=0.2) * 0.6, q * vib * env(len(q), decay_pow=1.5) * 0.7])
    # Impactos
    s["wall_hit"] = noise(0.09, 0.25) * env(int(RATE * 0.09), decay_pow=3) * 0.9
    c = noise(0.45, 0.18) * env(int(RATE * 0.45), decay_pow=1.6)
    s["wall_break"] = mix(c * 0.9, at(noise(0.2, 0.3) * env(int(RATE * 0.2), decay_pow=2) * 0.5, 0.12), sweep(140, 50, 0.3, "square") * env(int(RATE * 0.3), decay_pow=3) * 0.3)
    p = sweep(520, 110, 0.14, "square", 0.6); s["enemy_hit"] = mix(p * env(len(p), decay_pow=1.5) * 0.55, noise(0.05) * env(int(RATE * 0.05), decay_pow=2) * 0.4)
    t = t_axis(0.3); ping = np.sin(2 * np.pi * 1400 * t) + 0.5 * np.sin(2 * np.pi * 2130 * t) + 0.3 * np.sin(2 * np.pi * 3170 * t)
    s["shield"] = ping / 1.8 * env(len(t), decay_pow=2.2) * 0.8
    # Explosión de muerte del jefe
    boom = sweep(90, 30, 0.9, "sine") * env(int(RATE * 0.9), attack=0.01, decay_pow=1.4)
    s["explosion"] = mix(noise(1.0, 0.08) * env(int(RATE * 1.0), attack=0.01, decay_pow=1.3) * 0.9, boom * 0.8,
                         at(noise(0.4, 0.2) * env(int(RATE * 0.4), decay_pow=2) * 0.5, 0.18))
    # Recarga
    click = lambda: noise(0.025, 0.6) * env(int(RATE * 0.025), decay_pow=2)
    s["reload"] = mix(click() * 0.7, at(click() * 0.6, 0.11), at(sweep(260, 200, 0.06, "square") * env(int(RATE * 0.06)) * 0.25, 0.11))
    s["reload_done"] = mix(click() * 0.8, at(sweep(600, 900, 0.07, "square") * env(int(RATE * 0.07)) * 0.3, 0.04))
    # Habilidad, compra y jingles
    s["ability"] = notes([523, 659, 784, 1047], 0.06, "square", decay_pow=0.8) * 0.4
    s["buy"] = np.concatenate([notes([988], 0.07, "square") * 0.4, notes([1319], 0.22, "square", decay_pow=1.5) * 0.4])
    s["victory"] = np.concatenate([notes([523, 659, 784], 0.1, "square", decay_pow=0.6), notes([1047], 0.4, "square", decay_pow=1.4)]) * 0.4
    s["game_over"] = np.concatenate([notes([392, 330, 262], 0.16, "triangle", gap=0.02, decay_pow=0.7), notes([196], 0.55, "triangle", decay_pow=1.2)]) * 0.6
    return s


def write_wav(path, data):
    peak = np.abs(data).max()
    data = data / peak * 0.7 if peak > 0 else data  # normaliza a ~-3 dB
    pcm = (np.clip(data, -1, 1) * 32767).astype("<i2")
    with wave.open(path, "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(RATE)
        w.writeframes(pcm.tobytes())


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    import os
    os.makedirs(sys.argv[1], exist_ok=True)
    for name, data in make_sounds().items():
        write_wav(f"{sys.argv[1]}/{name}.wav", data)
        print(f"{name}.wav  {len(data) / RATE:.2f} s")
