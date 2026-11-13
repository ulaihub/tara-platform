# Documents juridiques de Tara

Projets rédigés en langage simple, à faire relire par un juriste avant toute mise en service.
Chaque point qui demande son avis est marqué **[À VALIDER]**.

| Document                                                     | Pour qui                    | Où il apparaît                                     |
| ------------------------------------------------------------ | --------------------------- | -------------------------------------------------- |
| [Conditions expéditeurs](conditions-expediteurs.md)          | particuliers et boutiques   | app Tara : inscription, puis à chaque version      |
| [Conditions livreurs](conditions-livreurs.md)                | livreurs partenaires        | app Tara Livreur + contrat papier au bureau        |
| [À savoir pour le destinataire](conditions-destinataires.md) | destinataires (sans compte) | page de suivi web, lien des SMS                    |
| [Politique de confidentialité](politique-confidentialite.md) | tous                        | les deux apps et la page de suivi                  |
| [Registre des traitements](registre-des-traitements.md)      | juriste, APDP               | dossier de déclaration (pas affiché dans les apps) |

## Acceptation « dûment signée » (en place dans les deux apps)

Les textes de ce dossier sont ceux que les apps affichent : après une modification, lancer
`pnpm --filter @tara/api legal` (un test refuse une copie pas à jour). Changer la ligne
« Version AAAA-MM » d'un texte le fait accepter de nouveau par tous.

1. **Texte complet dans l'app**, pas seulement un lien : l'utilisateur fait défiler le texte.
2. **Case à cocher explicite**, non cochée par défaut : « J'ai lu et j'accepte les conditions
   (version 2026-11) et la politique de confidentialité ».
3. **Confirmation par le code SMS** reçu sur son numéro : la personne qui accepte est celle qui
   détient le numéro.
4. **Preuve conservée** : version, date et heure, numéro vérifié, appareil et adresse IP,
   enregistrés au journal d'audit (non modifiable).
5. **Copie consultable** à tout moment dans l'app (Profil › Conditions acceptées).
6. **Nouvelle version** : présentée à l'ouverture de l'app ; sans acceptation, plus de nouvelle
   commande (expéditeurs) ni de nouvelle course (livreurs).
7. **Livreurs** : en plus, contrat de partenariat signé sur papier au bureau lors de la
   validation des pièces.

## Points clés rendus explicites (retours contre paiement)

Le paiement des frais avant de récupérer un colis retourné est écrit dans les conditions
expéditeurs (article 8) et rappelé à trois moments dans l'app :

- au récapitulatif, avant de commander : « En cas d'échec de livraison : nouvelle tentative
  500 F, retour du colis 750 F, à votre charge. Le colis retourné vous est rendu contre
  paiement de ce que votre solde Tara ne couvre pas. » ;
- au moment de choisir après un échec : prix sur chaque choix ;
- une fois le retour choisi : rappel des frais et du paiement à la remise.
