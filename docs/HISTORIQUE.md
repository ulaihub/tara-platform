# Historique du projet

Liste des tâches suivies : [historique/TACHES.md](historique/TACHES.md). Chaque demande de fusion (PR) fusionnée, avec son texte complet dans `docs/historique/PR-NNN.md`
(ce qui a été fait, pourquoi, vérifications, points restés ouverts). Les règles et décisions
qui en découlent sont résumées dans [DECISIONS.md](DECISIONS.md) ; les lots à venir dans
[LOTS_A_VENIR.md](LOTS_A_VENIR.md).

**À chaque fusion :** ajouter la ligne de la PR ici et son texte dans `docs/historique/`
(titre, date, branche, description sans les lignes de signature).

## Fondations et phases 0 à 5 (serveur, argent, apps, page de suivi)

| PR                         | Fusion     | Sujet                                                                                |
| -------------------------- | ---------- | ------------------------------------------------------------------------------------ |
| [1](historique/PR-001.md)  | 2026-11-03 | Phase 0 — fondations du monorepo et schéma de données                                |
| [2](historique/PR-002.md)  | 2026-11-03 | Phase 1 — back-end cœur (A1–A5, B1–B6, C1–C7)                                        |
| [3](historique/PR-003.md)  | 2026-11-03 | Sécurité — passe de durcissement avant la phase 2                                    |
| [4](historique/PR-004.md)  | 2026-11-03 | Phase 2 : attribution des courses et temps réel (D1–D4, F1, F3)                      |
| [5](historique/PR-005.md)  | 2026-11-03 | Phase 3 : argent — paiements, encaissements, portefeuilles, reversements (G1–G8, E5) |
| [6](historique/PR-006.md)  | 2026-11-06 | Phase 4 : app livreur (Flutter)                                                      |
| [7](historique/PR-007.md)  | 2026-11-03 | Bump actions/checkout from 5 to 7                                                    |
| [8](historique/PR-008.md)  | 2026-11-03 | Bump actions/setup-node from 5 to 7                                                  |
| [9](historique/PR-009.md)  | 2026-11-03 | Bump pnpm/action-setup from 4 to 5                                                   |
| [10](historique/PR-010.md) | 2026-11-03 | CI : recherche de secrets limitée à la branche testée                                |
| [11](historique/PR-011.md) | 2026-11-06 | Phase 5 : app expéditeur et page de suivi                                            |

## Back-office, pilote, mise en ligne, sécurité des colis

| PR                         | Fusion     | Sujet                                                                                    |
| -------------------------- | ---------- | ---------------------------------------------------------------------------------------- |
| [12](historique/PR-012.md) | 2026-11-26 | Bump actions/setup-java from 5 to 6                                                      |
| [13](historique/PR-013.md) | 2026-11-26 | Bump actions/upload-artifact from 4 to 7                                                 |
| [14](historique/PR-014.md) | 2026-11-26 | Bump pnpm/action-setup from 5 to 6                                                       |
| [21](historique/PR-021.md) | 2026-11-13 | Phase 6 : back-office d'exploitation (H1 à H8) et modèle de prix validé                  |
| [22](historique/PR-022.md) | 2026-11-13 | CI allégée : un workflow par partie, APK seulement à la fusion                           |
| [25](historique/PR-025.md) | 2026-11-13 | Phase 7 : test de charge, revue de sécurité, stockage S3, dossier APDP                   |
| [26](historique/PR-026.md) | 2026-11-13 | Pilote : conservation 90 jours, tout Douala, mise en ligne sur VPS                       |
| [27](historique/PR-027.md) | 2026-11-13 | Mise en ligne : serveur KVM 1 (4 Go) pris en charge                                      |
| [28](historique/PR-028.md) | 2026-11-13 | Téléphones de test : codes lisibles sur le serveur, sans crédit SMS                      |
| [29](historique/PR-029.md) | 2026-11-13 | Apps plus compactes, tara paiements, clé de test stable                                  |
| [30](historique/PR-030.md) | 2026-11-13 | Adresses : 134 quartiers de Douala et quartier affiché sous l'épingle                    |
| [31](historique/PR-031.md) | 2026-11-14 | Apps iPhone prêtes pour TestFlight (Codemagic)                                           |
| [32](historique/PR-032.md) | 2026-11-15 | Back-office sur téléphone : menu en tiroir, tableaux et carte adaptés                    |
| [33](historique/PR-033.md) | 2026-11-15 | Notifications de l'app expéditeur (Android et iPhone)                                    |
| [34](historique/PR-034.md) | 2026-11-15 | Temps réel : reconnexion après un jeton expiré pendant une coupure                       |
| [35](historique/PR-035.md) | 2026-11-15 | Retraits et fermeture de compte : frais partagés, solde protégé, données téléchargeables |
| [36](historique/PR-036.md) | 2026-11-15 | Sécurité des colis (vol, dommage) et volet juridique complet                             |
| [37](historique/PR-037.md) | 2026-11-15 | APK : publication d’un seul coup, après vérification de l’archive                        |

