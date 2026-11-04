# tara_core

Cœur partagé par l'app livreur (`apps/rider`) et l'app expéditeur (`apps/client`) :

- `api/` : client HTTP de l'API (jeton renouvelé seul, erreurs typées), connexion par code
  SMS (A1), modèles communs (session, utilisateur, position) ;
- `session/` : session et identifiant d'installation dans le stockage chiffré du téléphone ;
- `realtime/` : Socket.IO avec renouvellement du jeton ;
- `push/` : notifications Firebase reçues app ouverte ;
- `network/` : réseau coupé ou rétabli ;
- `phone/` : numéros mobiles camerounais (saisie, affichage).

Ce qui ne concerne qu'une app (courses du livreur, commandes de l'expéditeur) reste dans
l'app.
