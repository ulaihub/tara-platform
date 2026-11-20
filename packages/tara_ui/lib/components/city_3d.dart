import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../motion/motion_clock.dart';
import '../tara_colors.dart';

// Quartier en relief de la maquette (accueil du livreur) : un sol de 360 × 360 avec ses
// rues et le fleuve, incliné à 55° et tourné de −35°, qui pivote lentement (−35° ↔ −27°
// en 30 s). Chaque immeuble est une boîte dont les faces sont projetées à la main, comme
// le CSS `perspective: 820px` de la maquette, puis peintes du fond vers l'avant.

/// Un immeuble : emprise au sol (gauche, haut, largeur, profondeur) et hauteur, en pixels
/// de la maquette. [windows] : rangées de fenêtres éclairées sur les façades.
@immutable
class CityBlock {
  const CityBlock(this.left, this.top, this.width, this.depth, this.height, {this.windows = false});
  final double left, top, width, depth, height;
  final bool windows;
}

/// Quartier de l'accueil hors ligne (Livreur-Hors-Ligne).
const cityOffline = [
  CityBlock(11, 11, 47, 39, 42, windows: true),
  CityBlock(11, 63, 50, 42, 52, windows: true),
  CityBlock(68, 63, 50, 40, 56),
  CityBlock(11, 147, 43, 38, 51),
  CityBlock(68, 147, 51, 41, 29),
  CityBlock(68, 196, 47, 36, 45, windows: true),
  CityBlock(11, 273, 46, 30, 19, windows: true),
  CityBlock(68, 273, 44, 28, 20),
  CityBlock(157, 11, 47, 40, 38, windows: true),
  CityBlock(157, 63, 40, 39, 14),
  CityBlock(211, 11, 44, 38, 38),
  CityBlock(211, 63, 42, 44, 19),
  CityBlock(157, 147, 42, 42, 29),
  CityBlock(211, 147, 47, 39, 41),
  CityBlock(211, 196, 47, 38, 21, windows: true),
  CityBlock(157, 273, 46, 26, 28),
  CityBlock(211, 273, 46, 31, 29, windows: true),
  CityBlock(293, 63, 54, 44, 60),
  CityBlock(293, 147, 55, 42, 49),
  CityBlock(293, 196, 53, 39, 72, windows: true),
  CityBlock(293, 273, 49, 33, 17, windows: true),
];

/// Couleurs du quartier selon le thème (variables `--map-*`, `--road-*`, `--b1…b5`).
@immutable
class CityPalette {
  const CityPalette({
    required this.background,
    required this.ground,
    required this.road1,
    required this.road2,
    required this.water,
    required this.south,
    required this.north,
    required this.east,
    required this.west,
    required this.roof,
    required this.edge,
  });

  final Color background, ground, road1, road2, water;
  final Color south, north, east, west, roof, edge;

  static const dark = CityPalette(
    background: Color(0xFF0D0E13),
    ground: Color(0xFF111219),
    road1: Color(0xFF252833),
    road2: Color(0xFF1E2029),
    water: Color(0xFF0F1922),
    south: Color(0xFF1B1D25),
    north: Color(0xFF15161D),
    east: Color(0xFF20222C),
    west: Color(0xFF17181F),
    roof: Color(0xFF272A35),
    edge: Color(0x0DFFFFFF),
  );

  static const light = CityPalette(
    background: Color(0xFFEFE8DE),
    ground: Color(0xFFE7DED2),
    road1: Color(0xFFFFFFFF),
    road2: Color(0xFFFBF7F1),
    water: Color(0xFFBCD7E4),
    south: Color(0xFFE6D9CA),
    north: Color(0xFFDCCDBC),
    east: Color(0xFFEFE4D7),
    west: Color(0xFFD6C6B4),
    roof: Color(0xFFFFFFFF),
    edge: Color(0x0D16120E),
  );

  static CityPalette of(BuildContext context) => TaraColors.of(context).isDark ? dark : light;
}

