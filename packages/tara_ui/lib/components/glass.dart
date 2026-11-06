import 'dart:ui' show ImageFilter;

import 'package:flutter/widgets.dart';

import '../tara_colors.dart';
import '../tara_effects.dart';

/// Surface en verre dépoli (§2.4) : flou d'arrière-plan, remplissage translucide, bordure
/// claire de 1 px, reflet en haut. L'ombre est posée à l'extérieur du découpage. En mode
/// effets réduits : surface opaque, sans flou.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.radius = 26,
    this.borderRadius,
    this.padding = const EdgeInsets.all(18),
    this.fill,
    this.border,
    this.blur = 24,
    this.shadow = true,
    this.highlight = true,
  });

  final Widget child;
  final double radius;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry padding;
  final Color? fill;
  final Color? border;
  final double blur;
  final bool shadow;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final c = TaraColors.of(context);
    final effects = TaraEffects.of(context);
    final shape = borderRadius ?? BorderRadius.circular(radius);
    final surface = DecoratedBox(
      decoration: BoxDecoration(
        color: effects.blur ? (fill ?? c.glass) : c.glassFallback,
        borderRadius: shape,
        border: Border.all(color: border ?? c.glassBorder),
      ),
      child: Stack(
        children: [
          if (highlight)
            Positioned(
              left: shape.topLeft.x / 2,
              right: shape.topRight.x / 2,
              top: 0,
              child: SizedBox(height: 1, child: ColoredBox(color: c.glassHighlight)),
            ),
          Padding(padding: padding, child: child),
        ],
      ),
    );
    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: shape, boxShadow: shadow ? c.shadow : null),
      child: ClipRRect(
        borderRadius: shape,
        child: effects.blur
            ? BackdropFilter(
                // Équivalent visuel d'un flou CSS de 24 px avec Impeller/Skia.
                filter: ImageFilter.blur(sigmaX: blur * .6, sigmaY: blur * .6),
                child: surface,
              )
            : surface,
      ),
    );
  }
}

/// Panneau du bas (bottom sheet) en verre fort : rayon haut 32, poignée 40 × 5.
class GlassPanel extends StatelessWidget {
  const GlassPanel({super.key, required this.child, this.padding = const EdgeInsets.fromLTRB(20, 10, 20, 20)});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final c = TaraColors.of(context);
    return GlassCard(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      fill: c.glassStrong,
      padding: padding,
      shadow: !c.isDark,
      blur: 30,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 5,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: c.textTertiary.withValues(alpha: .35),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

/// Encart teinté (« à encaisser », espèces en main, succès, danger).
enum TintTone { accent, success, danger }

class TintBox extends StatelessWidget {
  const TintBox({
    super.key,
    required this.child,
    this.tone = TintTone.accent,
    this.radius = 16,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  });

  final Widget child;
  final TintTone tone;
  final double radius;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final c = TaraColors.of(context);
    final (bg, border) = switch (tone) {
      TintTone.accent => (c.accentTintBg, c.accentTintBorder),
      TintTone.success => (c.successTintBg, c.successTintBorder),
      TintTone.danger => (c.dangerTint, c.dangerText.withValues(alpha: .35)),
    };
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: border),
      ),
      child: child,
    );
  }
}

/// Socle flottant en verre clair (barre d'onglets, bouton du bas) : le contenu qui passe
/// dessous est flouté et ses couleurs avivées (saturation × 1,6), reflet en haut, bord
/// clair. L'enfant est posé hors du découpage pour garder son ombre (bouton orange).
/// Effets réduits : surface opaque sans flou.
class GlassDock extends StatelessWidget {
  const GlassDock({super.key, required this.child, this.radius = 28, this.padding = EdgeInsets.zero});

  final Widget child;
  final double radius;
  final EdgeInsets padding;

  static final _vibrancy = ColorFilter.matrix(_saturation(1.6));

  static List<double> _saturation(double s) {
    const r = 0.2126, g = 0.7152, b = 0.0722;
    return [
      r * (1 - s) + s, g * (1 - s), b * (1 - s), 0, 0, //
      r * (1 - s), g * (1 - s) + s, b * (1 - s), 0, 0,
      r * (1 - s), g * (1 - s), b * (1 - s) + s, 0, 0,
      0, 0, 0, 1, 0,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final c = TaraColors.of(context);
    final effects = TaraEffects.of(context);
    final shape = BorderRadius.circular(radius);
    final surface = DecoratedBox(
      decoration: BoxDecoration(
        color: effects.blur ? c.tabBarGlass : c.glassFallback,
        borderRadius: shape,
        border: Border.all(color: c.glassBorder.withValues(alpha: c.isDark ? .22 : .85)),
        // Reflet du verre : plus clair en haut, transparent en bas.
        gradient: effects.blur
            ? LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  c.glassHighlight.withValues(alpha: c.isDark ? .10 : .45),
                  c.glassHighlight.withValues(alpha: 0),
                ],
              )
            : null,
      ),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: shape,
        boxShadow: [
          BoxShadow(color: Color.fromRGBO(0, 0, 0, c.isDark ? .35 : .10), blurRadius: 30, offset: const Offset(0, 12)),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: shape,
              child: effects.blur
                  ? BackdropFilter(
                      filter: ImageFilter.compose(outer: _vibrancy, inner: ImageFilter.blur(sigmaX: 18, sigmaY: 18)),
                      child: surface,
                    )
                  : surface,
            ),
          ),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}
