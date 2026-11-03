import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../core/api/models.dart';
import '../../core/env.dart';
import '../../design/components/layout.dart';
import '../../design/components/map_backdrop.dart';
import '../../design/tara_colors.dart';
import '../../l10n/app_localizations.dart';
import 'map_zones.dart';

/// Carte réelle (MapLibre) ; remplacée par un fond dessiné dans les captures de test, où
/// une vue native ne peut pas s'afficher.
final realMapProvider = Provider<bool>((ref) => true);

/// Douala, Akwa : vue par défaut tant que la position n'est pas connue.
const _douala = LatLng(4.0496, 9.6996);

/// Contrôle de la carte depuis l'écran (recentrer sur le livreur).
class TaraMapHandle {
  _TaraMapState? _state;
  Future<void> recenter() async => _state?._recenter();
}

/// Étape visée pendant une course : le vendeur (enlèvement, retour) ou le destinataire.
@immutable
class MapStop {
  const MapStop({required this.latitude, required this.longitude, this.dropoff = false, this.label = ''});
  final double latitude;
  final double longitude;
  final bool dropoff;

  /// Nom affiché au-dessus du point (vendeur ou client).
  final String label;

  @override
  bool operator ==(Object other) =>
      other is MapStop &&
      other.latitude == latitude &&
      other.longitude == longitude &&
      other.dropoff == dropoff &&
      other.label == label;

  @override
  int get hashCode => Object.hash(latitude, longitude, dropoff, label);
}

/// Carte Tara : style sombre ou clair, rues et lieux détaillés, zones interdites aux motos,
/// position du livreur suivie par la caméra tant qu'il ne déplace pas la carte. Pendant une
/// course : itinéraire et étape visée, cadrés ensemble au-dessus du panneau ([framePadding]).
class TaraMap extends ConsumerStatefulWidget {
  const TaraMap({
    super.key,
    this.rider,
    this.handle,
    this.onFollowChanged,
    this.zoom = 16,
    this.stop,
    this.route,
    this.framePadding = const EdgeInsets.fromLTRB(40, 120, 40, 40),
  });

  final GeoPoint? rider;
  final TaraMapHandle? handle;
  final MapStop? stop;
  final RiderRoute? route;

  /// Marges du cadrage livreur + étape (le panneau du bas couvre une partie de la carte).
  final EdgeInsets framePadding;

  /// La caméra suit (true) ou le livreur a déplacé la carte (false : bouton « recentrer »).
  final ValueChanged<bool>? onFollowChanged;
  final double zoom;

  @override
  ConsumerState<TaraMap> createState() => _TaraMapState();
}

class _TaraMapState extends ConsumerState<TaraMap> {
  MapLibreMapController? _controller;
  String? _style;
  Brightness? _styleBrightness;
  bool _styleReady = false;
  bool _following = true;

  @override
  void initState() {
    super.initState();
    widget.handle?._state = this;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final brightness = TaraColors.of(context).brightness;
    if (brightness != _styleBrightness) {
      _styleBrightness = brightness;
      _styleReady = false;
      unawaited(_loadStyle(brightness));
    }
  }

  Future<void> _loadStyle(Brightness brightness) async {
    final raw = await rootBundle.loadString('assets/map/tara-${brightness == Brightness.dark ? 'dark' : 'light'}.json');
    if (!mounted) return;
    setState(() => _style = raw.replaceAll('{{TILES_URL}}', Env.tilesUrl).replaceAll('{{GLYPHS_URL}}', Env.glyphsUrl));
  }

  @override
  void didUpdateWidget(TaraMap old) {
    super.didUpdateWidget(old);
    widget.handle?._state = this;
    if (widget.route != old.route || widget.stop != old.stop) unawaited(_showCourse());
    if (widget.rider != old.rider || widget.stop != old.stop) unawaited(_showRider());
  }

  Future<void> _onStyleLoaded() async {
    _styleReady = true;
    await _showZones();
    await _showCourse();
    await _showRider();
  }

  Future<void> _showCourse() async {
    final controller = _controller;
    if (controller == null || !_styleReady) return;
    final stop = widget.stop;
    final route = widget.route;
    await controller.setGeoJsonSource('tara-stop', {
      'type': 'FeatureCollection',
      'features': [
        if (stop != null)
          {
            'type': 'Feature',
            'properties': {'kind': stop.dropoff ? 'dropoff' : 'pickup', 'label': stop.label},
            'geometry': {
              'type': 'Point',
              'coordinates': [stop.longitude, stop.latitude],
            },
          },
      ],
    });
    await controller.setGeoJsonSource('tara-route', {
      'type': 'FeatureCollection',
      'features': [
        if (stop != null && route != null)
          {
            'type': 'Feature',
            'properties': {'estimate': route.estimate},
            'geometry': {'type': 'LineString', 'coordinates': route.path},
          },
      ],
    });
  }

  Future<void> _showZones() async {
    final controller = _controller;
    final zones = ref.read(mapZonesProvider).value;
    if (controller == null || !_styleReady || zones == null || !mounted) return;
    await controller.setGeoJsonSource('tara-zones', labelledZones(zones, AppLocalizations.of(context).noMotoZone));
  }

