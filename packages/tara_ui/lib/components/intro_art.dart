import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../motion/motion_clock.dart';
import '../tara_colors.dart';
import '../tara_icons.dart';
import '../tara_typography.dart';

/// Pièces des illustrations de la présentation (maquettes « Présentation ») : sol en
/// perspective, trajet orange qui se dessine, carte d'argent sombre, pastilles de verre.
/// Les positions sont en fractions de la zone (0 à 1) : l'illustration suit la taille.

/// Sol quadrillé qui fuit vers l'horizon.
class IntroGrid extends StatelessWidget {
  const IntroGrid({super.key, this.horizon = .42});

  /// Hauteur de l'horizon, en fraction de la zone.
  final double horizon;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _GridPainter(TaraColors.of(context).textPrimary, horizon), size: Size.infinite);
}

class _GridPainter extends CustomPainter {
  _GridPainter(this.ink, this.horizon);
  final Color ink;
  final double horizon;

  @override
  void paint(Canvas canvas, Size size) {
    final top = size.height * horizon;
    final paint = Paint()
      ..strokeWidth = 1
      ..shader = ui.Gradient.linear(Offset(0, top), Offset(0, size.height), [
        ink.withValues(alpha: 0),
        ink.withValues(alpha: .10),
      ]);
    // Lignes horizontales, de plus en plus espacées vers le bas.
    for (var i = 0; i < 9; i++) {
      final f = math.pow(i / 8, 1.8).toDouble();
      final y = top + (size.height - top) * f;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    // Lignes qui convergent vers le point de fuite.
    final vanish = Offset(size.width / 2, top - size.height * .35);
    for (var i = -6; i <= 6; i++) {
      final x = size.width / 2 + i * size.width * .16;
      final bottom = Offset(x, size.height);
      final t = (top - vanish.dy) / (bottom.dy - vanish.dy);
      canvas.drawLine(Offset.lerp(vanish, bottom, t)!, bottom, paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => old.ink != ink || old.horizon != horizon;
}

/// Trajet orange (points en fractions) qui se dessine en boucle ; `mover` avance dessus.
class IntroRoute extends StatelessWidget {
  const IntroRoute({
    super.key,
    required this.points,
    this.curved = false,
    this.mover,
    this.period = const Duration(seconds: 5),
    this.stillPhase = .7,
    this.drawOnly = false,
  });

  final List<Offset> points;

  /// Courbe lissée (sinon segments droits, rues).
  final bool curved;

  /// Petit élément qui suit le trajet (moto, colis).
  final Widget? mover;
  final Duration period;
  final double stillPhase;

  /// Le trajet se dessine puis reste plein (pas de déplacement).
  final bool drawOnly;

  @override
  Widget build(BuildContext context) => MotionBuilder(
    period: period,
    stillPhase: stillPhase,
    builder: (context, t, _) => LayoutBuilder(
      builder: (context, box) {
        final size = box.biggest;
        final path = _path(size);
        final metric = path.computeMetrics().first;
        // Dessin progressif sur la première moitié du cycle, puis plein.
        final drawn = drawOnly ? math.min(1.0, t / .55) : 1.0;
        final along = drawOnly ? 1.0 : Curves.easeInOut.transform(t);
        final at = metric.getTangentForOffset(metric.length * along)?.position;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: CustomPaint(painter: _RoutePainter(metric.extractPath(0, metric.length * drawn))),
            ),
            if (mover != null && at != null)
              Positioned(left: at.dx - 18, top: at.dy - 18, width: 36, height: 36, child: mover!),
          ],
        );
      },
    ),
  );

  Path _path(Size size) {
    final pts = [for (final p in points) Offset(p.dx * size.width, p.dy * size.height)];
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    if (curved && pts.length >= 4) {
      for (var i = 1; i + 2 < pts.length + 1 && i + 2 <= pts.length; i += 3) {
        path.cubicTo(pts[i].dx, pts[i].dy, pts[i + 1].dx, pts[i + 1].dy, pts[i + 2].dx, pts[i + 2].dy);
      }
    } else {
      for (final p in pts.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
    }
    return path;
  }
}

class _RoutePainter extends CustomPainter {
  _RoutePainter(this.path);
  final Path path;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = path.getBounds();
    Paint stroke(double width, double alpha) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = width
      ..shader = ui.Gradient.linear(bounds.bottomLeft, bounds.topRight, [
        const Color(0xFFFFB000).withValues(alpha: alpha),
        const Color(0xFFFF5A00).withValues(alpha: alpha),
      ]);
    canvas
      ..drawPath(path, stroke(12, .18))
      ..drawPath(path, stroke(4, 1));
  }

  @override
  bool shouldRepaint(_RoutePainter old) => true;
}

/// Rond dégradé avec une icône (livreur, point d'arrivée).
class IntroPuck extends StatelessWidget {
  const IntroPuck({super.key, required this.icon, this.size = 34});
  final TaraIconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = TaraColors.of(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: TaraBrand.gradient,
        border: Border.all(color: c.bg, width: 3),
        boxShadow: const [BoxShadow(color: Color.fromRGBO(255, 106, 0, .55), blurRadius: 16)],
      ),
      alignment: Alignment.center,
      child: TaraIcon(icon, size: size * .45, color: TaraBrand.onBrand, strokeWidth: 2.4),
    );
  }
}

