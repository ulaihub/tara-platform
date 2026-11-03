# Tara Livreur — Passation design → développement (Flutter)

> Document destiné à Claude Code. Il traduit la maquette de l'app livreur Tara en spécifications directement implémentables.
> **Règle de priorité :** le **cahier des charges** fait foi pour le fonctionnel, les règles métier et le stack technique. **Ce document et la maquette** font foi pour le visuel, les composants et les animations. En cas de contradiction, signaler l'écart plutôt que trancher en silence.

---

## 0. Sources

| Source | Contenu | Accès |
|---|---|---|
| Maquette en ligne | 2 pages (Thème sombre / Thème clair), 15 écrans chacune, prototype cliquable | https://claude.ai/artifact/KnQq1vyMR4dXTkeVkgejg6 |
| Code source des écrans | Un fichier `.dc.html` par écran : valeurs exactes de couleurs, tailles, keyframes, logique d'état | Dossier `maquette/` livré avec ce document (copie hors ligne) |
| Logos | Versions transparentes pour fond sombre et fond clair | Dossier `assets/` livré avec ce document |

**Lire le code d'un écran :** chaque `.dc.html` est du HTML avec styles en ligne. Les animations sont dans le bloc `<style>` du `<helmet>` ; la logique (compte à rebours, sélection, maintien SOS) est dans le `<script type="text/x-dc">` en bas du fichier. Ignorer `support.js`, `<x-dc>`, `{{…}}` et `<sc-if>`/`<sc-for>` : ce sont des mécanismes de l'outil de maquette (gabarits et conditions), pas des choses à reproduire.

**Correspondance écrans ↔ fichiers**

| # | Écran | Sombre | Clair |
|---|---|---|---|
| 01 | Connexion par SMS | `Main.dc.html` | `MainClair.dc.html` |
| 02 | Code SMS | `CodeSMS.dc.html` | `CodeSMSClair.dc.html` |
| 03 | Inscription — profil | `Inscription.dc.html` | `InscriptionClair.dc.html` |
| 04 | Pièces justificatives | `Pieces.dc.html` | `PiecesClair.dc.html` |
| 05 | Accueil — hors ligne | `AccueilHorsLigne.dc.html` | `AccueilHorsLigneClair.dc.html` |
| 06 | Accueil — en ligne | `AccueilEnLigne.dc.html` | `AccueilEnLigneClair.dc.html` |
| 07 | Proposition de course (30 s) | `Proposition.dc.html` | `PropositionClair.dc.html` |
| 08 | Enlèvement | `Enlevement.dc.html` | `EnlevementClair.dc.html` |
| 09 | Livraison | `Livraison.dc.html` | `LivraisonClair.dc.html` |
| 10 | Échec de livraison | `Echec.dc.html` | `EchecClair.dc.html` |
| 11 | Retour du colis | `Retour.dc.html` | `RetourClair.dc.html` |
| 12 | Encaissement | `Encaissement.dc.html` | `EncaissementClair.dc.html` |
| 13 | Historique & gains | `Gains.dc.html` | `GainsClair.dc.html` |
| 14 | Bouton d'alerte (SOS) | `Alerte.dc.html` | `AlerteClair.dc.html` |
| 15 | Hors connexion | `HorsConnexion.dc.html` | `HorsConnexionClair.dc.html` |

**Données de la maquette = exemples.** Noms (Koffi Yao, Boutique Awa Mode, Mariam Touré), quartiers d'Abidjan, indicatif +225, montants en FCFA, numéros de course `TR-xxxxx`, opérateurs Mobile Money (Orange Money, MTN MoMo, Moov Money, Wave) : tout vient du backend ou de la configuration. `[NUMÉRO_SECOURS]` est un emplacement à remplir.

**Cadre de la maquette :** 390 × 844 (iPhone 14/15). La maquette n'a pas de barre d'état : les marges hautes de 56–64 px incluent la zone système. En Flutter : `SafeArea` puis 8–16 px. Tester aussi sur un Android compact (360 × 640) et avec une taille de texte système à 130 %.

---

## 1. Principes

1. **Verre dépoli (glassmorphism)** : cartes et barres semi-transparentes floutant ce qui est derrière, bordure fine claire, reflet intérieur en haut.
2. **Liquide** : des formes organiques en mouvement lent derrière le verre, et des **niveaux de liquide** qui portent de l'information (temps restant, progression, maintien du SOS).
3. **Épure** : une action principale par écran (bouton dégradé orange en bas), le reste en verre neutre.
4. **Lisibilité terrain** : les livreurs sont dehors, en plein soleil, souvent sur des Android d'entrée de gamme → contrastes ≥ 4,5:1, cibles tactiles ≥ 48 dp, et un **mode effets réduits** (voir §5.4).
5. **Deux thèmes** : sombre et clair, suivant le réglage système par défaut, avec bascule manuelle dans le profil.

---

## 2. Design tokens

### 2.1 Couleurs

Valeurs CSS reprises telles quelles de la maquette. En Dart, `rgba(r,g,b,a)` → `Color.fromRGBO(r, g, b, a)`.

**Marque (identique dans les deux thèmes)**

| Token | Valeur | Usage |
|---|---|---|
| `brandAmber` | `#FFB000` | début du dégradé |
| `brandOrange` | `#FF6A00` | milieu du dégradé, points, pastilles |
| `brandRed` | `#FF3D00` | fin du dégradé |
| `brandGradient` | `#FFB000 0 %` → `#FF6A00 55 %` → `#FF3D00 100 %`, angle CSS 100° | boutons principaux, segment actif, barre de progression, anneau |
| `onBrand` | `#140800` | texte et icônes **sur** le dégradé (le blanc ne passe pas le contraste) |
| `focusBorder` | `#FF8A3D` + halo 4 px `rgba(255,106,0,0.14)` | champ actif, case de code active |
| `sos` | `#E52535` (texte blanc) | bouton SOS, bouton Secours |

Dégradé en Flutter (100° CSS = vers la droite, incliné de 10° vers le bas) :

```dart
const brandGradient = LinearGradient(
  begin: Alignment.centerLeft,
  end: Alignment.centerRight,
  colors: [Color(0xFFFFB000), Color(0xFFFF6A00), Color(0xFFFF3D00)],
  stops: [0, .55, 1],
  transform: GradientRotation(10 * math.pi / 180),
);
```

**Thème** (sombre / clair)

