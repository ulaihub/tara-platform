import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../core/api/models.dart';
import '../../core/env.dart';
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

/// Carte Tara : style sombre ou clair, rues et lieux détaillés, zones interdites aux motos,
/// position du livreur suivie par la caméra tant qu'il ne déplace pas la carte.
class TaraMap extends ConsumerStatefulWidget {
  const TaraMap({super.key, this.rider, this.handle, this.onFollowChanged, this.zoom = 16});

  final GeoPoint? rider;
  final TaraMapHandle? handle;

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
    if (widget.rider != old.rider) unawaited(_showRider());
  }

  Future<void> _onStyleLoaded() async {
    _styleReady = true;
    await _showZones();
    await _showRider();
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
    if (_following) await controller.animateCamera(CameraUpdate.newLatLng(LatLng(rider.latitude, rider.longitude)));
  }

  Future<void> _recenter() async {
    _setFollowing(true);
    final rider = widget.rider;
    if (rider != null) {
      await _controller?.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(rider.latitude, rider.longitude), widget.zoom),
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
    if (!ref.watch(realMapProvider)) return const MapBackdrop();
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
