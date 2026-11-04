# tara_test

Outillage de test des apps Tara, en dépendance de développement seulement :

- `harness.dart` : variantes vérifiées (thèmes clair et sombre, 390×844 et 360×640, texte à
  100 % et 130 %, effets réduits, animations réduites), `pumpVariant`, `goldenTest`, `settle` ;
- `fonts.dart` : polices de `tara_ui` chargées pour que les captures montrent le vrai rendu ;
- `golden_config.dart` : tolérance de 0,2 % des pixels entre deux machines Linux.
