import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../tara_colors.dart';

/// Fond de carte stylisé (îlots, rues, eau) aux couleurs du thème. Sert de décor tant que
/// la carte réelle (MapLibre, tuiles du Cameroun) n'est pas affichée, et d'écran d'attente
/// quand elle ne peut pas l'être (hors connexion, sans tuiles).
class MapBackdrop extends StatelessWidget {
  const MapBackdrop({super.key, this.opacity = 1, this.seed = 7});

  final double opacity;
  final int seed;

  @override
  Widget build(BuildContext context) {
    final c = TaraColors.of(context);
    return RepaintBoundary(
      child: Opacity(
        opacity: opacity,
        child: CustomPaint(painter: _MapPainter(c, seed), size: Size.infinite),
      ),
    );
  }
}

class _MapPainter extends CustomPainter {
  _MapPainter(this.c, this.seed);

  final TaraColors c;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(seed);
    canvas.drawRect(Offset.zero & size, Paint()..color = c.mapGround);
    // Îlots bâtis.
    final blocks = Paint()..color = c.mapBlocks;
    for (var y = -20.0; y < size.height; y += 70 + random.nextDouble() * 40) {
      for (var x = -20.0; x < size.width; x += 60 + random.nextDouble() * 50) {
        final rect = Rect.fromLTWH(x, y, 40 + random.nextDouble() * 40, 30 + random.nextDouble() * 40);
        canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(6)), blocks);
      }
    }
    // Lagune ou fleuve (le Wouri à Douala).
    final water = Path()
      ..moveTo(size.width * .62, -10)
      ..cubicTo(
        size.width * .5,
        size.height * .25,
        size.width * .95,
        size.height * .4,
        size.width * .78,
        size.height * .7,
      )
      ..cubicTo(size.width * .7, size.height * .85, size.width * .9, size.height, size.width * 1.1, size.height * 1.05);
    canvas.drawPath(
      water,
      Paint()
        ..color = c.mapWater
        ..style = PaintingStyle.stroke
        ..strokeWidth = 46
        ..strokeCap = StrokeCap.round,
    );
    // Rues secondaires puis grands axes.
    final minor = Paint()
      ..color = c.mapMinorRoad
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 9; i++) {
      final y = random.nextDouble() * size.height;
      canvas.drawLine(Offset(-10, y), Offset(size.width + 10, y + (random.nextDouble() - .5) * 120), minor);
      final x = random.nextDouble() * size.width;
      canvas.drawLine(Offset(x, -10), Offset(x + (random.nextDouble() - .5) * 120, size.height + 10), minor);
    }
    final major = Paint()
      ..color = c.mapMajorRoad
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;
    canvas
      ..drawLine(Offset(-10, size.height * .32), Offset(size.width + 10, size.height * .46), major)
      ..drawLine(Offset(size.width * .28, -10), Offset(size.width * .4, size.height + 10), major);
  }

  @override
  bool shouldRepaint(_MapPainter old) => old.c != c || old.seed != seed;
}
