"""Sons de Tara : notes de balafon et de cloche synthétisées (aucun échantillon tiers).

Usage : python3 -I make_sounds.py <dossier de sortie>
"""
import sys
import wave
from pathlib import Path

import numpy as np

RATE = 44100
rng = np.random.default_rng(7)

NOTES = {
    'E4': 329.63, 'A4': 440.0, 'C5': 523.25, 'E5': 659.25, 'G5': 783.99, 'A5': 880.0,
    'B5': 987.77, 'C6': 1046.5, 'D6': 1174.66, 'E6': 1318.51, 'G6': 1567.98, 'A6': 1760.0,
    'B6': 1975.53, 'C7': 2093.0, 'E7': 2637.02,
}


def timeline(seconds):
    return np.zeros(int(RATE * seconds))


def balafon(freq, seconds=0.7, bright=1.0):
    """Lame de bois frappée : fondamentale, partiels inharmoniques qui s'éteignent vite,
    petit choc de mailloche à l'attaque."""
    t = np.arange(int(RATE * seconds)) / RATE
    tone = np.sin(2 * np.pi * freq * t) * np.exp(-t * 7)
    tone += 0.30 * bright * np.sin(2 * np.pi * freq * 3.93 * t) * np.exp(-t * 18)
    tone += 0.10 * bright * np.sin(2 * np.pi * freq * 9.2 * t) * np.exp(-t * 40)
    tone += 0.06 * np.sin(2 * np.pi * freq * 2 * t) * np.exp(-t * 10)
    mallet = rng.standard_normal(len(t)) * np.exp(-t * 420) * 0.18 * bright
    return tone + mallet


def bell(freq, seconds=1.2):
    """Petite cloche claire (pièce, scintillement)."""
    t = np.arange(int(RATE * seconds)) / RATE
    out = np.zeros_like(t)
    for ratio, gain, decay in ((1, 1, 3.2), (2.76, .45, 5.5), (5.4, .22, 9), (8.93, .1, 14)):
        out += gain * np.sin(2 * np.pi * freq * ratio * t) * np.exp(-t * decay)
    return out


def whoosh(seconds=0.42):
    """Souffle qui monte : bruit filtré dont la brillance croît, enveloppe en cloche."""
    n = int(RATE * seconds)
    t = np.arange(n) / RATE
    noise = rng.standard_normal(n)
    out = np.zeros(n)
    # Filtre passe-bas d'ordre 1 dont la coupure monte de 300 Hz à 4 kHz.
    cutoff = 300 * (4000 / 300) ** (t / seconds)
    alpha = 1 - np.exp(-2 * np.pi * cutoff / RATE)
    acc = 0.0
    for i in range(n):
        acc += alpha[i] * (noise[i] - acc)
        out[i] = acc
    envelope = np.sin(np.pi * t / seconds) ** 2
    glide = np.sin(2 * np.pi * np.cumsum(500 + 900 * (t / seconds) ** 2) / RATE) * 0.25
    return (out * 1.6 + glide) * envelope


def place(track, sound, at, gain=1.0):
    start = int(RATE * at)
    end = min(len(track), start + len(sound))
    track[start:end] += gain * sound[: end - start]


def finish(track, peak=0.89):
    fade = int(RATE * 0.002)
    track[:fade] *= np.linspace(0, 1, fade)
    tail = int(RATE * 0.03)
    track[-tail:] *= np.linspace(1, 0, tail)
    return track / np.max(np.abs(track)) * peak


def offer():
    track = timeline(1.25)
    for i, note in enumerate(('G5', 'B5', 'D6', 'G6')):
        place(track, balafon(NOTES[note]), i * 0.085)
    place(track, balafon(NOTES['D6']), 0.52, 0.85)
    place(track, balafon(NOTES['G6']), 0.605, 0.95)
    return finish(track, 0.95)


def accepted():
    track = timeline(0.7)
    place(track, balafon(NOTES['D6']), 0)
    place(track, balafon(NOTES['G6']), 0.1)
    return finish(track)


def picked_up():
    track = timeline(0.6)
    place(track, balafon(NOTES['C6'], bright=0.7), 0)
    place(track, balafon(NOTES['E6'], bright=0.7), 0.08, 0.9)
    return finish(track, 0.75)


def delivered():
    track = timeline(1.6)
    for i, note in enumerate(('C6', 'E6', 'G6')):
        place(track, balafon(NOTES[note]), i * 0.08)
    place(track, bell(NOTES['C7']), 0.26, 0.7)
    place(track, bell(NOTES['E7'], 1.0), 0.34, 0.25)
    return finish(track)


def cash():
    track = timeline(0.9)
    place(track, bell(NOTES['B6'], 0.8), 0, 0.8)
    place(track, bell(NOTES['E7'], 0.8), 0.07)
    place(track, balafon(NOTES['G5'], bright=0.5), 0, 0.35)
    return finish(track, 0.8)


def sent():
    track = timeline(0.85)
    place(track, whoosh(), 0, 0.8)
    place(track, balafon(NOTES['G6']), 0.3)
    return finish(track, 0.8)


def received():
    track = timeline(0.65)
    place(track, balafon(NOTES['E6']), 0)
    place(track, balafon(NOTES['A6']), 0.09)
    return finish(track, 0.8)


def error():
    track = timeline(0.6)
    place(track, balafon(NOTES['A4'], bright=0.4), 0)
    place(track, balafon(NOTES['E4'], bright=0.4), 0.12)
    return finish(track, 0.6)


def write(path, samples):
    data = (samples * 32767).astype('<i2').tobytes()
    with wave.open(str(path), 'wb') as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(RATE)
        out.writeframes(data)


if __name__ == '__main__':
    target = Path(sys.argv[1])
    target.mkdir(parents=True, exist_ok=True)
    for name, make in (
        ('offer', offer), ('accepted', accepted), ('picked_up', picked_up), ('delivered', delivered),
        ('cash', cash), ('sent', sent), ('received', received), ('error', error),
    ):
        write(target / f'{name}.wav', make())
        print(name, (target / f'{name}.wav').stat().st_size)
