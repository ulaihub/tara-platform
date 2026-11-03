import 'package:flutter/widgets.dart';
import 'package:path_parsing/path_parsing.dart';

/// Icônes de la maquette (style « trait » 2 px, extrémités arrondies, grille 24 × 24),
/// reprises tracé pour tracé des fichiers `.dc.html`. Aucune police d'icônes à télécharger.
abstract final class TaraIcons {
  static const navigation = TaraIconData([_P('M3 11l18-8-8 18-2-8z')]);
  static const home = TaraIconData([_P('M4 11l8-7 8 7v9h-5v-6H9v6H4z')]);
  static const activity = TaraIconData([_P('M4 20V10M10 20V4M16 20v-7M22 20H2')]);
  static const user = TaraIconData([_C(12, 8, 4), _P('M4.5 20c1.4-3.2 4.2-5 7.5-5s6.1 1.8 7.5 5')]);
  static const bell = TaraIconData([_P('M6 9a6 6 0 1112 0c0 5 2 6.5 2 6.5H4S6 14 6 9zM10 19.5a2 2 0 004 0')]);
  static const power = TaraIconData([_P('M12 3v8'), _P('M6.3 6.8a8 8 0 1011.4 0')]);
  static const shield = TaraIconData([_P('M12 3l7 3v5c0 4.5-3 8.3-7 10-4-1.7-7-5.5-7-10V6z')]);
  static const close = TaraIconData([_P('M6 6l12 12M18 6L6 18')]);
  static const mapPin = TaraIconData([_P('M12 21s-7-6.2-7-12a7 7 0 0114 0c0 5.8-7 12-7 12z'), _C(12, 9, 2.5)]);
  static const headset = TaraIconData([_P('M4 14v-2a8 8 0 0116 0v2'), _R(3, 14, 4, 6, 1.5), _R(17, 14, 4, 6, 1.5)]);
  static const phone = TaraIconData([
    _P('M5 4h4l2 5-2.5 1.5a11 11 0 005 5L15 13l5 2v4a2 2 0 01-2 2A16 16 0 013 6a2 2 0 012-2'),
  ]);
  static const chevronLeft = TaraIconData([_P('M15 6l-6 6 6 6')]);
  static const timer = TaraIconData([_C(12, 13, 8), _P('M12 9v4l2.5 2M9 2h6')]);
  static const phoneMissed = TaraIconData([
    _P('M16 3l5 5M21 3l-5 5M5 4h4l2 5-2.5 1.5a11 11 0 005 5L15 13l5 2v4a2 2 0 01-2 2A16 16 0 013 6a2 2 0 012-2'),
  ]);
  static const camera = TaraIconData([_P('M4 8h3l2-3h6l2 3h3v11H4z'), _C(12, 13, 3.5)]);
  static const check = TaraIconData([_P('M5 12.5l4.5 4.5L19 7.5')]);
  static const returnArrow = TaraIconData([_P('M9 14L4 9l5-5'), _P('M4 9h10a6 6 0 010 12h-3')]);
  static const wifiOff = TaraIconData([
    _P('M2 8.5a15 15 0 0120 0M5 12a10.5 10.5 0 0114 0M8.5 15.5a5 5 0 017 0'),
    _C(12, 19, 1),
    _P('M3 3l18 18'),
  ]);
  static const package = TaraIconData([_P('M3 7.5L12 3l9 4.5v9L12 21l-9-4.5z'), _P('M3 7.5L12 12l9-4.5M12 12v9')]);
  static const clock = TaraIconData([_C(12, 12, 9), _P('M12 7v5l3 2')]);
  static const cash = TaraIconData([_R(2.5, 6, 19, 12, 2.5), _C(12, 12, 2.5), _P('M6 9.5v5M18 9.5v5')]);
  static const refresh = TaraIconData([_P('M20 12a8 8 0 11-2.3-5.7M20 4v5h-5')]);
  static const arrowRight = TaraIconData([_P('M5 12h14M13 6l6 6-6 6')]);
  static const chevronDown = TaraIconData([_P('M6 9l6 6 6-6')]);
  static const idCard = TaraIconData([
    _R(3, 5, 18, 14, 3),
    _C(9, 11, 2),
    _P('M6.5 16c.6-1.4 1.5-2 2.5-2s1.9.6 2.5 2M14 10h4M14 13.5h3'),
  ]);
  static const license = TaraIconData([_R(3, 5, 18, 14, 3), _P('M7 10h6M7 14h10')]);
  static const upload = TaraIconData([_P('M12 16V4M7 9l5-5 5 5M4 16v2a2 2 0 002 2h12a2 2 0 002-2v-2')]);
  static const selfie = TaraIconData([_C(12, 9, 4), _P('M4.5 20c1.4-3.2 4.2-5 7.5-5s6.1 1.8 7.5 5')]);
  static const shieldCheck = TaraIconData([
    _P('M12 3l7 3v5c0 4.5-3 8.3-7 10-4-1.7-7-5.5-7-10V6z'),
    _P('M9 12l2 2 4-4'),
  ]);
  static const alertCircle = TaraIconData([_C(12, 12, 9), _P('M12 8v5M12 16.5v.5')]);
}