## Connexion, envoi en masse, tournée, solde des boutiques, frais validés

| PR                         | Fusion     | Sujet                                                                                  |
| -------------------------- | ---------- | -------------------------------------------------------------------------------------- |
| [38](historique/PR-038.md) | 2026-11-16 | Connexion : conditions sans code SMS, session de 90 jours                              |
| [39](historique/PR-039.md) | 2026-11-16 | Connexion : code secret, empreinte, solde masqué, code par WhatsApp et lecture du SMS  |
| [40](historique/PR-040.md) | 2026-11-16 | Commandes « créées » : paiement attendu visible, départ avancé par le dispatch         |
| [41](historique/PR-041.md) | 2026-11-16 | Connexion : le refus du code reste affiché, lecture du SMS limitée aux SMS de Tara     |
| [42](historique/PR-042.md) | 2026-11-17 | Mise à jour du serveur : migrations appliquées, rôles conservés                        |
| [43](historique/PR-043.md) | 2026-11-17 | Envoi de plusieurs colis : colis numérotés, frais justes, livreur guidé à l'enlèvement |
| [44](historique/PR-044.md) | 2026-11-17 | Envoi en masse : 100 colis, clients qui placent leur point, portefeuille boutique      |
| [45](historique/PR-045.md) | 2026-11-18 | Boutiques : solde Tara rechargeable, payé avant les ventes, réserve du soir            |
| [46](historique/PR-046.md) | 2026-11-18 | Garantie, annulation et attente payantes (idées A, C, D)                               |
| [47](historique/PR-047.md) | 2026-11-18 | Attente : 30 minutes comptées au plus (400 F)                                          |
| [48](historique/PR-048.md) | 2026-11-19 | Expéditeur absent : départ du livreur après 30 minutes, attente payée                  |
| [49](historique/PR-049.md) | 2026-11-19 | Tournée : plusieurs colis d'un envoi, un seul livreur (2c)                             |
| [50](historique/PR-050.md) | 2026-11-19 | Reversements : rien ne part sous le minimum du prestataire (Sebpay 30 000 F)           |

## Refonte visuelle (apps, web, back-office) et carte réelle

