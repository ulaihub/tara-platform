import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../tara_colors.dart';

/// Note de 1 à 5 étoiles (F4). On touche une étoile ou on fait glisser le doigt sur la
/// rangée ; les étoiles choisies se remplissent du dégradé de la marque et la dernière
/// rebondit. Chaque étoile est un bouton pour les lecteurs d'écran ([labelOf] : « 4 étoiles »).
class StarRating extends StatelessWidget {
  const StarRating({super.key, required this.value, required this.onChanged, required this.labelOf, this.size = 40});

  /// Étoiles choisies (0 : aucune).
  final int value;

  /// null : lecture seule.
  final ValueChanged<int>? onChanged;
  final String Function(int stars) labelOf;
  final double size;

  static const _gap = 8.0;

  void _select(int stars) {
    if (onChanged == null || stars == value) return;
    HapticFeedback.selectionClick();
    onChanged!(stars);
  }

  /// Étoile sous le doigt, d'après sa position horizontale dans la rangée.
  int _starAt(double dx) => (dx / (size + _gap)).floor().clamp(0, 4) + 1;

  @override
  Widget build(BuildContext context) {
    final c = TaraColors.of(context);
    return GestureDetector(
      onHorizontalDragUpdate: onChanged == null ? null : (details) => _select(_starAt(details.localPosition.dx)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var stars = 1; stars <= 5; stars++) ...[
            if (stars > 1) const SizedBox(width: _gap),
            Semantics(
              button: onChanged != null,
              selected: stars <= value,
              label: labelOf(stars),
              child: GestureDetector(
                onTap: onChanged == null ? null : () => _select(stars),
                child: AnimatedScale(
                  scale: stars == value ? 1.18 : 1,
                  duration: const Duration(milliseconds: 360),
                  curve: Curves.elasticOut,
                  child: CustomPaint(
                    size: Size.square(size),
                    painter: _StarPainter(filled: stars <= value, outline: c.chipBorder),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StarPainter extends CustomPainter {
  const _StarPainter({required this.filled, required this.outline});

  final bool filled;
  final Color outline;

  @override
  void paint(Canvas canvas, Size size) {
    final path = _star(size);
    if (filled) {
      canvas.drawPath(path, Paint()..shader = TaraBrand.gradient.createShader(Offset.zero & size));
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size.width * .06
        ..strokeJoin = StrokeJoin.round
        ..color = filled ? TaraBrand.orange : outline,
    );
  }

  /// Étoile à cinq branches aux pointes arrondies par le trait.
  static Path _star(Size size) {
    final center = size.center(Offset.zero).translate(0, size.height * .03);
    final outer = size.width * .46;
    final inner = outer * .48;
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final radius = i.isEven ? outer : inner;
      final angle = -math.pi / 2 + i * math.pi / 5;
      final point = center + Offset(math.cos(angle), math.sin(angle)) * radius;
      i == 0 ? path.moveTo(point.dx, point.dy) : path.lineTo(point.dx, point.dy);
    }
    return path..close();
  }

  @override
  bool shouldRepaint(_StarPainter old) => old.filled != filled || old.outline != outline;
}
