import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../motion/motion_clock.dart';
import '../tara_colors.dart';
import '../tara_effects.dart';
import '../tara_typography.dart';

// Éléments en relief de la refonte : le colis Tara qui tourne, les colonnes des tableaux
// de bord et la carte qui s'incline. Dessinés sans moteur 3D : chaque face est projetée à
// la main, les faces cachées ne sont pas peintes, les autres sont peintes du fond vers
// l'avant. Repères comme en CSS : x vers la droite, y vers le bas, z vers l'œil.

@immutable
class _V3 {
  const _V3(this.x, this.y, this.z);
  final double x, y, z;

  _V3 operator +(_V3 o) => _V3(x + o.x, y + o.y, z + o.z);
  _V3 operator -(_V3 o) => _V3(x - o.x, y - o.y, z - o.z);
  _V3 operator *(double k) => _V3(x * k, y * k, z * k);
  _V3 cross(_V3 o) => _V3(y * o.z - z * o.y, z * o.x - x * o.z, x * o.y - y * o.x);

  /// Rotation autour de y (CSS `rotateY`), puis autour de x (CSS `rotateX`).
  _V3 rotate(double yaw, double pitch) {
    final cy = math.cos(yaw), sy = math.sin(yaw);
    final x1 = x * cy + z * sy, z1 = -x * sy + z * cy;
    final cx = math.cos(pitch), sx = math.sin(pitch);
    return _V3(x1, y * cx - z1 * sx, y * sx + z1 * cx);
  }
}

/// Face carrée du colis : coin haut gauche, axes horizontal et vertical (longueur 1).
@immutable
class _Face {
  const _Face(this.origin, this.u, this.v, this.color, {this.ribbon, this.front = false, this.top = false});
  final _V3 origin, u, v;
  final Color color;
  final Color? ribbon;
  final bool front, top;
}

/// Colis Tara en 3D (carton, ruban orange, numéro devant, étiquette dessus), qui tourne
/// lentement sur lui-même et flotte au-dessus de son ombre. Sans animations (réglage du
/// téléphone, effets réduits), il reste immobile, de trois quarts.
class Parcel3D extends StatelessWidget {
  const Parcel3D({
    super.key,
    this.size = 96,
    this.label,
    this.spin = true,
    this.floating = true,
    this.period = const Duration(seconds: 10),
    this.semanticLabel,
  });

  /// Arête du carton.
  final double size;

  /// Numéro écrit sur la face avant (« n° 4 »).
  final String? label;
  final bool spin;
  final bool floating;
  final Duration period;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final box = size * 1.9;
    Widget body = MotionBuilder(
      period: period,
      stillPhase: 0,
      builder: (context, t, _) => CustomPaint(
        size: Size.square(box),
        painter: _ParcelPainter(edge: size, yaw: (spin ? t * 2 * math.pi : 0) - math.pi / 6, label: label),
      ),
    );
    if (floating) {
      body = MotionBuilder(
        period: const Duration(seconds: 4),
        stillPhase: .25,
        builder: (context, t, child) {
          final lift = (1 - math.cos(t * 2 * math.pi)) / 2; // 0 en bas, 1 en haut
          return SizedBox(
            width: box,
            height: box + size * .25,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: size * .3,
                  child: CustomPaint(painter: _ShadowPainter(width: size * (1.05 - .18 * lift), opacity: .4 - .18 * lift)),
                ),
                Transform.translate(offset: Offset(0, -8 * lift), child: child),
              ],
            ),
          );
        },
        child: body,
      );
    }
    return Semantics(
      image: semanticLabel != null,
      label: semanticLabel,
      excludeSemantics: true,
      child: RepaintBoundary(child: body),
    );
  }
}

/// Ombre floue du colis sur le sol : ovale plus petit et plus pâle quand il monte.
class _ShadowPainter extends CustomPainter {
  _ShadowPainter({required this.width, required this.opacity});

  final double width;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCenter(center: size.center(Offset.zero), width: width, height: size.height * .5);
    canvas.drawOval(
      rect,
      Paint()
        ..color = Color.fromRGBO(0, 0, 0, opacity.clamp(0, 1))
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, size.height * .18),
    );
  }

  @override
  bool shouldRepaint(_ShadowPainter old) => old.width != width || old.opacity != opacity;
}

