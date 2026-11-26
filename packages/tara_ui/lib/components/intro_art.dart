import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path_parsing/path_parsing.dart';

import '../motion/motion_clock.dart';
import '../tara_colors.dart';
import '../tara_icons.dart';
import '../tara_typography.dart';

/// Pièces des illustrations de la présentation, reprises des maquettes « Présentation »
/// (HTML et CSS) : mêmes mesures en pixels sur une zone de 390 × 430, mêmes transformations
/// 3D (perspective, rotations), mêmes animations et durées.

// ── Outils ────────────────────────────────────────────────────────────────────────────

/// Chemin SVG (attribut `d`) en [Path].
Path introPath(String data) {
  final path = Path();
  writeSvgPathDataToPath(data, _Sink(path));
  return path;
}

class _Sink extends PathProxy {
  _Sink(this.path);
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

/// Dégradé CSS `linear-gradient(<angle>deg, …)` sur une boîte de taille [size].
LinearGradient cssGradient(double degrees, Size size, List<Color> colors, [List<double>? stops]) {
  final a = degrees * math.pi / 180;
  final dx = math.sin(a);
  final dy = -math.cos(a);
  final half = ((size.width * dx).abs() + (size.height * dy).abs()) / 2;
  final end = Alignment(dx * half / (size.width / 2), dy * half / (size.height / 2));
  return LinearGradient(begin: -end, end: end, colors: colors, stops: stops);
}

/// CSS `perspective(d)` : +z vers l'observateur.
Matrix4 cssPerspective(double d) => Matrix4.identity()..setEntry(3, 2, -1 / d);

double _rad(double degrees) => degrees * math.pi / 180;

/// Point (x, y, z) transformé, avant division : (x, y, z, w).
(double, double, double, double) _apply(Matrix4 m, double x, double y, double z) {
  final s = m.storage;
  return (
    s[0] * x + s[4] * y + s[8] * z + s[12],
    s[1] * x + s[5] * y + s[9] * z + s[13],
    s[2] * x + s[6] * y + s[10] * z + s[14],
    s[3] * x + s[7] * y + s[11] * z + s[15],
  );
}

/// Aller-retour adouci (keyframes CSS 0 %, 50 %, 100 % en `ease-in-out`).
double introPingPong(double t) => Curves.easeInOut.transform(t < .5 ? t * 2 : 2 - t * 2);

/// Carte de verre des maquettes : fond encre 7 %, bord encre 12 %.
class IntroGlassCard extends StatelessWidget {
  const IntroGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    this.radius = 16,
    this.width,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final c = TaraColors.of(context);
    return Container(
      width: width,
      padding: padding,
      decoration: BoxDecoration(
        color: c.textPrimary.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: c.textPrimary.withValues(alpha: .12)),
      ),
      child: child,
    );
  }
}

// ── Sol en perspective (Envoyer) ──────────────────────────────────────────────────────

/// Sol quadrillé orange qui défile vers l'avant (maquette : plan de 630 × 700 incliné
/// `rotateX(70deg)` sous une perspective de 380, cases de 44, `t3-floor` 1,6 s, fondu
/// en haut jusqu'à 55 %). À poser sur une zone de 630 × 240.
class IntroFloor extends StatelessWidget {
  const IntroFloor({super.key, this.stillPhase = .3});
  final double stillPhase;

  @override
  Widget build(BuildContext context) => MotionBuilder(
    period: const Duration(milliseconds: 1600),
    stillPhase: stillPhase,
    builder: (context, t, _) => CustomPaint(painter: _FloorPainter(t), size: Size.infinite),
  );
}

class _FloorPainter extends CustomPainter {
  _FloorPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    const d = 380.0;
    final ox = size.width / 2;
    // Profondeur du plan visible dans la zone (au-delà, sous l'observateur).
    final visible = size.height / (math.cos(_rad(70)) + size.height * math.sin(_rad(70)) / d) + 4;
    final m = Matrix4.translationValues(ox, 0, 0)
      ..multiply(cssPerspective(d))
      ..rotateX(_rad(70))
      ..translateByDouble(-ox, 0, 0, 1);
    canvas
      ..clipRect(Offset.zero & size)
      ..saveLayer(Offset.zero & size, Paint());
    canvas
      ..save()
      ..transform(m.storage);
    final h = Paint()
      ..color = const Color.fromRGBO(255, 106, 0, .26)
      ..strokeWidth = 1;
    final v = Paint()
      ..color = const Color.fromRGBO(255, 106, 0, .18)
      ..strokeWidth = 1;
    for (var y = 44 * t; y < visible; y += 44) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), h);
    }
    for (var x = 0.0; x <= size.width; x += 44) {
      canvas.drawLine(Offset(x, 0), Offset(x, visible), v);
    }
    canvas.restore();
    // Masque : invisible en haut, plein à 55 %.
    canvas
      ..drawRect(
        Offset.zero & size,
        Paint()
          ..blendMode = BlendMode.dstIn
          ..shader = ui.Gradient.linear(
            Offset.zero,
            Offset(0, size.height),
            const [Color(0x00000000), Color(0xFF000000)],
            const [0, .55],
          ),
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_FloorPainter old) => old.t != t;
}