/// Pastille de verre avec un texte (« 1 minute pour commander »).
class IntroChip extends StatelessWidget {
  const IntroChip({super.key, required this.label, this.icon, this.tint});
  final String label;
  final TaraIconData? icon;

  /// Fond teinté (vert pour « Mobile Money ✓ »).
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final c = TaraColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: tint?.withValues(alpha: .16) ?? c.textPrimary.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: (tint ?? c.textPrimary).withValues(alpha: .18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon case final icon?) ...[
            TaraIcon(icon, size: 14, color: tint ?? c.accentText, strokeWidth: 2.4),
            const SizedBox(width: 6),
          ],
          Text(label, style: TaraText.smallStrong.copyWith(color: c.textPrimary)),
        ],
      ),
    );
  }
}

/// Étiquette posée sur l'illustration : titre et ligne secondaire.
class IntroLabel extends StatelessWidget {
  const IntroLabel({super.key, required this.title, this.subtitle, this.leading});
  final String title;
  final String? subtitle;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final c = TaraColors.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (leading case final leading?) ...[leading, const SizedBox(width: 8)],
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TaraText.label.copyWith(color: c.textPrimary, fontWeight: FontWeight.w800)),
            if (subtitle case final subtitle?)
              Text(subtitle, style: TaraText.small.copyWith(color: c.textPrimary.withValues(alpha: .7))),
          ],
        ),
      ],
    );
  }
}

/// Carte d'argent sombre (maquette « Ventes à recevoir ») : libellé, montant qui monte,
/// ligne du bas, barres orange ; légère inclinaison en 3D.
class MoneyCard extends StatelessWidget {
  const MoneyCard({
    super.key,
    required this.label,
    required this.amount,
    this.from,
    this.unit = 'F',
    this.footer,
    this.footerColor,
    this.tag,
    this.tilt = -.05,
    this.width = 280,
  });

  final String label;
  final int amount;

  /// Montant de départ : la carte compte jusqu'à [amount].
  final int? from;
  final String unit;
  final String? footer;
  final Color? footerColor;
  final String? tag;
  final double tilt;
  final double width;

  static String format(int value) {
    final digits = value.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(' ');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFFFFFFFF);
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..setEntry(3, 2, .0012)
        ..rotateX(.18)
        ..rotateY(tilt * 3)
        ..rotateZ(tilt),
      child: Container(
        width: width,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2A1F18), Color(0xFF120D0A)],
          ),
          border: Border.all(color: const Color.fromRGBO(255, 177, 92, .18)),
          boxShadow: const [
            BoxShadow(color: Color.fromRGBO(255, 106, 0, .28), blurRadius: 40, offset: Offset(0, 18)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(label, style: TaraText.label.copyWith(color: ink.withValues(alpha: .72))),
                ),
                if (tag case final tag?)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color.fromRGBO(255, 177, 92, .16),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(tag, style: TaraText.smallStrong.copyWith(color: const Color(0xFFFFB15C))),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: (from ?? amount).toDouble(), end: amount.toDouble()),
              duration: const Duration(milliseconds: 1400),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: format(value.round())),
                    TextSpan(text: ' $unit', style: TaraText.unit.copyWith(color: ink.withValues(alpha: .6))),
                  ],
                ),
                style: TaraText.amountL.copyWith(color: ink, fontSize: 34),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Text(
                    footer ?? '',
                    style: TaraText.smallStrong.copyWith(color: footerColor ?? ink.withValues(alpha: .6)),
                  ),
                ),
                const _Bars(),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Bars extends StatelessWidget {
  const _Bars();

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      for (final (w, color) in const [(52.0, Color(0xFFFF5A00)), (36.0, Color(0xFFFF8A3D)), (20.0, Color(0xFFFFB000))])
        Container(
          margin: const EdgeInsets.only(top: 4),
          width: w,
          height: 5,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
        ),
    ],
  );
}

/// Pièce « F » qui tombe en boucle vers la carte.
class IntroCoin extends StatelessWidget {
  const IntroCoin({super.key, this.delay = Duration.zero, this.fall = 90});
  final Duration delay;
  final double fall;

  @override
  Widget build(BuildContext context) => MotionBuilder(
    period: const Duration(milliseconds: 2400),
    delay: delay,
    stillPhase: .35,
    builder: (context, t, child) => Transform.translate(
      offset: Offset(0, fall * Curves.easeIn.transform(t)),
      child: Opacity(opacity: t < .85 ? 1 : (1 - t) / .15, child: child),
    ),
    child: Container(
      width: 20,
      height: 20,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: TaraBrand.gradient,
        boxShadow: [BoxShadow(color: Color.fromRGBO(255, 106, 0, .4), blurRadius: 8)],
      ),
      alignment: Alignment.center,
      child: const Text('F', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: TaraBrand.onBrand)),
    ),
  );
}

/// Halo orange flou derrière un élément.
class IntroGlow extends StatelessWidget {
  const IntroGlow({super.key, this.size = 220, this.alpha = .35});
  final double size;
  final double alpha;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [Color.fromRGBO(255, 122, 40, alpha), const Color.fromRGBO(255, 122, 40, 0)],
        ),
      ),
    ),
  );
}
