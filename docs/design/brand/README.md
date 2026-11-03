# Logo Tara — version vectorielle validée

Redessiné en vectoriel à partir des PNG détourés de la passation
(`docs/design/tara-livreur/assets/`), le fichier SVG fourni ne contenant qu'une image JPEG.
Validé par le porteur du projet le 3 novembre 2026.

| Fichier | Contenu |
| --- | --- |
| `tara-logo-clair.svg` / `tara-logo-sombre.svg` | logo complet (« Tara », « Livraison à la demande ») |
| `tara-pictogramme-clair.svg` / `tara-pictogramme-sombre.svg` | pictogramme seul |
| `tara-icone-sombre.svg` / `tara-icone-clair.svg` | icône d'app carrée 1024 × 1024, pleine (les systèmes arrondissent) |
| `*.png` | exports prêts à l'emploi (logo 2000 px, pictogramme 1000 px, icônes 512 et 1024 px) |

Couleurs : dégradé `#FFB000 → #FF6A00 → #FF3D00` ; encre `#16120E` (fond clair) ou blanc.
L'app livreur utilise l'icône sombre.

## Régénérer les ressources des apps

`source/paths.json` contient les tracés ; `source/build_brand.py` en produit les SVG, les
icônes vectorielles Android (`res/drawable/ic_launcher_*.xml`, `splash_*.xml`) et
`lib/design/brand_paths.dart` :

```sh
python3 docs/design/brand/source/build_brand.py docs/design/brand/source apps/rider /tmp/kit
```