// ── Trajet qui se dessine ─────────────────────────────────────────────────────────────

/// Trajet d'une maquette (attribut `d`) : pointillés gris dessous, trait en dégradé ambre,
/// orange, rouge qui se dessine en 55 % du cycle puis reste plein (`tara-draw`).
class IntroDrawnRoute extends StatelessWidget {
  const IntroDrawnRoute({
    super.key,
    required this.path,
    required this.from,
    required this.to,
    this.period = const Duration(milliseconds: 3600),
    this.dashLength = 520,
    this.stillPhase = .8,
  });

  final String path;

  /// Extrémités du dégradé (`linearGradient` en unités de l'écran).
  final Offset from;
  final Offset to;
  final Duration period;

  /// `stroke-dasharray` du trait animé.
  final double dashLength;
  final double stillPhase;

  @override
  Widget build(BuildContext context) {
    final ink = TaraColors.of(context).textPrimary;
    return MotionBuilder(
      period: period,
      stillPhase: stillPhase,
      builder: (context, t, _) => CustomPaint(
        painter: _DrawnRoutePainter(
          introPath(path),
          from,
          to,
          Curves.easeInOut.transform(math.min(1, t / .55)),
          dashLength,
          ink,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _DrawnRoutePainter extends CustomPainter {
  _DrawnRoutePainter(this.path, this.from, this.to, this.progress, this.dash, this.ink);
  final Path path;
  final Offset from;
  final Offset to;
  final double progress;
  final double dash;
  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    final metric = path.computeMetrics().first;
    final dots = Paint()
      ..color = ink.withValues(alpha: .22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    for (var at = 0.0; at < metric.length; at += 11) {
      canvas.drawPath(metric.extractPath(at, math.min(metric.length, at + 2)), dots);
    }
    final shown = math.min(metric.length, dash * progress);
    if (shown <= 0) return;
    canvas.drawPath(
      metric.extractPath(0, shown),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..shader = ui.Gradient.linear(
          from,
          to,
          const [TaraBrand.amber, TaraBrand.orange, TaraBrand.red],
          const [0, .55, 1],
        ),
    );
  }

  @override
  bool shouldRepaint(_DrawnRoutePainter old) => old.progress != progress || old.ink != ink;
}

/// Élément qui suit un chemin (CSS `offset-path`, `offset-rotate: auto`) : il tourne avec
/// le trajet, apparaît sur les premiers 8 % et s'efface sur les derniers 12 %.
class IntroTraveler extends StatelessWidget {
  const IntroTraveler({
    super.key,
    required this.path,
    required this.size,
    required this.child,
    this.period = const Duration(milliseconds: 3600),
    this.stillPhase = .62,
  });

  final String path;

  /// Taille de l'élément, centré sur le chemin.
  final Size size;
  final Widget child;
  final Duration period;
  final double stillPhase;

  @override
  Widget build(BuildContext context) {
    final metric = introPath(path).computeMetrics().first;
    return MotionBuilder(
      period: period,
      stillPhase: stillPhase,
      child: SizedBox.fromSize(size: size, child: child),
      builder: (context, t, child) {
        final tangent = metric.getTangentForOffset(metric.length * Curves.easeInOut.transform(t))!;
        final opacity = t < .08 ? t / .08 : (t > .88 ? (1 - t) / .12 : 1.0);
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: tangent.position.dx - size.width / 2,
              top: tangent.position.dy - size.height / 2,
              child: Opacity(
                opacity: opacity.clamp(0, 1),
                child: Transform.rotate(angle: -tangent.angle, child: child),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Traits de vitesse derrière le colis (`tara-speed` 0,6 s).
class IntroSpeedLines extends StatelessWidget {
  const IntroSpeedLines({super.key});

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      for (final (width, color, delay) in const [
        (18.0, TaraBrand.amber, Duration.zero),
        (11.0, Color(0xFFFF8A3D), Duration(milliseconds: -150)),
      ]) ...[
        if (width != 18) const SizedBox(height: 4),
        MotionBuilder(
          period: const Duration(milliseconds: 600),
          delay: delay,
          builder: (context, t, child) {
            final p = introPingPong(t);
            return Transform.translate(
              offset: Offset(-5 * p, 0),
              child: Opacity(opacity: .95 - .4 * p, child: child),
            );
          },
          child: Container(
            width: width,
            height: 4,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
          ),
        ),
      ],
    ],
  );
}

// ── Colis en 3D ───────────────────────────────────────────────────────────────────────

/// Colis carton de 30 qui tourne sur lui-même (`t3-spin` 2,4 s : `rotateX(-22deg)` puis
/// `rotateY` de 0 à 360°, perspective 260), ruban orange, halo derrière. Zone de 44 × 44.
class IntroCube extends StatelessWidget {
  const IntroCube({super.key, this.stillPhase = .92});
  final double stillPhase;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 44,
    height: 44,
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        const Positioned(
          left: -6,
          top: -6,
          width: 56,
          height: 56,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [Color.fromRGBO(255, 106, 0, .5), Color.fromRGBO(255, 106, 0, 0)],
                stops: [0, .7],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: MotionBuilder(
            period: const Duration(milliseconds: 2400),
            stillPhase: stillPhase,
            builder: (context, t, _) => CustomPaint(painter: _CubePainter(360 * t)),
          ),
        ),
      ],
    ),
  );
}

class _CubePainter extends CustomPainter {
  _CubePainter(this.spin);
  final double spin;

  // Faces : couleur, ruban, transformation depuis le centre du colis.
  static final _faces = <(Color, Color?, Matrix4)>[
    (const Color(0xFFD9A066), TaraBrand.orange, Matrix4.translationValues(0, 0, 15)),
    (const Color(0xFFC98F55), const Color(0xFFE85F00), Matrix4.rotationY(math.pi)..translateByDouble(0, 0, 15, 1)),
    (const Color(0xFFCF9458), null, Matrix4.rotationY(math.pi / 2)..translateByDouble(0, 0, 15, 1)),
    (const Color(0xFFC68A4F), null, Matrix4.rotationY(-math.pi / 2)..translateByDouble(0, 0, 15, 1)),
    (const Color(0xFFE6B276), TaraBrand.orange, Matrix4.rotationX(math.pi / 2)..translateByDouble(0, 0, 15, 1)),
    (const Color(0xFF8A5A2E), null, Matrix4.rotationX(-math.pi / 2)..translateByDouble(0, 0, 15, 1)),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final view = Matrix4.translationValues(center.dx, center.dy, 0)
      ..multiply(cssPerspective(260))
      ..rotateX(_rad(-22))
      ..rotateY(_rad(spin));
    final model = Matrix4.rotationX(_rad(-22))..rotateY(_rad(spin));
    final faces = [
      for (final (color, tape, face) in _faces)
        (color, tape, view.clone()..multiply(face), _apply(model.clone()..multiply(face), 0, 0, 0).$3),
    ]..sort((a, b) => a.$4.compareTo(b.$4));
    for (final (color, tape, m, _) in faces) {
      canvas
        ..save()
        ..transform(m.storage)
        ..drawRect(const Rect.fromLTWH(-15, -15, 30, 30), Paint()..color = color);
      if (tape != null) canvas.drawRect(const Rect.fromLTWH(-2.1, -15, 4.2, 30), Paint()..color = tape);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_CubePainter old) => old.spin != spin;
}

/// Point d'arrivée qui pulse : rond orange cerclé de blanc et onde (`tara-pulse` 1,8 s).
class IntroPulseDot extends StatelessWidget {
  const IntroPulseDot({super.key, this.stillPhase = .35});
  final double stillPhase;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 24,
    height: 24,
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: MotionBuilder(
            period: const Duration(milliseconds: 1800),
            stillPhase: stillPhase,
            builder: (context, t, child) {
              final p = Curves.easeOut.transform(t);
              return Opacity(
                opacity: .9 * (1 - p),
                child: Transform.scale(scale: .6 + 1.6 * p, child: child),
              );
            },
            child: const DecoratedBox(
              decoration: BoxDecoration(shape: BoxShape.circle, color: Color.fromRGBO(255, 106, 0, .5)),
            ),
          ),
        ),
        Positioned(
          left: 4,
          top: 4,
          width: 16,
          height: 16,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: TaraBrand.orange,
              border: Border.all(color: const Color(0xFFFFFFFF), width: 3),
            ),
          ),
        ),
      ],
    ),
  );
}

