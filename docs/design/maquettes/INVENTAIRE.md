# Fidélité aux maquettes — inventaire (25 nov.)

Outils : `tools/design/rendre.cjs` (rend les maquettes avec leur état par défaut, code évalué en vm vide),
`tools/design/photo.cjs` (captures 390×844 / 1440×900), `tools/design/cmp.py app planche.png Maquette:golden…`.
Rendus : `tools/design/rendus/<Page>.<clair|sombre>.png` (voir tools/design/README.md).

Décisions à garder (prises par l'utilisateur, différentes des maquettes) :
- carte réelle (MapLibre) sur les écrans de suivi / adresse / course : la carte 3D est en attente (#167)
- barre d'onglets en pilule de l'app livreur (PR #73)

## Fait (fusionné)
- Présentation expéditeur (4) + livreur (3) : PR 77
- Expéditeur lot 1 : connexion, code, conditions, bienvenue : PR 78
- Expéditeur lot 2 : accueil, commandes, nouvelle livraison (6 écrans) : PR 80
- Cloche des notifications, « Mon activité » de la boutique : PR 81
- Expéditeur lot 3 : paiement en attente, suivi (livreur trouvé, livré, échec, retour), profil : PR 82, 87
- Pages web : vraie carte, code de livraison : PR 88 (le reste des pages web et le back-office ne sont pas refaits : choix du porteur)
- Livreur lot A : enlèvement (scan QR + 4 chiffres), en route : PR 89
- Livreur lot B : livraison impossible, retour du colis : PR 90

## Reste à comparer
- Livreur lot C : Recharger, Retirer, Reverser, Pièces, Profil
- Expéditeur, écrans listés plus bas sans PR ci-dessus (envoi en masse, portefeuille, contacts,
  demander l'adresse, supprimer le compte…) : recomparer avant de les déclarer conformes

Les listes d'écarts ci-dessous datent du premier passage (25 nov.).

## Expéditeur — écarts constatés (maquette → écran)
- Connexion : logo en tuile + colis 3D, titre bas, champs Pays / Numéro séparés, « WhatsApp ou SMS » ; à refaire
- Code : titre dans l'en-tête, ligne WhatsApp (point vert), 6 cases, « Lecture automatique du code… », « Recevoir par SMS · Renvoyer dans 0:42 » ; à refaire
- Conditions (nouvelle version) : comparer avec 02_conditions_nouvelle_version
- Bienvenue : « NOUVEAU COMPTE », nom de boutique seul, segment, colis 3D, champ Mobile Money ; comparer 03_bienvenue_boutique
- Accueil : 4 raccourcis (+ Activité), cartes en cours avec chip temps / « Décider », espacements
- Commandes : proche ; texte de recherche différent
- NL Carte (adresse) : en-tête titre+sous-titre, bulle d'aide, feuille « Point placé », repère, photo façade + note vocale
- NL Colis : en-tête « Nouvelle livraison / Étape 3 sur 5 · Colis / Fermer », tailles en cartes 3D, nature en puces, valeur, garantie, objets interdits
- NL Destinataire : champs nom/numéro, choix « Où livrer ? » en radios, carte adresse connue
- NL Enlèvement : radios, adresses détaillées, « Nouvelle adresse sur la carte » en pointillés
- NL Quand : deux cartes côte à côte + colis 3D
- NL Récap : résumé A/B, segment payeur, moyens de paiement radios, à encaisser, glisser pour commander
- Paiement en attente : jauge liquide + logo opérateur, numéro qui paie
- Profil : statistiques (livraisons, réussies, depuis), badges, « Revoir la présentation »
- Suivi (livreur trouvé) : barre d'étapes à 4 libellés, titre + chip « 4 min », ligne livreur, bloc QR « Code d'enlèvement »
- Suivi échec : compte à rebours 12', photo du lieu, options radios, « Relancer la livraison »
- Suivi livré : coche liquide, photo de remise, étoiles, mot pour l'équipe, « Envoyer ma note »
- Suivi retour : « Code de retour » en grand, frais
- Supprimer compte : « Mon compte et mes données », télécharger, avertissement solde
- Coller liste : zone texte monospace, « Ce que Tara a compris » en lignes
- Colis en attente : cartes avec jauge jours, relancer / annuler
- Contacts : recherche en champ, sections, cases cochées
- Liste d'envoi : barre départ/quand/taille, 3 boutons, lignes numérotées
- Vérifier et envoyer : 3 bandeaux d'état, totaux, payer avec, glisser pour envoyer
- Portefeuille : en-tête titre + œil + relevé, carte ventes, 3 actions, « Cette semaine », mouvements
- Demander l'adresse : champs côte à côte, WhatsApp vert / SMS, adresses demandées
- Service client : proche
- Démarrage : sans capture

## Livreur — écarts constatés (premier passage)
- Connexion : champs Pays / Numéro séparés, WhatsApp ou SMS
- Conditions : écran propre au livreur (sections numérotées, « Lu à 35 % », case à cocher)
- Hors ligne / En ligne : proches (carte réelle et pilule gardées)
- Proposition : proche (carte réelle)
- Non conforme : radios en liste, photo obligatoire
- Enlèvement : adresse + façade, attente, photo, code (Scanner / Taper 4 chiffres), liens
- Encaissement : proche
- Mes gains : jauge du jour, tuiles courses / en ligne / distance / note, meilleures heures
- (à finir : 01-02, 05-06, 08-11)

## Back-office, pages web : à vérifier
