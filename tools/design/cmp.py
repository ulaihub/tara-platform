"""Planche maquette | app, en clair et en sombre (barre d'état de l'app retirée).
Usage : python3 tools/design/cmp.py <client|rider> sortie.png Maquette:dossier_golden ...
Le dossier golden est relatif à apps/<app>/test/goldens ; un chemin .png peut contenir THEME."""
import os
import sys
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
RENDUS = ROOT / 'tools/design/rendus'
app, out, pairs = sys.argv[1], sys.argv[2], sys.argv[3:]
G = ROOT / 'apps' / app / 'test/goldens'


def golden(d, theme):
    if d.endswith('.png'):
        return G / d.replace('THEME', theme)
    for n in [f'{theme}_390x844_text100.png', f'{theme}.png']:
        if os.path.exists(G / d / n):
            return G / d / n
    sys.exit(f'Capture introuvable : {d} ({theme})')


cols = []
for pair in pairs:
    m, d = pair.split(':', 1)
    for mt, gt in [('clair', 'light'), ('sombre', 'dark')]:
        a = Image.open(RENDUS / f'{m}.{mt}.png').convert('RGB')
        b = Image.open(golden(d, gt)).convert('RGB').crop((0, 47, 390, 844))
        cols.append((f'{m} {mt}', a, b))
o = Image.new('RGB', (len(cols) * 800, 870), 'white')
dr = ImageDraw.Draw(o)
for i, (t, a, b) in enumerate(cols):
    o.paste(a, (i * 800, 26))
    o.paste(b, (i * 800 + 395, 26))
    dr.text((i * 800 + 4, 6), t + '  (maquette | app)', fill='black')
o.save(out)
print(out)
