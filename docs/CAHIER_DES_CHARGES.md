# Tara — Cahier des charges technique

> Source : document « Projet de livraison au Cameroun — Étude, Business Plan & Cahier des charges » (2 novembre 2026), partie 3.
> Ce fichier fait foi pour le développement. Les identifiants d'exigences (A1 … H10) sont utilisés dans le code, les commits et la recette.
> Le business plan, les données financières et les salaires restent dans le document privé et ne sont pas versionnés ici.

## 1. Objet, périmètre et acteurs

Le MVP livre quatre briques : l'app Tara pour les expéditeurs, l'app Tara Livreur, la page de suivi web du destinataire et le back-office d'exploitation. Il couvre Douala, en moto, en français et en anglais.

### Objet

Concevoir, développer et mettre en production une plateforme de livraison urbaine à la demande. Elle met en relation des expéditeurs (particuliers, vendeurs en ligne, entreprises) avec des livreurs indépendants vérifiés. Elle gère la tarification, l'attribution des courses, le suivi, l'encaissement à la livraison et le reversement aux marchands.

### Périmètre

| Inclus dans le MVP | Reporté en V2 ou plus tard |
| --- | --- |
| Ville de Douala, livraison intra-urbaine | Yaoundé et autres villes (V2, année 2) |
| Motos, colis jusqu'à 20 kg | Tricycles, voitures, colis lourds |
| Livraison immédiate ou programmée jusqu'à J+7 | Interurbain via agences de voyage |
| Encaissement à la livraison et reversement Mobile Money | Paiement par carte bancaire |
| App expéditeur Android (particulier et marchand) | App iOS (mois 8), portail marchand web, API publique |
| App livreur Android | Commande par chatbot WhatsApp |
| Page de suivi web pour le destinataire | Points relais, plugins WooCommerce et Shopify |
| Back-office d'exploitation | Marketplace de produits (hors périmètre) |

### Acteurs et outils

| Acteur | Outil | Ce qu'il fait |
| --- | --- | --- |
| Expéditeur particulier | App Tara | Commande, paie, suit, note le livreur |
| Marchand ou entreprise | App Tara en mode marchand (portail web en V2) | Crée des commandes une à une ou en masse, suit ses encaissements, reçoit ses reversements et factures |
| Destinataire | Page de suivi web, SMS, WhatsApp | Suit le colis, donne le code de livraison, paie en espèces ou Mobile Money |
| Livreur | App Tara Livreur | Accepte, enlève, livre, encaisse, dépose les espèces, retire ses gains |
| Dispatcheur | Back-office | Surveille la flotte en direct, réattribue, gère les incidents |
| Agent de support | Back-office | Traite les réclamations et les litiges |
| Responsable financier | Back-office | Rapproche les encaissements, valide les reversements, exporte la comptabilité |
| Administrateur | Back-office | Gère zones, tarifs, promotions, rôles et paramètres |
| Point relais partenaire (V2) | App Tara en mode relais | Réceptionne et remet des colis |

### Cycle de vie d'une commande

