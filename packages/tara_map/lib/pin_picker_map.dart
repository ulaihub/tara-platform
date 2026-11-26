import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:tara_ui/components/map_backdrop.dart';
import 'package:tara_ui/tara_colors.dart';

import 'landmarks.dart';
import 'map_style.dart';

/// Point choisi sur la carte.
@immutable
class MapPoint {
  const MapPoint(this.latitude, this.longitude);
  final double latitude;
  final double longitude;

  /// Douala, Akwa : vue par défaut tant que la position n'est pas connue.
  static const douala = MapPoint(4.0496, 9.6996);

  @override
  bool operator ==(Object other) => other is MapPoint && other.latitude == latitude && other.longitude == longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);
}

/// Commande de la carte depuis l'écran (« Ma position »).
class PinPickerHandle {
  _PinPickerMapState? _state;
  Future<void> moveTo(MapPoint point) async => _state?._moveTo(point);
}

/// Choix d'un point (B1) : la carte glisse sous une épingle fixe au centre ; le point est
/// relu quand la carte s'arrête. Dans les captures de test ([real] faux), fond dessiné.
class PinPickerMap extends StatefulWidget {
  const PinPickerMap({
    super.key,
    required this.initial,
    required this.onChanged,
    this.handle,
    this.real = true,
    this.zoom = 17,
    this.bottomPadding = 0,
    this.label,
    this.landmarks = const [],
  });

  /// Repères de l'équipe (carrefours, lieux connus) dessinés sur la carte.
  final List<Landmark> landmarks;

  final MapPoint initial;
  final ValueChanged<MapPoint> onChanged;
  final PinPickerHandle? handle;
  final bool real;
  final double zoom;

  /// Hauteur cachée par le panneau du bas : l'épingle se place au centre de la partie
  /// visible.
  final double bottomPadding;

  /// Bulle sous l'épingle quand la carte est arrêtée (quartier du point, point hors de la
  /// zone desservie) : elle confirme que le point est bien placé.
  final Widget? label;

  @override
  State<PinPickerMap> createState() => _PinPickerMapState();
}

class _PinPickerMapState extends State<PinPickerMap> {
  MapLibreMapController? _controller;
  String? _style;
  Brightness? _brightness;
  bool _moving = false;

  @override
  void initState() {
    super.initState();
    widget.handle?._state = this;
  }

  bool _styleReady = false;

  @override
  void didUpdateWidget(PinPickerMap old) {
    super.didUpdateWidget(old);
    widget.handle?._state = this;
    if (!identical(widget.landmarks, old.landmarks)) unawaited(_showLandmarks());
  }

  Future<void> _showLandmarks() async {
    final controller = _controller;
    if (controller == null || !_styleReady) return;
    await controller.setGeoJsonSource('tara-landmarks', landmarksGeoJson(widget.landmarks));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final brightness = TaraColors.of(context).brightness;
    if (widget.real && brightness != _brightness) {
      _brightness = brightness;
      _styleReady = false;
      unawaited(
        loadTaraMapStyle(brightness).then((style) {
          if (mounted) setState(() => _style = style);
        }),
      );
    }
  }

  Future<void> _moveTo(MapPoint point) async {
    await _controller?.animateCamera(CameraUpdate.newLatLngZoom(LatLng(point.latitude, point.longitude), widget.zoom));
  }

  void _onIdle() {
    final target = _controller?.cameraPosition?.target;
    // L'épingle se pose sous le doigt : un petit retour au toucher le confirme.
    if (_moving) unawaited(HapticFeedback.selectionClick());
    if (mounted) setState(() => _moving = false);
    if (target != null) widget.onChanged(MapPoint(target.latitude, target.longitude));
  }

  @override
  Widget build(BuildContext context) {
    final c = TaraColors.of(context);
    final style = _style;
    final Widget map = !widget.real
        ? const MapBackdrop()
        : style == null
        ? ColoredBox(color: c.mapGround)
        : MapLibreMap(
            key: ValueKey(_brightness),
            styleString: style,
            initialCameraPosition: CameraPosition(
              target: LatLng(widget.initial.latitude, widget.initial.longitude),
              zoom: widget.zoom,
            ),
            trackCameraPosition: true,
            onMapCreated: (controller) => _controller = controller,
            onStyleLoadedCallback: () {
              _styleReady = true;
              unawaited(_showLandmarks());
            },
            onCameraIdle: _onIdle,
            compassEnabled: false,
            rotateGesturesEnabled: false,
            tiltGesturesEnabled: false,
            attributionButtonPosition: AttributionButtonPosition.bottomLeft,
            gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{},
          );
    return Stack(
      fit: StackFit.expand,
      children: [
        Listener(onPointerDown: (_) => setState(() => _moving = true), child: map),
        // Épingle au centre de la partie visible ; elle se soulève pendant le déplacement.
        Positioned.fill(
          bottom: widget.bottomPadding,
          child: IgnorePointer(
            child: Center(
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 180),
                offset: Offset(0, _moving ? -.75 : -.5),
                child: const _Pin(),
              ),
            ),
          ),
        ),
        // Bulle juste sous la pointe de l'épingle (loin du titre de l'écran), cachée pendant
        // le geste.
        if (widget.label != null)
          Positioned.fill(
            bottom: widget.bottomPadding,
            child: IgnorePointer(
              child: Center(
                child: FractionalTranslation(
                  translation: const Offset(0, .5),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 160),
                      opacity: _moving ? 0 : 1,
                      child: widget.label,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Épingle de la marque : tête ronde orange cerclée de blanc, pointe et ombre au sol.
class _Pin extends StatelessWidget {
  const _Pin();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            gradient: TaraBrand.gradient,
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFFFFFFF), width: 5),
            boxShadow: const [BoxShadow(color: Color.fromRGBO(0, 0, 0, .3), blurRadius: 12, offset: Offset(0, 5))],
          ),
        ),
        Container(width: 4, height: 18, color: const Color(0xFFFFFFFF)),
        Container(
          width: 12,
          height: 5,
          decoration: const BoxDecoration(
            color: Color.fromRGBO(0, 0, 0, .25),
            borderRadius: BorderRadius.all(Radius.elliptical(12, 5)),
          ),
        ),
      ],
    );
  }
}
