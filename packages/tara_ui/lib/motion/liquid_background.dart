import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/widgets.dart';

import '../tara_colors.dart';
import '../tara_effects.dart';
import 'motion_clock.dart';

/// Une forme liquide du fond (A1) : position, taille, couleurs, flou CSS d'origine.
@immutable
class BlobSpec {
  const BlobSpec({
    required this.alignment,
    required this.size,
    required this.colors,
    this.blur = 60,
    this.opacity = 1,
    this.delay = Duration.zero,
    this.center = const Alignment(-0.4, -0.4),
  });

  /// Position du centre de la forme dans l'écran (-1..1, peut déborder).
  final Alignment alignment;
  final double size;
  final List<Color> colors;

  /// Flou CSS d'origine en pixels (34–80).
  final double blur;

  /// Multiplicateur de l'opacité du thème.
  final double opacity;
  final Duration delay;

  /// Centre du dégradé radial (CSS `circle at 30% 30%` → (-0.4, -0.4)).
  final Alignment center;

  static const brand = [TaraBrand.amber, TaraBrand.orange, TaraBrand.red];
  static const warm = [Color(0xFFFF8A00), TaraBrand.red];
  static const soft = [Color(0xFFFFD27A), Color(0xFFFF8A00)];
  static const alarm = [Color(0xFFFF4D5A), TaraBrand.sos, Color(0xFFB3121F)];
}

/// Rayons CSS « horizontaux / verticaux » des 3 états du morphing (A1).
const _keys = [
  ([.42, .58, .70, .30], [.45, .45, .55, .55]),
  ([.70, .30, .46, .54], [.30, .29, .71, .70]),
  ([1.0, .60, .60, 1.0], [1.0, 1.0, .60, .60]),
];

/// Formes liquides en mouvement lent derrière le verre (A1) : morphing 14 s et dérive
/// 20 s. Le flou réel (coûteux) est remplacé par un flou de masque sur la forme elle-même.
/// Figées en mode effets réduits ou quand le téléphone demande moins d'animations.
class LiquidBackground extends StatelessWidget {
  const LiquidBackground({
    super.key,
    required this.blobs,
    this.morph = const Duration(seconds: 14),
    this.drift = const Duration(seconds: 20),
  });

  final List<BlobSpec> blobs;
  final Duration morph;
  final Duration drift;

  @override
  Widget build(BuildContext context) {
    final colors = TaraColors.of(context);
    final effects = TaraEffects.of(context);
    _BlobPainter painter(double morphT, double driftT) =>
        _BlobPainter(blobs: blobs, morphT: morphT, driftT: driftT, opacity: colors.blobOpacity);
    return RepaintBoundary(
      child: effects.ambientMotion
          ? MotionBuilder(
              period: drift,
              builder: (context, driftT, _) {
                final time = MotionClock.of(context).value;
                final morphT = (time.inMicroseconds % morph.inMicroseconds) / morph.inMicroseconds;
                return CustomPaint(painter: painter(morphT, driftT), size: Size.infinite);
              },
            )
          : CustomPaint(painter: painter(0, 0), size: Size.infinite),
    );
  }
}

class _BlobPainter extends CustomPainter {
  _BlobPainter({required this.blobs, required this.morphT, required this.driftT, required this.opacity});

  final List<BlobSpec> blobs;
  final double morphT;
  final double driftT;
  final double opacity;

  static double _ease(double t) => Curves.easeInOut.transform(t);

  /// Rayons interpolés entre les états clés (0 % → 33 % → 66 % → 100 % = 0 %).
  static (List<double>, List<double>) _radii(double t) {
    final segment = (t * 3).floor() % 3;
    final local = _ease((t * 3) - (t * 3).floor());
    final from = _keys[segment];
    final to = _keys[(segment + 1) % 3];
    List<double> lerp(List<double> a, List<double> b) => [for (var i = 0; i < 4; i++) lerpDouble(a[i], b[i], local)!];
    return (lerp(from.$1, to.$1), lerp(from.$2, to.$2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (final blob in blobs) {
      final delayShare = blob.delay.inMilliseconds / 20000;
      final m = (morphT + delayShare) % 1;
      final d = (driftT + delayShare) % 1;
      // Dérive : (0,0) échelle 1 → (24,−32) échelle 1,12 → retour.
      final wave = _ease(d < .5 ? d * 2 : (1 - d) * 2);
      final center = blob.alignment.alongSize(size) + Offset(24 * wave, -32 * wave);
      final side = blob.size * (1 + .12 * wave);
      final rect = Rect.fromCenter(center: center, width: side, height: side);
      final (h, v) = _radii(m);
      final shape = RRect.fromRectAndCorners(
        rect,
        topLeft: Radius.elliptical(side * h[0], side * v[0]),
        topRight: Radius.elliptical(side * h[1], side * v[1]),
        bottomRight: Radius.elliptical(side * h[2], side * v[2]),
        bottomLeft: Radius.elliptical(side * h[3], side * v[3]),
      );
      final alpha = (opacity * blob.opacity).clamp(0.0, 1.0);
      final paint = Paint()
        ..shader = RadialGradient(
          center: blob.center,
          radius: 0.9,
          colors: [for (final c in blob.colors) c.withValues(alpha: alpha)],
        ).createShader(rect);
      // Flou gardé en effets réduits : les formes y sont figées, dessinées une seule fois
      // puis réutilisées par le RepaintBoundary ; sans flou, leurs bords seraient durs.
      paint.maskFilter = MaskFilter.blur(BlurStyle.normal, blob.blur / 2);
      canvas.drawRRect(shape, paint);
    }
  }

  @override
  bool shouldRepaint(_BlobPainter old) => old.morphT != morphT || old.driftT != driftT || old.opacity != opacity;
}

/// Utilitaire : angle en radians.
double degrees(double value) => value * math.pi / 180;
