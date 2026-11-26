import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../motion/effects.dart';
import '../tara_colors.dart';
import '../tara_icons.dart';
import '../tara_typography.dart';

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

/// Bouton principal fin, en pilule : dégradé de marque, texte foncé, ombre orange légère,
/// reflet qui balaie (A4), petit rebond au toucher.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.height = 50,
    this.strong = false,
    this.sheenPeriod = const Duration(milliseconds: 3600),
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final TaraIconData? icon;
  final double height;

  /// Graisse 800 (Accepter).
  final bool strong;
  final Duration sheenPeriod;

  /// Requête en cours : le bouton reste plein mais ne réagit plus, une icône tourne.
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final c = TaraColors.of(context);
    final enabled = onPressed != null;
    final style = (strong ? TaraText.buttonStrong : TaraText.button).copyWith(
      color: TaraBrand.onBrand,
      fontSize: 16,
      letterSpacing: .1,
    );
    final radius = BorderRadius.circular(height / 2);
    return Semantics(
      button: true,
      enabled: enabled && !loading,
      child: Squish(
        enabled: enabled && !loading,
        child: GestureDetector(
          onTap: enabled && !loading
              ? () {
                  HapticFeedback.lightImpact();
                  onPressed!();
                }
              : null,
          child: Opacity(
            opacity: enabled ? 1 : .45,
            child: Container(
              constraints: BoxConstraints(minHeight: height),
              decoration: BoxDecoration(
                gradient: TaraBrand.gradient,
                borderRadius: radius,
                boxShadow: enabled
                    ? [
                        BoxShadow(
                          color: Color.fromRGBO(255, 90, 0, c.isDark ? .30 : .26),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ]
                    : null,
              ),
              child: ClipRRect(
                borderRadius: radius,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Filet de lumière en haut.
                    Positioned(
                      top: 0,
                      left: height / 2,
                      right: height / 2,
                      child: SizedBox(
                        height: 1,
                        child: ColoredBox(color: const Color(0xFFFFFFFF).withValues(alpha: c.isDark ? .45 : .55)),
                      ),
                    ),
                    if (enabled) Sheen(period: sheenPeriod, opacity: c.isDark ? .55 : .6),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(label, style: style, textAlign: TextAlign.center),
                          ),
                          if (loading) ...[
                            const SizedBox(width: 10),
                            const Spin(
                              period: Duration(milliseconds: 900),
                              child: TaraIcon(TaraIcons.refresh, size: 18, strokeWidth: 2, color: TaraBrand.onBrand),
                            ),
                          ] else if (icon != null) ...[
                            const SizedBox(width: 8),
                            TaraIcon(icon!, size: 18, strokeWidth: 2, color: TaraBrand.onBrand),
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
      ),
    );
  }
}

/// Bouton secondaire fin en verre (Refuser, Reprendre, Réessayer) : pilule de 44 avec un
/// filet d'un pixel, dans une zone tactile de 48 ; petit rebond au toucher.
class GlassButton extends StatelessWidget {
  const GlassButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.height = 44,
    this.radius,
    this.color,
  });

  final String label;
  final VoidCallback? onPressed;
  final TaraIconData? icon;
  final double height;

  /// Coins ; pilule par défaut.
  final double? radius;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = TaraColors.of(context);
    final fg = color ?? c.textPrimary;
    final r = BorderRadius.circular(radius ?? height / 2);
    return Semantics(
      button: true,
      enabled: onPressed != null,
      child: Squish(
        enabled: onPressed != null,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPressed == null
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  onPressed!();
                },
          child: Opacity(
            opacity: onPressed == null ? .5 : 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Center(
                heightFactor: 1,
                child: Container(
                  height: height,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: c.isDark
                        ? const Color.fromRGBO(255, 255, 255, .07)
                        : const Color.fromRGBO(255, 255, 255, .72),
                    borderRadius: r,
                    border: Border.all(color: c.textPrimary.withValues(alpha: c.isDark ? .14 : .10)),
                  ),
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (icon != null) ...[
                          TaraIcon(icon!, size: 18, strokeWidth: 1.8, color: fg),
                          const SizedBox(width: 8),
                        ],
                        // Une ligne : avec le texte agrandi, le libellé rétrécit au lieu d'être
                        // coupé au milieu d'un mot.
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              label,
                              maxLines: 1,
                              softWrap: false,
                              style: TaraText.buttonSecondary.copyWith(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: fg,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bouton icône fin en verre (retour, notifications, recentrer, fermer) : rond de 42 avec
/// un filet d'un pixel, dans une zone tactile de 48 ; rebond au toucher. Libellé obligatoire.
class GlassIconButton extends StatelessWidget {
  const GlassIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.size = 42,
    this.radius,
    this.badge = false,
  });

  final TaraIconData icon;
  final String label;
  final VoidCallback? onPressed;
  final double size;

  /// Coins ; rond par défaut.
  final double? radius;

  /// Pastille orange (notification non lue).
  final bool badge;

  @override
  Widget build(BuildContext context) {
    final c = TaraColors.of(context);
    return Squish(
      enabled: onPressed != null,
      depth: .9,
      child: _TapTarget(
        onTap: onPressed,
        label: label,
        child: SizedBox.square(
          dimension: size,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: c.isDark ? const Color.fromRGBO(255, 255, 255, .07) : const Color.fromRGBO(255, 255, 255, .72),
                  borderRadius: BorderRadius.circular(radius ?? size / 2),
                  border: Border.all(color: c.textPrimary.withValues(alpha: c.isDark ? .14 : .10)),
                ),
                alignment: Alignment.center,
                child: TaraIcon(icon, size: 20, strokeWidth: 1.8, color: c.textPrimary),
              ),
              if (badge)
                Positioned(
                  top: size * .2,
                  right: size * .22,
                  child: Container(
                    width: 8,
                    height: 8,
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
  const SosButton({super.key, required this.label, required this.onPressed, this.size = 50, this.round = false});

  final String label;
  final VoidCallback? onPressed;
  final double size;

  /// Rond avec un halo rouge (accueil en ligne de la maquette) plutôt que carré arrondi.
  final bool round;

  @override
  Widget build(BuildContext context) {
    return _TapTarget(
      onTap: onPressed,
      label: label,
      child: Container(
        width: size,
        height: size,
        decoration: round
            ? const BoxDecoration(
                color: Color(0xFFF01E2C),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: Color.fromRGBO(240, 30, 44, .25), spreadRadius: 4),
                  BoxShadow(color: Color.fromRGBO(240, 30, 44, .4), blurRadius: 22, offset: Offset(0, 10)),
                ],
              )
            : BoxDecoration(
                color: TaraBrand.sos,
                borderRadius: BorderRadius.circular(17),
                boxShadow: const [
                  BoxShadow(color: Color.fromRGBO(229, 37, 53, 0.45), blurRadius: 18, offset: Offset(0, 8)),
                ],
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
