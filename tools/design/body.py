"""Corps HTML d'une maquette, dessins (svg, 3D) remplacés, pour la lire facilement.
Usage : python3 tools/design/body.py Page [texte_de_depart] [longueur]"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
s = (ROOT / 'docs/design/maquettes' / f'{sys.argv[1]}.dc.html').read_text()
i = s.find('<div style="width: 390px')
body = s[i:s.find('<script type="text/x-dc"', i)]
body = re.sub(r'<svg.*?</svg>', '<svg/>', body, flags=re.S)
body = re.sub(r'<div class="tara-anim" style="position: relative; width: \d+px; height: \d+px; transform-style.*?</div></div>', '<3D/>', body, flags=re.S)
if len(sys.argv) > 2:
    j = body.find(sys.argv[2])
    body = body[max(0, j):]
print(body[: int(sys.argv[3]) if len(sys.argv) > 3 else 999999])
