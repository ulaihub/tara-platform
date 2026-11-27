# Comparer les écrans aux maquettes

Les maquettes de la refonte sont dans `docs/design/maquettes` (une page par fichier `.dc.html`,
version claire et `-Sombre`). `INVENTAIRE.md` liste les écarts déjà constatés et les décisions prises.

## 1. Rendre les maquettes en images (une fois, puis après chaque changement de maquette)

```bash
node tools/design/rendre.cjs
npx -y playwright@1.57.0 install chromium
NODE_PATH=$(npm root -g) npx -y -p playwright@1.57.0 node tools/design/photo.cjs
```

Les images arrivent dans `tools/design/rendus/<Page>.<clair|sombre>.png` (dossier non versionné).

## 2. Produire les captures de l'app

```bash
cd apps/client   # ou apps/rider
flutter test --update-goldens
```

## 3. Mettre maquette et app côte à côte

```bash
python3 tools/design/cmp.py client planche.png Profil:06_profil
```

`Maquette:dossier` : nom de la maquette, puis dossier de capture dans `apps/<app>/test/goldens`.
La planche montre clair et sombre, maquette à gauche, app à droite (Python avec Pillow).

## Autres outils

- `python3 tools/design/body.py Profil` : le HTML d'une maquette, lisible (dessins retirés).
- `python3 tools/arb_ins.py apps/client/lib/l10n textes.json` : ajoute des textes fr et en aux
  fichiers ARB sans les reformater (`{"cle": ["texte fr", "text en", {"param": "int"}]}`),
  puis `flutter gen-l10n`.