| Token | Sombre | Clair | Usage |
|---|---|---|---|
| `bg` | `#0A0A0F` | `#F6F2EC` | fond d'écran |
| `textPrimary` | `#FFFFFF` | `#16120E` | titres, valeurs |
| `textSecondary` | `rgba(255,255,255,0.72)` | `rgba(22,18,14,0.70)` | sous-titres, libellés |
| `textTertiary` (minimum) | `rgba(255,255,255,0.62)` | `rgba(22,18,14,0.66)` | aides, métadonnées — ne jamais descendre en dessous |
| `accentText` | `#FFB15C` | `#C2410C` | liens, sur-titres, étape active, onglet actif |
| `accentStrongText` | `#FFC283` | `#9A3412` | montants à encaisser, valeur mise en avant |
| `glass` | `rgba(255,255,255,0.06)` | `rgba(255,255,255,0.58)` → `0.62` | cartes |
| `glassBorder` | `rgba(255,255,255,0.14)` | `rgba(255,255,255,0.95)` | bordure 1 px des cartes |
| `glassHighlight` | ombre interne `0 1 0 rgba(255,255,255,0.12)` | ombre interne `0 1 0 #FFFFFF` | reflet du haut |
| `glassStrong` | `rgba(20,20,26,0.84)` | `rgba(255,255,255,0.88)` | panneaux du bas (bottom sheets) |
| `glassBar` | `rgba(22,22,28,0.60)` | `rgba(255,255,255,0.72)` | barre d'onglets, pastilles sur la carte |
| `chipBg` | `rgba(255,255,255,0.05)` | `rgba(255,255,255,0.70)` | puces non sélectionnées |
| `chipBorder` | `rgba(255,255,255,0.14)` | `rgba(22,18,14,0.10)` | bordure des puces et des champs |
| `chipSelected` | dégradé 160° `rgba(255,176,0,0.28)` → `rgba(255,61,0,0.20)` + bordure `rgba(255,177,92,0.9)` | dégradé 160° `rgba(255,176,0,0.26)` → `rgba(255,106,0,0.16)` + bordure 1,5 px `#FF8A3D` | puce/radio sélectionnée |
| `inputBg` | `rgba(10,10,15,0.45)` | `#FFFFFF` | champs de saisie |
| `placeholder` | `rgba(255,255,255,0.50)` | `rgba(22,18,14,0.50)` | texte indicatif |
| `accentTint` | fond `rgba(255,138,0,0.10–0.16)`, bordure `rgba(255,177,92,0.25–0.40)` | fond `rgba(255,138,0,0.10–0.14)`, bordure `rgba(255,106,0,0.28–0.35)` | encarts « à encaisser », espèces en main |
| `success` (texte/icône) | `#4ADE9B` | `#0E7F57` | envoyé, livré, monnaie à rendre, appeler |
| `successTint` | `rgba(74,222,155,0.14–0.16)` + bordure `0.40` | `rgba(16,160,110,0.12)` + bordure `0.35` | fonds associés |
| `online` (point) | `#4ADE9B` + halo | `#10A06E` + halo | statut en ligne |
| `offline` (point) | `#8A8B93` | `#8A8580` | statut hors ligne |
| `dangerText` | `#FF7A85` / `#FF9AA2` | `#C81E2C` / `#B3121F` | appel manqué, motif d'échec |
| `dangerTint` | `rgba(229,37,53,0.16–0.18)` | `rgba(229,37,53,0.10)` | fonds associés |
| `warningText` | `#FFC24D` | `#B45309` | actions en attente (hors connexion) |
| `warningBanner` | fond `rgba(40,28,12,0.72)`, bordure `rgba(255,177,92,0.5)` | fond `rgba(255,247,230,0.9)`, bordure `rgba(217,119,6,0.45)` | bandeau hors connexion |
| `alertBg` | `#0C080A` | `#FBF1F0` | fond de l'écran SOS |
| `shadow` | `0 20 40 rgba(0,0,0,0.35)` | `0 16 36 rgba(140,70,10,0.10–0.14)` | ombre portée des cartes |
| `brandShadow` | `0 14 30 rgba(255,90,0,0.38)` | `0 14 30 rgba(255,90,0,0.32)` | sous le bouton principal |

**Carte (fond de plan)** — à transposer dans le style JSON du fournisseur de cartes retenu par le cahier des charges :

| Élément | Sombre | Clair |
|---|---|---|
| Sol | `#0D0E13` | `#ECE7E0` |
| Bâtiments / îlots | `#121319` | `#E3DDD4` |
| Rues secondaires | `#1A1C24` | `#F8F6F2` |
| Grands axes | `#252833` | `#FFFFFF` |
| Eau (lagune) | `#0F1922` | `#CFE2EA` |
| Itinéraire | trait 5 px dégradé `#FFB000`→`#FF3D00`, halo 12 px opacité 0,25, tirets 14/6 animés | idem |
| Itinéraire retour | dégradé `#FFFFFF`→`#FFB000` | dégradé `#6B6560`→`#FF8A00` |
| Carte hors connexion | désaturée (niveaux de gris), opacité 0,6 | désaturée, opacité 0,85 |

Implémentation conseillée : une `ThemeExtension<TaraColors>` avec deux instances `TaraColors.dark` / `TaraColors.light`, `ThemeMode.system` par défaut.

### 2.2 Typographie

Deux familles (licence OFL) : **Sora** (titres, chiffres) et **Plus Jakarta Sans** (texte). **Les embarquer dans les assets** plutôt que les télécharger à l'exécution : l'app doit fonctionner hors connexion.

| Rôle | Police | Taille / graisse | Interlettrage | Exemple |
|---|---|---|---|---|
| Chiffre géant | Sora | 72 / 800 | −0,04 em | compte à rebours |
| Montant XL | Sora | 40–42 / 800 | −0,02 à −0,03 em | gain proposé, montant à encaisser |
| Montant L | Sora | 34–36 / 800 | −0,02 em | gains du jour / de la période |
| Titre écran | Sora | 30 / 700 (accès), 26 (formulaires), 22 (en course), 19 (titre de panneau) | −0,02 em | « Prêt à prendre la route ? » |
| SOS | Sora | 44 / 800 | +0,04 em | bouton d'alerte |
| Titre carte | Sora | 16–18 / 700 | 0 | « Recherche de courses… » |
| Texte principal | Plus Jakarta Sans | 15 / 400–700, interligne 1,5 | 0 | paragraphes, noms |
| Texte | Plus Jakarta Sans | 14 / 600–700 | 0 | lignes de liste |
| Libellé | Plus Jakarta Sans | 13 / 600–700 | 0 | libellés de champ |
| Petit | Plus Jakarta Sans | 12 / 500–700 | 0 | métadonnées, aides |
| Micro / sur-titre | Plus Jakarta Sans | 11 / 700, majuscules | +0,08 em (sur-titre 13 px : +0,12 em) | « ENLÈVEMENT · 1,2 KM », onglets |
| Bouton principal | Plus Jakarta Sans | 17 / 700 (Accepter : 800) | 0 | |

