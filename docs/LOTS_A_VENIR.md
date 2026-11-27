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

## 1. Retour du colis sans dette (priorité 1, touche à l'argent)

### Décisions du porteur

- Accepté : « éviter le plus de litiges possible et avoir le moins de dettes possible » ; prévenir
  le vendeur **dans l'interface à chaque étape**, pas seulement dans les conditions.
- **En attente de sa réponse** (ne pas coder ces valeurs sans elle) :
  1. durée de garde au bureau Tara (proposé : 30 jours, sans frais de garde) ;
  2. ce que Tara fait du colis après ce délai (à faire valider par l'avocat) ;
  3. adresse et horaires du bureau Tara (une valeur provisoire, réglable, est acceptable).

### Fonctionnement actuel (à remplacer)

- À l'échec, l'expéditeur choisit nouvelle tentative ou retour ; sans réponse dans
  `FAILURE_DECISION_TIMEOUT_MINUTES` (15 min, `apps/api/src/config/env.ts`), retour automatique.
- Au retour, les frais (`order.returnFee`, plus la course si elle n'était pas payée) sont pris sur
  le solde Tara (`apps/api/src/finance/order-finance.service.ts`, `returnShortfall()` et le bloc
  « Retour » vers les lignes 640-680) ; une boutique peut devoir jusqu'à `MERCHANT_DEBT_LIMIT`
  (3 000 F).
- Le reste est encaissé **à la porte** par le livreur (espèces ou Mobile Money), sinon erreur
  `RETURN_COLLECTION_REQUIRED` : le livreur est bloqué, seule l'équipe peut passer outre.
- Écrans : livreur `apps/rider/lib/features/course/return_screen.dart` (étape frais) ; expéditeur
  `apps/client/lib/features/tracking/tracking_screen.dart` (`_DecidePage`, texte `returnFeeHint`).

### Nouveau fonctionnement

1. **Échec** : notification à l'expéditeur avec les preuves (photo, appels au destinataire, heure).
2. **Choix « Retour »** : l'app affiche « Frais de retour X F. Votre solde paie Y F. Reste à payer
   maintenant : Z F » et un paiement Mobile Money dans l'app (même mécanisme que la nouvelle
   tentative payée d'avance, texte `topUpFailed` / `topUpCancel`).
   - Payé, ou solde suffisant : le livreur ramène le colis ; remise contre le **code de retour**
     seulement. **Plus aucun encaissement à la porte** (retirer l'étape frais de `return_screen`).
3. **Pas payé avant la fin du compte à rebours** (ou pas de réponse) : le colis part au **bureau
   Tara**. Nouvel état de commande (ex. `HELD_AT_OFFICE` dans `enum OrderStatus`,
   `apps/api/prisma/schema.prisma`) ou étape équivalente ; le livreur voit « Déposer au bureau
   Tara » (adresse, horaires), dépose avec photo ; il est payé pour le retour comme aujourd'hui.
4. **Au bureau** : l'expéditeur voit « Votre colis est gardé au bureau Tara. Payez Z F (dans
   l'app ou au bureau) pour le récupérer. Il vous reste N jours. » ; rappels J+1, J+7, J+25
   (notification + WhatsApp/SMS) ; après paiement, un code de retrait ; l'équipe confirme la
   remise dans le back-office (ou une nouvelle livraison payée d'avance).
5. **Plus de dette créée par un retour** : le solde ne descend plus sous zéro à cause d'un
   retour (le plafond de 3 000 F reste pour les autres cas, inchangé sauf accord).
6. **Page web de suivi** (`apps/tracking`) : afficher « Colis rapporté chez Tara ».
7. **Back-office** : liste des colis gardés au bureau (jours restants, montant dû), bouton
   « Remis à l'expéditeur ».

### À livrer aussi

- Nouvelle version des conditions expéditeurs (`docs/juridique/conditions-expediteurs.md`,
  section 8 « Si la livraison échoue » et 9 « Solde négatif ») et livreurs si leur rôle change ;
  numéro de version augmenté, puis `pnpm --filter @tara/api legal` ; signaler que l'avocat
  doit relire.
- Textes fr/en des deux apps (`tools/arb_ins.py`), notifications
  (`apps/api/src/notifications/push-templates.ts`), migration Prisma, `docs/API.md`, openapi.
- Tests : cas payé d'avance, solde suffisant, impayé → bureau, paiement au bureau, rappels,
  aucune dette créée ; captures des nouveaux écrans (pas de maquette : rester dans le style des
  écrans Retour / Échec existants).

---

## 2. App livreur, lot C : fidèle aux maquettes

Écrans et maquettes (clair = suffixe `-Clair`) :

| Écran                | Maquette            | Code                                                    | Capture actuelle                |
| -------------------- | ------------------- | ------------------------------------------------------- | ------------------------------- |
| Recharger le solde   | `Livreur-Recharger` | `apps/rider/lib/features/activity/` (recherche `topUp`) | `13_recharger`                  |
| Retirer              | `Livreur-Retirer`   | `activity/withdraw_screen.dart`                         | `13_retirer`                    |
| Reverser les espèces | `Livreur-Reverser`  | `activity/deposit_screen.dart`                          | `13_reverser`                   |
| Pièces               | `Livreur-Pieces`    | `onboarding/documents_screen.dart`                      | `04_pieces`, `16_pieces_profil` |
| Profil               | `Livreur-Profil`    | `account/account_screen.dart`                           | `16_profil`                     |

- Même méthode que les lots A et B (PR 89, 90) : composants `tara_ui` existants (`SwipeButton`,
  `ChoiceChips`, `BoxedField`, `PhotoCard`…), pages poussées avec `scopedPage(...)`.
- Garder : la barre d'onglets en pilule et la vraie carte (décisions du porteur).
- Ne change aucune règle d'argent : seulement l'apparence et les textes. Si une maquette montre
  une règle différente (montant minimum, frais), demander avant.
- Vérifier aussi `Livreur-Fermer-Compte`, `Livreur-Support`, `Livreur-Gain`, `Livreur-Noter` s'il
  reste du temps, et noter les écarts dans `INVENTAIRE.md`.

---

## 3. App expéditeur : écrans pas encore comparés

Envoi en masse (coller une liste, contacts, liste d'envoi, vérifier et envoyer, colis en
attente), portefeuille, demander l'adresse, supprimer le compte, service client. Les écarts du
premier passage sont dans `docs/design/maquettes/INVENTAIRE.md`. Faire un lot par groupe
(envoi en masse d'abord), même méthode que ci-dessus.

---

## 4. Repères de Douala (carrefours, ronds-points, marchés…)

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

## 5. Décisions et réglages en attente (pas de code sans réponse)

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

## 6. Plus tard (après le pilote, sur demande du porteur)

- Espace boutique sur ordinateur (envoi en masse depuis un navigateur).
- Carte en 3D dans les apps (MapLibre incliné, immeubles en relief).
- Bouton « Prime de pluie » pour le dispatch, avec plafonds.
- V2 : agences de livraison partenaires (Tara fournit la technologie).
