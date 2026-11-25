import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:tara_map/landmarks.dart';
import 'package:tara_map/map_style.dart';
import 'package:tara_map/pin_picker_map.dart';
import 'package:tara_ui/components/layout.dart';
import 'package:tara_ui/components/map_backdrop.dart';
import 'package:tara_ui/motion/motion_clock.dart';
import 'package:tara_ui/tara_colors.dart';
import 'package:tara_ui/tara_icons.dart';

import '../../core/location.dart';

/// Carte du suivi (F1) : enlèvement, livraison, trajet en pointillés et moto du livreur,
/// qui glisse en douceur d'une position à la suivante. Pendant la recherche d'un livreur,
/// des ondes partent du point d'enlèvement. Dans les captures de test, fond dessiné.
class TrackingMap extends ConsumerStatefulWidget {
  const TrackingMap({
    super.key,
    required this.pickup,
    required this.dropoff,
    required this.searching,
    required this.toDropoff,
    this.rider,
    this.heading,
    this.framePadding = EdgeInsets.zero,
    this.route,
    this.landmarks = const [],
  });

  /// Repères de l'équipe (carrefours, lieux connus).
  final List<Landmark> landmarks;

  /// Trajet sur les rues ([longitude, latitude]) ; null : ligne droite en pointillés.
  final List<List<double>>? route;

  final MapPoint pickup;
  final MapPoint dropoff;
  final MapPoint? rider;
  final double? heading;

  /// Recherche d'un livreur : ondes sur l'enlèvement.
  final bool searching;

  /// Colis à bord : la caméra cadre le livreur et la livraison (sinon l'enlèvement).
  final bool toDropoff;

  /// Place occupée par les panneaux au-dessus de la carte.
  final EdgeInsets framePadding;

  @override
  ConsumerState<TrackingMap> createState() => _TrackingMapState();
}

class _TrackingMapState extends ConsumerState<TrackingMap> with SingleTickerProviderStateMixin {
  MapLibreMapController? _controller;
  String? _style;
  Brightness? _brightness;
  bool _styleReady = false;

