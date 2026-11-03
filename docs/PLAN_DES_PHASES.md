# Plan des phases du MVP

Le MVP représente environ **85 jours-développeur**. À deux développeurs, les apps (phases 4 à 6)
avancent en parallèle du back-end (phases 2 et 3) dès que les contrats d'API de la phase 1 sont
publiés. Cela donne environ 11 semaines ouvrées, marge comprise, ce qui tient dans les 4 mois prévus
avant le pilote.

Chaque phase se termine par une démonstration et la validation du porteur de projet (« go »)
avant de démarrer la suivante.

**Avancement** : phases 0 à 3 livrées (back-end). Phase 3 : le simulateur financier traite 500
commandes (espèces, Mobile Money, solde, contre-remboursement, annulations, retours, incidents
Mobile Money) et le rapprochement sort à 0 FCFA d'écart, sans aucun reversement en double. Phase 2 : le simulateur attribue 100 % des
60 courses de son scénario en moins de 2 minutes (médiane 16 s, 95e centile 73 s) ; il se relance
avec `pnpm --filter @tara/api simulate`. Les maquettes des écrans sont attendues avant la phase 4.

| Phase | Contenu                                                                                                                                                                                                                                     | Exigences                                         | Estimation (jours-dev) | Condition de sortie                                                                                |
| ----- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------- | ---------------------- | -------------------------------------------------------------------------------------------------- |
| 0     | Fondations : monorepo, infrastructure locale, intégration continue, schéma de données, protections en base                                                                                                                                  | Socle                                             | 3                      | Schéma validé par le porteur de projet                                                             |
| 1     | Back-end cœur : connexion par code SMS, comptes et rôles, inscription et validation KYC des livreurs, adresses et repères, lien de localisation, tarification paramétrable, création de commande et machine à états                         | A1–A5, B1–B6, C1–C7                               | 12                     | Une commande se crée, se tarifie et change de statut via l'API, tests verts                        |
| 2     | Attribution et temps réel : positions Redis GEO, proposition des courses, réattribution, Socket.IO, notifications push/SMS/WhatsApp avec repli, simulateur de 50 livreurs                                                                   | D1–D4, F1 (serveur), F3                           | 8                      | Le simulateur attribue 95 % des courses en moins de 2 min                                          |
| 3     | Argent : grand livre, `PaymentProvider` (agrégateur choisi + implémentation factice), encaissement à la livraison, portefeuilles marchand et livreur, plafond d'espèces, reversements, rapprochement quotidien, relevés PDF, remboursements | G1–G8, E5 (serveur)                               | 12                     | 500 commandes simulées : rapprochement à 0 FCFA d'écart, aucun reversement en double               |
| 4     | App livreur Flutter, hors ligne d'abord                                                                                                                                                                                                     | A3, E1–E9                                         | 15                     | 100 courses sans plantage sur 3 Android réels de 2 Go de RAM ; 20 actions hors ligne synchronisées |
| 5     | App expéditeur Flutter et page de suivi web                                                                                                                                                                                                 | A1, A2, A4, B1–B5, C1–C6, F1, F2, F4, G1          | 15                     | Parcours complet d'un vendeur, du lien de localisation au relevé                                   |
| 6     | Back-office Next.js : carte en direct, commandes, validation des livreurs, marchands et tarifs, finance, support, indicateurs, rôles et audit                                                                                               | H1–H8                                             | 12                     | Une journée de pilote simulée se pilote entièrement depuis le back-office                          |
| 7     | Préparation du pilote : test de charge (5 000 commandes/jour, 500 livreurs), revue de sécurité, conformité APDP, déploiement en production, Play Store en test fermé (30 marchands, 40 livreurs)                                            | Exigences non fonctionnelles, critères de recette | 8                      | Critères de recette du cahier des charges tous cochés                                              |

## Ordonnancement à deux développeurs

- **Développeur 1 (back-end)** : phases 0 → 1 → 2 → 3 → 7.
- **Développeur 2 (Flutter puis web)** : rejoint en fin de phase 1, enchaîne 4 → 5 → 6 en s'appuyant
  sur le client d'API généré depuis l'OpenAPI.

## Hors MVP (V2), à garder possible sans refonte

A6 comptes marchands multi-utilisateurs · B7 recherche de lieux connus · C8 import CSV/Excel ·
C9 commande par WhatsApp · D5 regroupement automatique des tournées · F5 messagerie in-app ·
G9 factures TVA · H9 portail marchand web, API publique et plugins · H10 points relais.
