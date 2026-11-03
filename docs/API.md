# API Tara — guide pour les développeurs des applications

Le contrat complet est dans [`apps/api/openapi.json`](../apps/api/openapi.json), généré depuis le code et vérifié par la CI. En développement, l'interface Swagger est servie sur <http://localhost:3000/docs>.

Pour générer le client Dart des applications Flutter :

```bash
npx @openapitools/openapi-generator-cli generate -i apps/api/openapi.json -g dart-dio -o packages/api_client_dart
```

## Conventions

| Sujet       | Règle                                                                                                                                                                                                                |
| ----------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Adresse     | Toutes les routes sont sous `/v1`, sauf `/health`.                                                                                                                                                                   |
| Connexion   | `Authorization: Bearer <accessToken>` sur toutes les routes, sauf `auth/*`, `public/*` et `/health`.                                                                                                                 |
| Langue      | `Accept-Language: fr` ou `en`. Pour un utilisateur connecté, la langue de son compte prime.                                                                                                                          |
| Erreurs     | Toujours `{ "error": { "code", "message", "details?", "requestId?" } }`. L'app se fie à `code` (liste fermée dans le schéma `ErrorBody`) ; `message` est prêt à afficher ; `requestId` est à communiquer au support. |
| Argent      | Montants en FCFA entiers, devise `XAF`. Jamais de décimales.                                                                                                                                                         |
| Dates       | ISO 8601 en UTC (`2026-11-03T09:00:00.000Z`). L'app affiche l'heure du Cameroun (UTC+1).                                                                                                                             |
| Téléphones  | Toutes les écritures courantes sont acceptées (`690 00 00 00`, `+237690000000`…) et renvoyées au format `+2376XXXXXXXX`.                                                                                             |
| Pagination  | `?limit=20&cursor=<nextCursor>` ; la réponse contient `items` et `nextCursor` (`null` à la fin).                                                                                                                     |
| Idempotence | En-tête `Idempotency-Key` (UUID) sur `POST /v1/orders` et `POST /v1/orders/batch` : en cas de coupure réseau, renvoyer la même requête avec la même clé renvoie la commande déjà créée (`replayed: true`).           |
| Fichiers    | `multipart/form-data`, champ `file`. Photos et notes vocales : 1 Mo au plus (compresser côté app, viser moins de 150 Ko). Pièces KYC : 5 Mo, JPEG, PNG, WebP ou PDF ; le contenu réel est vérifié.                   |
| Limitation  | 120 requêtes par minute et par compte connecté ; sur les routes publiques, par adresse IP avec des seuils larges (les opérateurs partagent une même IP entre abonnés). Au-delà : `429` avec le code `RATE_LIMITED`.  |

## Connexion par code SMS (A1)

