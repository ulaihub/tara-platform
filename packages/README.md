# Paquets partagés

Code partagé entre les applications :

- `tara_ui` : design Tara (couleurs, typographie, composants, animations, icônes, polices) ;
- `tara_core` : client de l'API, session, connexion par code SMS, temps réel, notifications,
  réseau, numéros camerounais ;
- `tara_map` : carte Tara (styles MapLibre sombre et clair, tuiles, choix d'un point) ;
- `tara_test` (tests seulement) : variantes d'écran vérifiées, captures de référence, polices.

L'app livreur (`apps/rider`) et l'app expéditeur (`apps/client`) en dépendent par chemin
(`path: ../../packages/…`).
