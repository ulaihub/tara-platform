# Décisions du porteur du projet

Règles validées par le porteur, à respecter dans tout nouveau lot. **Ne jamais en changer une
sans son accord** (surtout l'argent). Les montants sont réglables sur le serveur
(`apps/api/src/config/env.ts`, valeurs par défaut ci-dessous) ; les textes qui engagent sont
dans `docs/juridique/` (conditions expéditeurs, livreurs, destinataires). Le détail de chaque
décision est dans la PR citée (`docs/historique/PR-NNN.md`).

**À chaque nouvelle décision :** l'ajouter ici, dans la bonne section, avec la date et la PR.

## Contexte

- Livraison à la demande à Douala (Cameroun), tout Douala comme zone de service (PR 26) ;
  réseau 2G/3G instable, Android d'entrée de gamme, Mobile Money (MTN MoMo, Orange Money),
  français et anglais.
- Deux apps Flutter (expéditeur `apps/client`, livreur `apps/rider`), une page web pour le
  destinataire (`apps/tracking`), un back-office (`apps/backoffice`), une API (`apps/api`).
- Hébergement : VPS Hostinger (Paris), commandes `tara install / update / apk / config`
  (`docs/DEPLOIEMENT.md`). Paiements : Sebpay. SMS : Twilio (repli), WhatsApp Meta en premier.
  Notifications : Firebase. Analyse de la photo du colis par IA (PR 21, facultative).

## Prix et partage (PR 21)

- Grille : 1 000 F jusqu'à 5 km, +100 F/km jusqu'à 10 km, +50 F/km au-delà ; **70 % au
  livreur**, 30 % à Tara.
- Tarif pro par volume mensuel, pris sur la part de Tara ; prime d'approche et primes de renfort
  payées par Tara.
- Gros objets : catégorie « Gros objet », attribution par véhicule, grille tricycle + manutention.

## Frais validés (PR 46, 47, 48, 50, 55)

- **Garantie** : 1 % de la valeur déclarée au-delà de 25 000 F.
- **Annulation** quand le livreur est déjà en route : 300 F (200 F livreur, 100 F Tara).
- **Attente à l'enlèvement** : 10 min gratuites, puis 100 F par tranche de 5 min (70 % livreur),
  30 min comptées au plus (400 F).
- **Expéditeur absent** : le livreur peut partir après 30 min ; 700 F facturés, dont 480 F au
  livreur.
- **Échec de livraison** : frais de nouvelle tentative et de retour annoncés et figés à la
  commande ; au moins 2 appels au destinataire espacés de 5 min avant de déclarer l'échec ;
  l'expéditeur a 15 min pour choisir nouvelle tentative ou retour.
- **Retour sans dette** (27/11, PR 94) : le retour se paie **avant** de partir (solde Tara,
  puis Mobile Money dans l'app) ; **rien n'est encaissé à la porte**. Sans paiement dans les
  15 min : colis déposé au **bureau Tara** (provisoire : Bonabéri, Douala, lundi-vendredi
  8 h - 17 h), gardé **30 jours sans frais**, rendu contre paiement (app ou espèces, code de
  retrait). Rappels à J+1, J+7, J+25 et à la fin. Après 30 jours : **don à une association**,
  ou destruction s'il est périssable, dangereux ou sans valeur ; **jamais de vente** ; frais
  abandonnés. Un retour ne crée jamais de dette. Point juridique à faire valider par l'avocat.
- Frais Mobile Money payés par le client ; retraits gratuits au-dessus d'un seuil (50 000 F),
  sinon frais partagés.
- Reversements : rien ne part sous le minimum du prestataire (Sebpay 30 000 F) ; on le dit avant
  la recharge.

## Soldes et dettes

- Boutiques : solde Tara rechargeable, utilisé avant les ventes, réserve du soir (PR 45).
- Plafond de dette d'une boutique : 3 000 F ; un particulier ne peut pas commander en dette
  (PR 11, 35). Un retour de colis n'entre plus dans la dette (PR 94).
- Livreurs (PR 6) : solde prépayé (remplace le dépôt des espèces) ; espèces encaissées à reverser sous
  24 h, suspension après 72 h, garant, plafond progressif ; retraits gelés si suspendu.
- Suppression de compte protégée tant qu'un solde ou une dette existe ; données téléchargeables.

## Confiance, sécurité, litiges

- Attribution selon la valeur déclarée : nouveau livreur (moins de 20 courses) limité à
  25 000 F ; à partir de 100 000 F, 50 courses et note 4,5 exigées.
- Livreur muet : course retirée après 3 min avant l'enlèvement (PR 75).
- Colis abîmé : refus motivé, ticket automatique, délai de 24 h, destinataire averti (PR 36).
- Conservation 90 jours des photos, du support clos et des pièces des livreurs partis (PR 26).
- **Code d'enlèvement** : montré à l'expéditeur (chiffres + QR, scanné par le livreur, PR 89).
- **Code de livraison** : **jamais affiché**, ni dans l'app ni sur la page web (le lien peut
  circuler) ; envoyé par SMS au destinataire, renvoi possible 3 fois, 2 min d'écart (PR 88).
- Connexion : code par WhatsApp avec repli SMS en 45 s, code secret à 4 chiffres, empreinte,
  session de 90 jours, conditions acceptées sans code SMS (PR 38, 39, 41, 78).

## Fonctionnalités

- Envoi de plusieurs colis (numérotés) et envoi en masse jusqu'à 100 colis, clients qui placent
  leur point eux-mêmes (PR 43, 44) ; tournée : plusieurs colis, un livreur (PR 49).
- 134 quartiers de Douala ; repères gérés par l'équipe (PR 30, 83).
- Messages expéditeur ↔ livreur et support en direct ; photo du livreur et de sa moto (PR 76).

## Apparence (refonte)

- Maquettes de référence : `docs/design/maquettes` ; écarts dans `INVENTAIRE.md`.
- Gardés malgré les maquettes : **vraie carte** (rues réelles) au lieu de la carte dessinée,
  **barre d'onglets en pilule** (PR 73, 79).
- Back-office et pages web : pas de nouvelle refonte ; seulement la vraie carte sur les pages
  web (décision du 26/11, PR 88).

## Façon de travailler

- Voir `CLAUDE.md` : une branche par lot, fusion seulement sur « ouvre et fusionne », captures
  et tests avant, données fictives, secrets jamais dans le dépôt, points juridiques à l'avocat.
