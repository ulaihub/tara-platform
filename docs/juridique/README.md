# Documents juridiques de Tara

Textes rédigés en langage simple au regard du droit camerounais et du droit OHADA (sources
ci-dessous). Les informations sur la société, à renseigner avant la publication, sont marquées
**[À COMPLÉTER]**. Les points à faire confirmer par un avocat sont regroupés en fin de document.

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

## Données personnelles, contrat en ligne, encaissements (version 2026-11.3)

- **Loi n° 2024/017 du 23 décembre 2024** (applicable depuis le 23 juin 2026) : accord des
  personnes recueilli par case à cocher et code SMS ; référent pour la protection des données ;
  déclaration des traitements à l'APDP ; **tout transfert hors du Cameroun soumis à son
  autorisation préalable** (hébergement en France, Twilio, Google, Meta, Anthropic), sanctions
  élevées sinon ; notification d'une violation à l'APDP sous 72 heures (engagement de Tara) ;
  réponse aux demandes sous 30 jours.
- **Conservation** : pièces comptables 10 ans (Acte uniforme OHADA relatif au droit comptable, 2017) ; journal d'audit 5 ans (prescription commerciale).
- **Contrat en ligne** : loi n° 2010/021 du 21 décembre 2010 sur le commerce électronique (le
  document électronique conservé fait foi comme l'écrit ; l'offre en ligne s'accompagne des
  conditions contractuelles).
- **Encaissements des boutiques** : Tara agit comme mandataire de la boutique, via un
  prestataire de paiement agréé (règlement n° 04/18/CEMAC/UMAC/COBAC relatif aux services de
  paiement : seuls les établissements agréés fournissent des services de paiement).

## À faire confirmer par un avocat avant l'ouverture au public

1. Texte exact des articles cités : le Journal officiel de l'OHADA et celui du Cameroun
   n'étaient pas accessibles pendant la rédaction ; les règles viennent de commentaires
   concordants.
2. Qualification de Tara comme transporteur (et non simple intermédiaire) et plafonds de
   remboursement.
3. Indépendance des livreurs (risque de requalification en contrat de travail) et retenue sur
   le solde d'un partenaire.
4. Encaissement pour les boutiques : confirmation écrite par Sebpay de son agrément et du
   statut de Tara dans ce montage (marchand, mandataire ou distributeur).
5. Formalités auprès de l'APDP : forme exacte de la déclaration et des demandes d'autorisation
   de transfert, une fois l'autorité en état de les recevoir.
