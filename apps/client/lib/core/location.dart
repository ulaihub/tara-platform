import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:tara_map/pin_picker_map.dart';

/// Position du téléphone pour placer une adresse (« Ma position ») ; null si elle est
/// refusée ou indisponible. Remplacée dans les tests.
final currentPositionProvider = Provider<Future<MapPoint?> Function()>((ref) => _devicePosition);

Future<MapPoint?> _devicePosition() async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) return null;
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) return null;
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 12)),
    );
    return MapPoint(position.latitude, position.longitude);
  } catch (_) {
    return null;
  }
}

/// Carte réelle (MapLibre) ; fond dessiné dans les captures de test.
final realMapProvider = Provider<bool>((ref) => true);
