# Liste des tâches suivies depuis le début (au 27/11/2026)

Tâches telles que suivies pendant le développement (✅ fait, 🔄 en cours, ⏳ à faire). Les
explications complètes sont dans les PR (`docs/HISTORIQUE.md`) ; la suite détaillée dans
`docs/LOTS_A_VENIR.md`.

## Phase 1 · Serveur cœur

✅ Socle commun de l'API · ✅ Authentification par code SMS (A1) · ✅ Profil, mode marchand,
consentements, parrainage (A2, A4, C6) · ✅ Livreurs et KYC (A3, A5) · ✅ Adresses, zones,
repères, lien de localisation (B1-B6) · ✅ Tarification et promotions (C2, C6, C7) · ✅ Commandes
et machine à états (C1, C3, C4, C5) · ✅ OpenAPI, tests e2e, seed, docs

## Sécurité (avant phase 2)

✅ Codes SMS : verrouillage et anti-pompage · ✅ Double authentification TOTP pour l'équipe ·
✅ Durcissement HTTP et journaux · ✅ Données personnelles : conservation, effacement, export ·
✅ Base de données à moindre privilège · ✅ CI sécurité

## Phase 2 · Attribution et temps réel

✅ Infra Redis, file de tâches · ✅ Présence et positions des livreurs · ✅ Attribution
automatique (D1-D4) · ✅ Actions du livreur côté serveur (E2-E9) · ✅ Temps réel Socket.IO (F1) ·
✅ Notifications push, WhatsApp, SMS avec repli (F3) · ✅ Simulateur 50 livreurs · ✅ Revue de
sécurité · ✅ Fournisseur SMS réel avec secours et alertes de coût

## Phase 3 · Argent

✅ Grand livre · ✅ Prestataire de paiement (factice, CamPay, webhooks) · ✅ Paiement des
commandes et encaissement à la livraison · ✅ Portefeuilles, reversements, dépôts, avoirs ·
✅ Rapprochement quotidien, export comptable, relevés PDF · ✅ Simulateur 500 commandes ·
✅ Revue de sécurité

## Phase 4 · App livreur

✅ Outillage Flutter, CI · ✅ Socle visuel (tokens, composants, animations, catalogue) ·
✅ Services de l'app · ✅ Logo vectoriel (icônes, démarrage) · ✅ Contact d'urgence, annulation
SOS, refus de payer · ✅ Temps en ligne, série des gains, pièces exigées · ✅ File hors connexion ·
✅ Temps réel, notifications, position · ✅ Écrans 01-05 (connexion, code, profil, pièces,
accueil hors ligne) · ✅ Zones interdites, style de carte · ✅ Écrans 06-07 (en ligne,
proposition 30 s) · ✅ Itinéraire (OSRM + repli) · ✅ Course en cours (persistance, reprise) ·
✅ 08 Enlèvement · ✅ Trajet enregistré (90 j, équipe seulement) · ✅ Positions gardées hors
réseau, position falsifiée signalée · ✅ 09 Livraison · ✅ 12 Encaissement · ✅ 14 Alerte SOS
(équipe + police) · ✅ 10 Échec et 11 Retour · ✅ 13 Activité · ✅ Espèces non versées (24 h,
suspension + garant, plafond progressif) · ✅ 15 Hors connexion · ✅ Solde prépayé du livreur ·
✅ Profil et réglages · ✅ 04 pièce refusée · ✅ Glisser pour accepter, « Colis récupéré »,
« Confirmer la livraison » · ✅ Sons, vibrations, transitions · ✅ Gain qui s'envole,
célébration à 5 et 10 courses

## Phase 5 · App expéditeur et page de suivi

✅ Paquets partagés `tara_ui`, `tara_core` · ✅ Projet, CI, connexion · ✅ Nouvelle livraison
(5 étapes : colis, quand, récapitulatif…) · ✅ Pied de page en verre · ✅ Notif quand le
destinataire place son point (B3) · ✅ Ventes du jour en direct, son de pièce au reversement ·
✅ Suivi de commande (F1) · ✅ Livraison impossible : nouvelle tentative ou retour (E6) ·
✅ Notation réciproque (F4) · ✅ Page web de suivi (F2) · ✅ Dette et suppression de compte,
plafond de dette marchand 3 000 F · ✅ Frais de tentative et de retour figés à la commande ·
✅ Retour contre paiement, tentative payée d'avance · ✅ Conditions versionnées dans chaque app ·
✅ Revue de sécurité · ✅ Page web du lien de localisation (B3) · ✅ Portefeuille et relevés
(G1-G3, G7) · ✅ Photo de façade et note vocale (B2) · ✅ Adresses favorites, repères (A2, B4) ·
✅ « Demander l'adresse » depuis l'accueil