// ── Quartier en relief (Suivre) ───────────────────────────────────────────────────────

/// Couleurs du plan en relief, par thème (variables `--map-*`, `--road-*`, `--b1…b5`).
class IntroMapPalette {
  const IntroMapPalette({
    required this.background,
    required this.ground,
    required this.road1,
    required this.road2,
    required this.water,
    required this.faces,
    required this.panel,
  });

  static const dark = IntroMapPalette(
    background: Color(0xFF0D0E13),
    ground: Color(0xFF111219),
    road1: Color(0xFF252833),
    road2: Color(0xFF1E2029),
    water: Color(0xFF0F1922),
    faces: [Color(0xFF1B1D25), Color(0xFF15161D), Color(0xFF20222C), Color(0xFF17181F), Color(0xFF272A35)],
    panel: Color(0xFF16161E),
  );

  static const light = IntroMapPalette(
    background: Color(0xFFEFE8DE),
    ground: Color(0xFFE7DED2),
    road1: Color(0xFFFFFFFF),
    road2: Color(0xFFFBF7F1),
    water: Color(0xFFBCD7E4),
    faces: [Color(0xFFE6D9CA), Color(0xFFDCCDBC), Color(0xFFEFE4D7), Color(0xFFD6C6B4), Color(0xFFFFFFFF)],
    panel: Color(0xFFFFFFFF),
  );

