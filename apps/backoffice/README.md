# Back-office Tara (Next.js)

Le poste de pilotage de l'équipe : carte en direct (H1), commandes (H2), livreurs (H3),
marchands et tarifs (H4), finance (H5), support (H6), indicateurs (H7), équipe et audit
(H8). Pensé d'abord pour l'ordinateur, utilisable sur tablette. En français.

## Démarrer

```bash
cp apps/backoffice/.env.example apps/backoffice/.env.local   # puis remplir SESSION_SECRET
pnpm --filter @tara/api dev                                   # l'API sur le port 3000
pnpm --filter @tara/backoffice dev                            # le back-office sur le port 3100
```

Premier administrateur (numéro fictif en local) :

```bash
SEED_ADMIN_PHONE=+237690000777 pnpm --filter @tara/api db:seed
```

Les autres membres et leurs rôles (`DISPATCHER`, `SUPPORT`, `FINANCE`, `ADMIN`) se gèrent
ensuite depuis la section Équipe (H8). En local, le code SMS s'affiche dans le journal de
l'API.

### Ville fictive (démonstration)

Pour voir le back-office vivre sans vrais clients : boutiques, livreurs qui roulent dans
Douala, commandes qui arrivent, et quelques incidents mis en scène (commande sans livreur,
retards, livreur sans signal, SOS, remise sans code). Données entièrement fictives, sur la
base de développement uniquement (refusé en production) :

```bash
pnpm --filter @tara/api demo:city -- --riders 30 --minutes 30
```

## Carte en direct (H1)

La carte relit l'état de la ville toutes les 5 secondes (en pause quand l'onglet est caché) :
livreurs libres (vert), en course (orange), hors ligne avec leur dernière position (gris),
prochain arrêt de chaque commande, SOS qui clignotent. Le panneau de droite classe les
alertes : SOS (avec un son et le nombre de SOS dans le titre de l'onglet), commandes sans
livreur ou en retard, livreur en course qui ne répond plus, remises sans code et décisions
attendues, alertes de trajet. Un clic montre l'élément sur la carte et ouvre sa fiche.

Fonds de carte : style Tara des apps (`packages/tara_map`), tuiles OpenFreeMap en attendant
les nôtres. Le fichier de calcul de la carte est copié dans `public/` avant `dev` et `build`
(`scripts/copy-map-worker.mjs`).

## Connexion

1. Numéro de mobile, puis code reçu par SMS (comme dans les apps).
2. Second facteur obligatoire : la première fois, QR code à scanner dans une application
   d'authentification (Google Authenticator, Microsoft Authenticator…), ensuite son code
   à 6 chiffres. Valable 12 heures.

Un numéro sans rôle d'équipe est refusé et sa session aussitôt fermée.

## Sécurité

- Les jetons de l'API restent sur le serveur du back-office : le navigateur ne reçoit
  qu'un cookie chiffré (AES-256-GCM, `httpOnly`, `SameSite=Strict`, `Secure` en
  production). Toutes les données passent par des composants serveur et des actions.
- `src/proxy.ts`, avant chaque page : politique de sécurité du contenu avec nonce (aucun
  script ni style écrit dans la page), renouvellement du jeton d'accès une minute avant
  son échéance (un seul renouvellement à la fois, voir `src/lib/refresh.ts`), renvoi vers
  la connexion sans second facteur vérifié.
- Chaque section vérifie aussi le rôle côté serveur (`requireStaff` dans
  `src/lib/dal.ts`) : le menu masqué ne suffit pas, l'API refuse de toute façon.
- Pages non indexées par les moteurs de recherche.

## Réglages (`.env.example`)

| Variable         | Rôle                                             |
| ---------------- | ------------------------------------------------ |
| `TARA_API_URL`   | Adresse de l'API, vue du serveur du back-office  |
| `SESSION_SECRET` | Clé des cookies, 32 caractères au moins, secrète |

## Types de l'API

Les types des réponses viennent du contrat OpenAPI de l'API (`apps/api/openapi.json`) :
`pnpm --filter @tara/backoffice api:types` régénère `src/lib/api-schema.d.ts`. La CI
vérifie qu'ils sont à jour.

## Vérifications

```bash
pnpm --filter @tara/backoffice lint
pnpm --filter @tara/backoffice typecheck
pnpm --filter @tara/backoffice test
pnpm --filter @tara/backoffice build
```

La CI les lance avec le reste du dépôt (`pnpm lint`, `typecheck`, `test`, `build`).

Voir `docs/CAHIER_DES_CHARGES.md` et `docs/ARCHITECTURE.md`.
