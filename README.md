# tara-platform

Plateforme de livraison urbaine à la demande. Elle met en relation des expéditeurs (particuliers, vendeurs en ligne, entreprises) avec des livreurs indépendants vérifiés. Elle gère la tarification, l'attribution des courses, le suivi, l'encaissement à la livraison et le reversement aux marchands.

Lancement prévu à Douala (Cameroun) : réseau 2G/3G instable, téléphones Android d'entrée de gamme, paiement Mobile Money (MTN MoMo, Orange Money), application en français et en anglais.

## Documentation

- [Cahier des charges technique](docs/CAHIER_DES_CHARGES.md) : exigences A1 à H10, exigences non fonctionnelles, critères de recette.
- [Architecture](docs/ARCHITECTURE.md) : composants, versions, décisions de conception, développement local.
- [Plan des phases](docs/PLAN_DES_PHASES.md) : phases 0 à 7, exigences couvertes, estimations.
- [Sécurité](docs/SECURITE.md) : menaces, protections, gestion des clés, procédures et réponse aux incidents.
- [Guide de l'API](docs/API.md) : conventions, connexion par SMS, routes par exigence ; contrat complet dans `apps/api/openapi.json`.

## Démarrage rapide

Prérequis : Node 22 (22.12 ou plus), pnpm 10, Docker. Sous Windows : arrêter un éventuel
PostgreSQL déjà installé (il occupe le port 5432) et utiliser `Copy-Item` au lieu de `cp`.

```bash
pnpm install
pnpm infra:up
cp apps/api/.env.example apps/api/.env
pnpm --filter @tara/api generate   # client de la base (à refaire après chaque changement du schéma)
pnpm db:migrate
pnpm --filter @tara/api db:seed   # zone de Douala, tarif de lancement, offre BIENVENUE
pnpm dev
```

L'API répond alors sur <http://localhost:3000/health>.

## État d'avancement

| Phase                              | État                                                  |
| ---------------------------------- | ----------------------------------------------------- |
| 0. Fondations et schéma de données | Terminée                                              |
| 1. Back-end cœur                   | Terminée                                              |
| 2. Attribution et temps réel       | Terminée                                              |
| 3. Argent                          | Terminée (Sebpay en cours), retour sans dette (PR 94) |
| 4. App livreur                     | Terminée, refonte en cours (lot C)                    |
| 5. App expéditeur et page de suivi | Terminée, refonte faite                               |
| 6. Back-office                     | Terminé                                               |
| 7. Préparation du pilote           | En cours                                              |

Le détail de ce qui reste à faire est dans [CLAUDE.md](CLAUDE.md) (« État et suite »).

## Licence

Logiciel propriétaire de Ulai Hub, tous droits réservés. Voir [LICENSE](LICENSE).