  static IntroMapPalette of(BuildContext context) => TaraColors.of(context).isDark ? dark : light;

  final Color background;
  final Color ground;
  final Color road1;
  final Color road2;
  final Color water;

  /// Façade avant, arrière, droite, gauche, toit.
  final List<Color> faces;
  final Color panel;
}

/// Immeuble du plan : emprise (x, y, largeur, profondeur), hauteur, fenêtres.
typedef IntroBuilding = ({double x, double y, double w, double d, double h, bool windows});

/// Quartier de la maquette « Suivre » (plan de 300 × 300).
const introDoualaBlock = <IntroBuilding>[
  (x: 10, y: 12, w: 40, d: 34, h: 40, windows: true),
  (x: 58, y: 10, w: 42, d: 56, h: 70, windows: false),
  (x: 12, y: 56, w: 36, d: 34, h: 26, windows: true),
  (x: 136, y: 14, w: 84, d: 30, h: 30, windows: true),
  (x: 140, y: 54, w: 36, d: 38, h: 56, windows: false),
  (x: 184, y: 52, w: 38, d: 40, h: 38, windows: true),
  (x: 252, y: 44, w: 40, d: 44, h: 46, windows: true),
  (x: 12, y: 128, w: 44, d: 40, h: 34, windows: false),
  (x: 64, y: 126, w: 36, d: 80, h: 62, windows: true),
  (x: 12, y: 176, w: 40, d: 34, h: 22, windows: true),
  (x: 138, y: 130, w: 80, d: 34, h: 44, windows: false),
  (x: 140, y: 176, w: 34, d: 34, h: 28, windows: true),
  (x: 184, y: 174, w: 36, d: 36, h: 52, windows: true),
  (x: 252, y: 126, w: 40, d: 40, h: 66, windows: false),
  (x: 254, y: 178, w: 38, d: 34, h: 30, windows: true),
  (x: 12, y: 240, w: 60, d: 22, h: 14, windows: true),
  (x: 136, y: 240, w: 84, d: 22, h: 18, windows: false),
  (x: 252, y: 240, w: 40, d: 22, h: 20, windows: true),
];

/// Plan en relief de la maquette « Suivre » : sol de 300 × 300 posé à (25, 8) dans une
/// carte de 350 × 410, `rotateX(55deg) rotateZ(-35…-27deg)` (`t3-orbit` 24 s), perspective
/// 760 vue depuis 50 % 15 %. Rues, eau, immeubles à fenêtres, trajet orange, maison au
/// départ, épingle qui pulse à l'arrivée, livreur qui roule (`t3-ride` 7 s).
class IntroCity extends StatelessWidget {
  const IntroCity({
    super.key,
    this.buildings = introDoualaBlock,
    this.route = const [Offset(20, 226), Offset(118, 226), Offset(118, 108), Offset(236, 108), Offset(236, 24)],
    this.rider = TaraIcons.navigation,
    this.stillRide = .52,
  });

