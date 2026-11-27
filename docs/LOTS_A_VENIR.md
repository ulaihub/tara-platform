# Lots et tâches à venir : instructions détaillées

Ce fichier dit, pour chaque lot à venir, **quoi faire, où dans le code, comment vérifier** et ce
qui attend une décision du porteur du projet. Une nouvelle conversation doit pouvoir enchaîner
sans autre explication. Les règles de travail sont dans [CLAUDE.md](../CLAUDE.md).

**À la fin de chaque lot :** retirer le lot de ce fichier (ou le marquer fait avec son numéro de
PR), ajouter ce qu'on a appris d'utile pour les lots suivants, mettre à jour « État et suite » de
`CLAUDE.md`. **Nouvelle demande du porteur :** l'ajouter ici avec le même niveau de détail.

Déroulé commun à chaque lot :

1. Branche depuis `main` à jour (`git checkout -b <thème>/<lot>`).
2. Lire les maquettes concernées (`python3 tools/design/body.py <Maquette>`) et l'inventaire.
3. Coder ; tests du serveur et des apps touchées ; captures `flutter test --update-goldens` ;
   planches `python3 tools/design/cmp.py …` (voir `tools/design/README.md`).
4. Mettre à jour les fichiers `.md` listés dans `CLAUDE.md`.
5. Montrer au porteur : ce qui change (en français simple), les planches, les résultats des tests.
   Attendre « ouvre et fusionne ».

---

## Fait

- Retour du colis sans dette : PR 94 (voir `docs/historique/PR-094.md`). Reste : relecture
  des conditions 2026-11.12 par l'avocat, adresse définitive du bureau (`OFFICE_ADDRESS` et
  conditions), modèles WhatsApp des messages du bureau.

---

## 1. App livreur, lot C : fidèle aux maquettes

Écrans et maquettes (clair = suffixe `-Clair`) :

| Écran                | Maquette            | Code                                                    | Capture actuelle                |
| -------------------- | ------------------- | ------------------------------------------------------- | ------------------------------- |
| Recharger le solde   | `Livreur-Recharger` | `apps/rider/lib/features/activity/` (recherche `topUp`) | `13_recharger`                  |
| Retirer              | `Livreur-Retirer`   | `activity/withdraw_screen.dart`                         | `13_retirer`                    |
| Reverser les espèces | `Livreur-Reverser`  | `activity/deposit_screen.dart`                          | `13_reverser`                   |
| Pièces               | `Livreur-Pieces`    | `onboarding/documents_screen.dart`                      | `04_pieces`, `16_pieces_profil` |
| Profil               | `Livreur-Profil`    | `account/account_screen.dart`                           | `16_profil`                     |

- Même méthode que les lots A et B (PR 89, 90) ; l'écran Retour n'a plus d'étape « frais » et
  l'écran « Déposer au bureau Tara » (PR 94) n'a pas de maquette : composants `tara_ui` existants (`SwipeButton`,
  `ChoiceChips`, `BoxedField`, `PhotoCard`…), pages poussées avec `scopedPage(...)`.
- Garder : la barre d'onglets en pilule et la vraie carte (décisions du porteur).
- Ne change aucune règle d'argent : seulement l'apparence et les textes. Si une maquette montre
  une règle différente (montant minimum, frais), demander avant.
- Vérifier aussi `Livreur-Fermer-Compte`, `Livreur-Support`, `Livreur-Gain`, `Livreur-Noter` s'il
  reste du temps, et noter les écarts dans `INVENTAIRE.md`.

---

## 2. App expéditeur : écrans pas encore comparés

Envoi en masse (coller une liste, contacts, liste d'envoi, vérifier et envoyer, colis en
attente), portefeuille, demander l'adresse, supprimer le compte, service client. Les écarts du
premier passage sont dans `docs/design/maquettes/INVENTAIRE.md`. Faire un lot par groupe
(envoi en masse d'abord), même méthode que ci-dessus.

---

## 3. Repères de Douala (carrefours, ronds-points, marchés…)

- Déjà fait (PR 83) : table des repères, `GET /map/landmarks`, ajout et retrait par l'équipe dans
  le back-office (onglet « Repères »), repères en gras sur les cartes, « Près de … » sous
  l'épingle.
- Reste : **pré-remplir** la table avec les lieux connus de Douala tirés d'OpenStreetMap
  (carrefours nommés, ronds-points, marchés, églises, écoles, stations-service, pharmacies).
  Depuis le cloud, Overpass et Geofabrik coupaient la connexion : **le faire depuis l'ordinateur
  du porteur**.
- Méthode : requête Overpass sur la zone de service (tout Douala), garder les lieux nommés, écrire
  un script d'import idempotent (par identifiant OSM) qui alimente la même table ; attribution
  « © contributeurs OpenStreetMap » ; jamais de données personnelles.
- Option du porteur si OSM est trop pauvre : liste « à vérifier » confirmée par les livreurs.

---

## 4. Décisions et réglages en attente (pas de code sans réponse)

- **Code de livraison en QR** : la maquette Scanner le suggère ; recommandé **non** (le code
  n'est jamais affiché car le lien de suivi peut circuler ; il reste envoyé par SMS).
- **Sebpay** (paiements, en cours) : nouvelles clés `pk_live`/`sk_live` à générer par le porteur
  (les anciennes ont été exposées), à saisir sur le serveur avec `tara config` ; déclarer l'IP du
  serveur et l'adresse de notification ; premier essai réel de 100 F (`docs/DEPLOIEMENT.md`).
- **WhatsApp (Meta)** : le porteur doit d'abord faire vérifier son compte Meta (SMS non reçu) ;
  ensuite brancher le webhook en suivant `docs/DEPLOIEMENT.md`.
- **GitHub Actions** : crédit épuisé, la CI ne démarre plus ; à recharger par le porteur. En
  attendant, lancer les tests en local avant chaque fusion.
- **Lecture automatique du SMS** (tâche ouverte) : vérifier sur un vrai téléphone, après
  `tara update` et `tara apk`, que le code se remplit seul ; sinon relever le message exact.

---

## 5. Plus tard (après le pilote, sur demande du porteur)

- Espace boutique sur ordinateur (envoi en masse depuis un navigateur).
- Carte en 3D dans les apps (MapLibre incliné, immeubles en relief).
- Bouton « Prime de pluie » pour le dispatch, avec plafonds.
- V2 : agences de livraison partenaires (Tara fournit la technologie).
