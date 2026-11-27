# App Tara Livreur (Flutter, Android)

Construite en **phase 4** (exigences A3, E1 à E9).

Contraintes clés : hors ligne d'abord (file d'actions locale chiffrée), Android 8+ avec 2 Go de RAM,
moins de 25 Mo à télécharger et au plus 32 Mo installée (carte comprise), moins de 5 Mo de données
par heure, GPS adaptatif.
Voir `docs/CAHIER_DES_CHARGES.md` et `docs/ARCHITECTURE.md`.

**Retour sans dette** (PR 94) : le livreur n'encaisse plus rien chez l'expéditeur (retour payé
d'avance). Retour non payé : écran « Déposer au bureau Tara » (adresse, horaires, photo du
dépôt, action gardée hors réseau comme les autres).
