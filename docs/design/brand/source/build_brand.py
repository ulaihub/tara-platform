"""Génère le kit de marque à partir du tracé validé : SVG, ressources Android, chemins Dart."""
import json, os, sys
OUT, RIDER, KIT = sys.argv[1], sys.argv[2], sys.argv[3]
P = json.load(open(OUT + '/paths.json'))['paths']
INK = {'light': '#16120E', 'dark': '#FFFFFF'}
BG = {'light': '#F6F2EC', 'dark': '#0A0A0F'}
FR = {'light': 'clair', 'dark': 'sombre'}
STOPS = [(0, '#FFB000'), (.55, '#FF6A00'), (1, '#FF3D00')]

def svg_grad(id_, x1, y1, x2, y2):
    stops = ''.join(f'<stop offset="{o:g}" stop-color="{c}"/>' for o, c in STOPS)
    return (f'<linearGradient id="{id_}" gradientUnits="userSpaceOnUse" x1="{x1}" y1="{y1}" '
            f'x2="{x2}" y2="{y2}">{stops}</linearGradient>')

def p(d, fill):
    return f'<path fill="{fill}" fill-rule="evenodd" d="{d}"/>'

def mark(ink):
    return p(P['mark_orange'], 'url(#tara-mark-g)') + p(P['mark_leg'], ink) + p(P['mark_box'], ink)

MARK_G = svg_grad('tara-mark-g', 0, 0, 650, 110)

def write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    open(path, 'w').write(text)

def svg(vb, defs, body, title):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{vb}" role="img">'
            f'<title>{title}</title><defs>{defs}</defs>{body}</svg>\n')

# Icône carrée plein cadre (stores, iOS) : pictogramme à 74 % de la largeur, recentré.
ICON_W = 0.74 * 1024
s = ICON_W / 646
tx, ty = (1024 - ICON_W) / 2 - 0.03 * 1024, (1024 - 447 * s) / 2
for t in ('light', 'dark'):
    write(f'{KIT}/tara-pictogramme-{FR[t]}.svg', svg('0 0 655 460', MARK_G, mark(INK[t]), 'Tara'))
    defs = MARK_G + svg_grad('tara-word-g', 1160, 0, 1469, 0) + svg_grad('tara-line-g', 1340, 0, 680, 0)
    body = (mark(INK[t]) + p(P['word_tara'], INK[t]) + p(P['word_swoosh'], 'url(#tara-word-g)')
            + p(P['tag_dark'], INK[t]) + p(P['tag_orange'], '#FF6A00') + p(P['tag_line'], 'url(#tara-line-g)'))
    write(f'{KIT}/tara-logo-{FR[t]}.svg', svg('0 0 1469 551', defs, body, 'Tara, livraison à la demande'))
    write(f'{KIT}/tara-icone-{FR[t]}.svg', svg(
        '0 0 1024 1024', MARK_G,
        f'<rect width="1024" height="1024" fill="{BG[t]}"/>'
        f'<g transform="translate({tx:.1f} {ty:.1f}) scale({s:.5f})">{mark(INK[t])}</g>', 'Tara Livreur'))

# --- Android : drawables vectoriels -------------------------------------------------
def vd_grad():
    items = ''.join(f'<item android:offset="{o:g}" android:color="{c.replace("#", "#FF")}"/>' for o, c in STOPS)
    return ('<aapt:attr name="android:fillColor"><gradient android:type="linear" android:startX="0" '
            f'android:startY="0" android:endX="650" android:endY="110">{items}</gradient></aapt:attr>')

def vd_paths(ink, mono=False):
    orange = (f'<path android:fillType="evenOdd" android:fillColor="{ink}" android:pathData="{P["mark_orange"]}"/>'
              if mono else
              f'<path android:fillType="evenOdd" android:pathData="{P["mark_orange"]}">{vd_grad()}</path>')
    return (orange
            + f'<path android:fillType="evenOdd" android:fillColor="{ink}" android:pathData="{P["mark_leg"]}"/>'
            + f'<path android:fillType="evenOdd" android:fillColor="{ink}" android:pathData="{P["mark_box"]}"/>')

def vector(size_dp, viewport, width_units, ink, mono=False, comment=''):
    sc = width_units / 646
    gx = viewport / 2 - 323 * sc
    gy = viewport / 2 - 223.5 * sc
    return ('<?xml version="1.0" encoding="utf-8"?>\n'
            f'<!-- {comment} Généré depuis docs/design/brand (tracé vectoriel du logo). -->\n'
            '<vector xmlns:android="http://schemas.android.com/apk/res/android" '
            'xmlns:aapt="http://schemas.android.com/aapt" '
            f'android:width="{size_dp}dp" android:height="{size_dp}dp" '
            f'android:viewportWidth="{viewport}" android:viewportHeight="{viewport}">'
            f'<group android:scaleX="{sc:.5f}" android:scaleY="{sc:.5f}" '
            f'android:translateX="{gx:.2f}" android:translateY="{gy:.2f}">'
            f'{vd_paths(ink, mono)}</group></vector>\n')

RES = f'{RIDER}/android/app/src/main/res'
# Icône adaptative : zone sûre de 66 dp au centre d'un carré de 108 dp.
write(f'{RES}/drawable/ic_launcher_foreground.xml',
      vector(108, 108, 58, '#FFFFFFFF', comment='Avant-plan de l\'icône adaptative.'))
write(f'{RES}/drawable/ic_launcher_monochrome.xml',
      vector(108, 108, 58, '#FFFFFFFF', mono=True, comment='Icône à thème (Android 13).'))
# Écran de démarrage Android 12+ : icône sans fond, dans un cercle de 192 dp sur 288 dp.
write(f'{RES}/drawable/splash_icon.xml',
      vector(288, 288, 150, '@color/tara_ink', comment='Démarrage Android 12+.'))
# Écran de démarrage Android 8 à 11 : pictogramme centré.
write(f'{RES}/drawable/splash_mark.xml',
      vector(180, 180, 172, '@color/tara_ink', comment='Démarrage Android 8 à 11.'))

# --- Dart : chemins pour TaraLogo / TaraMark ----------------------------------------
dart = ['// GÉNÉRÉ depuis docs/design/brand (tracé vectoriel du logo) : ne pas modifier.',
        '// ignore_for_file: lines_longer_than_80_chars', '',
        "/// Chemins SVG du logo Tara (repère 1469 × 551 ; le pictogramme occupe 655 × 460).",
        'abstract final class TaraBrandPaths {']
for k, v in P.items():
    name = ''.join(w.capitalize() if i else w for i, w in enumerate(k.split('_')))
    dart.append(f"  static const {name} = '{v}';")
dart.append('}')
# Design partagé par les apps (paquet tara_ui), à côté de l'app livreur.
write(os.path.join(RIDER, '..', '..', 'packages', 'tara_ui', 'lib', 'brand_paths.dart'), '\n'.join(dart) + '\n')
print('ok')