sealed class _Shape {
  const _Shape();
  void addTo(Path path);
}

class _P extends _Shape {
  const _P(this.data);
  final String data;
  @override
  void addTo(Path path) => writeSvgPathDataToPath(data, _PathSink(path));
}

class _C extends _Shape {
  const _C(this.cx, this.cy, this.r);
  final double cx, cy, r;
  @override
  void addTo(Path path) => path.addOval(Rect.fromCircle(center: Offset(cx, cy), radius: r));
}

class _R extends _Shape {
  const _R(this.x, this.y, this.w, this.h, this.rx);
  final double x, y, w, h, rx;
  @override
  void addTo(Path path) => path.addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(rx)));
}

class _PathSink extends PathProxy {
  _PathSink(this.path);
  final Path path;
  @override
  void close() => path.close();
  @override
  void cubicTo(double x1, double y1, double x2, double y2, double x3, double y3) =>
      path.cubicTo(x1, y1, x2, y2, x3, y3);
  @override
  void lineTo(double x, double y) => path.lineTo(x, y);
  @override
  void moveTo(double x, double y) => path.moveTo(x, y);
}

/// Description d'une icône : ses formes sur la grille 24 × 24.
@immutable
class TaraIconData {
  const TaraIconData(this._shapes);
  final List<_Shape> _shapes;

  static final _cache = Expando<Path>();

  Path get path => _cache[this] ??= () {
    final path = Path();
    for (final shape in _shapes) {
      shape.addTo(path);
    }
    return path;
  }();
}

/// Icône en trait. `semanticLabel` est obligatoire quand l'icône est seule (bouton).
class TaraIcon extends StatelessWidget {
  const TaraIcon(this.icon, {super.key, this.size = 22, this.color, this.strokeWidth = 2, this.semanticLabel});

  final TaraIconData icon;
  final double size;
  final Color? color;
  final double strokeWidth;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final color = this.color ?? DefaultTextStyle.of(context).style.color ?? const Color(0xFF000000);
    final glyph = SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _IconPainter(icon, color, strokeWidth)),
    );
    if (semanticLabel == null) return ExcludeSemantics(child: glyph);
    return Semantics(
      label: semanticLabel,
      child: ExcludeSemantics(child: glyph),
    );
  }
}

class _IconPainter extends CustomPainter {
  _IconPainter(this.icon, this.color, this.strokeWidth);
  final TaraIconData icon;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24;
    canvas.scale(scale);
    canvas.drawPath(
      icon.path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_IconPainter old) => old.icon != icon || old.color != color || old.strokeWidth != strokeWidth;
}
