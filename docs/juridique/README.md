# Documents juridiques de Tara

Projets rédigés en langage simple, à faire relire par un juriste avant toute mise en service.
Chaque point qui demande son avis est marqué **[À VALIDER]**.

| Document                                                         | Pour qui                    | Où il apparaît                                           |
| ---------------------------------------------------------------- | --------------------------- | -------------------------------------------------------- |
| [Conditions expéditeurs](conditions-expediteurs.md)              | particuliers et boutiques   | app Tara : inscription, puis à chaque version            |
| [Conditions livreurs](conditions-livreurs.md)                    | livreurs partenaires        | app Tara Livreur + contrat papier au bureau              |
| [À savoir pour le destinataire](conditions-destinataires.md)     | destinataires (sans compte) | page de suivi web, lien des SMS                          |
| [Politique de confidentialité](politique-confidentialite.md)     | tous                        | les deux apps et la page de suivi                        |
| [Registre des traitements](registre-des-traitements.md)          | juriste, APDP               | dossier de déclaration (pas affiché dans les apps)       |
| [Contrat de partenariat livreur](contrat-partenariat-livreur.md) | livreurs et leurs garants   | imprimé et signé au bureau (avec l'engagement du garant) |

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

## Perte, vol et dommage (version 2026-11.3)

Rédigé à partir de l'Acte uniforme OHADA relatif aux contrats de transport de marchandises par
route (AUCTMR, 2003), de la loi-cadre n° 2011/012 du 6 mai 2011 portant protection du
consommateur et de l'Acte uniforme OHADA portant organisation des sûretés (2010) :

- **Tara répond du colis** de l'enlèvement à la remise (AUCTMR, obligation de résultat) ;
  exonérations : emballage insuffisant, défaut propre, déclaration fausse, force majeure.
- **Remboursement** : valeur prouvée, plafonnée par la valeur déclarée (500 000 FCFA au plus dans
  l'app) ; sans déclaration, 25 000 FCFA par colis ou 5 000 FCFA/kg si plus élevé (plafond
  légal, art. 18) ; pas de plafond en cas de faute volontaire ou inexcusable (art. 21).
- **Délais** : dommage visible à la remise ou le jour ouvrable suivant ; dommage caché sous
  7 jours, dimanches et jours fériés non compris (art. 14, appliqué dans l'API avec une marge
  pour les fêtes à date mobile) ; prescription d'un an, trois en cas de dol (art. 25).
- **Livreur** : garde du colis, remboursement à Tara (totalité en cas de faute volontaire,
  moitié plafonnée à 25 000 FCFA en cas de négligence), droit de réponse de 7 jours, retenue sur
  le solde puis appel au garant ; retraits gelés pendant une suspension.
- **Garant** : engagement écrit avec mention manuscrite du montant maximal en chiffres et en
  lettres (Acte uniforme sur les sûretés, art. 14), 100 000 FCFA proposés.

Points à faire confirmer par un avocat avant l'ouverture au public : texte exact des articles
cités (le Journal officiel de l'OHADA n'était pas accessible pendant la rédaction), qualification
de Tara comme transporteur, indépendance des livreurs (risque de requalification en contrat de
travail), retenue sur le solde d'un partenaire.