## Phase 6 · Back-office

✅ Socle Next.js, connexion équipe · ✅ H1 carte en direct et alertes · ✅ H2 commandes ·
✅ H3 livreurs (validation sur pièces, suspension, fiabilité) · ✅ H4 tarifs, marchands,
promotions, zones (dessin sur carte) · ✅ H5 finance · ✅ H6 support (tickets, litiges avec
preuves) · ✅ H7 indicateurs · ✅ H8 équipe et audit · ✅ Carte : livreurs sur les rues,
itinéraire · ✅ Modèle de prix validé (70 %, grille, tarif pro, primes) · ✅ Écarter un livreur
avec SOS ouvert · ✅ Gros objets · ✅ Photo du colis analysée par IA · ✅ Frais Mobile Money
payés par le client, retraits gratuits au-dessus d'un seuil · ✅ « Signaler un problème » dans
les apps · ✅ CI allégée

## Phase 7 · Pilote

🔄 Préparation du pilote (données fictives) · ✅ Test de charge (5 000 commandes/jour, 500
livreurs, 95 % < 500 ms) · ✅ Revue de sécurité · ✅ Conservation 90 jours · ✅ Tout Douala ·
✅ Déploiement Hostinger, APK pour téléphones · ✅ Frais de retrait partagés, suppression
protégée · ✅ Retirer, supprimer mon compte, télécharger mes données (2 apps) · ✅ Textes
légaux · ✅ Retraits gelés si suspendu · ✅ Attribution selon la valeur déclarée · ✅ Alertes
course trop longue, livreur qui s'éloigne · ✅ Colis abîmé (24 h, ticket) · ✅ Volet juridique
(responsabilité, indemnisation, contrat livreur) · ✅ Conditions sans SMS, sessions 90 jours ·
✅ Code par WhatsApp, empreinte Android dans le SMS · ✅ Code secret 4 chiffres, empreinte ·
✅ Lecture auto du SMS, solde masqué · 🔄 Lecture automatique du SMS qui tourne en rond (à
vérifier sur téléphone) · ✅ `tara update` réparé (migrations) · 🔄 Sebpay (clés live à refaire)

## Envois multiples, boutiques, frais validés

✅ Colis numérotés dans un envoi, récapitulatif d'un lot mixte, suivi d'un lot, livreur guidé ·
✅ Envoi en masse (100 colis, coller une liste, clients qui placent leur point, colis en
attente) · ✅ Solde Tara des boutiques (recharge, ordre de paiement, réserve du soir) ·
✅ Garantie 1 % au-delà de 25 000 F · ✅ Annulation 300 F (200/100) · ✅ Attente 10 min
gratuites puis 100 F / 5 min, plafond 30 min (400 F) · ✅ Expéditeur absent 30 min (700 F, 480
livreur) · ✅ Tournée (proposition, enlèvement groupé, arrêts) · ✅ Minimum de reversement
Sebpay 30 000 F, dit avant la recharge

## Refonte visuelle

✅ Maquettes (portefeuille, tableau de bord, présentation, 72 pages, 3D, effets liquides, deux
thèmes) · ✅ Lot 0 socle `tara_ui` · ✅ Lot 1 app expéditeur · ✅ Lot 2 app livreur · ✅ Cloche
et « Mon activité » · ✅ Nouvelle livraison (6 écrans) · ✅ Paiement en attente, suivi (4
écrans), profil · ✅ Pages web : vraie carte, code de livraison et renvoi · ✅ Livreur lot A
(scan QR, en route) · ✅ Livreur lot B (échec, retour) · 🔄 Pages web et back-office : pas de
refonte complète (décision du porteur), seulement la vraie carte

## À faire (détail dans `docs/LOTS_A_VENIR.md`)

⏳ Retour du colis sans dette · ⏳ Livreur lot C · ⏳ Écrans expéditeur restants · ⏳ Repères
OSM · ⏳ Espace boutique sur ordinateur · ⏳ Carte 3D · ⏳ Prime de pluie · ⏳ V2 agences
partenaires
