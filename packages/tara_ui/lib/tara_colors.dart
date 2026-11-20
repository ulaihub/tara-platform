import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Couleurs de la marque, identiques dans les deux thèmes (passation §2.1).
abstract final class TaraBrand {
  static const amber = Color(0xFFFFB000);
  static const orange = Color(0xFFFF6A00);
  static const red = Color(0xFFFF3D00);

  /// Texte et icônes posés sur le dégradé : le blanc ne passe pas le contraste.
  static const onBrand = Color(0xFF140800);
  static const focusBorder = Color(0xFFFF8A3D);
  static const focusHalo = Color.fromRGBO(255, 106, 0, 0.14);
  static const sos = Color(0xFFE52535);

  /// Dégradé de marque : CSS `linear-gradient(100deg, #FFB000 0%, #FF6A00 55%, #FF3D00 100%)`.
  static const gradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [amber, orange, red],
    stops: [0, .55, 1],
    transform: GradientRotation(10 * math.pi / 180),
  );

  /// Variante verticale (liquide du bouton « Passer en ligne », barres).
  static const verticalGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [amber, orange, red],
    stops: [0, .4, 1],
  );
}

/// Couleurs dépendant du thème (sombre ou clair), lues par tous les composants :
/// aucune couleur n'est codée en dur dans les écrans.
@immutable
class TaraColors extends ThemeExtension<TaraColors> {
  const TaraColors({
    required this.brightness,
    required this.bg,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.accentText,
    required this.accentStrongText,
    required this.glass,
    required this.glassBorder,
    required this.glassHighlight,
    required this.glassStrong,
    required this.glassBar,
    required this.tabBarGlass,
    required this.glassFallback,
    required this.chipBg,
    required this.chipBorder,
    required this.chipSelected,
    required this.chipSelectedBorder,
    required this.chipSelectedBorderWidth,
    required this.inputBg,
    required this.placeholder,
    required this.accentTintBg,
    required this.accentTintBorder,
    required this.success,
    required this.successTintBg,
    required this.successTintBorder,
    required this.online,
    required this.offline,
    required this.dangerText,
    required this.dangerTextStrong,
    required this.dangerTint,
    required this.warningText,
    required this.warningBannerBg,
    required this.warningBannerBorder,
    required this.alertBg,
    required this.shadow,
    required this.brandShadow,
    required this.track,
    required this.neutralBar,
    required this.blobOpacity,
    required this.mapGround,
    required this.mapBlocks,
    required this.mapMinorRoad,
    required this.mapMajorRoad,
    required this.mapWater,
  });

  final Brightness brightness;
  final Color bg;
  final Color textPrimary;
  final Color textSecondary;

  /// Minimum pour les aides et métadonnées : ne jamais descendre en dessous.
  final Color textTertiary;
  final Color accentText;
  final Color accentStrongText;
  final Color glass;
  final Color glassBorder;

  /// Reflet de 1 px en haut des surfaces en verre.
  final Color glassHighlight;
  final Color glassStrong;
  final Color glassBar;

  /// Teinte du verre des barres (barre d'onglets, bouton du bas). Son opacité vient du
  /// réglage de transparence ([GlassLevel]) ; le contenu reste deviné dessous, flouté.
  final Color tabBarGlass;

  /// Surface opaque utilisée sans flou (mode effets réduits).
  final Color glassFallback;
  final Color chipBg;
  final Color chipBorder;
  final Gradient chipSelected;
  final Color chipSelectedBorder;
  final double chipSelectedBorderWidth;
  final Color inputBg;
  final Color placeholder;
  final Color accentTintBg;
  final Color accentTintBorder;
  final Color success;
  final Color successTintBg;
  final Color successTintBorder;
  final Color online;
  final Color offline;
  final Color dangerText;
  final Color dangerTextStrong;
  final Color dangerTint;
  final Color warningText;
  final Color warningBannerBg;
  final Color warningBannerBorder;
  final Color alertBg;
  final List<BoxShadow> shadow;
  final List<BoxShadow> brandShadow;