  /// Glissement de la moto entre l'ancienne et la nouvelle position.
  late final AnimationController _glide = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
    ..addListener(_onGlide);
  MapPoint? _from;
  MapPoint? _shown;
  DateTime _lastPush = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    _shown = widget.rider;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final brightness = TaraColors.of(context).brightness;
    if (ref.read(realMapProvider) && brightness != _brightness) {
      _brightness = brightness;
      _styleReady = false;
      unawaited(
        loadTaraMapStyle(brightness).then((style) {
          if (mounted) setState(() => _style = style);
        }),
      );
    }
  }

  @override
  void didUpdateWidget(TrackingMap old) {
    super.didUpdateWidget(old);
    final rider = widget.rider;
    if (rider != null && rider != old.rider) {
      if (_shown == null) {
        _shown = rider;
        unawaited(_pushRider());
      } else {
        _from = _shown;
        unawaited(_glide.forward(from: 0));
      }
    }
    if (widget.searching != old.searching || widget.toDropoff != old.toDropoff) unawaited(_frame());
    if (widget.route != old.route) unawaited(_pushRoute());
    if (!identical(widget.landmarks, old.landmarks) && _styleReady) {
      unawaited(_controller?.setGeoJsonSource('tara-landmarks', landmarksGeoJson(widget.landmarks)));
    }
  }

  @override
  void dispose() {
    _glide.dispose();
    super.dispose();
  }

  void _onGlide() {
    final from = _from;
    final to = widget.rider;
    if (from == null || to == null) return;
    final t = Curves.easeInOut.transform(_glide.value);
    final point = MapPoint(
      from.latitude + (to.latitude - from.latitude) * t,
      from.longitude + (to.longitude - from.longitude) * t,
    );
    setState(() => _shown = point);
    // Carte réelle : la source n'est rafraîchie qu'une vingtaine de fois par seconde.
    final now = DateTime.now();
    if (_glide.isCompleted || now.difference(_lastPush) > const Duration(milliseconds: 50)) {
      _lastPush = now;
      unawaited(_pushRider());
    }
  }

  // --- Carte réelle ----------------------------------------------------------------------

  Future<void> _onStyleLoaded() async {
    final controller = _controller;
    if (controller == null) return;
    _styleReady = true;
    final ratio = MediaQuery.devicePixelRatioOf(context);
    await controller.addImage('tara-moto', await motoMarkerPng(ratio), false, ratio);
    await controller.addSymbolLayer(
      'tara-rider',
      'tara-rider-moto',
      const SymbolLayerProperties(iconImage: 'tara-moto', iconAllowOverlap: true, iconIgnorePlacement: true),
    );
    await controller.setGeoJsonSource('tara-stop', {
      'type': 'FeatureCollection',
      'features': [
        _point(widget.pickup, {'kind': 'pickup', 'label': ''}),
        _point(widget.dropoff, {'kind': 'dropoff', 'label': ''}),
      ],
    });
    await _pushRoute();
    await controller.setGeoJsonSource('tara-landmarks', landmarksGeoJson(widget.landmarks));
    await _pushRider();
    await _frame();
  }

  /// Trajet sur les rues (trait plein) dès qu'il est connu ; avant, ligne droite en pointillés.
  Future<void> _pushRoute() async {
    final controller = _controller;
    if (controller == null || !_styleReady) return;
    final route = widget.route;
    await controller.setGeoJsonSource('tara-route', {
      'type': 'FeatureCollection',
      'features': [
        {
          'type': 'Feature',
          'properties': {'estimate': route == null},
          'geometry': {
            'type': 'LineString',
            'coordinates':
                route ??
                [
                  [widget.pickup.longitude, widget.pickup.latitude],
                  [widget.dropoff.longitude, widget.dropoff.latitude],
                ],
          },
        },
      ],
    });
  }

  static Map<String, Object?> _point(MapPoint point, Map<String, Object?> properties) => {
    'type': 'Feature',
    'properties': properties,
    'geometry': {
      'type': 'Point',
      'coordinates': [point.longitude, point.latitude],
    },
  };

  Future<void> _pushRider() async {
    final controller = _controller;
    final rider = _shown;
    if (controller == null || !_styleReady) return;
    await controller.setGeoJsonSource('tara-rider', {
      'type': 'FeatureCollection',
      'features': [
        if (rider != null) _point(rider, {'heading': widget.heading ?? 0}),
      ],
    });
  }

  /// Recherche : l'enlèvement au centre. Course : le livreur et l'étape visée.
  Future<void> _frame() async {
    final controller = _controller;
    if (controller == null || !_styleReady) return;
    final rider = widget.rider;
    final target = widget.toDropoff ? widget.dropoff : widget.pickup;
    final points = widget.searching
        ? null
        : rider == null
        ? [widget.pickup, widget.dropoff]
        : [rider, target];
    final pad = widget.framePadding;
    if (points == null) {
      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(widget.pickup.latitude, widget.pickup.longitude), 15),
      );
      return;
    }
    const minSpan = 0.0015;
    final south = points.map((p) => p.latitude).reduce(math.min) - minSpan;
    final north = points.map((p) => p.latitude).reduce(math.max) + minSpan;
    final west = points.map((p) => p.longitude).reduce(math.min) - minSpan;
    final east = points.map((p) => p.longitude).reduce(math.max) + minSpan;
    await controller.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(southwest: LatLng(south, west), northeast: LatLng(north, east)),
        left: pad.left + 40,
        top: pad.top + 40,
        right: pad.right + 40,
        bottom: pad.bottom + 40,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = TaraColors.of(context);
    if (!ref.watch(realMapProvider)) {
      return _DrawnTracking(
        pickup: widget.pickup,
        dropoff: widget.dropoff,
        rider: _shown,
        searching: widget.searching,
        framePadding: widget.framePadding,
      );
    }
    final style = _style;
    if (style == null) return ColoredBox(color: c.mapGround);
    return Stack(
      fit: StackFit.expand,
      children: [
        MapLibreMap(
          key: ValueKey(_brightness),
          styleString: style,
          initialCameraPosition: CameraPosition(
            target: LatLng(widget.pickup.latitude, widget.pickup.longitude),
            zoom: 14,
          ),
          onMapCreated: (controller) => _controller = controller,
          onStyleLoadedCallback: () => unawaited(_onStyleLoaded()),
          compassEnabled: false,
          rotateGesturesEnabled: false,
          tiltGesturesEnabled: false,
          // Pendant la recherche, la carte reste sur l'enlèvement, sous les ondes.
          scrollGesturesEnabled: !widget.searching,
          zoomGesturesEnabled: !widget.searching,
          attributionButtonPosition: AttributionButtonPosition.bottomLeft,
          gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{},
        ),
        if (widget.searching)
          Positioned.fill(
            top: widget.framePadding.top,
            bottom: widget.framePadding.bottom,
            child: const IgnorePointer(child: Center(child: SearchRipple())),
          ),
      ],
    );
  }
}

/// Ondes qui partent de l'enlèvement pendant la recherche d'un livreur (« radar »).
class SearchRipple extends StatelessWidget {
  const SearchRipple({super.key, this.size = 220});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: MotionBuilder(
        period: const Duration(milliseconds: 2400),
        stillPhase: .45,
        builder: (context, t, _) => CustomPaint(painter: _RipplePainter(t)),
      ),
    );
  }
}