class _ParcelPainter extends CustomPainter {
  _ParcelPainter({required this.edge, required this.yaw, required this.label});

  final double edge;
  final double yaw;
  final String? label;

  static const _pitch = -22 * math.pi / 180;
  static const _carton = Color(0xFF16120E);

  @override
  void paint(Canvas canvas, Size size) {
    final h = edge / 2;
    final faces = [
      _Face(_V3(-h, -h, h), const _V3(1, 0, 0), const _V3(0, 1, 0), const Color(0xFFD9A066),
          ribbon: TaraBrand.orange, front: true),
      _Face(_V3(h, -h, -h), const _V3(-1, 0, 0), const _V3(0, 1, 0), const Color(0xFFC98F55),
          ribbon: const Color(0xFFE85F00)),
      _Face(_V3(h, -h, h), const _V3(0, 0, -1), const _V3(0, 1, 0), const Color(0xFFCF9458)),
      _Face(_V3(-h, -h, -h), const _V3(0, 0, 1), const _V3(0, 1, 0), const Color(0xFFC68A4F)),
      _Face(_V3(-h, -h, -h), const _V3(1, 0, 0), const _V3(0, 0, 1), const Color(0xFFE6B276),
          ribbon: TaraBrand.orange, top: true),
      _Face(_V3(-h, h, h), const _V3(1, 0, 0), const _V3(0, 0, -1), const Color(0xFF8A5A2E)),
    ];
    final center = size.center(Offset.zero);
    final distance = edge * 6; // perspective douce
    Offset project(_V3 p) {
      final r = p.rotate(yaw, _pitch);
      final k = distance / (distance - r.z);
      return center + Offset(r.x * k, r.y * k);
    }

    final visible = <(_Face, double)>[];
    for (final face in faces) {
      final normal = face.u.cross(face.v).rotate(yaw, _pitch);
      if (normal.z <= 0.001) continue;
      final mid = (face.origin + face.u * h + face.v * h).rotate(yaw, _pitch);
      visible.add((face, mid.z));
    }
    visible.sort((a, b) => a.$2.compareTo(b.$2));

    for (final (face, _) in visible) {
      _V3 at(double a, double b) => face.origin + face.u * a + face.v * b;
      Path quad(double a0, double b0, double a1, double b1) => Path()
        ..addPolygon([project(at(a0, b0)), project(at(a1, b0)), project(at(a1, b1)), project(at(a0, b1))], true);
      // Lumière venue d'en haut à gauche : les faces tournées vers elle s'éclaircissent.
      final normal = face.u.cross(face.v).rotate(yaw, _pitch);
      final light = (normal.x * -.35 + normal.y * -.75 + normal.z * .55).clamp(0.0, 1.0);
      final shade = Color.lerp(face.color, Colors.black, .12 * (1 - light))!;
      canvas.drawPath(quad(0, 0, edge, edge), Paint()..color = shade);
      final ribbon = face.ribbon;
      if (ribbon != null) {
        final w = edge * .14;
        canvas.drawPath(quad((edge - w) / 2, 0, (edge + w) / 2, edge), Paint()..color = ribbon);
      }
      // Repères dessinés dans le plan de la face (approximation affine, assez juste ici).
      final o = project(at(0, 0));
      final ax = (project(at(edge, 0)) - o) / edge;
      final ay = (project(at(0, edge)) - o) / edge;
      canvas
        ..save()
        ..transform(Float64List.fromList([ax.dx, ax.dy, 0, 0, ay.dx, ay.dy, 0, 0, 0, 0, 1, 0, o.dx, o.dy, 0, 1]));
      if (face.front) {
        final text = label;
        if (text != null && edge >= 40) {
          final painter = TextPainter(
            text: TextSpan(
              text: text,
              style: TextStyle(
                fontFamily: TaraText.sora,
                fontWeight: FontWeight.w800,
                fontSize: edge * .17,
                color: _carton,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          painter.paint(canvas, Offset(edge * .09, edge * .06));
        }
        final bar = Paint()..color = _carton;
        final t = math.max(2.0, edge * .04);
        canvas
          ..drawRRect(RRect.fromLTRBR(edge * .09, edge * .78, edge * .35, edge * .78 + t, const Radius.circular(2)), bar)
          ..drawRRect(
            RRect.fromLTRBR(edge * .09, edge * .78 + t * 1.8, edge * .26, edge * .78 + t * 2.8, const Radius.circular(2)),
            bar,
          );
      }
      if (face.top && edge >= 44) {
        // Étiquette d'expédition crème, posée en travers du ruban.
        canvas.drawRRect(
          RRect.fromLTRBR(edge * .21, edge * .3, edge * .79, edge * .7, Radius.circular(edge * .08)),
          Paint()..color = const Color(0xFFFFF6EA),
        );
        canvas.drawRRect(
          RRect.fromLTRBR(edge * .3, edge * .42, edge * .7, edge * .5, Radius.circular(edge * .04)),
          Paint()..shader = TaraBrand.gradient.createShader(Rect.fromLTRB(edge * .3, edge * .42, edge * .7, edge * .5)),
        );
        canvas.drawRRect(
          RRect.fromLTRBR(edge * .3, edge * .55, edge * .58, edge * .59, Radius.circular(edge * .02)),
          Paint()..color = const Color(0x5916120E),
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ParcelPainter old) => old.yaw != yaw || old.edge != edge || old.label != label;
}

/// Une colonne du tableau de bord : valeur (hauteur), libellé dessous, détail annoncé.
@immutable
class Column3D {
  const Column3D({required this.label, required this.value, required this.detail});

  /// Libellé court sous la colonne (« Jeu »).
  final String label;
  final double value;

  /// Détail montré au-dessus de la colonne choisie et lu par le lecteur d'écran
  /// (« 7 courses · 4 900 F »).
  final String detail;
}

/// Graphique en colonnes en relief (livraisons, ventes, gains) : chaque colonne a sa face
/// avant, son côté et son dessus. On touche une colonne : elle s'allume en orange et donne
/// le détail du jour. Les colonnes montent à l'affichage.
class Column3DChart extends StatefulWidget {
  const Column3DChart({
    super.key,
    required this.columns,
    this.selected,
    this.onSelected,
    this.height = 150,
  });

  final List<Column3D> columns;

  /// Colonne allumée au départ (le jour en cours).
  final int? selected;
  final ValueChanged<int>? onSelected;

  /// Hauteur de la plus haute colonne.
  final double height;

  @override
  State<Column3DChart> createState() => _Column3DChartState();
}

class _Column3DChartState extends State<Column3DChart> {
  late int? _selected = widget.selected;

  @override
  void didUpdateWidget(Column3DChart old) {
    super.didUpdateWidget(old);
    if (old.selected != widget.selected) _selected = widget.selected;
  }

  void _select(int index) {
    if (index == _selected) return;
    HapticFeedback.selectionClick();
    setState(() => _selected = index);
    widget.onSelected?.call(index);
  }

  @override
  Widget build(BuildContext context) {
    final c = TaraColors.of(context);
    final effects = TaraEffects.of(context);
    final max = widget.columns.fold<double>(0, (m, col) => math.max(m, col.value));
    const bubble = 30.0;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: effects.decorativeMotion ? 0 : 1, end: 1),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutBack,
      builder: (context, grow, _) => Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < widget.columns.length; i++)
            Expanded(
              child: Semantics(
                button: true,
                selected: i == _selected,
                label: '${widget.columns[i].label} : ${widget.columns[i].detail}',
                excludeSemantics: true,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _select(i),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: bubble,
                        child: i == _selected
                            ? FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  widget.columns[i].detail.split(' · ').first,
                                  maxLines: 1,
                                  style: TaraText.small.copyWith(
                                    color: c.accentText,
                                    fontWeight: FontWeight.w800,
                                    fontFeatures: TaraText.tabular,
                                  ),
                                ),
                              )
                            : null,
                      ),
                      SizedBox(
                        height: widget.height + 10,
                        child: CustomPaint(
                          size: Size.infinite,
                          painter: _ColumnPainter(
                            ratio: max <= 0 ? 0 : (widget.columns[i].value / max) * grow,
                            selected: i == _selected,
                            dark: c.isDark,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.columns[i].label,
                        maxLines: 1,
                        style: TaraText.small.copyWith(
                          color: i == _selected ? c.accentText : c.textTertiary,
                          fontWeight: i == _selected ? FontWeight.w800 : FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ColumnPainter extends CustomPainter {
  _ColumnPainter({required this.ratio, required this.selected, required this.dark});

  final double ratio;
  final bool selected;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    // Profondeur oblique : le côté et le dessus fuient vers la droite et vers le haut.
    final depth = math.min(10.0, size.width * .22);
    final rise = depth * .7;
    final width = math.min(26.0, size.width - depth - 6);
    final left = (size.width - width - depth) / 2;
    final bottom = size.height;
    final columnHeight = math.max(4.0, (size.height - rise) * ratio.clamp(0.0, 1.06));
    final top = bottom - columnHeight;
    final front = Rect.fromLTRB(left, top, left + width, bottom);

    final (Paint frontPaint, Color side, Color cap) = selected
        ? (
            Paint()..shader = TaraBrand.verticalGradient.createShader(front),
            const Color(0xFFC2410C),
            const Color(0xFFFFC56B),
          )
        : dark
        ? (
            Paint()..color = const Color.fromRGBO(255, 255, 255, .16),
            const Color.fromRGBO(255, 255, 255, .08),
            const Color.fromRGBO(255, 255, 255, .26),
          )
        : (
            Paint()..color = const Color(0xFFE4D6C6),
            const Color(0xFFCDBBA6),
            const Color(0xFFF3EADF),
          );

    // Côté, dessus, puis face avant : la face avant est toujours pleine.
    canvas.drawPath(
      Path()..addPolygon([
        Offset(front.right, top),
        Offset(front.right + depth, top - rise),
        Offset(front.right + depth, bottom - rise),
        Offset(front.right, bottom),
      ], true),
      Paint()..color = side,
    );
    canvas.drawPath(
      Path()..addPolygon([
        Offset(front.left, top),
        Offset(front.left + depth, top - rise),
        Offset(front.right + depth, top - rise),
        Offset(front.right, top),
      ], true),
      Paint()..color = cap,
    );
    canvas.drawRect(front, frontPaint);
    if (selected) {
      // Reflet clair sur l'arête gauche de la colonne allumée.
      canvas.drawRect(
        Rect.fromLTWH(front.left, top, 2, columnHeight),
        Paint()..color = const Color.fromRGBO(255, 255, 255, .35),
      );
    }
  }

  @override
  bool shouldRepaint(_ColumnPainter old) => old.ratio != ratio || old.selected != selected || old.dark != dark;
}

/// Carte en relief (solde, carte boutique) : elle s'incline doucement d'un côté puis de
/// l'autre et un reflet la traverse. Sans animations, elle reste légèrement inclinée.
class TiltCard extends StatelessWidget {
  const TiltCard({super.key, required this.child, this.radius = 28, this.sheen = true});

  final Widget child;
  final double radius;
  final bool sheen;

  @override
  Widget build(BuildContext context) {
    return MotionBuilder(
      period: const Duration(seconds: 9),
      stillPhase: .25,
      builder: (context, t, child) {
        final wave = math.sin(t * 2 * math.pi);
        final pitch = (6.5 + 2.5 * wave) * math.pi / 180;
        final yaw = (-1.5 + 10.5 * wave) * math.pi / 180;
        final matrix = Matrix4.identity()
          ..setEntry(3, 2, 1 / 800)
          ..rotateX(pitch)
          ..rotateY(yaw);
        return Transform(
          transform: matrix,
          alignment: Alignment.center,
          child: Stack(
            children: [
              child!,
              if (sheen)
                Positioned.fill(
                  child: IgnorePointer(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(radius),
                      child: MotionBuilder(
                        period: const Duration(seconds: 6),
                        stillPhase: 0,
                        builder: (context, s, _) {
                          // Le reflet passe pendant le premier tiers du cycle, puis attend.
                          final x = s < .4 ? -1.6 + s / .4 * 3.2 : 1.6;
                          return DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment(x - .6, -1),
                                end: Alignment(x + .6, 1),
                                colors: const [Color(0x00FFFFFF), Color(0x33FFFFFF), Color(0x00FFFFFF)],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
      child: child,
    );
  }
}