  final List<IntroBuilding> buildings;

  /// Trajet sur le plan (coordonnées 0 à 300).
  final List<Offset> route;
  final TaraIconData rider;
  final double stillRide;

  @override
  Widget build(BuildContext context) {
    final palette = IntroMapPalette.of(context);
    final c = TaraColors.of(context);
    return MotionBuilder(
      period: const Duration(seconds: 24),
      builder: (context, orbit, _) => MotionBuilder(
        period: const Duration(seconds: 7),
        stillPhase: stillRide,
        builder: (context, ride, _) => MotionBuilder(
          period: const Duration(milliseconds: 2200),
          stillPhase: .3,
          builder: (context, ping, _) => CustomPaint(
            size: Size.infinite,
            painter: _CityPainter(
              palette: palette,
              bg: c.bg,
              ink: c.textPrimary,
              buildings: buildings,
              route: route,
              rider: rider,
              rotation: -35 + 8 * introPingPong(orbit),
              ride: ride,
              ping: ping,
            ),
          ),
        ),
      ),
    );
  }
}

class _CityPainter extends CustomPainter {
  _CityPainter({
    required this.palette,
    required this.bg,
    required this.ink,
    required this.buildings,
    required this.route,
    required this.rider,
    required this.rotation,
    required this.ride,
    required this.ping,
  });

  final IntroMapPalette palette;
  final Color bg;
  final Color ink;
  final List<IntroBuilding> buildings;
  final List<Offset> route;
  final TaraIconData rider;
  final double rotation;
  final double ride;
  final double ping;