| Statut | Déclenché par | Notification envoyée |
| --- | --- | --- |
| Créée | Expéditeur | Confirmation à l'expéditeur ; message au destinataire pour confirmer adresse et disponibilité |
| Recherche de livreur | Système | — |
| Attribuée | Système ou dispatcheur | Nom, photo et note du livreur à l'expéditeur |
| Colis enlevé | Livreur (photo du colis, code d'enlèvement) | Lien de suivi et code de livraison au destinataire |
| En livraison | Livreur | Heure d'arrivée estimée mise à jour |
| Livrée | Livreur (code du destinataire + photo + position GPS) | Reçu à l'expéditeur et au destinataire |
| Échec de livraison | Livreur (motif obligatoire : absent, injoignable, refus, adresse introuvable) | Alerte à l'expéditeur avec choix : nouvelle tentative ou retour |
| Retournée | Livreur (code de l'expéditeur) | Confirmation de retour et frais appliqués |
| Annulée | Expéditeur avant enlèvement, ou dispatcheur | Confirmation et remboursement éventuel |

## 2. Exigences fonctionnelles

Le MVP compte 51 exigences, réparties en 8 modules ; la V2 en ajoute 9. Chaque exigence porte un identifiant pour le suivi des développements et de la recette.

### A. Comptes et vérification

| ID | Exigence | Lot |
| --- | --- | --- |
| A1 | Inscription et connexion par numéro de téléphone (+237) et code SMS à usage unique ; aucun e-mail obligatoire | MVP |
| A2 | Profil expéditeur avec adresses favorites ; passage en mode marchand (nom de boutique, catégorie, numéro Mobile Money de reversement, RCCM et NIU facultatifs) | MVP |
| A3 | Inscription livreur dans l'app : CNI recto-verso, permis A, carte grise, selfie, garant ; validation au back-office ; statuts en attente, actif, suspendu | MVP |
| A4 | Choix de la langue : français ou anglais | MVP |
| A5 | Rappel automatique avant expiration d'un document du livreur | MVP |
| A6 | Compte marchand multi-utilisateurs (gérant, employés) | V2 |

### B. Adresses et cartographie

| ID | Exigence | Lot |
| --- | --- | --- |
| B1 | Adresse = point sur la carte (GPS ou épingle déplacée) + quartier choisi dans une liste + repère écrit obligatoire | MVP |
| B2 | Photo de façade et note vocale de 30 s maximum, facultatives | MVP |
| B3 | **Lien de localisation** : le marchand envoie un lien à son client, qui place lui-même son point et son repère ; l'adresse remplit la commande automatiquement | MVP |
| B4 | Base de repères : après une livraison réussie, le point exact et la photo sont mémorisés pour ce destinataire | MVP |
| B5 | Carnet des destinataires fréquents pour les marchands | MVP |
| B6 | Zones de service et zones interdites aux motos paramétrables (polygones) | MVP |
| B7 | Recherche de lieux connus (carrefours, églises, pharmacies, écoles) dans la base de repères | V2 |

### C. Commande et tarification

| ID | Exigence | Lot |
| --- | --- | --- |
| C1 | Saisie : enlèvement, livraison, nom et téléphone du destinataire, taille (S, M, L, XL), fragile, valeur déclarée, montant à encaisser, instructions | MVP |
| C2 | Prix calculé avant validation (distance routière, suppléments) et affiché TTC | MVP |
| C3 | Livraison immédiate ou programmée sur un créneau, jusqu'à J+7 | MVP |
| C4 | Jusqu'à 10 livraisons depuis un même point d'enlèvement en une seule saisie | MVP |
| C5 | Confirmation automatique du destinataire par WhatsApp ou SMS (adresse, disponibilité) avant l'enlèvement | MVP |
| C6 | Codes promo et parrainage | MVP |
| C7 | Grille tarifaire et suppléments modifiables au back-office, sans nouvelle version de l'app | MVP |
| C8 | Import en masse par fichier CSV ou Excel | V2 |
| C9 | Commande par message WhatsApp (chatbot) | V2 |

### D. Attribution des courses

| ID | Exigence | Lot |
| --- | --- | --- |
| D1 | Proposition automatique au livreur disponible le mieux placé (distance d'approche, note, courses en cours, espèces détenues) | MVP |
| D2 | 30 s pour accepter, puis proposition au suivant ; diffusion à plusieurs livreurs après 3 refus ; alerte au dispatch après 5 min sans livreur | MVP |
| D3 | Attribution et réattribution manuelles par le dispatcheur | MVP |
| D4 | Livreur exclu des propositions si plafond d'espèces atteint ou document expiré | MVP |
| D5 | Regroupement automatique de colis dans une même tournée | V2 |

### E. Exécution de la livraison (app livreur)

| ID | Exigence | Lot |
| --- | --- | --- |
| E1 | Passage en ligne ou hors ligne ; proposition de course avec son et vibration, même écran verrouillé | MVP |
| E2 | Ouverture de l'itinéraire dans Google Maps ou Waze ; appel direct de l'expéditeur et du destinataire | MVP |
| E3 | Enlèvement validé par photo du colis et code donné par l'expéditeur | MVP |
| E4 | Livraison validée par le code à 4 chiffres du destinataire et une photo ; sans code, validation par le support après appel | MVP |
| E5 | Encaissement en espèces, MTN MoMo ou Orange Money ; pour le Mobile Money, demande de paiement envoyée au téléphone du destinataire et confirmation automatique | MVP |
| E6 | Échec de livraison : motif obligatoire, photo du lieu, preuve d'appel ; retour vers l'expéditeur ou le bureau | MVP |
| E7 | Mode hors ligne : actions mises en file avec heure et position, synchronisées au retour du réseau | MVP |
| E8 | Bouton d'alerte qui envoie la position au dispatch | MVP |
| E9 | Historique des courses et des gains du jour, de la semaine, du mois | MVP |

### F. Suivi et notifications

| ID | Exigence | Lot |
| --- | --- | --- |
| F1 | Position du livreur rafraîchie toutes les 10 à 15 s dans l'app expéditeur | MVP |
| F2 | Page de suivi web sans connexion, de moins de 200 Ko : statut, livreur, heure estimée, bouton d'appel, paiement Mobile Money | MVP |
| F3 | Notifications push, SMS et WhatsApp selon le statut, avec repli sur SMS si WhatsApp échoue | MVP |
| F4 | Notation réciproque expéditeur ↔ livreur, avec commentaire | MVP |
| F5 | Messagerie dans l'app entre expéditeur et livreur | V2 |

### G. Paiements, encaissements et portefeuilles

| ID | Exigence | Lot |
| --- | --- | --- |
| G1 | Paiement de la livraison par MTN MoMo, Orange Money, solde Tara ou espèces ; option « le destinataire paie la livraison » | MVP |
| G2 | Portefeuille marchand : encaissements, frais déduits, solde, historique ligne par ligne | MVP |
| G3 | Reversement automatique quotidien à heure fixe (par défaut 18 h) vers le Mobile Money du marchand ; reversement à la demande pour les Pro | MVP |
| G4 | Portefeuille livreur : gains, commissions dues sur courses payées en espèces, espèces détenues, retrait vers Mobile Money | MVP |
| G5 | Plafond d'espèces par livreur ; dépôt par Mobile Money ou au bureau ; blocage des nouvelles courses au-delà | MVP |
| G6 | Rapprochement automatique quotidien : encaissements déclarés, dépôts et reversements, avec liste des écarts | MVP |
| G7 | Relevé mensuel PDF par marchand | MVP |
| G8 | Remboursements et avoirs | MVP |
| G9 | Factures TVA conformes, générées automatiquement | V2 |

Point à valider par un juriste avant le développement : encaisser pour le compte de marchands puis leur reverser peut relever de la réglementation CEMAC des services de paiement. Le montage le plus sûr passe par un agrégateur agréé qui effectue lui-même les reversements.

### H. Back-office d'exploitation

| ID | Exigence | Lot |
| --- | --- | --- |
| H1 | Carte en direct : livreurs (libre, en course, hors ligne), commandes en cours, alertes de retard | MVP |
| H2 | Gestion des commandes : recherche, détail, historique des statuts, réattribution, annulation, notes internes | MVP |
| H3 | Validation des livreurs (documents, entretien), suspension, historique de fiabilité | MVP |
| H4 | Gestion des marchands, tarifs, zones et promotions | MVP |
| H5 | Finance : rapprochement, validation des reversements, export comptable CSV | MVP |
| H6 | Support : tickets liés aux commandes, litiges avec preuves (photos, positions, journal d'appels) | MVP |
| H7 | Tableau de bord des indicateurs (livraisons/jour, taux de réussite, délais, reversements le jour même, courses par livreur, rétention des marchands, écart de caisse, note des livreurs) | MVP |
| H8 | Rôles et permissions ; journal d'audit des actions sensibles | MVP |
| H9 | Portail marchand web, API REST avec webhooks de statut, plugins WooCommerce et Shopify | V2 |
| H10 | Points relais : réception, stockage et remise de colis avec code | V2 |

## 3. Exigences non fonctionnelles

L'application doit fonctionner sur un Android à 60 000 FCFA, en 3G instable, pendant un délestage. C'est la contrainte qui dicte la plupart des choix techniques.

| Domaine | Exigence mesurable |
| --- | --- |
| Compatibilité | Android 8.0 et plus, 2 Go de RAM, écrans de 5 pouces ; iOS 14 et plus à partir du mois 8 |
| Poids | App livreur et app expéditeur : moins de 25 Mo à l'installation ; page de suivi : moins de 200 Ko |
| Performance | Ouverture de l'app en moins de 3 s sur un téléphone d'entrée de gamme ; réponse de l'API en moins de 500 ms pour 95 % des appels |
| Réseau | Fonctionne en 2G/3G ; requêtes compressées ; images réduites à moins de 150 Ko avant envoi ; reprise automatique des envois interrompus |
| Hors ligne | L'app livreur conserve la course en cours et enregistre toutes ses actions sans réseau, puis synchronise sans perte ni doublon |
| Consommation de data | Moins de 5 Mo par heure de travail pour un livreur |
| Batterie | Géolocalisation adaptative (toutes les 10 s en course, toutes les 60 s à l'arrêt, coupée hors ligne) ; moins de 8 % de batterie par heure |
| Disponibilité | 99,5 % par mois, de 6 h à 23 h ; maintenance hors de ces heures |
| Montée en charge | 5 000 commandes par jour et 500 livreurs connectés sans changement d'architecture |
| Sécurité | Chiffrement TLS de bout en bout ; mots de passe exclus (code SMS) ; jetons à durée courte ; limitation des tentatives ; secrets hors du code ; référentiel OWASP MASVS pour les apps |
| Argent | Toute opération financière est tracée dans un journal comptable en double entrée, non modifiable ; idempotence de tous les appels de paiement |
| Données personnelles | Conformité à la loi n° 2024/017 : consentement, déclarations à l'APDP, droit d'accès et de suppression, documents d'identité chiffrés, numéros des destinataires masqués après 30 jours |
| Hébergement | Lieu d'hébergement choisi après avis juridique sur les transferts de données hors du Cameroun |
| Sauvegardes | Base sauvegardée chaque jour, conservée 30 jours, restauration testée chaque trimestre |
| Langues | Français et anglais ; montants en FCFA sans décimales, séparateur de milliers par espace |
| Accessibilité | Textes lisibles en plein soleil (contraste AA), boutons d'au moins 48 px, icônes accompagnées de texte |
| Supervision | Remontée automatique des plantages, journaux centralisés, alertes si un paiement ou un SMS échoue en série |
| Qualité du code | Tests automatisés sur la tarification, l'attribution et les portefeuilles (couverture de 80 % sur ces modules) ; intégration continue |
| Propriété | Code source, comptes des stores, noms de domaine et comptes des prestataires au nom de la société du porteur de projet |

## 4. Architecture et stack technique

Un seul back-end, découpé en modules, sert les quatre applications. Pas de microservices : une équipe de trois développeurs doit pouvoir tout comprendre, déployer et dépanner.

Schéma détaillé et décisions : voir [`ARCHITECTURE.md`](ARCHITECTURE.md).

Chaque prestataire externe est branché derrière une interface : changer d'agrégateur Mobile Money ou de fournisseur SMS ne touche pas au reste du code.

| Couche | Choix | Pourquoi, dans le contexte camerounais |
| --- | --- | --- |
| Apps mobiles | Flutter (Dart) | Une seule base de code pour Android et iOS, fluide sur les téléphones d'entrée de gamme, développeurs disponibles localement |
| API | NestJS (TypeScript), monolithe modulaire | Structure claire, même langage que le back-office, un seul service à exploiter |
| Base de données | PostgreSQL 16 + PostGIS | Transactions fiables pour l'argent, requêtes géographiques (zones, repères) |
| Temps réel et tâches | Redis, Socket.IO, BullMQ | Positions des livreurs en mémoire, reconnexion automatique sur réseau instable, reversements et relances en tâche de fond |
| Back-office et page de suivi | Next.js + Tailwind | Rapide à construire, même langage que l'API ; page de suivi rendue côté serveur pour rester légère |
| Cartographie | Google Maps pour l'affichage, OSRM auto-hébergé sur OpenStreetMap pour les distances | Les calculs de distance, poste le plus coûteux chez Google, deviennent gratuits ; grille Google en vigueur à vérifier |
| Paiements | Agrégateur Mobile Money camerounais, puis API MTN MoMo et Orange Money en direct | Une intégration couvre les deux opérateurs au démarrage ; le passage en direct réduit les frais avec le volume |
| Notifications | Firebase (push), WhatsApp Cloud API, SMS via agrégateur local | WhatsApp est le canal naturel ; le SMS reste le secours pour les destinataires sans data |
| Hébergement | Conteneurs Docker sur un cloud, région choisie après avis juridique | Portabilité : on peut changer d'hébergeur, ou rapatrier les données au Cameroun si la loi l'exige |
| Qualité | GitHub Actions, Sentry, tests automatisés | Chaque modification est testée avant d'arriver en production |

**Données principales** : utilisateur, profil marchand, profil livreur, document KYC, adresse, repère, zone, grille tarifaire, commande, événement de statut, preuve de livraison, encaissement, compte et écriture du grand livre, reversement, notification, ticket, journal d'audit.

## 5. Critères de recette du MVP

- [ ] Scénario complet démontré : commande, attribution, enlèvement, livraison avec encaissement, reversement, relevé (exigences A1 à H8)
- [ ] Aucun plantage sur 100 courses simulées avec 3 téléphones Android réels de 2 Go de RAM
- [ ] 20 actions faites sans réseau, synchronisées sans perte ni doublon
- [ ] 500 commandes simulées : rapprochement à 0 FCFA d'écart, aucun reversement en double après coupure réseau ou notification répétée
- [ ] Charge de 5 000 commandes par jour et 500 livreurs connectés : 95 % des appels en moins de 500 ms
- [ ] Revue de sécurité sans défaut critique ni majeur ; documents d'identité chiffrés
- [ ] Tous les écrans disponibles en français et en anglais
- [ ] Remise du code source, des accès (stores, cloud, prestataires), de la documentation d'architecture et d'exploitation, et d'une procédure de restauration testée
- [ ] Si un prestataire externe développe : garantie de correction gratuite des anomalies pendant 3 mois après la mise en production