  /// Piste des barres de progression et de l'anneau (10 %).
  final Color track;

  /// Barres neutres de l'histogramme.
  final Color neutralBar;

  /// Opacité des formes liquides de fond.
  final double blobOpacity;
  final Color mapGround;
  final Color mapBlocks;
  final Color mapMinorRoad;
  final Color mapMajorRoad;
  final Color mapWater;

  bool get isDark => brightness == Brightness.dark;

  static const dark = TaraColors(
    brightness: Brightness.dark,
    bg: Color(0xFF0A0A0F),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color.fromRGBO(255, 255, 255, 0.72),
    textTertiary: Color.fromRGBO(255, 255, 255, 0.62),
    accentText: Color(0xFFFFB15C),
    accentStrongText: Color(0xFFFFC283),
    glass: Color.fromRGBO(255, 255, 255, 0.06),
    glassBorder: Color.fromRGBO(255, 255, 255, 0.14),
    glassHighlight: Color.fromRGBO(255, 255, 255, 0.12),
    glassStrong: Color.fromRGBO(20, 20, 26, 0.84),
    glassBar: Color.fromRGBO(22, 22, 28, 0.60),
    tabBarGlass: Color.fromRGBO(26, 26, 32, 0.32),
    glassFallback: Color.fromRGBO(26, 26, 33, 0.92),
    chipBg: Color.fromRGBO(255, 255, 255, 0.05),
    chipBorder: Color.fromRGBO(255, 255, 255, 0.14),
    chipSelected: LinearGradient(
      begin: Alignment(-0.34, -0.94),
      end: Alignment(0.34, 0.94),
      colors: [Color.fromRGBO(255, 176, 0, 0.28), Color.fromRGBO(255, 61, 0, 0.20)],
    ),
    chipSelectedBorder: Color.fromRGBO(255, 177, 92, 0.9),
    chipSelectedBorderWidth: 1,
    inputBg: Color.fromRGBO(10, 10, 15, 0.45),
    placeholder: Color.fromRGBO(255, 255, 255, 0.50),
    accentTintBg: Color.fromRGBO(255, 138, 0, 0.12),
    accentTintBorder: Color.fromRGBO(255, 177, 92, 0.32),
    success: Color(0xFF4ADE9B),
    successTintBg: Color.fromRGBO(74, 222, 155, 0.15),
    successTintBorder: Color.fromRGBO(74, 222, 155, 0.40),
    online: Color(0xFF4ADE9B),
    offline: Color(0xFF8A8B93),
    // Rouge vif : lisible sur le fond noir (contraste 6:1).
    dangerText: Color(0xFFFF4D5A),
    dangerTextStrong: Color(0xFFFF6B75),
    dangerTint: Color.fromRGBO(229, 37, 53, 0.17),
    warningText: Color(0xFFFFC24D),
    warningBannerBg: Color.fromRGBO(40, 28, 12, 0.72),
    warningBannerBorder: Color.fromRGBO(255, 177, 92, 0.5),
    alertBg: Color(0xFF0C080A),
    shadow: [BoxShadow(color: Color.fromRGBO(0, 0, 0, 0.35), blurRadius: 40, offset: Offset(0, 20))],
    brandShadow: [BoxShadow(color: Color.fromRGBO(255, 90, 0, 0.38), blurRadius: 30, offset: Offset(0, 14))],
    track: Color.fromRGBO(255, 255, 255, 0.10),
    neutralBar: Color.fromRGBO(255, 255, 255, 0.16),
    blobOpacity: 0.5,
    mapGround: Color(0xFF0D0E13),
    mapBlocks: Color(0xFF121319),
    mapMinorRoad: Color(0xFF1A1C24),
    mapMajorRoad: Color(0xFF252833),
    mapWater: Color(0xFF0F1922),
  );