1. `POST /v1/auth/otp` avec `{ phone }` : un code à 6 chiffres part par SMS, valable 5 minutes. Nouvelle demande possible après 60 secondes, 5 au plus par quart d'heure.
2. `POST /v1/auth/otp/verify` avec `{ challengeId, code, device }`. Pour un nouveau compte, la réponse est `422 TERMS_REQUIRED` : afficher les conditions puis renvoyer **le même code** avec `termsVersion` (et `referralCode` si l'utilisateur en a un). Après 5 codes faux, il faut en demander un nouveau.
3. La réponse contient `accessToken` (15 minutes), `refreshToken` (30 jours) et `isNewUser`.
4. `POST /v1/auth/refresh` remplace la paire de jetons. Un jeton de rafraîchissement ne sert qu'une fois : le réutiliser ferme toutes les sessions du compte. Stocker le nouveau jeton avant toute autre action.
5. `POST /v1/auth/logout` ferme la session de l'appareil.

## Double authentification de l’équipe

Les comptes ayant un rôle d’équipe (`DISPATCHER`, `SUPPORT`, `FINANCE`, `ADMIN`) doivent confirmer un code TOTP (Google Authenticator, Microsoft Authenticator, Aegis…). Sans vérification depuis moins de 12 heures, l’API répond `403 MFA_REQUIRED` sur le back-office, avec `details.enrolled`, et le compte n’a aucun droit d’équipe ailleurs.

1. Premier passage (`enrolled: false`) : `POST /v1/auth/mfa/setup` renvoie `otpauthUrl`, à afficher en QR code, puis `POST /v1/auth/mfa/activate` avec `{ code, refreshToken }`.
2. Ensuite (`enrolled: true`) : `POST /v1/auth/mfa/verify` avec `{ code, refreshToken }`.
3. Les deux renvoient une nouvelle paire de jetons, à utiliser à la place de l’ancienne.

Après 5 codes faux, le second facteur est bloqué 15 minutes (`MFA_LOCKED`). Téléphone perdu : un administrateur appelle `POST /v1/admin/users/{id}/mfa/reset`.

## Données personnelles (loi n° 2024/017)

- `GET /v1/me/export` : toutes les données du compte, en fichier JSON (3 fois par heure au plus).
- Suppression du compte : `POST /v1/me/deletion/code` envoie un code SMS dédié, puis `POST /v1/me/deletion` avec `{ challengeId, code }`. Refusée pour un livreur ou l’équipe (passer par le support), et tant qu’une commande est en cours.
- Les coordonnées des destinataires sont masquées 30 jours après la fin de la commande.

## Couverture des exigences de la phase 1

| Exigence | Routes                                                                                                                                                                                                                     |
| -------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| A1       | `POST /auth/otp`, `POST /auth/otp/verify`, `POST /auth/refresh`, `POST /auth/logout`                                                                                                                                       |
| A2       | `GET /me`, `PATCH /me`, `PUT /me/merchant`                                                                                                                                                                                 |
| A3       | `POST /riders/apply`, `GET /riders/me`, `POST /riders/me/documents` ; back-office : `GET /admin/riders`, `POST /admin/kyc-documents/{id}/review`, `POST /admin/riders/{id}/decision`, `GET /admin/kyc-documents/{id}/file` |
| A4       | `PATCH /me` (`locale`) et `Accept-Language`                                                                                                                                                                                |
| A5       | Tâche quotidienne à 7 h : pièces échues en `EXPIRED`, SMS 30, 7 et 1 jours avant                                                                                                                                           |
| B1, B6   | `GET /zones`, `POST /addresses` (refus `OUT_OF_SERVICE_AREA`, quartier déduit, `motorbikeRestricted`) ; back-office : `POST /admin/zones`, `PATCH /admin/zones/{id}`                                                       |
| B2       | `POST /media` puis `photoKey` / `voiceNoteKey` dans l'adresse                                                                                                                                                              |
| B3       | `POST /location-links`, `GET /location-links`, `GET /location-links/{id}` ; page publique : `GET` et `POST /public/location-links/{token}`                                                                                 |
| B4, B5   | `GET /addresses`, `DELETE /addresses/{id}`, `GET /recipients` (`lastAddress.verifiedAt` après une livraison réussie)                                                                                                       |
| C1, C3   | `POST /orders` (`scheduledFor` entre 30 minutes et 7 jours), `GET /orders`, `GET /orders/{id}`, `POST /orders/{id}/cancel`, `POST /orders/{id}/pickup-code`                                                                |
| C2       | `POST /orders/quote`                                                                                                                                                                                                       |
| C4       | `POST /orders/batch` (1 à 10 livraisons, un seul code d'enlèvement)                                                                                                                                                        |
| C5       | SMS au destinataire ; page publique : `GET /public/tracking/{token}`, `POST /public/tracking/{token}/response`                                                                                                             |
| C6       | `promoCode` dans le devis et la commande, `referralCode` à l'inscription ; back-office : `/admin/promo-codes`                                                                                                              |
| C7       | Back-office : `GET` et `POST /admin/pricing-grids`, `POST /admin/pricing-grids/{id}/activate`, `PATCH /admin/pricing-grids/{id}/surcharges/{code}`                                                                         |

`POST /admin/orders/{id}/transition` permet aux opérations de faire avancer une commande à la main, en attendant l'attribution automatique (phase 2) et l'app livreur (phase 4).

## Cycle de vie d'une commande à sa création

- Paiement en espèces ou par le destinataire, sans créneau : la commande passe aussitôt en `SEARCHING_RIDER`.
- Prépaiement Mobile Money ou portefeuille : elle reste en `CREATED` jusqu'au paiement (phase 3).
- Créneau programmé : elle reste en `CREATED` jusqu'à son lancement automatique (phase 2).

Le code d'enlèvement (4 chiffres) n'est renvoyé qu'une fois, à la création ; s'il est perdu, `POST /orders/{id}/pickup-code` en génère un nouveau. Le code de livraison est créé à l'enlèvement et envoyé par SMS au destinataire.