  Future<void> _showRider() async {
    final controller = _controller;
    final rider = widget.rider;
    if (controller == null || !_styleReady || rider == null) return;
    await controller.setGeoJsonSource('tara-rider', {
      'type': 'FeatureCollection',
      'features': [
        {
          'type': 'Feature',
          'properties': {'heading': rider.heading ?? 0},
          'geometry': {
            'type': 'Point',
            'coordinates': [rider.longitude, rider.latitude],
          },
        },
      ],
    });
    if (!_following) return;
    final frame = _courseFrame();
    await controller.animateCamera(frame ?? CameraUpdate.newLatLng(LatLng(rider.latitude, rider.longitude)));
  }

  /// Livreur et étape visée dans le même cadre, au-dessus du panneau.
  CameraUpdate? _courseFrame() {
    final rider = widget.rider;
    final stop = widget.stop;
    if (rider == null || stop == null) return null;
    // Au moins ~200 m de côté : pas de zoom extrême quand le livreur est arrivé.
    const minSpan = 0.001;
    final south = math.min(rider.latitude, stop.latitude) - minSpan;
    final north = math.max(rider.latitude, stop.latitude) + minSpan;
    final west = math.min(rider.longitude, stop.longitude) - minSpan;
    final east = math.max(rider.longitude, stop.longitude) + minSpan;
    final pad = widget.framePadding;
    return CameraUpdate.newLatLngBounds(
      LatLngBounds(southwest: LatLng(south, west), northeast: LatLng(north, east)),
      left: pad.left,
      top: pad.top,
      right: pad.right,
      bottom: pad.bottom,
    );
  }

  Future<void> _recenter() async {
    _setFollowing(true);
    final rider = widget.rider;
    if (rider != null) {
      await _controller?.animateCamera(
        _courseFrame() ?? CameraUpdate.newLatLngZoom(LatLng(rider.latitude, rider.longitude), widget.zoom),
      );
    }
  }

  void _setFollowing(bool value) {
    if (_following == value) return;
    _following = value;
    widget.onFollowChanged?.call(value);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(mapZonesProvider, (_, _) => unawaited(_showZones()));
    final c = TaraColors.of(context);
    if (!ref.watch(realMapProvider)) {
      return widget.stop == null ? const MapBackdrop() : _CourseBackdrop(framePadding: widget.framePadding);
    }
    final style = _style;
    if (style == null) return ColoredBox(color: c.mapGround);
    final rider = widget.rider;
    return Listener(
      // Le livreur déplace la carte : la caméra arrête de le suivre jusqu'à « recentrer ».
      onPointerMove: (_) => _setFollowing(false),
      child: MapLibreMap(
        key: ValueKey(_styleBrightness),
        styleString: style,
        initialCameraPosition: CameraPosition(
          target: rider == null ? _douala : LatLng(rider.latitude, rider.longitude),
          zoom: widget.zoom,
        ),
        onMapCreated: (controller) => _controller = controller,
        onStyleLoadedCallback: () => unawaited(_onStyleLoaded()),
        compassEnabled: false,
        rotateGesturesEnabled: false,
        tiltGesturesEnabled: false,
        attributionButtonPosition: AttributionButtonPosition.bottomLeft,
        gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{},
      ),
    );
  }
}

/// Fond dessiné des captures de test pendant une course : itinéraire stylisé du livreur à
/// l'étape, dans la partie visible de la carte. La carte réelle trace l'itinéraire réel.
class _CourseBackdrop extends StatelessWidget {
  const _CourseBackdrop({required this.framePadding});
  final EdgeInsets framePadding;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final visible = Rect.fromLTRB(
          framePadding.left,
          framePadding.top,
          constraints.maxWidth - framePadding.right,
          math.max(framePadding.top + 80, constraints.maxHeight - framePadding.bottom),
        );
        final stop = Offset(visible.left + visible.width * .22, visible.top + visible.height * .2);
        final rider = Offset(visible.left + visible.width * .78, visible.bottom - visible.height * .15);
        return Stack(
          children: [
            const Positioned.fill(child: MapBackdrop()),
            Positioned.fill(
              child: CustomPaint(
                painter: _RoutePainter(from: rider, to: stop),
              ),
            ),
            Positioned(
              left: stop.dx - 16,
              top: stop.dy - 16,
              child: const SizedBox.square(dimension: 32, child: Center(child: PickupPin())),
            ),
            Positioned(
              left: rider.dx - 60,
              top: rider.dy - 60,
              child: const SizedBox.square(dimension: 120, child: Center(child: RiderPin(heading: 315))),
            ),
          ],
        );
      },
    );
  }
}

class _RoutePainter extends CustomPainter {
  _RoutePainter({required this.from, required this.to});
  final Offset from;
  final Offset to;

  @override
  void paint(Canvas canvas, Size size) {
    // Trajet en équerre, comme le long des rues.
    final corner = Offset(from.dx, to.dy + (from.dy - to.dy) * .45);
    final path = Path()
      ..moveTo(from.dx, from.dy)
      ..lineTo(corner.dx, corner.dy)
      ..lineTo(to.dx + (corner.dx - to.dx) * .35, corner.dy)
      ..lineTo(to.dx, to.dy);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas
      ..drawPath(
        path,
        stroke
          ..color = const Color(0xE6FFFFFF)
          ..strokeWidth = 9,
      )
      ..drawPath(
        path,
        stroke
          ..strokeWidth = 5
          ..color = const Color(0xFFFF6A00),
      );
  }

  @override
  bool shouldRepaint(_RoutePainter old) => old.from != from || old.to != to;
}
