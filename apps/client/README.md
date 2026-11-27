# App Tara (Flutter, Android puis iOS)

Application des expéditeurs, particuliers et marchands (phase 5 : A1, A2, A4, B1 à B5,
C1 à C6, F1, F4, G1). Priorité : le lien de localisation (B3), qui permet au destinataire
de placer lui-même son point.

Même style que l'app livreur : le design (`packages/tara_ui`), le client de l'API et la
session (`packages/tara_core`) et l'outillage de test (`packages/tara_test`) sont partagés.
Pas de maquette dédiée : chaque écran est soumis au porteur du projet avant d'être gardé.

```sh
flutter pub get
flutter gen-l10n
flutter test                      # tests et captures (2 thèmes, 390×844 et 360×640, texte 130 %)
flutter run --dart-define=TARA_API_URL=http://10.0.2.2:3000
```

Identifiant Android : `cm.tara.app` (icône claire ; l'app livreur a l'icône sombre).
Notifications : à brancher quand l'app sera enregistrée dans le projet Firebase.

**Retour sans dette** (PR 94) : après un échec, le prix du retour est annoncé (frais, part du
solde, reste à payer) ; le reste se paie par Mobile Money dans l'app. Non payé à temps : le
colis part au bureau Tara ; l'écran « Colis gardé au bureau Tara » montre l'adresse, les
horaires, les jours restants et le paiement, puis le code de retrait.
