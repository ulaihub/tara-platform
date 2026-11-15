# Registre des traitements de données personnelles

Dossier de conformité à la loi n° 2024/017 relative à la protection des données à caractère personnel, à remettre au juriste puis à l'Autorité de protection des données personnelles (APDP). Établi le 13 novembre 2026 à partir du code de la plateforme : chaque durée et chaque destinataire cités ci-dessous correspondent à ce que le logiciel fait réellement.

Les points qui demandent l'avis du juriste sont marqués **[À VALIDER]**. Le registre est à tenir à jour à chaque nouvelle fonction qui touche des données personnelles.

## Responsable du traitement

| Rubrique                              | Valeur                                                                                                             |
| ------------------------------------- | ------------------------------------------------------------------------------------------------------------------ |
| Société                               | **[À VALIDER : raison sociale, forme, RCCM, NIU, adresse du siège à Douala]**                                      |
| Représentant                          | **[À VALIDER : nom et fonction]**                                                                                  |
| Contact pour les personnes concernées | **[À VALIDER : adresse électronique et numéro dédiés]** ; aussi depuis les apps (Profil, « Signaler un problème ») |
| Délégué à la protection des données   | **[À VALIDER : obligatoire ou non pour Tara ; si oui, nom et contact]**                                            |

## Les traitements

### 1. Comptes et connexion