/// Filtre « en veille » de la maquette (`--sleep`) : le quartier pâlit quand le livreur
/// est hors ligne. Sombre : saturate(.35) brightness(.55) ; clair : saturate(.25)
/// brightness(1.02) contrast(.92).
ColorFilter citySleepFilter({required bool dark}) {
  final s = dark ? .35 : .25;
  final b = dark ? .55 : 1.02;
  final c = dark ? 1.0 : .92;
  // Saturation (coefficients CSS), puis luminosité, puis contraste.
  const r = .2126, g = .7152, bl = .0722;
  final sat = [
    r + (1 - r) * s,
    g - g * s,
    bl - bl * s,
    r - r * s,
    g + (1 - g) * s,
    bl - bl * s,
    r - r * s,
    g - g * s,
    bl + (1 - bl) * s,
  ];
  final k = b * c;
  final offset = (1 - c) * 127.5;
  return ColorFilter.matrix([
    sat[0] * k,
    sat[1] * k,
    sat[2] * k,
    0,
    offset,
    sat[3] * k,
    sat[4] * k,
    sat[5] * k,
    0,
    offset,
    sat[6] * k,
    sat[7] * k,
    sat[8] * k,
    0,
    offset,
    0,
    0,
    0,
    1,
    0,
  ]);
}

/// Quartier en relief, à la largeur de l'écran (390 px de maquette). [top] : position du
/// sol dans la zone (70 px hors ligne, 130 px en ligne). Sans animations, il reste à −35°.
class City3D extends StatelessWidget {
  const City3D({
    super.key,
    this.blocks = cityOffline,
    this.top = 70,
    this.height = 450,
    this.period = const Duration(seconds: 30),
    this.overlay,
  });

  final List<CityBlock> blocks;
  final double top;

  /// Hauteur de la zone, en pixels de maquette.
  final double height;
  final Duration period;

  /// Dessin posé sur le sol, sous les immeubles (zones), en coordonnées du sol.
  final void Function(Canvas canvas, Offset Function(double x, double y) ground)? overlay;

  @override
  Widget build(BuildContext context) {
    final palette = CityPalette.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = constraints.maxWidth / 390;
        return MotionBuilder(
          period: period,
          stillPhase: 0,
          builder: (context, t, _) {
            // ease-in-out entre −35° et −27°, aller et retour.
            final wave = (1 - math.cos(t * 2 * math.pi)) / 2;
            return CustomPaint(
              size: Size(constraints.maxWidth, height * scale),
              painter: _CityPainter(
                blocks: blocks,
                palette: palette,
                top: top,
                scale: scale,
                yaw: (-35 + 8 * wave) * math.pi / 180,
                overlay: overlay,
              ),
            );
          },
        );
      },
    );
  }
}

@immutable
class _P3 {
  const _P3(this.x, this.y, this.z);
  final double x, y, z;
}

class _Face {
  _Face(this.points, this.color, this.depth, {this.windows = false, this.roof = false});
  final List<_P3> points;
  final Color color;
  final double depth;
  final bool windows;
  final bool roof;
}

class _CityPainter extends CustomPainter {
  _CityPainter({
    required this.blocks,
    required this.palette,
    required this.top,
    required this.scale,
    required this.yaw,
    required this.overlay,
  });

  final List<CityBlock> blocks;
  final CityPalette palette;
  final double top;
  final double scale;
  final double yaw;
  final void Function(Canvas canvas, Offset Function(double x, double y) ground)? overlay;

  static const _side = 360.0;
  static const _pitch = 55 * math.pi / 180;
  static const _perspective = 820.0;

  /// Point du sol (x, y) à la hauteur z → point de la scène, avant la perspective.
  _P3 _world(double x, double y, double z) {
    // Origine de la transformation : centre du sol.
    final lx = x - _side / 2, ly = y - _side / 2;
    // rotateZ(yaw)
    final cz = math.cos(yaw), sz = math.sin(yaw);
    final x1 = lx * cz - ly * sz, y1 = lx * sz + ly * cz;
    // rotateX(55°)
    final cx = math.cos(_pitch), sx = math.sin(_pitch);
    final y2 = y1 * cx - z * sx, z2 = y1 * sx + z * cx;
    return _P3(15 + _side / 2 + x1, top + _side / 2 + y2, z2);
  }

  Offset _project(_P3 p, Size size) {
    // perspective-origin : 50 % 10 % de la zone.
    final ox = 195.0, oy = size.height / scale * .1;
    final k = _perspective / (_perspective - p.z);
    return Offset((ox + (p.x - ox) * k) * scale, (oy + (p.y - oy) * k) * scale);
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = palette.background);
    Path poly(List<_P3> pts) => Path()..addPolygon([for (final p in pts) _project(p, size)], true);
    Path rect(double x, double y, double w, double h) =>
        poly([_world(x, y, 0), _world(x + w, y, 0), _world(x + w, y + h, 0), _world(x, y + h, 0)]);

