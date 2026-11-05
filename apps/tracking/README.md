# Page de suivi destinataire (web)

Page publique ouverte depuis le lien reçu par SMS ou WhatsApp (`/t/{jeton}`), sans compte ni
installation (exigence F2) : statut, livreur à appeler, heure d'arrivée estimée, somme à
payer à la porte et demande Mobile Money en cours, confirmation de disponibilité (C5).

- **Rendue côté serveur** avec [Hono](https://hono.dev) (JSX côté serveur), sans framework
  côté navigateur. Le seul JavaScript (moins de 1 Ko) relit toutes les 20 s l'empreinte de
  l'état (`/t/{jeton}/etat`) et recharge la page quand elle change, sauf pendant une saisie.
  Sans JavaScript, tout fonctionne (lien « Actualiser », formulaires classiques).
- **Légère** : environ 4 Ko compressés pour la page, 12 Ko par police (Plus Jakarta Sans 500
  et 800, sous-ensemble latin), 2,5 Ko pour le logo complet (tracés simplifiés depuis
  `docs/design/brand`, version claire ou sombre selon le téléphone). Un test garde le total
  sous 200 Ko.
- **Thème clair ou sombre** selon le téléphone ; français ou anglais selon le navigateur,
  ou `?lang=fr|en`.
- **Sécurité** : CSP stricte à nonce, `Referrer-Policy: no-referrer` (le jeton est dans
  l'adresse), pas de cache, pas d'indexation. Seuls les jetons au bon format vont jusqu'à
  l'API.

## Lien de localisation (B3)

`/l/{jeton}` : l'expéditeur envoie ce lien au destinataire, qui place lui-même son point de
livraison, sans compte.

1. **Sa position** : bouton « Utiliser ma position » (GPS du téléphone, précision affichée ;
   au-delà de 100 m, la page conseille de la reprendre). Seule page autorisée à lire la
   position (`Permissions-Policy: geolocation=(self)`), seulement après le toucher.
2. **Son repère** écrit, obligatoire (3 à 300 caractères).
3. **Facultatif** : son nom (prérempli) et un autre numéro, vérifié (mobile camerounais).

Envoi par formulaire classique ; l'API refuse un point hors de la zone desservie, un lien
déjà utilisé (`409`) ou expiré (`410`). Après l'envoi : remerciement, et l'expéditeur est
prévenu dans son app. Sans JavaScript, la page explique qu'il faut l'activer : la position
ne peut pas être lue autrement.

## Lancer

```sh
pnpm --filter @tara/tracking dev      # http://localhost:3001, API sur http://localhost:3000
pnpm --filter @tara/tracking test
pnpm --filter @tara/tracking build && pnpm --filter @tara/tracking start
```

| Variable      | Défaut                  | Rôle                                                                                |
| ------------- | ----------------------- | ----------------------------------------------------------------------------------- |
| `PORT`        | `3001`                  | Port d'écoute                                                                       |
| `API_URL`     | `http://localhost:3000` | API Tara (routes `/v1/public/tracking/…`)                                           |
| `TRUST_PROXY` | (non)                   | `true` derrière un hébergeur : l'adresse du visiteur est lue dans `X-Forwarded-For` |

Côté API, `PUBLIC_WEB_URL` doit pointer vers cette page (liens des SMS).

## Limite de débit

L'API limite chaque adresse IP à 120 requêtes par minute. La page transmet l'adresse du
visiteur dans `X-Forwarded-For` ; en production, l'API doit faire confiance à ce relais
(`TRUST_PROXY` de l'API : adresse ou plage du serveur de la page), sinon tous les
destinataires partagent la limite d'une seule adresse.
