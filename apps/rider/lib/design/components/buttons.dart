import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../motion/effects.dart';
import '../tara_colors.dart';
import '../tara_icons.dart';
import '../tara_typography.dart';
import 'glass.dart';

/// Zone tactile d'au moins 48 dp, sans changer le visuel (§2.3).
class _TapTarget extends StatelessWidget {
  const _TapTarget({required this.child, required this.onTap, required this.label});

  final Widget child;
  final VoidCallback? onTap;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: label,
      excludeSemantics: label != null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          child: Center(widthFactor: 1, heightFactor: 1, child: child),
        ),
      ),
    );
  }
}

/// Bouton principal : dégradé de marque, texte foncé, ombre orange, reflet qui balaie (A4).
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.height = 58,
    this.strong = false,
    this.sheenPeriod = const Duration(milliseconds: 3600),
  });

  final String label;
  final VoidCallback? onPressed;
  final TaraIconData? icon;
  final double height;

  /// Graisse 800 (Accepter).
  final bool strong;
  final Duration sheenPeriod;

  @override
  Widget build(BuildContext context) {
    final c = TaraColors.of(context);
    final enabled = onPressed != null;
    final style = (strong ? TaraText.buttonStrong : TaraText.button).copyWith(color: TaraBrand.onBrand);
    return Semantics(
      button: true,
      enabled: enabled,
      child: GestureDetector(
        onTap: enabled
            ? () {
                HapticFeedback.selectionClick();
                onPressed!();
              }
            : null,
        child: Opacity(
          opacity: enabled ? 1 : .45,
          child: Container(
            constraints: BoxConstraints(minHeight: height),
            decoration: BoxDecoration(
              gradient: TaraBrand.gradient,
              borderRadius: BorderRadius.circular(20),
              boxShadow: enabled ? c.brandShadow : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Reflet interne en haut.
                  Positioned(
                    top: 0,
                    left: 12,
                    right: 12,
                    child: SizedBox(
                      height: 1,
                      child: ColoredBox(color: const Color(0xFFFFFFFF).withValues(alpha: c.isDark ? .45 : .5)),
                    ),
                  ),
                  if (enabled) Sheen(period: sheenPeriod, opacity: c.isDark ? .55 : .6),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(label, style: style, textAlign: TextAlign.center),
                        ),
                        if (icon != null) ...[
                          const SizedBox(width: 10),
                          TaraIcon(icon!, size: 20, strokeWidth: 2.2, color: TaraBrand.onBrand),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bouton secondaire en verre (Refuser, Reprendre, Réessayer).
class GlassButton extends StatelessWidget {
  const GlassButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.height = 54,
    this.radius = 18,
    this.color,
  });

  final String label;
  final VoidCallback? onPressed;
  final TaraIconData? icon;
  final double height;
  final double radius;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = TaraColors.of(context);
    final fg = color ?? c.textPrimary;
    return Semantics(
      button: true,
      enabled: onPressed != null,
      child: GestureDetector(
        onTap: onPressed,
        child: Opacity(
          opacity: onPressed == null ? .5 : 1,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: height < 48 ? 48 : height),
            child: GlassCard(
              radius: radius,
              shadow: false,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (icon != null) ...[TaraIcon(icon!, size: 20, color: fg), const SizedBox(width: 8)],
                    Flexible(
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: TaraText.buttonSecondary.copyWith(color: fg),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bouton icône en verre (retour, notifications, recentrer, fermer). Libellé obligatoire.
class GlassIconButton extends StatelessWidget {
  const GlassIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.size = 48,
    this.radius = 16,
    this.badge = false,
  });

  final TaraIconData icon;
  final String label;
  final VoidCallback? onPressed;
  final double size;
  final double radius;

  /// Pastille orange (notification non lue).
  final bool badge;

  @override
  Widget build(BuildContext context) {
    final c = TaraColors.of(context);
    return _TapTarget(
      onTap: onPressed,
      label: label,
      child: SizedBox.square(
        dimension: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            GlassCard(
              radius: radius,
              shadow: false,
              padding: EdgeInsets.zero,
              fill: c.isDark ? const Color.fromRGBO(255, 255, 255, 0.07) : null,
              child: Center(child: TaraIcon(icon, size: 22, color: c.textPrimary)),
            ),
            if (badge)
              Positioned(
                top: 10,
                right: 11,
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: TaraBrand.orange,
                    shape: BoxShape.circle,
                    border: Border.all(color: c.bg, width: 1.5),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Bouton d'appel (48, rond, teinte succès) : ouvre le composeur.
class CallButton extends StatelessWidget {
  const CallButton({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final c = TaraColors.of(context);
    return _TapTarget(
      onTap: onPressed,
      label: label,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: c.successTintBg,
          shape: BoxShape.circle,
          border: Border.all(color: c.successTintBorder),
        ),
        child: Center(child: TaraIcon(TaraIcons.phone, size: 20, color: c.success)),
      ),
    );
  }
}

/// Petit bouton SOS (accueil en ligne, écrans de course) : mène à l'écran d'alerte.
class SosButton extends StatelessWidget {
  const SosButton({super.key, required this.label, required this.onPressed, this.size = 50});

  final String label;
  final VoidCallback? onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    return _TapTarget(
      onTap: onPressed,
      label: label,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: TaraBrand.sos,
          borderRadius: BorderRadius.circular(17),
          boxShadow: const [BoxShadow(color: Color.fromRGBO(229, 37, 53, 0.45), blurRadius: 18, offset: Offset(0, 8))],
        ),
        child: Center(
          child: Text(
            'SOS',
            style: TaraText.overline.copyWith(
              fontFamily: TaraText.sora,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: const Color(0xFFFFFFFF),
            ),
          ),
        ),
      ),
    );
  }
}

/// Lien texte (Modifier, Détails, Tout voir, « Le client n'a pas de code »).
class TaraLink extends StatelessWidget {
  const TaraLink({super.key, required this.label, required this.onPressed, this.style});

  final String label;
  final VoidCallback? onPressed;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final c = TaraColors.of(context);
    return Semantics(
      link: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Align(
            widthFactor: 1,
            alignment: Alignment.centerLeft,
            child: Text(
              label,
              style: (style ?? TaraText.text).copyWith(color: c.accentText, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ),
    );
  }
}
