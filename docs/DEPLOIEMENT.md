# Mise en ligne de Tara (VPS Hostinger)

Guide pas à pas pour installer Tara sur un serveur, puis tester les apps sur de vrais téléphones Android. Les blocs de commandes se copient-collent tels quels dans le terminal du serveur.

## Ce qu'il faut avant de commencer

| Quoi                                                                                                                                 | Où                                                                                                 | Pourquoi                                                                                                                                                                                                                                                            |
| ------------------------------------------------------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Serveur **VPS KVM 1** (1 processeur, 4 Go) ou **KVM 2** (2 processeurs, 8 Go), système **Ubuntu 24.04**, centre de données **Paris** | Hostinger                                                                                          | Le KVM 1 suffit pour les tests et le début du pilote : l'installation ajoute 4 Go de mémoire d'appoint sur le disque, et les constructions sont plus lentes. Passer au KVM 2 quand l'activité grandit. Paris est le plus proche de Douala parmi les choix Hostinger |
| Un **nom de domaine** (ex. `taralivraison.com`)                                                                                      | Hostinger ou autre                                                                                 | HTTPS obligatoire pour les apps                                                                                                                                                                                                                                     |
| Compte **Twilio** (essai gratuit) : Account SID, Auth Token, numéro d'envoi                                                          | twilio.com                                                                                         | Codes de connexion par SMS. En essai, Twilio n'envoie qu'aux numéros vérifiés dans son tableau de bord : y ajouter les téléphones de test                                                                                                                           |
| **Compte de service Firebase** (fichier JSON)                                                                                        | console Firebase › Paramètres du projet › Comptes de service › « Générer une nouvelle clé privée » | Notifications (nouvelle course, statut de la commande)                                                                                                                                                                                                              |
| **Nouvelles clés Sebpay** `pk_live_…` et `sk_live_…`                                                                                 | tableau de bord Sebpay                                                                             | Paiements Mobile Money. Ne jamais réutiliser les anciennes clés, qui ont été exposées                                                                                                                                                                               |

Ne jamais envoyer de mot de passe, de clé ou de fichier de compte de service par messagerie ou dans une discussion : ils se saisissent seulement dans le terminal du serveur.

## 1. Adresses du domaine (DNS)

Dans la zone DNS du domaine, créer quatre enregistrements de type **A** vers l'adresse IP du serveur (affichée par Hostinger) :

| Nom     | Sert à                                                             |
| ------- | ------------------------------------------------------------------ |
| `api`   | API, utilisée par les apps                                         |
| `admin` | back-office de l'équipe                                            |
| `suivi` | page de suivi et lien de localisation envoyés aux destinataires    |
| `apps`  | téléchargement des apps Android de test (protégé par mot de passe) |

## 2. Accès du serveur au code

Dans Hostinger : VPS › **Terminal** (dans le navigateur). Copier-coller :

```bash
apt-get update -q && apt-get install -y -q git
mkdir -p /root/.ssh && ssh-keygen -t ed25519 -N "" -C tara-vps -f /root/.ssh/tara_deploy
cat /root/.ssh/tara_deploy.pub
```

La dernière ligne affichée commence par `ssh-ed25519` : c'est une clé **publique**, sans danger. L'autoriser en lecture seule sur le dépôt GitHub : sur github.com, dépôt `ulaihub/tara-platform` › **Settings** › **Deploy keys** › **Add deploy key** ; titre `Serveur Hostinger`, coller la ligne dans **Key**, laisser **Allow write access** décoché, valider. Puis, dans le terminal du serveur :

```bash
GIT_SSH_COMMAND="ssh -i /root/.ssh/tara_deploy -o StrictHostKeyChecking=accept-new" \
  git clone git@github.com:ulaihub/tara-platform.git /opt/tara/src
bash /opt/tara/src/infra/production/tara install
```

## 3. Installation

`tara install` pose quelques questions : domaine, adresse e-mail (certificats HTTPS), numéro du premier administrateur, puis les clés des prestataires (Twilio, Firebase, Sebpay ; Anthropic est facultatif). Ensuite, sans intervention :