  Offset _along(double f) {
    var total = 0.0;
    for (var i = 1; i < route.length; i++) {
      total += (route[i] - route[i - 1]).distance;
    }
    var left = total * f;
    for (var i = 1; i < route.length; i++) {
      final segment = (route[i] - route[i - 1]).distance;
      if (left <= segment) return Offset.lerp(route[i - 1], route[i], left / segment)!;
      left -= segment;
    }
    return route.last;
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Le sol, puis la perspective de la carte (origine 50 % 15 %).
    final model = Matrix4.translationValues(25 + 150, 8 + 150, 0)
      ..rotateX(_rad(55))
      ..rotateZ(_rad(rotation))
      ..translateByDouble(-150, -150, 0, 1);
    final origin = Offset(size.width / 2, size.height * .15);
    final view = Matrix4.translationValues(origin.dx, origin.dy, 0)
      ..multiply(cssPerspective(760))
      ..translateByDouble(-origin.dx, -origin.dy, 0, 1)
      ..multiply(model);

    canvas
      ..save()
      ..clipRect(Offset.zero & size)
      ..drawRect(Offset.zero & size, Paint()..color = palette.background)
      ..save()
      ..transform(view.storage)
      ..drawRect(const Rect.fromLTWH(0, 0, 300, 300), Paint()..color = palette.ground)
      ..drawRect(const Rect.fromLTWH(0, 100, 300, 16), Paint()..color = palette.road1)
      ..drawRect(const Rect.fromLTWH(0, 220, 300, 12), Paint()..color = palette.road2)
      ..drawRect(const Rect.fromLTWH(110, 0, 16, 300), Paint()..color = palette.road1)
      ..drawRect(const Rect.fromLTWH(230, 0, 12, 300), Paint()..color = palette.road2)
      ..drawRect(const Rect.fromLTWH(0, 268, 300, 32), Paint()..color = palette.water);
    final line = Path()..addPolygon(route, false);
    Paint stroke(Color color, double width) => Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas
      ..drawPath(line, stroke(const Color.fromRGBO(255, 106, 0, .28), 10))
      ..drawPath(line, stroke(TaraBrand.orange, 4));
    // Onde de l'arrivée (`t3-ping` 2,2 s) et halo du livreur, posés sur le sol.
    final wave = Curves.easeOut.transform(ping);
    canvas.drawCircle(
      route.last,
      12 * (.5 + 1.9 * wave),
      Paint()..color = Color.fromRGBO(255, 61, 0, .5 * .8 * (1 - wave)),
    );
    final at = _along(ride);
    canvas
      ..drawCircle(
        at,
        16,
        Paint()
          ..shader = ui.Gradient.radial(
            at,
            16,
            const [Color.fromRGBO(255, 106, 0, .6), Color.fromRGBO(255, 106, 0, 0)],
            const [0, .7],
          ),
      )
      ..restore();

    // Façades et repères, du plus loin au plus proche.
    final items = <(double, void Function())>[];
    for (final b in buildings) {
      final faces = <(Matrix4, Size, Color, int)>[
        // (position sur le sol, taille, couleur, fenêtres : 0 aucune, 1 lignes, 2 colonnes)
        (
          Matrix4.translationValues(b.x, b.y + b.d, 0)..rotateX(math.pi / 2),
          Size(b.w, b.h),
          palette.faces[0],
          b.windows ? 1 : 0,
        ),
        (Matrix4.translationValues(b.x, b.y, 0)..rotateX(math.pi / 2), Size(b.w, b.h), palette.faces[1], 0),
        (
          Matrix4.translationValues(b.x + b.w, b.y, 0)..rotateY(-math.pi / 2),
          Size(b.h, b.d),
          palette.faces[2],
          b.windows ? 2 : 0,
        ),
        (Matrix4.translationValues(b.x, b.y, 0)..rotateY(-math.pi / 2), Size(b.h, b.d), palette.faces[3], 0),
        (Matrix4.translationValues(b.x, b.y, b.h), Size(b.w, b.d), palette.faces[4], 3),
      ];
      for (final (local, face, color, kind) in faces) {
        final depth = _apply(model.clone()..multiply(local), face.width / 2, face.height / 2, 0).$3;
        items.add((
          depth,
          () {
            canvas
              ..save()
              ..transform((view.clone()..multiply(local)).storage)
              ..drawRect(Offset.zero & face, Paint()..color = color);
            final windows = Paint()..color = const Color.fromRGBO(255, 177, 92, .16);
            if (kind == 1 || kind == 2) {
              for (var v = face.height - 9; v > -2; v -= 9) {
                canvas.drawRect(Rect.fromLTWH(0, math.max(0, v), face.width, math.min(2, v + 2)), windows);
              }
            } else if (kind == 3) {
              canvas.drawRect(
                (Offset.zero & face).deflate(.5),
                Paint()
                  ..style = PaintingStyle.stroke
                  ..color = ink.withValues(alpha: .05),
              );
            }
            canvas.restore();
          },
        ));
      }
    }

    Offset project(Offset ground) {
      final (x, y, _, w) = _apply(view, ground.dx, ground.dy, 0);
      return Offset(x / w, y / w);
    }

    double depthOf(Offset ground) => _apply(model, ground.dx, ground.dy, 0).$3 + 1;

    void icon(TaraIconData data, Offset center, double size, Paint paint) {
      canvas
        ..save()
        ..translate(center.dx - size / 2, center.dy - size / 2)
        ..scale(size / 24)
        ..drawPath(data.path, paint)
        ..restore();
    }

    // Maison au départ : carré blanc, tige.
    items.add((
      depthOf(route.first),
      () {
        final p = project(route.first);
        canvas
          ..drawRect(Rect.fromLTWH(p.dx - 1, p.dy - 12, 2, 12), Paint()..color = ink.withValues(alpha: .7))
          ..drawRRect(
            RRect.fromRectAndRadius(Rect.fromLTWH(p.dx - 12, p.dy - 36, 24, 24), const Radius.circular(8)),
            Paint()..color = const Color(0xFFFFFFFF),
          );
        icon(
          TaraIcons.homeFlat,
          Offset(p.dx, p.dy - 24),
          13,
          Paint()
            ..color = const Color(0xFF16120E)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.4 * 24 / 13
            ..strokeJoin = StrokeJoin.round
            ..strokeCap = StrokeCap.round,
        );
      },
    ));
    // Épingle d'arrivée en dégradé.
    items.add((
      depthOf(route.last),
      () {
        final p = project(route.last);
        canvas.drawRect(
          Rect.fromLTWH(p.dx - 1, p.dy - 12, 2, 12),
          Paint()..color = const Color.fromRGBO(255, 177, 92, .8),
        );
        final pin = Path()
          ..addRRect(
            RRect.fromRectAndCorners(
              const Rect.fromLTWH(-11, -11, 22, 22),
              topLeft: const Radius.circular(11),
              topRight: const Radius.circular(11),
              bottomRight: const Radius.circular(11),
              bottomLeft: const Radius.circular(3),
            ),
          );
        canvas
          ..save()
          ..translate(p.dx, p.dy - 12 - 11 - 4)
          ..rotate(-math.pi / 4)
          ..drawPath(
            pin,
            Paint()
              ..color = const Color.fromRGBO(255, 106, 0, .55)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
          )
          ..drawPath(
            pin,
            Paint()
              ..shader = ui.Gradient.linear(
                const Offset(-11, 0),
                const Offset(11, 0),
                const [TaraBrand.amber, TaraBrand.orange, TaraBrand.red],
                const [0, .55, 1],
              ),
          )
          ..restore();
      },
    ));
    // Livreur : rond en dégradé cerclé du fond, flèche pleine, tige.
    final riderAt = _along(ride);
    items.add((
      depthOf(riderAt) + .5,
      () {
        final p = project(riderAt);
        final center = Offset(p.dx, p.dy - 14 - 15);
        canvas
          ..drawRect(Rect.fromLTWH(p.dx - 1, p.dy - 14, 2, 14), Paint()..color = const Color.fromRGBO(255, 177, 92, .8))
          ..drawCircle(
            center,
            15,
            Paint()
              ..color = const Color.fromRGBO(255, 106, 0, .7)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
          )
          ..drawCircle(center, 15, Paint()..color = bg)
          ..drawCircle(
            center,
            12,
            Paint()
              ..shader = ui.Gradient.linear(
                center - const Offset(12, 0),
                center + const Offset(12, 0),
                const [TaraBrand.amber, TaraBrand.orange, TaraBrand.red],
                const [0, .55, 1],
              ),
          );
        icon(rider, center, 14, Paint()..color = TaraBrand.onBrand);
      },
    ));

    items.sort((a, b) => a.$1.compareTo(b.$1));
    for (final (_, draw) in items) {
      draw();
    }

    // Vignette : le bord de la carte se fond dans la couleur du plan.
    final center = Offset(size.width / 2, size.height * .4);
    final rx = math.max(center.dx, size.width - center.dx) * math.sqrt2;
    final ry = math.max(center.dy, size.height - center.dy) * math.sqrt2;
    canvas
      ..save()
      ..translate(center.dx, center.dy)
      ..scale(1, ry / rx)
      ..drawRect(
        Rect.fromCenter(center: Offset.zero, width: rx * 2, height: rx * 2),
        Paint()
          ..shader = ui.Gradient.radial(
            Offset.zero,
            rx,
            [palette.background.withValues(alpha: 0), palette.background.withValues(alpha: .9)],
            const [.55, 1],
          ),
      )
      ..restore()
      ..restore();
  }

