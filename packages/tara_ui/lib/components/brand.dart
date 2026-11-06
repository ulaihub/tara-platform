import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../brand_paths.dart';
import '../svg_path.dart';
import '../tara_colors.dart';

/// Logo complet Tara (« Tara » et « Livraison à la demande »), vectoriel. L'encre suit
/// le thème : foncée en clair, blanche en sombre.
class TaraLogo extends StatelessWidget {
  const TaraLogo({super.key, this.width = 214, this.semanticLabel = 'Tara'});

  final double width;
  final String semanticLabel;

  static const aspectRatio = 1469 / 551;

  @override
  Widget build(BuildContext context) => _Brand(
    width: width,
    aspectRatio: aspectRatio,
    full: true,
    ink: TaraColors.of(context).textPrimary,
    semanticLabel: semanticLabel,
  );
}

/// Pictogramme Tara seul (épingle, colis, élan), vectoriel.
class TaraMark extends StatelessWidget {
  const TaraMark({super.key, this.width = 96, this.semanticLabel = 'Tara'});

  final double width;
  final String semanticLabel;

  static const aspectRatio = 655 / 460;

  @override
  Widget build(BuildContext context) => _Brand(
    width: width,
    aspectRatio: aspectRatio,
    full: false,
    ink: TaraColors.of(context).textPrimary,
    semanticLabel: semanticLabel,
  );
}

class _Brand extends StatelessWidget {
  const _Brand({
    required this.width,
    required this.aspectRatio,
    required this.full,
    required this.ink,
    required this.semanticLabel,
  });

  final double width;
  final double aspectRatio;
  final bool full;
  final Color ink;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) => Semantics(
    image: true,
    label: semanticLabel,
    child: RepaintBoundary(
      child: CustomPaint(
        size: Size(width, width / aspectRatio),
        painter: _BrandPainter(full: full, ink: ink),
      ),
    ),
  );
}

class _BrandPainter extends CustomPainter {
  _BrandPainter({required this.full, required this.ink});

  final bool full;
  final Color ink;

  // Tracés analysés une seule fois pour toute l'app.
  static Path _p(String d) => svgPath(d, fillType: PathFillType.evenOdd);
  static final _markOrange = _p(TaraBrandPaths.markOrange);
  static final _markLeg = _p(TaraBrandPaths.markLeg);
  static final _markBox = _p(TaraBrandPaths.markBox);
  static final _wordTara = _p(TaraBrandPaths.wordTara);
  static final _wordSwoosh = _p(TaraBrandPaths.wordSwoosh);
  static final _tagDark = _p(TaraBrandPaths.tagDark);
  static final _tagOrange = _p(TaraBrandPaths.tagOrange);
  static final _tagLine = _p(TaraBrandPaths.tagLine);

  static const _colors = [TaraBrand.amber, TaraBrand.orange, TaraBrand.red];
  static const _stops = [0.0, .55, 1.0];

  static Paint _gradient(Offset from, Offset to) => Paint()..shader = ui.Gradient.linear(from, to, _colors, _stops);

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..save()
      ..scale(size.width / (full ? 1469 : 655));
    final inkPaint = Paint()..color = ink;
    canvas
      ..drawPath(_markOrange, _gradient(Offset.zero, const Offset(650, 110)))
      ..drawPath(_markLeg, inkPaint)
      ..drawPath(_markBox, inkPaint);
    if (full) {
      canvas
        ..drawPath(_wordTara, inkPaint)
        ..drawPath(_wordSwoosh, _gradient(const Offset(1160, 0), const Offset(1469, 0)))
        ..drawPath(_tagDark, inkPaint)
        ..drawPath(_tagOrange, Paint()..color = TaraBrand.orange)
        ..drawPath(_tagLine, _gradient(const Offset(1340, 0), const Offset(680, 0)));
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BrandPainter old) => old.full != full || old.ink != ink;
}
