"""Ajoute des clés à la fin des ARB fr et en, sans reformater le fichier.
Usage : python3 arb_ins.py <dossier l10n> <spec.json {cle: [fr, en, {placeholder: type}]}>"""
import json, sys
folder, spec = sys.argv[1], json.load(open(sys.argv[2]))
for i, lang in enumerate(['fr', 'en']):
    path = f'{folder}/app_{lang}.arb'
    text = open(path).read().rstrip()
    assert text.endswith('}')
    body = text[:-1].rstrip()
    existing = json.loads(text)
    lines = []
    for key, v in spec.items():
        assert key not in existing, key
        lines.append(f'  {json.dumps(key)}: {json.dumps(v[i], ensure_ascii=False)}')
        if len(v) > 2 and lang == 'fr':
            ph = json.dumps({'placeholders': {n: {'type': t} for n, t in v[2].items()}}, ensure_ascii=False, indent=2)
            ph = ph.replace('\n', '\n  ')
            lines.append(f'  {json.dumps("@" + key)}: {ph}')
    open(path, 'w').write(body + ',\n' + ',\n'.join(lines) + '\n}\n')