| PR                         | Fusion     | Sujet                                                                                                                           |
| -------------------------- | ---------- | ------------------------------------------------------------------------------------------------------------------------------- |
| [51](historique/PR-051.md) | 2026-11-20 | Refonte · socle visuel : verre réglable, rouge vif, vrais logos, liquide vif                                                    |
| [52](historique/PR-052.md) | 2026-11-20 | Refonte · éléments en relief et accueil de l’app expéditeur                                                                     |
| [53](historique/PR-053.md) | 2026-11-20 | Refonte · portefeuille et accueil fidèles aux maquettes                                                                         |
| [54](historique/PR-054.md) | 2026-11-20 | Refonte · onglet Commandes et barre du bas fidèles aux maquettes                                                                |
| [55](historique/PR-055.md) | 2026-11-20 | Recharge : dire avant de payer que le solde se retire à partir du minimum                                                       |
| [56](historique/PR-056.md) | 2026-11-20 | Refonte · Profil fidèle à la maquette                                                                                           |
| [57](historique/PR-057.md) | 2026-11-20 | Refonte livreur · accueils fidèles à la maquette                                                                                |
| [58](historique/PR-058.md) | 2026-11-20 | Refonte livreur · onglet Gains fidèle à la maquette                                                                             |
| [59](historique/PR-059.md) | 2026-11-20 | Refonte livreur · Profil fidèle à la maquette                                                                                   |
| [60](historique/PR-060.md) | 2026-11-20 | Refonte livreur · proposition de course fidèle à la maquette                                                                    |
| [61](historique/PR-061.md) | 2026-11-20 | Refonte livreur · enlèvement, en route et livraison fidèles aux maquettes                                                       |
| [62](historique/PR-062.md) | 2026-11-20 | Refonte livreur · encaissement, échec et course livrée                                                                          |
| [63](historique/PR-063.md) | 2026-11-20 | Refonte livreur · SOS, recharger, reverser et retirer                                                                           |
| [64](historique/PR-064.md) | 2026-11-20 | Refonte livreur · derniers écrans                                                                                               |
| [65](historique/PR-065.md) | 2026-11-20 | Refonte web · page de suivi du destinataire (Web-Suivi)                                                                         |
| [66](historique/PR-066.md) | 2026-11-20 | Refonte web · page « Mon point » (Web-Point)                                                                                    |
| [67](historique/PR-067.md) | 2026-11-20 | Refonte web · vérifier un reçu (Web-Verifier-Recu)                                                                              |
| [68](historique/PR-068.md) | 2026-11-20 | Refonte back-office · cadre, connexion et accueil                                                                               |
| [69](historique/PR-069.md) | 2026-11-20 | Refonte back-office · carte en direct, commandes, verre et téléphone                                                            |
| [70](historique/PR-070.md) | 2026-11-20 | Refonte back-office · livreurs, boutiques et tarifs                                                                             |
| [71](historique/PR-071.md) | 2026-11-20 | Refonte back-office · finance, contrôle, support, indicateurs, équipe                                                           |
| [72](historique/PR-072.md) | 2026-11-25 | Sécurité : Next.js à jour et dépendances corrigées                                                                              |
| [73](historique/PR-073.md) | 2026-11-25 | App livreur : barre de menu fine en pilule                                                                                      |
| [74](historique/PR-074.md) | 2026-11-25 | Livreur : carte réelle, carte déplaçable, retour à l’accueil ; suivi expéditeur sur les rues ; validation des remises sans code |
| [75](historique/PR-075.md) | 2026-11-25 | Livreur muet : course retirée après 3 min avant l’enlèvement ; livreur le plus proche par les rues                              |
| [76](historique/PR-076.md) | 2026-11-25 | Livreur trouvé : photo et moto ; messages expéditeur ↔ livreur et support en direct                                             |

## Fidélité aux maquettes, outils et mémoire du projet

| PR                         | Fusion     | Sujet                                                                                     |
| -------------------------- | ---------- | ----------------------------------------------------------------------------------------- |
| [77](historique/PR-077.md) | 2026-11-26 | Présentation expéditeur et livreur refaite d'après les maquettes                          |
| [78](historique/PR-078.md) | 2026-11-26 | Fidélité lot 1 : connexion, code, conditions, bienvenue ; WhatsApp avec repli SMS en 45 s |
| [79](historique/PR-079.md) | 2026-11-26 | Finesse : boutons et champs en pilule, barre d'onglets pilule dans l'app expéditeur       |
| [80](historique/PR-080.md) | 2026-11-26 | Fidélité lot 2 : accueil, commandes et nouvelle livraison                                 |
| [81](historique/PR-081.md) | 2026-11-26 | Cloche des notifications et « Mon activité » de la boutique                               |
| [82](historique/PR-082.md) | 2026-11-26 | Paiement en attente, suivi « livreur trouvé » ; logos Orange Money / MTN lisibles         |
| [83](historique/PR-083.md) | 2026-11-26 | Carte : repères de Douala pour placer le point précisément                                |
| [84](historique/PR-084.md) | 2026-11-26 | Mises à jour des dépendances (API, back-office, apps)                                     |
| [87](historique/PR-087.md) | 2026-11-26 | Lot 3 · Suivi (livré, échec, retour) et profil fidèles aux maquettes                      |
| [88](historique/PR-088.md) | 2026-11-26 | Pages web : vraie carte et code de livraison avec renvoi                                  |
| [89](historique/PR-089.md) | 2026-11-27 | Livreur lot A : scan du code d'enlèvement et écran En route fidèles aux maquettes         |
| [90](historique/PR-090.md) | 2026-11-27 | Livreur lot B : Livraison impossible et Retour du colis fidèles aux maquettes             |
| [91](historique/PR-091.md) | 2026-11-27 | Maquettes de la refonte et outils de comparaison dans le projet                           |
| [92](historique/PR-092.md) | 2026-11-27 | CLAUDE.md : consignes et état du projet, fichiers à tenir à jour                          |
