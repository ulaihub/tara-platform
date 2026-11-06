import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../tara_colors.dart';
import '../tara_effects.dart';

/// Pluie de confettis aux couleurs de la marque, lancée une fois depuis le haut de
/// l'écran (palier de courses, première livraison…). Ne capte aucun toucher. Animations
/// réduites : rien n'est dessiné.
class Confetti extends StatefulWidget {
  const Confetti({super.key, this.count = 70, this.duration = const Duration(milliseconds: 2400), this.seed = 7});

  final int count;
  final Duration duration;

  /// Graine du tirage : même pluie d'une fois sur l'autre (captures de test).
  final int seed;

  @override
  State<Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<Confetti> with SingleTickerProviderStateMixin {
  late final AnimationController _time = AnimationController(vsync: this, duration: widget.duration)..forward();
  late final List<_Piece> _pieces = _Piece.scatter(widget.count, math.Random(widget.seed));

  @override
  void dispose() {
    _time.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!TaraEffects.of(context).decorativeMotion) return const SizedBox.shrink();
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(size: Size.infinite, painter: _ConfettiPainter(_time, _pieces)),
      ),
    );
  }
}

class _Piece {
  _Piece(this.x, this.vx, this.vy, this.spin, this.color, this.size, this.round, this.delay);

  /// Départ (part de la largeur), vitesses (part de la hauteur par seconde).
  final double x;
  final double vx;
  final double vy;
  final double spin;
  final Color color;
  final double size;
  final bool round;
  final double delay;

  static const _colors = [TaraBrand.amber, TaraBrand.orange, TaraBrand.red, Color(0xFFFFFFFF), Color(0xFFFFD27A)];

  static List<_Piece> scatter(int count, math.Random random) => [
    for (var i = 0; i < count; i++)
      _Piece(
        random.nextDouble(),
        (random.nextDouble() - .5) * .35,
        .25 + random.nextDouble() * .45,
        (random.nextDouble() - .5) * 14,
        _colors[random.nextInt(_colors.length)],
        5 + random.nextDouble() * 6,
        random.nextInt(3) == 0,
        random.nextDouble() * .25,
      ),
  ];
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.time, this.pieces) : super(repaint: time);

  final Animation<double> time;
  final List<_Piece> pieces;

  @override
  void paint(Canvas canvas, Size size) {
    final t = time.value;
    final paint = Paint();
    for (final piece in pieces) {
      final local = ((t - piece.delay) / (1 - piece.delay)).clamp(0.0, 1.0);
      if (local <= 0) continue;
      final seconds = local * 2.4;
      // Chute freinée : rapide au début, flottante ensuite, balancement latéral.
      final fall = piece.vy * seconds + .06 * seconds * seconds;
      final dx = (piece.x + piece.vx * seconds + .03 * math.sin(seconds * 5 + piece.spin)) * size.width;
      final dy = (-0.05 + fall) * size.height;
      final opacity = local > .75 ? (1 - local) / .25 : 1.0;
      paint.color = piece.color.withValues(alpha: piece.color.a * opacity);
      canvas
        ..save()
        ..translate(dx, dy)
        ..rotate(piece.spin * seconds);
      if (piece.round) {
        canvas.drawCircle(Offset.zero, piece.size / 2.6, paint);
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: piece.size, height: piece.size * .45),
            const Radius.circular(1.5),
          ),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => false;
}
