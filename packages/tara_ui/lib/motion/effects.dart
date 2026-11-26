import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/widgets.dart';

import '../tara_colors.dart';
import '../tara_effects.dart';
import 'motion_clock.dart';

/// Reflet qui balaie les boutons principaux (A4) : bande de 70 px inclinée de −20°, de
/// −140 % à +420 % de sa largeur sur 55 % d'un cycle de 3,6 s, puis pause.
class Sheen extends StatelessWidget {
  const Sheen({super.key, this.period = const Duration(milliseconds: 3600), this.opacity = .55});

  final Duration period;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: MotionBuilder(
          period: period,
          stillPhase: 1,
          builder: (context, v, _) {
            final t = Curves.easeInOut.transform((v / .55).clamp(0, 1));
            final dx = -1.4 * 70 + (4.2 * 70 + 1.4 * 70) * t;
            if (t >= 1) return const SizedBox.shrink();
            return Stack(
              children: [
                Positioned(
                  left: dx,
                  top: -10,
                  bottom: -10,
                  width: 70,
                  child: Transform(
                    transform: Matrix4.skewX(-20 * math.pi / 180),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0x00FFFFFF),
                            const Color(0xFFFFFFFF).withValues(alpha: opacity),
                            const Color(0x00FFFFFF),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Trois gouttes qui fusionnent (A5) : flou puis seuillage alpha (α' = 22·α − 10).
class GooLoader extends StatelessWidget {
  const GooLoader({super.key, this.compact = false, this.semanticLabel});

  /// Variante 46 × 24 (attente Mobile Money).
  final bool compact;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final width = compact ? 46.0 : 76.0;
    final height = compact ? 24.0 : 40.0;
    final big = compact ? 16.0 : 24.0;
    final small = compact ? 12.0 : 16.0;
    final spread = compact ? 14.0 : 26.0;
    final period = Duration(milliseconds: compact ? 1400 : 1600);
    Widget dot(double size, Color color, Offset offset) => Transform.translate(
      offset: offset,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
    return Semantics(
      label: semanticLabel,
      child: SizedBox(
        width: width,
        height: height,
        child: ColorFiltered(
          colorFilter: const ColorFilter.matrix(<double>[
            1, 0, 0, 0, 0, //
            0, 1, 0, 0, 0, //
            0, 0, 1, 0, 0, //
            0, 0, 0, 22, -2550,
          ]),
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: compact ? 3 : 5, sigmaY: compact ? 3 : 5),
            child: MotionBuilder(
              period: period,
              stillPhase: .35,
              builder: (context, t, _) {
                final travel = Curves.easeInOut.transform(t < .5 ? t * 2 : (1 - t) * 2);
                final breathe = 1 + .18 * math.sin(t * math.pi);
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    dot(small, TaraBrand.amber, Offset(-spread * (1 - travel), 0)),
                    dot(small, TaraBrand.red, Offset(spread * (1 - travel), 0)),
                    Transform.scale(scale: breathe, child: dot(big, TaraBrand.orange, Offset.zero)),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Ondes qui s'éloignent d'un élément (A6) : deux anneaux ou disques décalés d'une demi-période.
class PulseRings extends StatelessWidget {
  const PulseRings({
    super.key,
    required this.size,
    required this.color,
    this.period = const Duration(milliseconds: 3000),
    this.from = .92,
    this.to = 1.45,
    this.startOpacity = .55,
    this.strokeWidth,
    this.child,
  });

  final double size;
  final Color color;
  final Duration period;
  final double from;
  final double to;
  final double startOpacity;

  /// Anneau (trait) ; sans valeur, disque plein.
  final double? strokeWidth;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    Widget ring(double t) {
      final eased = Curves.easeOut.transform(t);
      return Transform.scale(
        scale: from + (to - from) * eased,
        child: Opacity(
          opacity: (startOpacity * (1 - eased)).clamp(0, 1),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: strokeWidth == null ? color : null,
              border: strokeWidth == null ? null : Border.all(color: color, width: strokeWidth!),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          IgnorePointer(
            child: MotionBuilder(
              period: period,
              stillPhase: 1,
              builder: (context, t, _) => Stack(alignment: Alignment.center, children: [ring(t), ring((t + .5) % 1)]),
            ),
          ),
          ?child,
        ],
      ),
    );
  }
}

/// Dégradé qui défile (A10 barre de progression, A13 filet du bandeau hors connexion).
class FlowingGradient extends StatelessWidget {
  const FlowingGradient({super.key, required this.colors, required this.period});

  final List<Color> colors;
  final Duration period;

  @override
  Widget build(BuildContext context) {
    return MotionBuilder(
      period: period,
      builder: (context, t, _) => DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: colors,
            tileMode: TileMode.repeated,
            begin: Alignment(-1 - 2 * t, 0),
            end: Alignment(3 - 2 * t, 0),
          ),
        ),
      ),
    );
  }
}

/// Clignotement franc (A11 curseur) ou doux (A12 point « Nouvelle course »).
class Blink extends StatelessWidget {
  const Blink({
    super.key,
    required this.child,
    this.period = const Duration(seconds: 1),
    this.smooth = false,
    this.minOpacity = 0,
  });

  final Widget child;
  final Duration period;
  final bool smooth;
  final double minOpacity;

  @override
  Widget build(BuildContext context) {
    return MotionBuilder(
      period: period,
      child: child,
      builder: (context, t, child) {
        final opacity = smooth
            ? minOpacity + (1 - minOpacity) * (0.5 + 0.5 * math.cos(t * 2 * math.pi))
            : (t < .5 ? 1.0 : minOpacity);
        return Opacity(opacity: opacity, child: child);
      },
    );
  }
}

/// Rotation continue (A14 : icône de rechargement pendant une tentative).
class Spin extends StatelessWidget {
  const Spin({super.key, required this.child, this.period = const Duration(seconds: 1)});

  final Widget child;
  final Duration period;

  @override
  Widget build(BuildContext context) => MotionBuilder(
    period: period,
    child: child,
    builder: (context, t, child) => Transform.rotate(angle: t * 2 * math.pi, child: child),
  );
}

/// Rebond au toucher (« finesse ») : l'élément s'enfonce légèrement quand le doigt se pose,
/// puis revient avec un petit ressort. Sans animations (réglage du téléphone), il ne bouge
/// pas. N'intercepte pas le geste : le bouton qu'il enveloppe reste seul à réagir.
class Squish extends StatefulWidget {
  const Squish({super.key, required this.child, this.enabled = true, this.depth = .95});

  final Widget child;
  final bool enabled;

  /// Échelle au plus fort de l'appui.
  final double depth;

  @override
  State<Squish> createState() => _SquishState();
}

class _SquishState extends State<Squish> {
  bool _down = false;

  void _set(bool down) {
    if (_down != down && mounted) setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || !TaraEffects.of(context).decorativeMotion) return widget.child;
    return Listener(
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _down ? widget.depth : 1,
        duration: _down ? const Duration(milliseconds: 90) : const Duration(milliseconds: 420),
        curve: _down ? Curves.easeOut : Curves.elasticOut,
        child: widget.child,
      ),
    );
  }
}
