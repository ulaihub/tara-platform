# Tara : consignes pour Claude

Lu au début de chaque conversation. Mémoire du projet : `docs/DECISIONS.md` (règles validées),
`docs/HISTORIQUE.md` (tout ce qui a été fait, PR par PR), `docs/LOTS_A_VENIR.md` (la suite). **À la fin de chaque lot, mettre à jour « État et suite »
ci-dessous (et le tableau d'avancement du README) dans la même branche que le lot.**
Rester court : ce fichier est relu à chaque message.

## Le porteur du projet

- Non technique : répondre en **français simple**, sans jargon, avec des captures pour montrer.
- Il décide ; je propose avec une recommandation, puis j'attends son accord.

## Règles de travail (toujours en vigueur)

- Une branche par lot, jamais de travail direct sur `main`, jamais de force-push.
- Ouvrir une demande de fusion (PR) et fusionner **seulement** quand il écrit « ouvre et fusionne ».
  Montrer les résultats (tests, captures) avant.
- Respecter les maquettes (`docs/design/maquettes`, outils dans `tools/design/README.md`).
- Tester avant de conclure ; dire franchement ce qui échoue ou n'a pas été fait.
- **Argent** : ne jamais changer une règle d'argent (frais, soldes, dettes, partage) sans son accord.
- Points juridiques : à faire valider par son avocat.
- Secrets : jamais dans le dépôt ni dans la conversation (clés Sebpay, compte de service Firebase,
  `google-services.json`). Les clés Sebpay « live » doivent être régénérées.
- Données fictives seulement (tests, démo, captures).
- Le **code de livraison** n'est jamais affiché (le lien de suivi peut circuler) : envoyé par SMS seulement.
- Commits et PR : pas de nom de modèle d'IA.

## Fichiers à tenir à jour (dans la branche du lot qui les concerne)

- `docs/HISTORIQUE.md` + `docs/historique/PR-NNN.md` : à chaque fusion, la ligne et le texte de la PR.
- `docs/DECISIONS.md` : toute nouvelle décision du porteur (règle, montant, choix d'apparence).
- `docs/LOTS_A_VENIR.md` : instructions détaillées de chaque lot à venir ; retirer un lot fini,
  ajouter toute nouvelle demande du porteur avec le même niveau de détail.
- `CLAUDE.md` « État et suite » et le tableau du `README.md` : à chaque lot.
- `docs/design/maquettes/INVENTAIRE.md` : écrans rendus fidèles, écarts restants.
- `docs/API.md` (et `apps/api/openapi.json`) : toute route ajoutée ou changée.
- `docs/juridique/*.md` : toute règle d'argent ou de responsabilité (nouvelle version des
  conditions, à faire relire par l'avocat).
- `docs/SECURITE.md` : nouvelle protection, nouveau secret ou nouvelle donnée personnelle
  (et `docs/juridique/registre-des-traitements.md`).
- `docs/DEPLOIEMENT.md` : nouvelle variable de configuration ou étape sur le serveur.
- `docs/ARCHITECTURE.md` : nouveau composant ou décision technique.
- `docs/PLAN_DES_PHASES.md` : phase terminée ou ajoutée.
- README de l'app ou du paquet touché (`apps/*/README.md`, `packages/*/README.md`, `tools/design/README.md`).

## Commandes utiles

- Installation : voir « Démarrage rapide » du README (`pnpm install`, `pnpm infra:up`, …).
- Serveur : `pnpm --filter @tara/api test`, puis tests base de données `pnpm --filter @tara/api test:db`
  (Docker ouvert ; jamais deux lancements en même temps). Après un changement d'API :
  `pnpm --filter @tara/api openapi`. Une nouvelle route publique va dans `PUBLIC_ROUTES`
  de `apps/api/test/route-guards.db-spec.ts`.
- Page web (`apps/tracking`) et back-office : `pnpm --filter <nom> test`.
- Apps Flutter (`apps/client` expéditeur, `apps/rider` livreur) : `flutter test`,
  captures `flutter test --update-goldens`, `dart format -l 120 .`, textes ajoutés avec
  `tools/arb_ins.py` puis `flutter gen-l10n`.
- Serveur de production (VPS) : `tara update` puis `tara apk` (voir `docs/DEPLOIEMENT.md`).

## État et suite (mis à jour le 27/11/2026)

Fait récemment : **retour du colis sans dette** (PR 94 : payé d'avance, sinon gardé 30 jours au
bureau Tara de Bonabéri, rendu contre paiement, jamais vendu), suivi Livré / Échec / Retour +
profil (expéditeur), vraie carte et code de livraison renvoyable sur les pages web, app livreur
lots A et B, maquettes et outils dans le dépôt.

À faire, dans l'ordre proposé (instructions complètes : `docs/LOTS_A_VENIR.md`) :

1. App livreur lot C : Recharger, Retirer, Reverser, Pièces, Profil (fidèles aux maquettes).
2. App expéditeur : écrans pas encore comparés (envoi en masse d'abord).
3. Repères de Douala : le téléchargement OpenStreetMap échouait depuis le cloud ; réessayer
   depuis son ordinateur, ou liste « à vérifier » confirmée par les livreurs.
4. Décision en attente : scanner le code de livraison en QR (recommandé : non, SMS seulement).

À lui rappeler : faire relire par l'avocat les conditions 2026-11.12 (bureau, colis non
réclamé) et donner l'adresse définitive du bureau ; recharger GitHub Actions (la CI ne démarre
plus), vérifier le compte Meta puis brancher le webhook WhatsApp, lancer `tara update` et
`tara apk` après les fusions.
