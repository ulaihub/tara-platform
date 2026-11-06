import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'motion_clock.dart';

/// Vague liquide (A2) : deux sinusoïdes (avant en dégradé, arrière plus sombre, sens
/// inverse) dont le niveau porte l'information (temps restant, progression, maintien SOS).
class LiquidWavePainter extends CustomPainter {
  LiquidWavePainter({
    required this.phase,
    required this.level,
    required this.front,
    required this.back,
    this.amplitude = 7,
    this.backPhase,
    this.horizontal = false,
    this.gradientHeight,
  });

  /// 0..2π, boucle continue.
  final double phase;

  /// Phase de la couche arrière (par défaut, liée à la phase avant).
  final double? backPhase;

  /// 0 = vide, 1 = plein.
  final double level;
  final Gradient front;
  final Color back;
  final double amplitude;

  /// Remplissage de gauche à droite (pièce en cours d'envoi).
  final bool horizontal;

  /// Hauteur du dégradé, accroché à la surface du liquide comme dans la maquette (le
  /// dégradé y couvre la grande forme qui tourne, environ deux fois la largeur).
  final double? gradientHeight;

  Path _wave(Size s, double ph, double amp, double lift) {
    final p = Path();
    if (horizontal) {
      final x0 = s.width * level + lift;
      p.moveTo(0, 0);
      for (double y = 0; y <= s.height + 2; y += 2) {
        p.lineTo(x0 + math.sin(y / s.height * 2 * math.pi + ph) * amp, y);
      }
      return p
        ..lineTo(0, s.height)
        ..close();
    }
    final y0 = s.height * (1 - level) - lift;
    p.moveTo(0, s.height);
    for (double x = 0; x <= s.width + 2; x += 2) {
      p.lineTo(x, y0 + math.sin(x / s.width * 2 * math.pi + ph) * amp);
    }
    return p
      ..lineTo(s.width, s.height)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (level <= 0) return;
    canvas.drawPath(_wave(size, backPhase ?? (-phase * .7 + 1.3), amplitude * 1.2, 8), Paint()..color = back);
    final shaderRect = horizontal
        ? Offset.zero & size
        : Rect.fromLTWH(0, size.height * (1 - level) - amplitude, size.width, gradientHeight ?? size.width * 2);
    canvas.drawPath(_wave(size, phase, amplitude, 0), Paint()..shader = front.createShader(shaderRect));
  }

  @override
  bool shouldRepaint(LiquidWavePainter o) =>
      o.phase != phase ||
      o.level != level ||
      o.backPhase != backPhase ||
      o.front != front ||
      o.back != back ||
      o.gradientHeight != gradientHeight;
}

/// Liquide animé qui remplit son parent jusqu'à `level`, avec transition du niveau.
class LiquidFill extends StatelessWidget {
  const LiquidFill({
    super.key,
    required this.level,
    required this.front,
    required this.back,
    this.frontPeriod = const Duration(seconds: 6),
    this.backPeriod = const Duration(seconds: 9),
    this.amplitude = 7,
    this.levelDuration = const Duration(seconds: 1),
    this.horizontal = false,
    this.gradientHeight,
  });

  final double level;
  final Gradient front;
  final Color back;
  final Duration frontPeriod;
  final Duration backPeriod;
  final double amplitude;

  /// Transition du niveau (1 s linéaire pour le compte à rebours, 250 ms pour le SOS).
  final Duration levelDuration;
  final bool horizontal;
  final double? gradientHeight;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: level.clamp(0, 1)),
        duration: levelDuration,
        curve: Curves.linear,
        builder: (context, animatedLevel, _) => MotionBuilder(
          period: frontPeriod,
          stillPhase: .25,
          builder: (context, t, _) {
            final time = MotionClock.of(context).value;
            final backT = (time.inMicroseconds % backPeriod.inMicroseconds) / backPeriod.inMicroseconds;
            return CustomPaint(
              size: Size.infinite,
              painter: LiquidWavePainter(
                phase: t * 2 * math.pi,
                backPhase: -backT * 2 * math.pi + 1.3,
                level: animatedLevel,
                front: front,
                back: back,
                amplitude: amplitude,
                horizontal: horizontal,
                gradientHeight: gradientHeight,
              ),
            );
          },
        ),
      ),
    );
  }
}
