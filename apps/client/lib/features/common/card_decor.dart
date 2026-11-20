import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:flutter/widgets.dart';
import 'package:tara_ui/motion/motion_clock.dart';

/// Décors animés des cartes sombres de la refonte (accueil, portefeuille) : trajet de
/// livraison en pointillé où voyage un point lumineux, et bande de lumière qui passe.

/// Trajet en pointillé (courbe de la maquette, à l'échelle de la carte) et point lumineux
/// qui le parcourt en 4,6 s, en apparaissant puis en s'effaçant. Sans animations, le
/// point reste au milieu du trajet.
class RouteTrail extends StatelessWidget {
  const RouteTrail({super.key, required this.route, required this.base, this.dot = 9});

  /// Départ puis deux courbes de Bézier, en coordonnées de la maquette.
  final List<Offset> route;

  /// Taille de la carte dans la maquette (les coordonnées y sont mises à l'échelle).
  final Size base;

  /// Diamètre du point.
  final double dot;

  /// Carte « Ventes à recevoir » du portefeuille (352 × 196).
  static const walletCard = [
    Offset(-10, 172),
    Offset(70, 160), Offset(110, 104), Offset(186, 104),
    Offset(262, 104), Offset(296, 48), Offset(362, 22),
  ];

  /// Carte « Encaissé aujourd'hui » de l'accueil (352 × 122).
  static const homeHero = [
    Offset(-10, 110),
    Offset(90, 104), Offset(120, 60), Offset(200, 62),
    Offset(280, 64), Offset(300, 24), Offset(362, 12),
  ];

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: MotionBuilder(
        period: const Duration(milliseconds: 4600),
        stillPhase: .55,
        builder: (context, t, _) => CustomPaint(
          painter: _RoutePainter(route: route, base: base, dot: dot, t: Curves.easeInOut.transform(t)),
        ),
      ),
    );
  }
}

class _RoutePainter extends CustomPainter {
  _RoutePainter({required this.route, required this.base, required this.dot, required this.t});

  final List<Offset> route;
  final Size base;
  final double dot;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / base.width, sy = size.height / base.height;
    Offset at(int i) => Offset(route[i].dx * sx, route[i].dy * sy);
    final path = Path()
      ..moveTo(at(0).dx, at(0).dy)
      ..cubicTo(at(1).dx, at(1).dy, at(2).dx, at(2).dy, at(3).dx, at(3).dy)
      ..cubicTo(at(4).dx, at(4).dy, at(5).dx, at(5).dy, at(6).dx, at(6).dy);
    final dash = Paint()
      ..color = const Color.fromRGBO(255, 177, 92, .34)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    PathMetric? first;
    for (final metric in path.computeMetrics()) {
      first ??= metric;
      for (double d = 0; d < metric.length; d += 9) {
        canvas.drawPath(metric.extractPath(d, math.min(d + 2, metric.length)), dash);
      }
    }
    final metric = first;
    if (metric == null) return;
    final point = metric.getTangentForOffset(metric.length * t)?.position;
    if (point == null) return;
    final fade = t < .1 ? t / .1 : (t > .85 ? (1 - t) / .15 : 1.0);
    final r = dot / 2;
    canvas
      ..drawCircle(
        point,
        r + 4,
        Paint()
          ..color = Color.fromRGBO(255, 106, 0, .65 * fade)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, r + 3),
      )
      ..drawCircle(point, r + 4, Paint()..color = Color.fromRGBO(255, 176, 0, .18 * fade))
      ..drawCircle(point, r, Paint()..color = Color.fromRGBO(255, 176, 0, fade));
  }

  @override
  bool shouldRepaint(_RoutePainter old) => old.t != t || old.route != route;
}

/// Bande de lumière inclinée qui traverse la carte, puis attend (cycle de 6 s).
class SheenSweep extends StatelessWidget {
  const SheenSweep({super.key, required this.color, required this.delay, this.width = .34, this.height = 1.8});

  final Color color;
  final Duration delay;

  /// Largeur et hauteur de la bande, en part de la carte.
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: LayoutBuilder(
          builder: (context, box) => MotionBuilder(
            period: const Duration(seconds: 6),
            delay: Duration(microseconds: 6000000 - delay.inMicroseconds),
            stillPhase: .9,
            builder: (context, t, _) {
              if (t >= .45) return const SizedBox.shrink();
              final p = Curves.easeInOut.transform(t / .45);
              final band = box.maxWidth * width;
              final x = -1.6 * band + p * 5.8 * band;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: x,
                    top: -box.maxHeight * (height - 1) / 2,
                    width: band,
                    height: box.maxHeight * height,
                    child: Transform.rotate(
                      angle: 18 * math.pi / 180,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [color.withValues(alpha: 0), color, color.withValues(alpha: 0)]),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