  static const light = TaraColors(
    brightness: Brightness.light,
    bg: Color(0xFFF6F2EC),
    textPrimary: Color(0xFF16120E),
    textSecondary: Color.fromRGBO(22, 18, 14, 0.70),
    textTertiary: Color.fromRGBO(22, 18, 14, 0.66),
    accentText: Color(0xFFC2410C),
    accentStrongText: Color(0xFF9A3412),
    glass: Color.fromRGBO(255, 255, 255, 0.60),
    glassBorder: Color.fromRGBO(255, 255, 255, 0.95),
    glassHighlight: Color(0xFFFFFFFF),
    glassStrong: Color.fromRGBO(255, 255, 255, 0.88),
    glassBar: Color.fromRGBO(255, 255, 255, 0.72),
    tabBarGlass: Color.fromRGBO(255, 255, 255, 0.40),
    glassFallback: Color.fromRGBO(255, 255, 255, 0.94),
    chipBg: Color.fromRGBO(255, 255, 255, 0.70),
    chipBorder: Color.fromRGBO(22, 18, 14, 0.10),
    chipSelected: LinearGradient(
      begin: Alignment(-0.34, -0.94),
      end: Alignment(0.34, 0.94),
      colors: [Color.fromRGBO(255, 176, 0, 0.26), Color.fromRGBO(255, 106, 0, 0.16)],
    ),
    chipSelectedBorder: Color(0xFFFF8A3D),
    chipSelectedBorderWidth: 1.5,
    inputBg: Color(0xFFFFFFFF),
    placeholder: Color.fromRGBO(22, 18, 14, 0.50),
    accentTintBg: Color.fromRGBO(255, 138, 0, 0.12),
    accentTintBorder: Color.fromRGBO(255, 106, 0, 0.30),
    success: Color(0xFF0E7F57),
    successTintBg: Color.fromRGBO(16, 160, 110, 0.12),
    successTintBorder: Color.fromRGBO(16, 160, 110, 0.35),
    online: Color(0xFF10A06E),
    offline: Color(0xFF8A8580),
    // Rouge vif, encore lisible sur le fond crème (contraste 4,8:1 et 5,1:1).
    dangerText: Color(0xFFD21C2B),
    dangerTextStrong: Color(0xFFC81E2C),
    dangerTint: Color.fromRGBO(229, 37, 53, 0.10),
    warningText: Color(0xFFB45309),
    warningBannerBg: Color.fromRGBO(255, 247, 230, 0.9),
    warningBannerBorder: Color.fromRGBO(217, 119, 6, 0.45),
    alertBg: Color(0xFFFBF1F0),
    shadow: [BoxShadow(color: Color.fromRGBO(140, 70, 10, 0.12), blurRadius: 36, offset: Offset(0, 16))],
    brandShadow: [BoxShadow(color: Color.fromRGBO(255, 90, 0, 0.32), blurRadius: 30, offset: Offset(0, 14))],
    track: Color.fromRGBO(22, 18, 14, 0.10),
    neutralBar: Color.fromRGBO(22, 18, 14, 0.10),
    blobOpacity: 0.42,
    mapGround: Color(0xFFECE7E0),
    mapBlocks: Color(0xFFE3DDD4),
    mapMinorRoad: Color(0xFFF8F6F2),
    mapMajorRoad: Color(0xFFFFFFFF),
    mapWater: Color(0xFFCFE2EA),
  );

  static TaraColors of(BuildContext context) => Theme.of(context).extension<TaraColors>()!;

  @override
  TaraColors copyWith() => this;

  /// Les thèmes basculent d'un coup : pas d'interpolation couleur par couleur.
  @override
  TaraColors lerp(TaraColors? other, double t) {
    if (other == null) return this;
    return t < 0.5 ? this : other;
  }
}
