# Sécurité de Tara

Principes : défense en profondeur (chaque risque est couvert par au moins deux protections), moindre privilège, aucun secret dans le code, minimisation des données personnelles. Aucun système n'est inviolable : l'objectif est de rendre une attaque coûteuse, d'en limiter les dégâts et de la détecter vite.

## Menaces prioritaires et protections en place

| Menace                        | Exemple                                                      | Protections                                                                                                                                                                                                                                       |
| ----------------------------- | ------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Prise de compte client        | Deviner un code SMS, voler un jeton                          | Codes hachés, 5 essais par code, numéro bloqué 24 h après 10 échecs ; sessions de 15 min ; jeton de rafraîchissement à usage unique, toute réutilisation ferme toutes les sessions ; compte relu en base à chaque requête                         |
| Prise de compte de l'équipe   | Détournement de carte SIM (« SIM swap ») d'un administrateur | Second facteur TOTP obligatoire ; sans vérification depuis moins de 12 h, les droits de l'équipe sont retirés sur toutes les routes ; anti-rejeu ; blocage après 5 échecs ; SMS d'alerte à l'activation et à la réinitialisation ; audit          |
| Pompage de SMS                | Faire envoyer des milliers de codes pour gonfler la facture  | Numéros camerounais uniquement ; plafonds par numéro, par adresse IP et global sur 24 h ; au plafond global, seuls les clients existants reçoivent un code ; alertes à 80 % et 100 %                                                              |
| Fuite de données personnelles | Copie de la base, consultation abusive, journaux             | Pièces d'identité chiffrées (AES-256-GCM, clé dérivée par usage) ; consultations auditées ; téléchargement en pièce jointe ; destinataires masqués après 30 jours ; journaux sans numéros ni jetons ; réponses non mises en cache                 |
| Fraude financière             | Payer moins, modifier une écriture, doubler un reversement   | Prix recalculé par le serveur ; grand livre équilibré et en ajout seul, imposé par la base (trigger) ET par les droits ; idempotence ; verrouillage optimiste                                                                                     |
| Compromission de l'API        | Faille exploitée dans le code                                | Compte de base restreint : pas de modification de structure, pas de désactivation des protections, pas d'accès à l'historique des migrations ; en-têtes de sécurité ; CORS fermé par défaut ; refus de démarrer avec une configuration dangereuse |
| Chaîne d'approvisionnement    | Dépendance piégée ou vulnérable                              | Versions verrouillées ; scripts d'installation des dépendances bloqués ; audit en CI ; Dependabot ; outils de CI épinglés et vérifiés par empreinte                                                                                               |
| Attaques web classiques       | Injection SQL, fichier piégé, énumération                    | Requêtes paramétrées ; validation de chaque entrée ; type réel des fichiers contrôlé ; jetons publics aléatoires de 128 bits ; « introuvable » pour les ressources d'autrui                                                                       |
| Fraude à la livraison         | Livreur qui devine un code, livraison déclarée sans remise   | Codes à 4 chiffres hachés et bloqués après 5 erreurs (0,05 % de chances de deviner) ; photo et position GPS obligatoires ; livraison sans code validée par le support après appel, par un administrateur au-delà d'un montant ; audit             |
| Détournement du temps réel    | Écouter la position d'un livreur, se faire passer pour lui   | Connexion Socket.IO authentifiée par le même jeton que l'API, coupée à son expiration ; suivi d'une commande réservé à l'expéditeur, au livreur et à l'équipe ; débit limité par connexion                                                        |
| Faux accusés de remise        | Webhook WhatsApp forgé pour déclencher des SMS               | Signature HMAC-SHA256 du corps brut vérifiée en temps constant ; un seul repli par message ; route désactivée sans configuration                                                                                                                  |

## Contrôles automatiques à chaque pull request

- Audit des dépendances de production : la CI échoue sur une vulnérabilité élevée ou critique.
- Recherche de secrets dans tout l'historique Git (gitleaks).
- Tests de sécurité (`apps/api/test/security.db-spec.ts`, `privacy.db-spec.ts`, `db-guards.db-spec.ts`), exécutés avec le compte restreint de la base.
- Lint strict, typage, contrat OpenAPI à jour.

Dépendance de développement signalée et acceptée : `minimatch` (gravité modérée), utilisée seulement par l'outil de build NestJS, absente de l'API en production.

