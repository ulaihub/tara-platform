# Prompt à coller dans Claude Code

> Avant de coller : copier le dossier `tara-handoff/` dans le projet, par exemple sous `docs/design/tara-livreur/`. Adapter le chemin ci-dessous si besoin.

---

Implémente l'interface de l'app livreur Tara à partir de la maquette.

Sources, par ordre de priorité :
1. Le cahier des charges du projet : il fait foi pour le stack, l'architecture, les règles métier et le fonctionnel.
2. `docs/design/tara-livreur/HANDOFF_TARA_LIVREUR.md` : il fait foi pour le visuel (couleurs des thèmes sombre et clair, typographie, composants, animations, fiches des 15 écrans).
3. Le code source des écrans dans `docs/design/tara-livreur/maquette/` (un `.dc.html` par écran et par thème) pour les valeurs exactes. Maquette en ligne : https://claude.ai/artifact/KnQq1vyMR4dXTkeVkgejg6

Méthode :
- Commence par lire le cahier des charges et le document de passation, puis propose-moi un plan avant d'écrire du code.
- Construis d'abord le socle : les tokens (`ThemeExtension` avec thème sombre et thème clair, `ThemeMode.system`), les polices embarquées (Sora + Plus Jakarta Sans), les composants (§3) et les animations (§4 : formes liquides, vagues, compte à rebours 30 s, reflet des boutons, gouttes qui fusionnent, pulsations, sélecteur élastique, maintien SOS 3 s).
- Ensuite seulement, les écrans, dans l'ordre du parcours (§7), branchés sur les vrais modèles et services prévus par le cahier des charges. Les données de la maquette ne sont que des exemples.
- Respecte le réglage « réduire les animations » du téléphone et prévois le mode effets réduits pour les Android d'entrée de gamme (§5.3 et §5.4).
- Vérifie chaque écran dans les deux thèmes, sur un écran de 390×844 et sur un Android compact de 360×640, avec une taille de texte à 130 %.
- Si le cahier des charges et la maquette se contredisent, ou s'il manque un écran ou un état, signale-le-moi au lieu de trancher seul.