- En Flutter, `letterSpacing` est en px : `em × fontSize` (ex. −0,02 em à 30 px = −0,6).
- Tous les montants, heures et compteurs : `fontFeatures: [FontFeature.tabularFigures()]`.
- Le montant est suivi de l'unité « FCFA » en 15–18 / 600, couleur `textSecondary`.

### 2.3 Espacements, rayons, tailles

- **Marges latérales** : 24 (écrans d'accès), 20 (écrans en course), 16 (en-têtes sur carte), 12 (carte du bas sur l'accueil en ligne).
- **Écarts** : 4, 6, 8, 10, 12, 14, 16, 20, 22, 28.
- **Rayons** : 10 (barres d'histogramme), 12–16 (tuiles d'icône, petits boutons), 14–18 (champs, puces), 20 (boutons principaux), 22–28 (cartes), 32 (haut des panneaux du bas), cercle (avatars, gros boutons ronds).
- **Hauteurs** : bouton principal 58 (60 sur la proposition) ; bouton secondaire 44–54 ; champ 46–56 ; case de code 64 (SMS) / 58 (enlèvement, livraison) ; élément de barre d'onglets 52 ; bouton icône 44–52 ; tuile d'icône 38–52.
- **Cibles tactiles** : la maquette descend parfois à 44 px ; en Flutter, garder **≥ 48 dp** (au besoin zone tactile élargie sans changer le visuel).

### 2.4 Recette « verre »

| Paramètre | Sombre | Clair |
|---|---|---|
| Flou d'arrière-plan | 20–30 (24 par défaut) | idem |
| Saturation d'arrière-plan | 160 % | 180 % |
| Remplissage | `glass` / `glassStrong` / `glassBar` | idem |
| Bordure | 1 px `glassBorder` | 1 px `glassBorder` |
| Reflet | ombre interne 1 px en haut | idem |
| Ombre portée | `shadow` | `shadow` |

```dart
/// Carte en verre. L'ombre est posée À L'EXTÉRIEUR du clip, sinon elle est coupée.
class GlassCard extends StatelessWidget {
  const GlassCard({super.key, required this.child, this.radius = 26,
      this.padding = const EdgeInsets.all(18), this.fill, this.blur = 24});
  final Widget child;
  final double radius;
  final EdgeInsets padding;
  final Color? fill;
  final double blur;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<TaraColors>()!;
    final reduce = TaraEffects.of(context).reduced; // voir §5.4
    final shape = BorderRadius.circular(radius);
    final surface = DecoratedBox(
      decoration: BoxDecoration(
        // En mode effets réduits : surface plus opaque, pas de flou.
        color: reduce ? c.glassFallback : (fill ?? c.glass),
        borderRadius: shape,
        border: Border.all(color: c.glassBorder),
      ),
      child: Padding(padding: padding, child: child),
    );
    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: shape, boxShadow: c.shadow),
      child: ClipRRect(
        borderRadius: shape,
        child: reduce
            ? surface
            : BackdropFilter(filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur), child: surface),
      ),
    );
  }
}
```

`glassFallback` (à ajouter) : sombre `#1A1A21` à 92 % ; clair `#FFFFFF` à 94 %.
Ajuster `sigma` à l'œil : selon le moteur de rendu, l'équivalent visuel d'un `blur(24px)` CSS est entre 12 et 24.

---

## 3. Composants