| Rubrique      | Contenu                                                                                                                                                                       |
| ------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Personnes     | expéditeurs (particuliers et boutiques), livreurs, équipe Tara                                                                                                                |
| Données       | numéro de téléphone, nom, langue, appareil (identifiant d'installation, système), adresse IP, sessions ; pour l'équipe : rôles et secret de double authentification (chiffré) |
| Finalité      | créer le compte, se connecter par code SMS, sécuriser les accès                                                                                                               |
| Base légale   | exécution du contrat (conditions acceptées dans l'app) **[À VALIDER]**                                                                                                        |
| Durée         | tant que le compte existe ; codes SMS et sessions expirées supprimés après 30 jours ; compte supprimé à la demande (données effacées ou anonymisées)                          |
| Destinataires | équipe Tara selon son rôle ; opérateur SMS (Orange Cameroun, Twilio en secours) pour l'envoi du code                                                                          |

### 2. Commandes et livraisons

| Rubrique      | Contenu                                                                                                                                                                                                                                                                    |
| ------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Personnes     | expéditeurs, destinataires (sans compte), livreurs                                                                                                                                                                                                                         |
| Données       | adresses et points placés sur la carte, repères, photo de façade et note vocale d'une adresse, nom et numéro du destinataire, contenu déclaré et photo du colis, réponse « serez-vous là ? », codes d'enlèvement et de livraison (hachés), photos de preuve, notes données |
| Finalité      | prendre, attribuer et suivre les livraisons, prouver la remise du colis                                                                                                                                                                                                    |
| Base légale   | exécution du contrat avec l'expéditeur ; intérêt légitime pour les données du destinataire **[À VALIDER]**                                                                                                                                                                 |
| Durée         | coordonnées du destinataire **masquées 30 jours** après la fin de la commande ; commande elle-même gardée avec la comptabilité ; photos de preuve et du colis **90 jours**, sauf litige ou incident ouvert sur la commande                                                 |
| Destinataires | livreur de la course (numéro du destinataire tant que la course est en cours), expéditeur, équipe Tara ; destinataire par SMS ou WhatsApp (lien de suivi)                                                                                                                  |

### 3. Livreurs : validation et suivi des courses

| Rubrique      | Contenu                                                                                                                                                                                                                                                                                                                                |
| ------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Personnes     | livreurs, leurs garants et contacts d'urgence                                                                                                                                                                                                                                                                                          |
| Données       | pièces d'identité et du véhicule, selfie (**chiffrés**), dates d'expiration, garant (nom, numéro), contact d'urgence ; dernière position en ligne (effacée 15 minutes après le dernier envoi) ; **trajet de chaque course** (une position toutes les 10 s, de l'acceptation à la fin) ; alertes de sécurité (SOS) ; notes et fiabilité |
| Finalité      | vérifier l'identité et le droit de conduire, attribuer les courses aux plus proches, sécurité du livreur et des colis, preuves en cas de litige, lutte contre la fraude                                                                                                                                                                |
| Base légale   | exécution du contrat de partenariat ; intérêt légitime pour le trajet (sécurité, fraude) **[À VALIDER]**                                                                                                                                                                                                                               |
| Durée         | pièces : tant que le compte existe, effacées à sa suppression, et **90 jours** après le refus d'une candidature ; trajets détaillés **90 jours**, sauf litige ou incident ouvert (résumé gardé avec la commande)                                                                                                                       |
| Destinataires | équipe Tara (validation, support, répartition ; chaque consultation d'un trajet est tracée) ; la police, appelée par l'équipe, seulement en cas d'alerte SOS déclenchée par le livreur                                                                                                                                                 |

### 4. Paiements, portefeuilles et comptabilité

| Rubrique      | Contenu                                                                                                                                                                                                     |
| ------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Personnes     | expéditeurs, boutiques, destinataires qui paient, livreurs                                                                                                                                                  |
| Données       | montants, numéro Mobile Money et opérateur, références de l'agrégateur, soldes, reversements, retraits, écritures du grand livre                                                                            |
| Finalité      | encaisser, reverser aux boutiques, payer les livreurs, tenir la comptabilité, contrôler les comptes chaque jour                                                                                             |
| Base légale   | exécution du contrat ; obligation légale (comptabilité)                                                                                                                                                     |
| Durée         | durée légale de conservation des pièces comptables **[À VALIDER : 10 ans selon l'Acte uniforme OHADA relatif au droit comptable ?]** ; écritures rattachées à un compte anonyme après suppression du compte |
| Destinataires | équipe finance de Tara ; agrégateur Mobile Money (Sebpay) : numéro, montant, nom du bénéficiaire d'un reversement                                                                                           |

### 5. Notifications

| Rubrique      | Contenu                                                                                                                                        |
| ------------- | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| Personnes     | toutes                                                                                                                                         |
| Données       | numéro ou jeton de notification de l'appareil, contenu du message                                                                              |
| Finalité      | prévenir de l'état des livraisons, des propositions de course, des paiements                                                                   |
| Durée         | numéro effacé de l'historique des messages après 30 jours ; codes à transmettre (chiffrés) effacés après 1 jour                                |
| Destinataires | opérateurs SMS (Orange Cameroun ; Twilio, États-Unis, en secours), WhatsApp (Meta), notifications des téléphones (Google Firebase, États-Unis) |

### 6. Support et litiges

| Rubrique      | Contenu                                                                  |
| ------------- | ------------------------------------------------------------------------ |
| Données       | demandes, échanges, preuves jointes, décisions                           |
| Finalité      | répondre aux demandes, trancher les litiges                              |
| Durée         | **90 jours** après la clôture de la demande (messages et pièces jointes) |
| Destinataires | équipe support de Tara                                                   |

### 7. Analyse automatique de la photo du colis

| Rubrique      | Contenu                                                                                                                                 |
| ------------- | --------------------------------------------------------------------------------------------------------------------------------------- |
| Données       | la photo seule, sans nom ni numéro                                                                                                      |
| Finalité      | proposer la taille et la nature du colis, signaler un objet interdit visible ; l'expéditeur confirme ou corrige, rien n'est décidé seul |
| Destinataires | Anthropic (États-Unis)                                                                                                                  |

### 8. Sécurité et journal d'audit

| Rubrique    | Contenu                                                                                                                                |
| ----------- | -------------------------------------------------------------------------------------------------------------------------------------- |
| Données     | actions sensibles de l'équipe et des utilisateurs (qui, quoi, quand, adresse IP, appareil), journaux techniques sans numéros ni jetons |
| Finalité    | sécurité, preuve des acceptations des conditions, enquête en cas d'incident                                                            |
| Base légale | obligation de sécurité ; intérêt légitime                                                                                              |
| Durée       | journal d'audit non modifiable, conservé sans limite aujourd'hui **[À VALIDER : durée]**                                               |

## Transferts hors du Cameroun

| Prestataire                        | Pays                                                                                       | Données                                                | Pourquoi                                                                        |
| ---------------------------------- | ------------------------------------------------------------------------------------------ | ------------------------------------------------------ | ------------------------------------------------------------------------------- |
| Twilio                             | États-Unis                                                                                 | numéro, message                                        | secours si l'opérateur SMS camerounais échoue                                   |
| Google Firebase                    | États-Unis                                                                                 | jeton de l'appareil, titre et texte de la notification | notifications des téléphones                                                    |
| Meta (WhatsApp)                    | **[À VALIDER : pays de traitement]**                                                       | numéro, message                                        | messages aux destinataires (si activé)                                          |
| Anthropic                          | États-Unis                                                                                 | photo du colis                                         | analyse automatique                                                             |
| Hébergeur et stockage des fichiers | Hostinger, centre de données de Paris (France) ; **[À VALIDER : conditions du transfert]** | toutes les données                                     | serveurs de la plateforme ; le stockage compatible S3 permet de choisir le pays |

**[À VALIDER : conditions des transferts (autorisation de l'APDP, garanties contractuelles) et clauses à signer avec chaque prestataire.]**

## Mesures de sécurité

Détail dans [`docs/SECURITE.md`](../SECURITE.md). En résumé : connexion par code SMS, double authentification pour l'équipe, droits par rôle vérifiés sur chaque route, pièces d'identité et secrets chiffrés (AES-256-GCM), échanges chiffrés, base de données à moindre privilège, journal d'audit non modifiable, masquage automatique des destinataires après 30 jours, revue de sécurité sans défaut critique ni majeur (13 novembre 2026).

## Droits des personnes

| Droit                     | Comment                                                                                                                                                                                                                                                               |
| ------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Information               | politique de confidentialité affichée en entier dans les apps et sur la page de suivi, acceptée par case à cocher et code SMS                                                                                                                                         |
| Accès et portabilité      | depuis l'app : téléchargement de toutes ses données (fichier lisible)                                                                                                                                                                                                 |
| Effacement                | depuis l'app : suppression du compte, confirmée par code SMS (livreurs : fermeture demandée depuis l'app, faite par un administrateur) ; refusée tant qu'une commande est en cours, qu'une somme reste due, qu'un solde reste chez Tara ou qu'un retrait est en cours |
| Rectification, opposition | auprès du contact ci-dessus **[À VALIDER : délai de réponse]**                                                                                                                                                                                                        |
| Destinataires sans compte | contact indiqué sur la page de suivi **[À VALIDER]**                                                                                                                                                                                                                  |

## Violation de données

Procédure dans [`docs/SECURITE.md`](../SECURITE.md) (« Réponse à un incident ») : détecter, contenir, évaluer avec le journal d'audit, notifier, corriger. **[À VALIDER : délai et forme de la notification à l'APDP et aux personnes.]**

## Questions pour le juriste

1. Déclaration ou autorisation préalable auprès de l'APDP : laquelle pour chaque traitement ci-dessus, en particulier le suivi de position des livreurs et les pièces d'identité ?
2. Délégué à la protection des données : obligatoire pour Tara ?
3. Transferts hors du Cameroun : conditions pour Twilio, Google, Meta, Anthropic ; contraintes sur le pays d'hébergement.
4. Durées de conservation : 90 jours retenus par le porteur du projet (photos, support, pièces des livreurs refusés) ; restent à confirmer celles des pièces comptables et du journal d'audit.
5. Base légale des données du destinataire (il n'a pas de compte et n'a rien accepté).
6. Délai et forme de la notification d'une violation de données.
7. Mise à jour de la politique de confidentialité : une nouvelle version sera présentée à tous les utilisateurs, qui devront l'accepter de nouveau.

Le logiciel applique ces durées automatiquement chaque nuit : destinataires (30 jours) ; trajets, photos, demandes au support et pièces des livreurs refusés (90 jours).
