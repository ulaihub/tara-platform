# Test de charge

Critère de recette du cahier des charges : **5 000 commandes par jour et 500 livreurs connectés, 95 % des appels en moins de 500 ms**.

## Scénario : une heure de pointe

Une journée de 5 000 commandes ne se répartit pas également : le test rejoue une **heure de pointe à 1 000 commandes**, soit 20 % de la journée en une heure (2,4 fois la moyenne d'une journée de 12 heures).

| Acteur                | Ce qu'il fait pendant le test                                                                                                                                                                                                                                                                                                                                             |
| --------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 500 livreurs          | Connexion temps réel, passage en ligne, une position toutes les 10 s. Propositions : 70 % acceptées, 15 % refusées, 15 % laissées passer, réponse en 3 à 12 s. Course complète : détail, itinéraire, trajet vers la boutique (3 à 8 min), photo et code d'enlèvement, départ, trajet (5 à 15 min), encaissement en espèces s'il y en a, photo et code de livraison, gains |
| 150 boutiques         | Devis puis commande (40 % avec encaissement à la livraison), suivi en temps réel de leurs commandes, écran de suivi ouvert toutes les 45 à 90 s, liste des commandes toutes les 2 à 5 min                                                                                                                                                                                 |
| Destinataires         | Page de suivi publique, depuis des adresses IP différentes comme sur le réseau mobile                                                                                                                                                                                                                                                                                     |
| 5 membres de l'équipe | Carte en direct toutes les 10 s, liste des commandes toutes les 30 s                                                                                                                                                                                                                                                                                                      |

Photos de preuve de 120 Ko (taille des photos réduites par l'app). Le code de livraison part par SMS au destinataire ; avec le fournisseur factice, le simulateur le lit dans le journal de l'API, comme un destinataire lirait son SMS.

## Résultats du 13 novembre 2026

API construite (`node dist/main.js`), une seule instance, tâches de fond actives, OSRM local pour les distances et les itinéraires, limitation de débit active (Redis). Simulateur, API, PostgreSQL, Redis et OSRM sur la même machine de 4 cœurs.

**Heure de pointe, 25 minutes (dont 5 de montée en charge)** : réussi.

| Mesure                                    | Résultat                                                                                             |
| ----------------------------------------- | ---------------------------------------------------------------------------------------------------- |
| Appels en moins de 500 ms (régime établi) | **100 %** (objectif 95 %)                                                                            |
| Temps de réponse : médiane / 95 % / 99 %  | 4 ms / 20 ms / 66 ms                                                                                 |
| Appels traités                            | 85 328, soit 57 par seconde (dont 73 217 positions de livreurs)                                      |
| Erreurs                                   | 0 côté serveur ; aucun appel refusé                                                                  |
| Commandes                                 | 428 passées, 418 acceptées, 324 enlevées, 149 livrées pendant le test (les autres en route à la fin) |
| Commande acceptée par un livreur          | médiane 10 s, 95 % en moins de 49 s                                                                  |
| Processeur de l'API                       | 22 % d'un cœur en médiane, 28 % au plus                                                              |
| Mémoire de l'API                          | 677 Mo au plus                                                                                       |

Routes les plus lentes (95e centile) : création de commande 127 ms (prix, distance, codes, grand livre, attribution), carte en direct du back-office 181 ms, livraison 88 ms.

**Marge : trois fois l'heure de pointe (3 000 commandes par heure), 12 minutes, trajets deux fois plus courts** : réussi.

| Mesure                                    | Résultat                                                                    |
| ----------------------------------------- | --------------------------------------------------------------------------- |
| Appels en moins de 500 ms (régime établi) | **100 %**                                                                   |
| Temps de réponse : médiane / 95 % / 99 %  | 5 ms / 37 ms / 77 ms                                                        |
| Commandes                                 | 593 passées en 12 minutes, 565 acceptées, 0 refusée ; 0 erreur côté serveur |
| Commande acceptée par un livreur          | médiane 10 s, 95 % en moins de 64 s                                         |
| Processeur / mémoire de l'API             | 30 % d'un cœur en médiane, 33 % au plus / 655 Mo au plus                    |

Le serveur garde donc une large marge : une seule instance de l'API suffit pour le pilote et bien au-delà ; une seconde instance sert à la disponibilité (redémarrage sans coupure), pas à la charge.

## Corrigé grâce au test

- **Carte en direct du back-office** : à chaque rafraîchissement, elle recalait sur la rue toutes les positions qui avaient changé et pouvait attendre jusqu'à 1,5 s avec 500 livreurs. Elle attend désormais 200 ms au plus ; les positions pas encore recalées s'affichent à leur position GPS et sont recalées en arrière-plan pour le rafraîchissement suivant (`RoadSnapCache`).

## Limites du test

- Une seule machine : le simulateur prend une partie du processeur. En production, l'API, la base et Redis sont séparés.
- Pas de latence réseau : sur la 3G au Cameroun, il faut ajouter le temps de transport (souvent 100 à 300 ms), qui ne dépend pas du serveur.
- Fournisseurs factices (SMS, notifications, Mobile Money) : leurs temps de réponse ne sont pas mesurés ; les envois passent par des tâches de fond et ne ralentissent pas les appels.
- À refaire sur l'hébergement de production avant le pilote, avec la même commande.

## Relancer le test

Base et Redis **dédiés** (jamais ceux de production) ; les comptes sont recréés à chaque fois.

```bash
# 1. Comptes fictifs (jetons valables 1 h)
DATABASE_URL=postgresql://…/tara_load REDIS_URL=redis://…/3 JWT_ACCESS_TTL_SECONDS=3600 \
  pnpm --filter @tara/api load:setup -- --riders 500 --shops 150 --out comptes.json

# 2. API sur la même base, journal dans un fichier
NODE_ENV=development SMS_PROVIDER=fake PUSH_PROVIDER=fake JOBS_ENABLED=true \
  JWT_ACCESS_TTL_SECONDS=3600 node apps/api/dist/main.js > api.log 2>&1 &

# 3. Heure de pointe
pnpm --filter @tara/api load:run -- --accounts comptes.json --log api.log \
  --minutes 25 --warmup-minutes 5 --orders-per-hour 1000 --api-pid <pid> --report rapport.json
```

Options : `--orders-per-hour`, `--cod-share` (part des commandes avec encaissement), `--trip-scale` (durée des trajets, 1 = réaliste), `--api` (adresse de l'API).