  @override
  bool shouldRepaint(_CityPainter old) =>
      old.rotation != rotation || old.ride != ride || old.ping != ping || old.palette != palette || old.bg != bg;
}

// ── Argent ────────────────────────────────────────────────────────────────────────────

/// Reflet qui traverse une carte (`t3-sheen` 5 s : bande blanche à 20 % qui passe entre
/// 30 % et 70 % du cycle).
class IntroSheen extends StatelessWidget {
  const IntroSheen({super.key});

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: MotionBuilder(
      period: const Duration(seconds: 5),
      builder: (context, t, _) => CustomPaint(painter: _SheenPainter(t), size: Size.infinite),
    ),
  );
}

class _SheenPainter extends CustomPainter {
  _SheenPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final p = t <= .3 ? 0.0 : (t >= .7 ? 1.0 : Curves.easeInOut.transform((t - .3) / .4));
    final position = 1.2 - 2.4 * p;
    final width = size.width * 2.6;
    final left = (size.width - width) * position;
    final rect = Rect.fromLTWH(left, 0, width, size.height);
    final a = _rad(115);
    final dx = math.sin(a);
    final dy = -math.cos(a);
    final half = ((width * dx).abs() + (size.height * dy).abs()) / 2;
    final c = rect.center;
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.linear(
          c - Offset(dx, dy) * half,
          c + Offset(dx, dy) * half,
          const [Color(0x00FFFFFF), Color(0x33FFFFFF), Color(0x00FFFFFF)],
          const [.35, .48, .6],
        ),
    );
  }

  @override
  bool shouldRepaint(_SheenPainter old) => old.t != t;
}