| Composant | Spécification | Écrans |
|---|---|---|
| **PrimaryButton** | h 58, rayon 20, `brandGradient`, texte `onBrand` 17/700, ombre `brandShadow` + reflet interne `0 1 0 rgba(255,255,255,0.45–0.5)`. Animation **reflet** (§4 A4). Icône optionnelle à droite (flèche, coche) 20 px trait 2,2. | tous |
| **GlassButton** (secondaire) | h 44–60, rayon 14–20, verre, texte `textPrimary` 15–16/700. | Refuser, Reprendre, Réessayer |
| **IconButton verre** | 44–52 carré, rayon 15–18, verre, icône 20–22 trait 2. `Semantics(label: …)` obligatoire. | retour, notifications, recentrer, fermer |
| **CallButton** | 48 rond, `successTint` + bordure, icône téléphone `success`. Ouvre le composeur (`tel:`). | enlèvement, livraison, retour |
| **SosButton (petit)** | 48–52, rayon 16–18, `sos`, « SOS » Sora 11–12/800 blanc, ombre rouge. → écran Alerte. | accueil en ligne, enlèvement, livraison, retour |
| **TextField** | h 48–56, rayon 14–18, `inputBg`, bordure `chipBorder` ; actif : bordure `focusBorder` + halo 4 px. Libellé au-dessus 12–13/600 `textSecondary`. | connexion, inscription, livraison sans code, Mobile Money |
| **PhonePrefix** | bouton 56 h, « +225 » + chevron, ouvre le sélecteur de pays. | connexion |
| **CodeCells** | n cases (6 pour SMS, 4 pour les codes de course), écart 10. Case remplie : verre + chiffre Sora 24–26/700. **Case active** : bordure `focusBorder` + halo + **vague liquide** basse (A2) + **curseur clignotant** (A11). | 02, 08, 09 |
| **ChoiceChips (radio)** | grille 2 ou 4 colonnes, h 46–50, rayon 14–15 ; non sélectionnée `chipBg`/`chipBorder` ; sélectionnée `chipSelected`. Rôle radio (Semantics `inMutuallyExclusiveGroup`). | véhicule, motif d'échec, montant reçu, opérateur |
| **LiquidSegmented** | conteneur h 56, rayon 20, 2 segments ; curseur en dégradé qui glisse avec **rebond élastique** (A9) ; texte actif `onBrand`, inactif `textSecondary`. Variante compacte h 34 (Jour/Semaine/Mois). | encaissement, gains |
| **ProgressBar liquide** | h 8, rayon 8, piste 10 % ; remplissage dégradé **qui coule** (A10). | inscription, pièces |
| **Stepper de course** | 3 colonnes : barre 4 px + libellé 12. Faite : barre orange 45–60 % + « ✓ » ; active : dégradé + texte `accentText` 700 ; à venir : barre neutre. | enlèvement, livraison |
| **StatusPill / OnlineToggle** | pilule h 56, rayon 22, `glassBar` : point de statut + « En ligne » + interrupteur 64×38 dégradé, bouton blanc 30 px qui **se déforme doucement** (A8). Toucher → hors ligne. | accueil en ligne |
| **PowerButton** | rond 210, verre, **vague liquide basse** (A2) + 2 **ondes** (A6), icône marche/arrêt 40 + « Passer en ligne » Sora 18/700. | accueil hors ligne |
| **CountdownRing** | 236 px : anneau 6 px (piste 10 %, progression `brandGradient`, extrémités arrondies) + disque de verre inset 14 + **niveau liquide = temps restant** (A3) + chiffre 72 + « secondes ». | proposition |
| **GooLoader** | 3 gouttes qui fusionnent (A5). 76×40 (accueil) ou 46×24 (Mobile Money). | 06, 12 |
| **BottomSheet verre** | rayon haut 32, `glassStrong`, bordure haute 1 px, poignée 40×5 ; en clair, ombre `0 -16 40 rgba(140,70,10,0.12)`. | 08–11, 15 |
| **TabBar flottante** | 3 onglets (Accueil, Activité, Profil), conteneur rayon 26, `glassBar`, marges 20 ; onglet actif : fond `rgba(255,106,0,0.14–0.16)`, texte/icône `accentText`. Icône 22 + libellé 11. | 05, 06, 13 |
| **ListRow** | tuile d'icône 38–46 (rayon 12–15, fond teinté selon statut) + titre 14–15/700 + sous-titre 12 + élément à droite (montant Sora 14/700, statut, bouton). Conteneur rayon 18–22. | pièces, gains, hors connexion |
| **Avatar initiales** | 46–48, rond (accueil) ou rayon 16 (vendeur/client), Sora 15/700. | 05, 08–11 |
| **InfoNote** | icône 18 `accentText` + texte 13, interligne 1,5, fond verre léger. | 04 |
| **MapPins** | Livreur : pastille dégradée 24 + bordure blanche 3 + **pulsation** x2 (A6) + cône de direction (accueil). Enlèvement : point orange 9 + bordure blanche 3 + halo 16 à 25 %. Destination : anneau blanc 5 px orange. | 06, 08, 09, 11, 15 |
| **OfflineBanner** | rayon 22, `warningBanner`, icône wifi barré dans tuile 40, titre 15/700 + détail 12, **filet lumineux** animé en bas (A13). | 15 |
| **Icônes** | style « trait » 2 px, extrémités arrondies (famille type Lucide). Les tracés exacts sont dans les `.dc.html`. | tous |

---

## 4. Catalogue des animations

Chaque animation : **où**, **valeurs exactes de la maquette**, **implémentation Flutter**.
Courbes CSS → Flutter : `ease-in-out` → `Curves.easeInOut` ; `ease-out` → `Curves.easeOut` ; `linear` → `Curves.linear` ; `steps(1)` → bascule franche.

### A1 — Formes liquides de fond (« blobs »)
- **Où :** fonds de presque tous les écrans (2 à 3 formes).
- **Maquette :** disque 220–380 px, dégradé radial `#FFB000`→`#FF6A00`→`#FF3D00` (en clair, 2ᵉ forme `#FFD27A`→`#FF8A00`), flou 34–80 px, opacité sombre 0,22–0,60 / clair 0,30–0,55. Deux animations cumulées :
  - **morph** 14 s `ease-in-out` en boucle (10–12 s sur Proposition et Alerte), rayons CSS « horizontaux / verticaux » (coins haut-gauche, haut-droit, bas-droit, bas-gauche) :
    - 0 % et 100 % : `42% 58% 70% 30% / 45% 45% 55% 55%`
    - 33 % : `70% 30% 46% 54% / 30% 29% 71% 70%`
    - 66 % : `100% 60% 60% 100% / 100% 100% 60% 60%`
  - **drift** 20 s `ease-in-out` (14–16 s sur Proposition et Alerte) : translation `(0,0)` → `(24,−32)` avec échelle 1 → 1,12 → retour.
  - Les formes d'un même écran sont décalées (`animation-delay` −3 à −8 s).