## Secrets et clés

Les secrets vivent dans le gestionnaire de secrets de l'hébergeur, jamais dans le dépôt. Les valeurs de `apps/api/.env.example` sont factices.

| Secret                   | Rôle                                           | Rotation                                                                                                                                       |
| ------------------------ | ---------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| `JWT_SECRET`             | Signature des jetons d'accès                   | Mettre l'ancien dans `JWT_SECRET_PREVIOUS`, le nouveau dans `JWT_SECRET`, déployer, retirer l'ancien 15 minutes plus tard. Aucune déconnexion. |
| `CODE_HASH_SECRET`       | Hachage des codes SMS et des codes colis       | Possible à tout moment : les codes en cours deviennent invalides (régénérer les codes d'enlèvement des commandes ouvertes).                    |
| `STORAGE_ENCRYPTION_KEY` | Chiffrement des pièces KYC et des secrets TOTP | Pas encore d'outil de rechiffrement : clé à conserver avec les sauvegardes, rotation à outiller avant la mise en production.                   |
| Mots de passe PostgreSQL | Comptes `tara_migrator` et `tara_app`          | Rejouer `infra/postgres/roles.sql` avec les nouveaux mots de passe, puis redéployer.                                                           |

## Base de données en production

1. Créer la base avec un compte administrateur, puis exécuter `infra/postgres/roles.sql` (commande en tête du fichier).
2. Lancer `pnpm db:deploy` avec `MIGRATION_DATABASE_URL` (compte `tara_migrator`).
3. Rejouer `infra/postgres/roles.sql` pour appliquer les droits aux nouvelles tables.
4. L'API utilise uniquement `DATABASE_URL` avec le compte `tara_app`, en connexion chiffrée (`sslmode=require`).
5. Sauvegardes chiffrées, restauration testée chaque trimestre.

## Procédures humaines

**Équipe Tara**

- La double authentification s'active le jour même de l'attribution d'un rôle d'équipe. Ne jamais partager un code ni le QR code d'enrôlement.
- Téléphone perdu ou volé : prévenir un administrateur, qui réinitialise le second facteur (toutes les sessions sont fermées).
- Départ d'un membre : retrait des rôles le jour même.

**Support client**

- Ne jamais demander à un client de lire un code reçu par SMS : un code ne se donne qu'à l'application.
- Ne jamais changer un numéro de téléphone ni un numéro de reversement sur simple appel : vérification d'identité écrite.
- La validation d'une livraison sans code (E4) exigera une double validation au-delà d'un montant à fixer (phase 4).

**Développeurs et prestataires**

- Accès au dépôt et à l'hébergement limités au strict nécessaire, retirés en fin de mission.
- Aucune donnée de production sur les postes de travail.
- Contrats avec clause de confidentialité et de cession des droits sur le code.

## Réponse à un incident

1. **Détecter** : alertes des journaux (numéro bloqué, plafond SMS, second facteur bloqué, erreurs 500 avec leur identifiant de requête).
2. **Contenir** : suspendre le compte concerné, révoquer les sessions, changer le secret exposé.
3. **Évaluer** : grâce au journal d'audit, établir les données et les personnes touchées.
4. **Notifier** : l'APDP et les personnes concernées selon la loi n° 2024/017 (délais et forme à faire préciser par le juriste).
5. **Corriger et documenter** : correctif, test qui reproduit le problème, retour d'expérience écrit.

## Reste à faire, par phase

| Phase | Mesure                                                                                                                                                 |
| ----- | ------------------------------------------------------------------------------------------------------------------------------------------------------ |
| 2     | Fait : limitation de débit partagée (Redis), temps réel authentifié, webhook signé. Reste : vrai fournisseur SMS avec alertes de coût                  |
| 3     | Signature des webhooks Mobile Money ; plafonds et détection de fraude sur les encaissements et reversements                                            |
| 4, 5  | Apps : sessions dans le stockage chiffré du téléphone, vérification de l'intégrité de l'appareil, détection des téléphones modifiés, code obscurci     |
| 7     | HTTPS partout, protection anti-DDoS, sauvegardes chiffrées, outil de rotation de `STORAGE_ENCRYPTION_KEY`, test d'intrusion par un prestataire externe |