/// Barres orange en bas à droite des cartes d'argent.
class IntroBars extends StatelessWidget {
  const IntroBars({super.key, this.widths = const [54, 36, 20], this.height = 6, this.gap = 6});
  final List<double> widths;
  final double height;
  final double gap;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      for (final (i, (width, color)) in [
        for (final (j, w) in widths.indexed) (w, const [TaraBrand.orange, Color(0xFFFF8A3D), TaraBrand.amber][j]),
      ].indexed) ...[
        if (i > 0) SizedBox(height: gap),
        Container(
          width: width,
          height: height,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(height / 2 + .5)),
        ),
      ],
    ],
  );
}

/// Montant dont les chiffres défilent de 0 jusqu'au leur (`tara-roll` 2,8 s, chiffres
/// décalés de 0,1 s). [digits] : chiffres qui défilent, [fixed] : la fin, immobile.
class IntroRollingAmount extends StatelessWidget {
  const IntroRollingAmount({
    super.key,
    required this.digits,
    required this.fixed,
    required this.style,
    this.groupAfter = 2,
    this.stillPhase = .7,
  });

  final List<int> digits;
  final String fixed;
  final TextStyle style;

  /// Espace des milliers après ce nombre de chiffres.
  final int groupAfter;
  final double stillPhase;

  @override
  Widget build(BuildContext context) {
    final size = style.fontSize!;
    final line = size * 1.1;
    final digitStyle = style.copyWith(height: 1.1, fontFeatures: TaraText.tabular);
    final painter = TextPainter(
      text: TextSpan(text: '0', style: digitStyle),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    final width = painter.width;
    painter.dispose();
    Widget roll(int digit, int index) => SizedBox(
      width: width,
      height: line,
      child: ClipRect(
        child: MotionBuilder(
          period: const Duration(milliseconds: 2800),
          delay: Duration(milliseconds: -200 - 100 * index),
          stillPhase: stillPhase,
          builder: (context, t, child) {
            final p = const Cubic(.2, .8, .2, 1).transform(math.min(1, t / .4));
            return Transform.translate(offset: Offset(0, -digit * line * p), child: child);
          },
          child: OverflowBox(
            alignment: Alignment.topCenter,
            maxHeight: line * 10,
            maxWidth: width,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [for (var n = 0; n < 10; n++) Text('$n', style: digitStyle)],
            ),
          ),
        ),
      ),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (i, d) in digits.indexed) ...[if (i == groupAfter) SizedBox(width: size * .28), roll(d, i)],
        Text(fixed, style: digitStyle),
      ],
    );
  }
}

/// Pièce « F » qui suit un chemin (`tara-coin` 2,8 s : apparaît en grandissant, puis
/// rétrécit et s'efface à l'arrivée).
class IntroCoin extends StatelessWidget {
  const IntroCoin({
    super.key,
    required this.path,
    required this.size,
    this.delay = Duration.zero,
    this.stillPhase = .45,
  });

  final String path;
  final double size;
  final Duration delay;
  final double stillPhase;

  @override
  Widget build(BuildContext context) {
    final metric = introPath(path).computeMetrics().first;
    final ink = TaraColors.of(context).textPrimary;
    return MotionBuilder(
      period: const Duration(milliseconds: 2800),
      delay: -delay,
      stillPhase: stillPhase,
      builder: (context, t, child) {
        final at = metric.getTangentForOffset(metric.length * Curves.easeIn.transform(t))!.position;
        final double opacity;
        final double scale;
        if (t < .15) {
          opacity = t / .15;
          scale = .7 + .3 * t / .15;
        } else if (t < .8) {
          opacity = 1;
          scale = 1;
        } else {
          opacity = 1 - (t - .8) / .2;
          scale = 1 - .4 * (t - .8) / .2;
        }
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: at.dx - size / 2,
              top: at.dy - size / 2,
              child: Opacity(
                opacity: opacity.clamp(0, 1),
                child: Transform.scale(scale: scale, child: child),
              ),
            ),
          ],
        );
      },
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: cssGradient(
            135,
            Size.square(size),
            const [Color(0xFFFFD36B), TaraBrand.amber, TaraBrand.orange],
            const [0, .45, 1],
          ),
          border: Border.all(color: ink.withValues(alpha: .6), width: 2),
        ),
        alignment: Alignment.center,
        child: Text(
          'F',
          style: TextStyle(
            fontFamily: TaraText.sora,
            fontSize: size * .43,
            fontWeight: FontWeight.w800,
            height: 1,
            color: TaraBrand.onBrand,
          ),
        ),
      ),
    );
  }
}