- Docker et le pare-feu (seuls SSH, HTTP et HTTPS restent ouverts) ;
- tous les secrets internes, créés au hasard et gardés sur le serveur (`/opt/tara`, lisibles par root seulement) ;
- la carte des itinéraires du Cameroun ;
- la base de données (comptes à moindre privilège, zone « tout Douala », grilles de prix, administrateur) ;
- les services : API, back-office, page de suivi, stockage des fichiers, HTTPS automatique ;
- une sauvegarde chaque nuit à 2 h.

Compter 30 à 45 minutes la première fois (jusqu'à 1 h 30 sur un KVM 1). À la fin : `https://admin.<domaine>` ouvre le back-office (connexion par code SMS, puis double authentification à activer avec une app comme Google Authenticator).

Chez Sebpay, déclarer l'adresse IP du serveur et l'adresse de notification `https://api.<domaine>/v1/webhooks/payments/sebpay`. Premier essai : un paiement réel de 100 F.

## 4. Apps sur les téléphones de test (sans Google Play)

```bash
tara apk
```

Construit l'app livreur et l'app expéditeur pour ce serveur (20 à 60 minutes la première fois, davantage sur un KVM 1) et affiche l'adresse `https://apps.<domaine>`, l'identifiant et le mot de passe. Sur chaque téléphone Android (8.0 ou plus) : ouvrir l'adresse, télécharger `tara-livreur.apk` ou `tara-expediteur.apk`, accepter « installer des applis inconnues » pour le navigateur, installer.

Ces apps sont signées avec une clé de test : avant de passer à Google Play, il faudra les désinstaller (la version du Play Store est signée autrement).

## Téléphones de test sans crédit SMS

En essai, Twilio n'envoie qu'aux numéros vérifiés, et refuse de vérifier un numéro camerounais par SMS. Pour tester quand même, déclarer les téléphones de test sur le serveur : leurs SMS (code de connexion, code de livraison, lien de suivi…) ne partent pas chez l'opérateur, ils restent 24 h sur le serveur.

```bash
tara testeur 640114064
tara sms
```

- `tara testeur 6XXXXXXXX` ajoute un téléphone (20 au plus), `tara testeur` affiche la liste, `tara testeur retirer 6XXXXXXXX` le retire.
- `tara sms` affiche les 20 derniers messages, le plus récent en bas : y lire le code, puis le taper dans l'app ou le back-office.

Ne jamais y mettre le numéro d'un vrai client : il ne recevrait plus aucun SMS. Vider la liste avant l'ouverture au public.

## Au quotidien

| Commande        | Effet                                                                           |
| --------------- | ------------------------------------------------------------------------------- |
| `tara status`   | état des services                                                               |
| `tara logs api` | journal de l'API en direct (Ctrl+C pour sortir)                                 |
| `tara update`   | installe la dernière version validée (migrations comprises, données conservées) |
| `tara config`   | change les clés des prestataires                                                |
| `tara backup`   | sauvegarde immédiate (automatique chaque nuit)                                  |
| `tara apk`      | reconstruit les apps après une mise à jour                                      |
| `tara testeur`  | téléphones de test (voir plus haut)                                             |
| `tara sms`      | derniers SMS des téléphones de test                                             |

**Sauvegardes** : base et fichiers dans `/opt/tara/backups`, deux semaines gardées. Activer aussi les instantanés automatiques du VPS dans Hostinger, et copier de temps en temps une sauvegarde hors du serveur. Sans la clé `STORAGE_ENCRYPTION_KEY` (dans `/opt/tara/api.env`), les pièces d'identité sauvegardées sont illisibles : la garder en lieu sûr, hors du serveur.

## Ce qui tourne sur le serveur

| Service                    | Rôle                                                                              |
| -------------------------- | --------------------------------------------------------------------------------- |
| Caddy                      | HTTPS (certificats Let's Encrypt renouvelés automatiquement), seul service exposé |
| API                        | NestJS, mode production, tâches de fond                                           |
| Back-office, page de suivi | Next.js, Hono                                                                     |
| PostgreSQL + PostGIS       | base de données (l'API n'utilise que le compte restreint `tara_app`)              |
| Redis                      | positions des livreurs, files de tâches, limitation de débit (mot de passe)       |
| SeaweedFS                  | stockage objet compatible S3 (photos, notes vocales, pièces d'identité chiffrées) |
| OSRM                       | itinéraires et distances sur la carte du Cameroun                                 |

Fichiers : `infra/production/` (assemblage, commande `tara`, construction des apps), `Dockerfile` à la racine (images des services).