class _RipplePainter extends CustomPainter {
  _RipplePainter(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final max = size.shortestSide / 2;
    // Trois ondes décalées d'un tiers de période, qui s'éteignent en s'éloignant.
    for (var i = 0; i < 3; i++) {
      final phase = (t + i / 3) % 1;
      final radius = 14 + (max - 14) * Curves.easeOut.transform(phase);
      final opacity = (1 - phase) * .55;
      canvas
        ..drawCircle(center, radius, Paint()..color = TaraBrand.orange.withValues(alpha: opacity * .35))
        ..drawCircle(
          center,
          radius,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = TaraBrand.orange.withValues(alpha: opacity),
        );
    }
  }

  @override
  bool shouldRepaint(_RipplePainter old) => old.t != t;
}

/// Moto du livreur : pastille de la marque cerclée de blanc, moto sombre au centre.
class MotoMarker extends StatelessWidget {
  const MotoMarker({super.key, this.size = 44});

  final double size;

  @override
  Widget build(BuildContext context) => CustomPaint(size: Size.square(size), painter: const _MotoPainter());
}

class _MotoPainter extends CustomPainter {
  const _MotoPainter();

  @override
  void paint(Canvas canvas, Size size) => paintMoto(canvas, size.shortestSide);

  @override
  bool shouldRepaint(_MotoPainter old) => false;
}

/// Dessine la moto du livreur dans un carré de [side] pixels logiques.
void paintMoto(Canvas canvas, double side) {
  final radius = side / 2 - 3;
  final center = Offset(side / 2, side / 2);
  final rect = Rect.fromCircle(center: center, radius: radius);
  canvas
    ..drawCircle(
      center.translate(0, 2),
      radius,
      Paint()
        ..color = const Color(0x55000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    )
    ..drawCircle(center, radius, Paint()..shader = TaraBrand.gradient.createShader(rect))
    ..drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = const Color(0xFFFFFFFF),
    );
  final scale = side * .62 / 24;
  canvas
    ..save()
    ..translate(center.dx - 12 * scale, center.dy - 12 * scale)
    ..scale(scale)
    ..drawPath(
      TaraIcons.moto.path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = TaraBrand.onBrand,
    )
    ..restore();
}

/// Moto en image PNG pour la carte réelle (densité de l'écran).
Future<Uint8List> motoMarkerPng(double pixelRatio) async {
  const side = 44.0;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)..scale(pixelRatio);
  paintMoto(canvas, side);
  final pixels = (side * pixelRatio).round();
  final image = await recorder.endRecording().toImage(pixels, pixels);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  return bytes!.buffer.asUint8List();
}

/// Fond dessiné des captures de test : quartiers stylisés, enlèvement, livraison, trajet en
/// pointillés et moto placés à l'échelle dans la partie visible.
class _DrawnTracking extends StatelessWidget {
  const _DrawnTracking({
    required this.pickup,
    required this.dropoff,
    required this.rider,
    required this.searching,
    required this.framePadding,
  });

  final MapPoint pickup;
  final MapPoint dropoff;
  final MapPoint? rider;
  final bool searching;
  final EdgeInsets framePadding;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const MapBackdrop(),
        Positioned.fill(
          top: framePadding.top,
          bottom: framePadding.bottom,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = constraints.biggest;
              final points = [pickup, dropoff, ?rider];
              final south = points.map((p) => p.latitude).reduce(math.min);
              final north = points.map((p) => p.latitude).reduce(math.max);
              final west = points.map((p) => p.longitude).reduce(math.min);
              final east = points.map((p) => p.longitude).reduce(math.max);
              Offset place(MapPoint p) {
                const inset = 56.0;
                final x = east == west ? .5 : (p.longitude - west) / (east - west);
                final y = north == south ? .5 : (north - p.latitude) / (north - south);
                return Offset(inset + x * (size.width - 2 * inset), inset + y * (size.height - 2 * inset));
              }

              final from = place(pickup);
              final to = place(dropoff);
              final moto = rider == null ? null : place(rider!);
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(child: CustomPaint(painter: _DashedRoute(from, to))),
                  if (searching)
                    Positioned(
                      left: from.dx - 110,
                      top: from.dy - 110,
                      child: const IgnorePointer(child: SearchRipple()),
                    ),
                  Positioned(left: from.dx - 14, top: from.dy - 14, child: const PickupPin()),
                  Positioned(left: to.dx - 14, top: to.dy - 14, child: const DestinationPin()),
                  if (moto != null) Positioned(left: moto.dx - 22, top: moto.dy - 22, child: const MotoMarker()),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _DashedRoute extends CustomPainter {
  _DashedRoute(this.from, this.to);

  final Offset from;
  final Offset to;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = TaraBrand.orange.withValues(alpha: .75)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    final length = (to - from).distance;
    if (length == 0) return;
    final step = (to - from) / length;
    for (var d = 0.0; d < length; d += 14) {
      canvas.drawLine(from + step * d, from + step * math.min(d + 7, length), paint);
    }
  }

  @override
  bool shouldRepaint(_DashedRoute old) => old.from != from || old.to != to;
}