- **Flutter :** `BorderRadius.only` avec `Radius.elliptical(w·h%, h·v%)` interpolé entre les 3 états clés (Skia ramène les rayons trop grands à l'échelle, comme CSS). Pour les performances, **remplacer le flou réel par un `RadialGradient` qui s'estompe vers le transparent** (rendu quasi identique, coût nul). Un seul `AnimationController` par écran, `RepaintBoundary` autour du fond.

```dart
BorderRadius blobRadius(Size s, List<double> h, List<double> v) => BorderRadius.only(
  topLeft: Radius.elliptical(s.width * h[0], s.height * v[0]),
  topRight: Radius.elliptical(s.width * h[1], s.height * v[1]),
  bottomRight: Radius.elliptical(s.width * h[2], s.height * v[2]),
  bottomLeft: Radius.elliptical(s.width * h[3], s.height * v[3]),
);
const blobKeys = [
  ([.42, .58, .70, .30], [.45, .45, .55, .55]),
  ([.70, .30, .46, .54], [.30, .29, .71, .70]),
  ([1.0, .60, .60, 1.0], [1.0, 1.0, .60, .60]),
];
```

### A2 — Vague liquide (niveau de remplissage)
- **Maquette :** un grand carré à coins très arrondis (rayon 43 %) qui tourne en continu à l'intérieur d'un conteneur découpé : son bord supérieur forme la vague. Souvent 2 couches : avant (rayon 43 %, dégradé de marque, 5–7 s) et arrière (rayon 40 %, couleur plus sombre/transparente, 8–11 s, **sens inverse**, ~8 px plus haut).
- **Flutter :** plus simple et plus léger avec un `CustomPainter` qui dessine 2 sinusoïdes (amplitude 6–8 px, une longueur d'onde ≈ largeur du conteneur), découpé par `ClipOval`/`ClipRRect`. Le niveau est une valeur animée.

```dart
class LiquidWavePainter extends CustomPainter {
  LiquidWavePainter({required this.phase, required this.level, required this.front, required this.back, this.amplitude = 7});
  final double phase;     // 0..2π, boucle continue
  final double level;     // 0 = vide, 1 = plein
  final Gradient front;   // couche avant
  final Color back;       // couche arrière (plus sombre / plus transparente)
  final double amplitude;

  Path _wave(Size s, double ph, double amp, double lift) {
    final y0 = s.height * (1 - level) - lift;
    final p = Path()..moveTo(0, s.height);
    for (double x = 0; x <= s.width + 2; x += 2) {
      p.lineTo(x, y0 + math.sin(x / s.width * 2 * math.pi + ph) * amp);
    }
    return p..lineTo(s.width, s.height)..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(_wave(size, -phase * .7 + 1.3, amplitude * 1.2, 8), Paint()..color = back);
    canvas.drawPath(_wave(size, phase, amplitude, 0),
        Paint()..shader = front.createShader(Offset.zero & size));
  }

  @override
  bool shouldRepaint(LiquidWavePainter o) => o.phase != phase || o.level != level;
}
```

| Usage | Niveau | Couleurs (avant / arrière) | Vitesse |
|---|---|---|---|
| Bouton « Passer en ligne » (05) | ≈ 35 % fixe | dégradé vertical `#FFB000`→`#FF6A00` 40 %→`#FF3D00` / `rgba(255,61,0,0.45)` (clair 0,35) | 6 s / 9 s |
| Compte à rebours (07) | temps restant / 30 | dégradé `#FFB000` 0 %, `#FF6A00` 18 %, `#FF3D00` 50 % / `rgba(255,61,0,0.5)` (clair `rgba(255,106,0,0.35)`) | 5 s / 8 s |
| Case de code active (02, 08, 09) | ≈ 35 % | `rgba(255,138,0,0.5)`→`rgba(255,61,0,0.3)` (clair `rgba(255,176,0,0.55)`→`rgba(255,106,0,0.4)`) | 5 s |
| Pièce en cours d'envoi (04) | **horizontal** = % d'envoi (64 % dans la maquette) | `rgba(255,176,0,0.22)`→`rgba(255,61,0,0.18)` | 7 s |
| Carte « À encaisser » (12) | ≈ 30 % en bas | `rgba(255,176,0,0.75)`→`rgba(255,106,0,0.55)` / `rgba(255,61,0,0.35)` (clair : 0,7 / 0,55 / 0,22) | 7 s / 11 s |
| Bouton SOS maintenu (14) | 0 → 100 % en 3 s | sombre : `#FF4D5A`→`#E52535` 30 %→`#B3121F` sur fond verre rouge ; clair : liquide rouge foncé `#A50F1C`→`#8F0E19`→`#6E0A13` qui monte dans un bouton rouge vif | 4 s / 7 s |
| Barre du jour (13) | reflet en haut de la barre | `rgba(255,214,140,0.55)` (clair `rgba(255,230,180,0.6)`) | 4 s |

### A3 — Compte à rebours 30 s (Proposition)
- Départ à 30, décrément chaque seconde ; anneau : `strokeDasharray 710` (2π × 113), décalage = `710 × (1 − restant/30)`, transition **1 s linéaire** ; niveau du liquide : même ratio, transition 1 s linéaire.
- Chiffre 72 px Sora 800, centré au-dessus du liquide. Sombre : blanc + ombre `0 4 20 rgba(0,0,0,0.35)`. Clair : `#16120E` + halo blanc léger.
- Dans la maquette, le compteur repart à 30 en boucle (démo) ; dans l'app, à 0 la proposition expire (règle à prendre dans le cahier des charges).
- Flutter : `CustomPainter` pour l'anneau (`drawArc`, `StrokeCap.round`, `SweepGradient` ou shader linéaire) + `LiquidWavePainter` ; `TweenAnimationBuilder<double>(duration: 1s, curve: linear)` sur le ratio.
- **Accessibilité :** `Semantics(liveRegion: true, label: 'Temps restant pour accepter : $n secondes')`. **Suggestion à valider :** vibration à l'arrivée de la proposition et dans les 5 dernières secondes.

### A4 — Reflet qui balaie les boutons principaux
- Bande blanche de 70 px, dégradé horizontal `transparent → rgba(255,255,255,0.55) → transparent` (clair : 0,6), inclinée de −20°. Translation de −140 % à +420 % de sa largeur sur **55 %** d'un cycle de **3,6 s** (`ease-in-out`), puis pause jusqu'à la fin du cycle (Proposition : cycle de 3 s).
- Flutter : `AnimationController(duration: 3600ms)..repeat()`, `t = Curves.easeInOut.transform((v / .55).clamp(0, 1))`, `dx = lerp(-1.4 × 70, 4.2 × 70, t)`, bande dans un `ClipRRect` du bouton avec `Transform(skewX: −20°)`. Le reflet est sous le libellé.

### A5 — Gouttes qui fusionnent (« goo »)
- **Où :** « Recherche de courses… » (06), attente de paiement Mobile Money (12).
- **Maquette :** une goutte centrale (24 px, `#FF6A00`, « respire » : échelle 1 → 1,18 → 1, 1,6 s) et deux gouttes de 16 px (`#FFB000` et `#FF3D00`) qui partent de ±26 px et rejoignent le centre (1,6 s `ease-in-out`, en boucle). Variante compacte : 16 px + 12 px, ±14 px, 1,4 s. Effet obtenu par flou 5 px + seuillage alpha `α' = 22·α − 10`.
- **Flutter :**

```dart
ColorFiltered(
  // seuil alpha : α' = 22·α − 10 (en échelle 0–255 : décalage −10 × 255)
  colorFilter: const ColorFilter.matrix(<double>[
    1, 0, 0, 0, 0,
    0, 1, 0, 0, 0,
    0, 0, 1, 0, 0,
    0, 0, 0, 22, -2550,
  ]),
  child: ImageFiltered(
    imageFilter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
    child: GooDots(animation: controller), // 3 cercles positionnés par l'animation
  ),
)
```

### A6 — Pulsations et ondes
- **Position du livreur :** 2 disques `rgba(255,106,0,0.45)` (clair 0,40) qui grandissent de 0,6 → 2,6 et s'effacent de 0,7 → 0, 2,4 s `ease-out`, décalés de 1,2 s.
- **Bouton « Passer en ligne » :** 2 anneaux 1,5 px `rgba(255,138,0,0.55)`, échelle 0,92 → 1,45, opacité 0,55 → 0, 3 s `ease-out`, décalés de 1,5 s.
- **Bouton SOS :** 2 anneaux 2 px `rgba(255,77,90,0.6)`, échelle 0,95 → 1,5, 2,2 s, décalés de 1,1 s.
- Flutter : un contrôleur en boucle, deux `Transform.scale` + `Opacity` avec phase décalée (`(v + 0.5) % 1`).

### A7 — Itinéraire qui s'écoule
- Trait 5 px en tirets 14/6, décalage de −40 px par cycle de 1,2 s linéaire ; halo 12 px opacité 0,2–0,25 dessous.
- Flutter : sur une carte réelle, polyline en tirets (`patterns` de la polyline) + couche halo ; l'animation du décalage dépend du fournisseur de cartes (sinon redessiner via `PathMetrics` dans un overlay).

### A8 — Interrupteur « En ligne »
- Bouton blanc 30 px dont la forme ondule (rayon 50 % ↔ `46% 54% 50% 50% / 54% 46% 54% 46%`), 2,4 s `ease-in-out`.
- Au toucher : passage hors ligne. **Suggestion :** déplacement du bouton 300 ms avec une légère déformation (étirement horizontal 1,15) pendant le trajet.

### A9 — Sélecteur à rebond liquide
- Le curseur dégradé glisse sur 500 ms avec la courbe `cubic-bezier(.6, −.35, .3, 1.45)` (léger recul puis dépassement).
- Flutter : `AnimatedAlign`/`AnimatedPositioned(duration: 500ms, curve: Cubic(0.6, -0.35, 0.3, 1.45))`. Couleur du texte : transition 300 ms.

### A10 — Barre de progression qui coule
- Remplissage `linear-gradient(90°, #FFB000, #FF6A00, #FF3D00, #FF6A00, #FFB000)` sur 200 % de largeur, qui défile en 2,6 s linéaire.
- Flutter : `ShaderMask`, ou `LinearGradient(transform: _SlideGradient(v))` avec `tileMode: TileMode.repeated`.

### A11 — Curseur clignotant
- Trait 2 × 22–24 px, `#FFFFFF` (clair `#16120E`), clignotement 1 s en bascule franche.

### A12 — Point « Nouvelle course »
- Point 8 px `#FF6A00`, opacité 1 → 0,25 → 1, 1,2 s `ease-in-out`.

### A13 — Filet du bandeau hors connexion
- Ligne de 3 px `transparent → #FFB000 → #FF6A00 → transparent` qui défile (200 %), 3 s linéaire.

### A14 — Réessayer (hors connexion)
- Icône de rechargement en rotation 1 s linéaire pendant la tentative ; libellé « Tentative d'envoi… » → si échec, « Toujours hors connexion · Réessayer ». Statut des lignes : « En attente » → « Envoi… ».

### A15 — Maintien du SOS (3 s)
- Appui maintenu : progression +1/12 toutes les 250 ms (3 s), le liquide monte (transition 250 ms linéaire). Libellé : « Maintenir 3 s » → « Encore N s… » → « Envoyée ».
- Relâché avant 100 % : retour à 0 (le liquide redescend). À 100 % : état « Alerte envoyée », titre et texte changent, lien « Annuler l'alerte ».
- Flutter : `GestureDetector(onLongPressStart / onLongPressEnd)` ou `Listener(onPointerDown / onPointerUp / onPointerCancel)` ; `HapticFeedback.heavyImpact()` à l'envoi.
- **Accessibilité :** action alternative pour les lecteurs d'écran (`Semantics(onLongPress: …, label: 'Maintenir 3 secondes pour envoyer une alerte')`) ; la maquette gère aussi Entrée / Espace maintenus.

---

## 5. Règles transverses

### 5.1 Thèmes
- `ThemeMode.system` par défaut ; bascule manuelle dans le profil (écran non dessiné).
- Tous les composants lisent `TaraColors` : aucune couleur codée en dur dans les écrans.
- Le dégradé de marque, `onBrand` et `sos` sont identiques dans les deux thèmes.

### 5.2 Accessibilité
- Contrastes : les valeurs de §2.1 respectent 4,5:1 pour le texte courant ; ne pas descendre sous `textTertiary`.
- Libellés lecteur d'écran repris de la maquette (`aria-label`) : « Retour », « Notifications », « Recentrer la carte », « Alerte de sécurité », « Appeler <nom> », « Vous êtes en ligne. Passer hors ligne », « Chiffre N », etc.
- Groupes radio (véhicule, motif, montant, opérateur) : un seul choix, état annoncé.
- Taille de texte système jusqu'à 130 % sans débordement (textes sur 2 lignes, conteneurs qui grandissent).

### 5.3 Réduire les animations
- Si `MediaQuery.disableAnimationsOf(context)` est vrai, **arrêter les animations décoratives** (A1, A2 rotation de vague, A4, A6, A7, A8, A10, A12, A13).
- **Garder l'information** : le niveau du compte à rebours, la progression du SOS et l'état des boutons changent quand même, sans mouvement de vague.

### 5.4 Performances (Android d'entrée de gamme)
- Un seul `Ticker`/`AnimationController` partagé par écran pour le décor ; `RepaintBoundary` autour des zones animées.
- Arrêter les animations quand l'app est en arrière-plan (`AppLifecycleState`).
- Limiter le nombre de `BackdropFilter` visibles (≈ 3–4 par écran).
- **Mode effets réduits** (`TaraEffects.reduced`) : activé automatiquement sur appareil peu puissant ou à la demande dans le profil ; supprime le flou (surfaces `glassFallback`), fige les formes de fond, garde les niveaux liquides fonctionnels.
- Objectif : 60 i/s sur les écrans de course.

### 5.5 Hors connexion
- Polices et icônes embarquées ; codes et itinéraire de la course en cours gardés sur le téléphone.
- Les actions faites sans réseau (confirmations, encaissements, photos) vont dans une file locale persistante, visible sur l'écran 15, envoyée automatiquement au retour du réseau. Les règles exactes sont dans le cahier des charges.

---

## 6. Fiches écrans

Ordre de lecture recommandé : ouvrir le `.dc.html` correspondant à côté de la fiche.

### 01 · Connexion par SMS
- Fond : 3 formes liquides (haut droite, milieu gauche, bas droite).
- Logo 214 px centré (`assets/tara-logo-dark.png` / `tara-logo-light.png`).
- Sur-titre « ESPACE LIVREUR » 13/700, +0,12 em, `accentText`. Titre « Prêt à prendre la route ? » 30/700. Texte 15 « Connectez-vous avec votre numéro. Nous vous envoyons un code par SMS. »
- Carte verre (rayon 28, marge interne 20) : libellé « Numéro de téléphone », indicatif « +225 » (bouton) + champ téléphone (style actif), aide 12 « Utilisez le numéro lié à votre compte Mobile Money : vos gains y seront versés. »
- Bas : bouton principal « Recevoir le code → » + mentions légales 12 avec 2 liens (CGU, confidentialité).
- → Code SMS.

### 02 · Code SMS
- Bouton retour 48 ; titre « Entrez le code reçu » ; « Envoyé par SMS au **+225 …** · Modifier » (lien → 01).
- 6 cases 64 px (A2 + A11 sur la case active). Utiliser `AutofillHints.oneTimeCode` et la lecture automatique des SMS Android.
- Bloc « Renvoyer le code dans 0:42 » + bouton « Renvoyer » désactivé tant que le minuteur tourne.
- Bouton « Valider » → 03 (nouveau livreur) ou 05 (compte existant) selon le cahier des charges. Lien « Pas reçu de SMS ? Contacter le support ».

### 03 · Inscription — profil
- En-tête : retour 44 + « Étape 1 sur 2 · Profil » / « 50 % » + barre liquide (A10).
- Titre « Devenez livreur Tara » 26 ; texte « Quelques infos pour créer votre profil. Tout est vérifié avant votre première course. »
- Carte verre : Prénom / Nom (2 colonnes), Véhicule (puces radio ×4 : Moto, Vélo, Voiture, Tricycle), Immatriculation (placeholder « Ex. 1234 AB 01 »), Contact d'urgence + aide « Prévenu automatiquement si vous déclenchez une alerte. »
- « Continuer → » → 04.

### 04 · Pièces justificatives
- En-tête : « Étape 2 sur 2 · Pièces » / « 2 / 4 » + barre liquide.
- Liste (rayon 22) : Pièce d'identité (recto et verso) — **Envoyée** ; Permis de conduire — **Envoyé** ; Carte grise — **Envoi en cours…** avec vague horizontale (A2) et % ; Selfie de vérification — **à faire**, bordure pointillée, bouton « Prendre » (appareil photo).
- États à prévoir : à envoyer · envoi en cours (%) · envoyé · **refusé** (non dessiné : proposer `dangerTint` + motif + « Renvoyer »).
- Note sécurité (bouclier) : documents chiffrés, prévenu par SMS à la validation.
- « Envoyer mon dossier » (actif quand tout est envoyé) → 05.

### 05 · Accueil — hors ligne
- Fond : carte atténuée (opacité 0,55 sombre / 0,8 clair) + voile radial + forme liquide centrale.
- En-tête : avatar initiales 46, « Bonsoir, » + nom Sora 18, bouton notifications avec pastille orange.
- Carte « Gains du jour » + lien « Détails » (→ 13) : montant 36 + 3 tuiles (nombre de courses, temps en ligne, **espèces en main** en `accentTint`).
- Centre : **PowerButton** « Passer en ligne » (A2 + A6) → 06. Statut « ● Vous êtes hors ligne » + « Passez en ligne pour recevoir les propositions de course autour de vous. »
- TabBar (Accueil actif).

### 06 · Accueil — en ligne
- Carte plein écran, voiles haut et bas ; quelques points orange = commerces/demande (à confirmer avec le backend).
- Position du livreur (A6 + cône de direction).
- Haut : **OnlineToggle** (→ 05) + pastille « Aujourd'hui 8 750 F » (→ 13).
- Droite : SOS (→ 14) + recentrer.
- Bas : carte « Recherche de courses… » avec **GooLoader** (A5) + « Restez dans la zone, les propositions arrivent ici. » Dans le prototype, toucher cette carte simule une proposition (→ 07).
- TabBar.

### 07 · Proposition de course (30 s)
- Plein écran, par-dessus tout. Pastille « ● Nouvelle course · Moto » (A12).
- **CountdownRing** (A3).
- « Votre gain » + montant 40.
- Carte trajet : point dégradé (enlèvement) → tirets → anneau (livraison). Enlèvement : sur-titre « ENLÈVEMENT · 1,2 KM » `accentText`, nom du vendeur 16/700, quartier 13. Livraison : « LIVRAISON · 6,8 KM · ~22 MIN », quartier 16/700. Puces : « Colis moyen · 2 kg », « À encaisser : 12 500 F » (`accentTint`).
- Bas : « Refuser » (1/3, verre) → 06 ; « Accepter ✓ » (2/3, principal, 800) → 08.

### 08 · Enlèvement
- Carte (380 px) : itinéraire animé (A7) du livreur au vendeur, pin vendeur.
- En-tête sur carte : retour, « Course TR-… · Vers l'enlèvement · 4 min », SOS. Bouton « Itinéraire » (ouvre la navigation GPS).
- Panneau verre (à partir de y ≈ 322) : stepper (Enlèvement actif) ; vendeur (avatar, nom, adresse + repère) + appel ; « Code d'enlèvement · donné par le vendeur » (4 cases) ; tuile « Photographier le colis · Étiquette Tara visible » (pointillés) ; « Colis récupéré » → 09.

### 09 · Livraison
- Carte (300 px), pin destination (anneau blanc/orange + pulsations).
- En-tête : « Arrivé à destination ».
- Panneau : stepper (Livraison active) ; destinataire + appel ; bandeau « À encaisser à la remise **12 500 F** ».
- **Deux modes** (bascule par lien) : avec code (« Code du destinataire · reçu par SMS », 4 cases) / **sans code** (« Livraison sans code » : photo de remise obligatoire, SMS de confirmation au client, champ « Nom de la personne qui reçoit »). Liens « Le client n'a pas de code » / « Le client a un code ».
- Vignette « Photo de remise · Prise à 18:52 » + « Reprendre ».
- « Confirmer la livraison » → 12 ; lien « Livraison impossible ? » → 10.

### 10 · Échec de livraison
- Titre « Livraison impossible » + course et client.
- « Motif » : puces radio 2 colonnes — Client absent, Injoignable, Adresse introuvable, Colis refusé, Refus de payer, Autre motif.
- Carte « Appels au destinataire » (« 2 tentatives ») : journal (icône appel manqué, « Sans réponse », heure · durée) + « Rappeler » (`success`) / « Support Tara ». Le nombre d'appels exigé vient du cahier des charges.
- Tuile « Photo du lieu · obligatoire » (pointillés orange).
- Note « Le vendeur est prévenu automatiquement… ». « Valider l'échec » → 11.

### 11 · Retour du colis
- Carte : itinéraire retour (couleurs §2.1) vers le vendeur.
- En-tête : « Retour du colis · 24 min ».
- Panneau : puce « Échec · Client absent » (`dangerTint`) ; « Rapporter le colis à » + vendeur + distance + appel ; liste en 3 étapes (Rejoindre le vendeur — **En cours** ; Saisir le code de retour du vendeur ; Photographier le colis rendu).
- « Je suis chez le vendeur » → saisie du code de retour et photo (même composant qu'en 08), puis → 06.

### 12 · Encaissement
- Carte montant (rayon 28, h 136) : « À encaisser auprès du client » + montant 42, vagues en bas (A2).
- **LiquidSegmented** Espèces / Mobile Money (A9).
- **Espèces** : « Montant reçu » — puces radio (montant exact, puis coupures supérieures : 15 000, 20 000, 25 000 dans la maquette ; à calculer selon le montant dû) ; « Monnaie à rendre » calculée (`success`).
- **Mobile Money** : « Opérateur du client » (4 puces), « Numéro Mobile Money du client », carte d'attente avec GooLoader « Le client valide le paiement sur son téléphone, puis la course se clôture. »
- Ligne « Espèces en main après cette course **50 000 F** » (`accentStrongText`).
- Bouton : « Confirmer l'encaissement » (espèces) / « Envoyer la demande de paiement » (Mobile Money) → 06.

### 13 · Historique & gains
- Titre « Activité » + sélecteur compact Jour / Semaine / Mois.
- Carte : libellé de période, total 34, nombre de courses ; histogramme (hauteur max 104 px, barres ≤ 34 px de large, rayon 10). **Seule la barre courante** est en dégradé avec reflet liquide et sa valeur au-dessus ; les autres sont neutres (`rgba(255,255,255,0.16)` / `rgba(22,18,14,0.10)`). Libellés sous les barres (Mer … Auj. / 8h … 18h / S1 … S4). Alternative lecteur d'écran : liste des valeurs.
- Encart « Espèces à reverser à Tara · 37 500 F » + bouton « Reverser ».
- « Dernières courses » + « Tout voir » : lignes avec icône de statut (livrée = coche `success`, retour = flèche `accentText`), trajet, heure · statut · mode de paiement, gain « +1 500 ».
- TabBar (Activité actif).

### 14 · Bouton d'alerte (SOS)
- Fond `alertBg` + formes liquides rouges ; pastille « Sécurité » ; bouton fermer (→ 06).
- Titre/texte selon l'état : « Besoin d'aide ? / Maintenez le bouton 3 secondes… » → « Alerte envoyée / Restez en lieu sûr si possible. Un agent Tara vous rappelle. »
- Bouton SOS 236 px (A2 + A6 + A15).
- Carte position (adresse + précision ; « Position partagée en direct » une fois envoyée).
- « Support Tara » / « Secours » (`[NUMÉRO_SECOURS]`). Lien « Annuler l'alerte » après envoi.

### 15 · Hors connexion
- Carte désaturée (cache) avec itinéraire gris.
- **OfflineBanner** en haut : « Hors connexion · 3 actions en attente · enregistrées sur le téléphone » (A13).
- Panneau : « Actions en attente » / « Envoi automatique » ; lignes : Livraison confirmée (code + photo), Encaissement espèces, Photo d'enlèvement — chacune avec n° de course, détail, heure et statut `warningText`.
- Note : « Vous pouvez continuer la course : l'itinéraire et les codes restent disponibles hors connexion. »
- « Réessayer maintenant » (A14) + « Continuer la course » → écran de course en cours.
- Le bandeau s'affiche aussi, seul, en haut de tout écran quand le réseau tombe.

---

## 7. Parcours (prototype)

```
01 Connexion → 02 Code SMS → 03 Inscription → 04 Pièces → 05 Accueil hors ligne
05 ⇄ 06 Accueil en ligne (interrupteur)
06 → 07 Proposition ─ Refuser → 06
                    └ Accepter → 08 Enlèvement → 09 Livraison ─ Confirmer → 12 Encaissement → 06
                                                              └ Livraison impossible → 10 Échec → 11 Retour → 06
SOS (06, 08, 09, 11) → 14 Alerte → fermer → 06
Barre d'onglets : Accueil (05/06) · Activité (13) · Profil (non dessiné)
15 Hors connexion : état qui se superpose aux écrans de course
```

---

## 8. Ressources livrées

| Fichier | Usage |
|---|---|
| `assets/tara-logo-dark.png` | logo complet, fond transparent, texte blanc (thème sombre) |
| `assets/tara-logo-light.png` | logo complet, fond transparent, texte foncé (thème clair) |
| `assets/tara-mark-dark.png` | symbole seul (pin + colis), pour l'icône d'app ou un petit en-tête |
| `maquette/*.dc.html` | code source des 30 écrans (référence des valeurs exactes) |
| `maquette/canvas.json` | disposition du canevas et titres des écrans |

Ces PNG ont été détourés à partir d'une image matricielle. Pour la production (icône d'app, écran de démarrage, grandes tailles), **demander une version vectorielle (SVG/PDF) du logo**.

---

## 9. Hors maquette / à valider

- Écran **Profil** (bascule de thème, mode effets réduits, documents, contact d'urgence, déconnexion) : non dessiné.
- **Écran de démarrage** et **icône d'app** : à dériver du symbole.
- **Fournisseur de cartes** et style de carte : selon le cahier des charges ; palette en §2.1.
- **Notifications** (proposition en arrière-plan, son, vibration) : comportement selon le cahier des charges.
- **Textes** de la maquette : propositions, à relire. Pays, indicatif, devise, opérateurs et numéro des secours : à configurer.
- **Règles métier** visibles dans la maquette mais décidées par le cahier des charges : durée d'expiration de la proposition, nombre d'appels avant échec, conditions de la livraison sans code, reversement des espèces, contenu de la file hors connexion.
- État **pièce refusée** (04) et état **paiement Mobile Money échoué / expiré** (12) : à concevoir.
