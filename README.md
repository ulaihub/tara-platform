# tara-platform

Plateforme de livraison urbaine à la demande. Elle met en relation des expéditeurs (particuliers, vendeurs en ligne, entreprises) avec des livreurs indépendants vérifiés. Elle gère la tarification, l'attribution des courses, le suivi, l'encaissement à la livraison et le reversement aux marchands.

Lancement prévu à Douala (Cameroun) : réseau 2G/3G instable, téléphones Android d'entrée de gamme, paiement Mobile Money (MTN MoMo, Orange Money), application en français et en anglais.

## Documentation

- [Cahier des charges technique](docs/CAHIER_DES_CHARGES.md) : exigences A1 à H10, exigences non fonctionnelles, critères de recette.
- [Architecture](docs/ARCHITECTURE.md) : composants, versions, décisions de conception, développement local.
- [Plan des phases](docs/PLAN_DES_PHASES.md) : phases 0 à 7, exigences couvertes, estimations.

## Démarrage rapide

Prérequis : Node 22, pnpm 10, Docker.

```bash
pnpm install
pnpm infra:up
cp apps/api/.env.example apps/api/.env
pnpm db:migrate
pnpm dev
```

L'API répond alors sur <http://localhost:3000/health>.

## État d'avancement

| Phase                              | État     |
| ---------------------------------- | -------- |
| 0. Fondations et schéma de données | En cours |
| 1. Back-end cœur                   | À faire  |
| 2. Attribution et temps réel       | À faire  |
| 3. Argent                          | À faire  |
| 4. App livreur                     | À faire  |
| 5. App expéditeur et page de suivi | À faire  |
| 6. Back-office                     | À faire  |
| 7. Préparation du pilote           | À faire  |

## Licence

Logiciel propriétaire de Ulai Hub, tous droits réservés. Voir [LICENSE](LICENSE).
