import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Bordure en pointillés arrondie (pièce à envoyer, photo à prendre).
class DashedBorderPainter extends CustomPainter {
  DashedBorderPainter({required this.color, required this.radius, this.strokeWidth = 1.5});

  final Color color;
  final double radius;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()..addRRect(RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)));
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 10) {
        canvas.drawPath(metric.extractPath(d, math.min(d + 5, metric.length)), paint);
      }
    }
  }

  @override
  bool shouldRepaint(DashedBorderPainter old) =>
      old.color != color || old.radius != radius || old.strokeWidth != strokeWidth;
}
