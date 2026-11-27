# Tara : consignes pour Claude

Lu au début de chaque conversation. **À la fin de chaque lot, mettre à jour « État et suite »
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

Fait récemment : suivi Livré / Échec / Retour + profil (expéditeur), vraie carte et code de
livraison renvoyable sur les pages web, app livreur lots A (scan QR d'enlèvement, en route) et
B (livraison impossible, retour), maquettes et outils dans le dépôt.

À faire, dans l'ordre proposé :

1. **Retour du colis sans dette** (attend son accord sur 3 points : durée de garde au bureau,
   ce qui se passe après, adresse et horaires du bureau). Proposition : le vendeur paie avant
   le retour (solde Tara d'abord, puis Mobile Money dans l'app) ; sinon le colis part au bureau
   Tara, il paie pour le récupérer ; prévenu à chaque étape (app, notification, page web) ;
   pas d'argent encaissé à la porte ; nouvelle version des conditions.
2. App livreur lot C : Recharger, Retirer, Reverser, Pièces, Profil (fidèles aux maquettes).
3. Repères de Douala : le téléchargement OpenStreetMap échouait depuis le cloud ; réessayer
   depuis son ordinateur, ou liste « à vérifier » confirmée par les livreurs.
4. Décision en attente : scanner le code de livraison en QR (recommandé : non, SMS seulement).

À lui rappeler : recharger GitHub Actions (la CI ne démarre plus), vérifier le compte Meta
puis brancher le webhook WhatsApp, lancer `tara update` et `tara apk` après les fusions.
