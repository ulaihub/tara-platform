# Apps iPhone (TestFlight, puis App Store)

Les apps Tara sont écrites en Flutter : le même code tourne sur Android et sur iPhone. Pour l'iPhone, Apple impose deux choses : un **compte Apple Developer** (99 $ par an) et une construction sur un **Mac**. Le Mac est loué gratuitement chez **Codemagic** (500 minutes par mois sur un compte personnel, soit une vingtaine de constructions) : aucun achat de Mac n'est nécessaire.

| App            | Identifiant     | Sur iPhone                                                                                                                      |
| -------------- | --------------- | ------------------------------------------------------------------------------------------------------------------------------- |
| Tara Livreur   | `cm.tara.rider` | position pendant les courses, y compris app en arrière-plan (indicateur bleu en haut de l'écran), photos, notifications, appels |
| Tara (clients) | `cm.tara.app`   | position pour placer une adresse, photo de façade, note vocale, notifications                                                   |

Déjà prêt dans le code : autorisations iPhone des deux apps, suivi de position en arrière-plan de l’app livreur, notifications des deux apps, construction et envoi sur TestFlight (`codemagic.yaml` à la racine du dépôt). La première construction sur Codemagic peut demander quelques ajustements : en cas d'échec, copier les dernières lignes du journal de construction au support technique.

Ne jamais envoyer de clé (`.p8`), de mot de passe ou de fichier de compte par messagerie : ils se saisissent seulement dans Apple, Codemagic ou Firebase.

## 1. Compte Apple Developer

Sur [developer.apple.com/programs](https://developer.apple.com/programs/), « Enroll », avec un identifiant Apple. Inscription en nom propre possible (comme pour l'hébergeur), transférable plus tard à l'entreprise. Apple vérifie l'identité, souvent avec l'app « Apple Developer » sur un iPhone : compter un à deux jours.

## 2. Les deux apps chez Apple

1. [developer.apple.com/account](https://developer.apple.com/account) › Certificates, Identifiers & Profiles › **Identifiers** › « + » › App IDs › App :
   - `cm.tara.rider`, description « Tara Livreur », cocher **Push Notifications** ;
   - `cm.tara.app`, description « Tara », cocher **Push Notifications**.
2. [appstoreconnect.apple.com](https://appstoreconnect.apple.com) › Apps › « + » › **Nouvelle app**, pour chacune : plateforme iOS, nom (« Tara Livreur », « Tara »), langue Français, identifiant choisi dans la liste, référence (SKU) `tara-rider` ou `tara-app`.
3. App Store Connect › Utilisateurs et accès › **Intégrations** › Clés d'API App Store Connect › « + » : nom « Codemagic », accès **App Manager**. Télécharger la clé (fichier `.p8`, téléchargeable une seule fois) et noter l'**Issuer ID** et le **Key ID**.

## 3. Codemagic

1. Créer un compte sur [codemagic.io](https://codemagic.io) avec GitHub, en **compte personnel** (les minutes gratuites ne valent pas pour les équipes). Ajouter l'application depuis le dépôt `ulaihub/tara-platform` ; Codemagic lit `codemagic.yaml`.
2. Réglages du compte › Integrations › **Developer Portal** (App Store Connect) › ajouter la clé : nom **exactement** `Tara App Store Connect`, Issuer ID, Key ID, fichier `.p8`.
3. Réglages de l'app › **Environment variables**, groupe `tara_ios` :

| Variable                                                    | Valeur                                                                                                          |
| ----------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------- |
| `TARA_API_URL`                                              | `https://api.tara.ulaihub.tech` (l'adresse de l'API du serveur)                                                 |
| `FIREBASE_IOS_RIDER_APP_ID`, `FIREBASE_IOS_RIDER_API_KEY`   | étape 4, app livreur ; facultatif au début (sans elles, l'app marche sans notifications) ; la clé en « Secure » |
| `FIREBASE_IOS_CLIENT_APP_ID`, `FIREBASE_IOS_CLIENT_API_KEY` | étape 4, app clients ; même principe                                                                            |

## 4. Notifications sur iPhone (facultatif au début)

1. [Console Firebase](https://console.firebase.google.com) › projet **tara-ulaihub** › Ajouter une app › **iOS**, une fois par app : identifiant `cm.tara.rider`, puis `cm.tara.app`. Pour chacune, télécharger `GoogleService-Info.plist` et l'ouvrir : la valeur de `GOOGLE_APP_ID` va dans `FIREBASE_IOS_RIDER_APP_ID` (ou `FIREBASE_IOS_CLIENT_APP_ID`), celle de `API_KEY` dans `FIREBASE_IOS_RIDER_API_KEY` (ou `FIREBASE_IOS_CLIENT_API_KEY`), à l'étape 3.
2. Apple Developer › **Keys** › « + » › cocher **Apple Push Notifications service (APNs)**. Télécharger la clé `.p8`, noter son Key ID et l'identifiant d'équipe (Team ID, en haut à droite de la page).
3. Firebase › Paramètres du projet › **Cloud Messaging** › app iOS › Clé d'authentification APNs › importer la clé `.p8` avec son Key ID et le Team ID.

## 5. Construire et tester

1. Codemagic › tara-platform › **Start new build** › choisir « Tara (expéditeur) · iPhone » ou « Tara Livreur · iPhone ». Compter 15 à 25 minutes ; l'app part seule sur TestFlight.
2. App Store Connect › l'app › **TestFlight** :
   - testeurs internes (jusqu'à 100 personnes ajoutées à l'équipe App Store Connect) : disponibles tout de suite ;
   - testeurs externes : créer un groupe et activer le **lien public** ; Apple relit la première version (environ un jour).
3. Sur chaque iPhone : installer l'app **TestFlight** depuis l'App Store, ouvrir l'invitation ou le lien, installer Tara.

Les testeurs iPhone se déclarent comme les autres sur le serveur (`tara testeur 6XXXXXXXX`) tant que les SMS passent par l'essai Twilio.

## Plus tard : l'App Store

Depuis la même version TestFlight : fiche de l'app (description, captures d'écran, adresse de la politique de confidentialité, contact), puis « Soumettre pour vérification ». Pour l'app livreur, Apple demande pourquoi la position est utilisée en arrière-plan : la réponse est dans le texte affiché par l'app (suivi de la course en cours, arrêté hors ligne).