    canvas
      ..drawPath(rect(0, 0, _side, _side), Paint()..color = palette.ground)
      ..drawPath(rect(0, 120, _side, 16), Paint()..color = palette.road1)
      ..drawPath(rect(0, 250, _side, 12), Paint()..color = palette.road2)
      ..drawPath(rect(130, 0, 16, _side), Paint()..color = palette.road1)
      ..drawPath(rect(270, 0, 12, _side), Paint()..color = palette.road2)
      ..drawPath(rect(0, 318, _side, 42), Paint()..color = palette.water);
    overlay?.call(canvas, (x, y) => _project(_world(x, y, 0), size));

    // Œil : au-dessus de l'origine de perspective, à 820 px devant l'écran.
    final eye = _P3(195, size.height / scale * .1, _perspective);
    final faces = <_Face>[];
    void face(List<_P3> pts, Color color, {bool windows = false, bool roof = false}) {
      // Face visible si sa normale regarde l'œil.
      final a = pts[0], b = pts[1], c = pts[2];
      final ux = b.x - a.x, uy = b.y - a.y, uz = b.z - a.z;
      final vx = c.x - a.x, vy = c.y - a.y, vz = c.z - a.z;
      final nx = uy * vz - uz * vy, ny = uz * vx - ux * vz, nz = ux * vy - uy * vx;
      var mx = 0.0, my = 0.0, mz = 0.0;
      for (final p in pts) {
        mx += p.x / pts.length;
        my += p.y / pts.length;
        mz += p.z / pts.length;
      }
      // Sommets dans le sens des aiguilles d'une montre vus de dehors (y vers le bas).
      if (nx * (eye.x - mx) + ny * (eye.y - my) + nz * (eye.z - mz) >= 0) return;
      final dx = eye.x - mx, dy = eye.y - my, dz = eye.z - mz;
      faces.add(_Face(pts, color, dx * dx + dy * dy + dz * dz, windows: windows, roof: roof));
    }

    for (final b in blocks) {
      final x0 = b.left, x1 = b.left + b.width, y0 = b.top, y1 = b.top + b.depth, h = b.height;
      // Même sens de parcours pour toutes les faces (voir le test de visibilité).
      face(
        [_world(x0, y1, 0), _world(x1, y1, 0), _world(x1, y1, h), _world(x0, y1, h)],
        palette.south,
        windows: b.windows,
      );
      face([_world(x1, y0, 0), _world(x0, y0, 0), _world(x0, y0, h), _world(x1, y0, h)], palette.north);
      face(
        [_world(x1, y1, 0), _world(x1, y0, 0), _world(x1, y0, h), _world(x1, y1, h)],
        palette.east,
        windows: b.windows,
      );
      face([_world(x0, y0, 0), _world(x0, y1, 0), _world(x0, y1, h), _world(x0, y0, h)], palette.west);
      face([_world(x0, y0, h), _world(x0, y1, h), _world(x1, y1, h), _world(x1, y0, h)], palette.roof, roof: true);
    }
    faces.sort((a, b) => b.depth.compareTo(a.depth));

    final windowPaint = Paint()
      ..color = const Color.fromRGBO(255, 177, 92, .16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * scale;
    final edgePaint = Paint()
      ..color = palette.edge
      ..style = PaintingStyle.stroke
      ..strokeWidth = scale;
    for (final f in faces) {
      final path = poly(f.points);
      canvas.drawPath(path, Paint()..color = f.color);
      if (f.roof) canvas.drawPath(path, edgePaint);
      if (f.windows) {
        // Rangées éclairées tous les 9 px, comptées depuis le toit (dégradé répété CSS).
        final p0 = f.points[0], p1 = f.points[1], p3 = f.points[3];
        final height = math.sqrt(math.pow(p3.x - p0.x, 2) + math.pow(p3.y - p0.y, 2) + math.pow(p3.z - p0.z, 2));
        for (var d = 8.0; d < height; d += 9) {
          final t = 1 - d / height;
          _P3 lerp(_P3 a, _P3 b) => _P3(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t, a.z + (b.z - a.z) * t);
          final a = lerp(p0, p3), b = lerp(p1, f.points[2]);
          canvas.drawLine(_project(a, size), _project(b, size), windowPaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_CityPainter old) =>
      old.yaw != yaw || old.palette != palette || old.scale != scale || old.blocks != blocks || old.top != top;
}
