import 'package:flutter/services.dart';

/// Tuiles vectorielles (TileJSON, schéma OpenMapTiles) et polices des libellés, fixées à la
/// compilation (`--dart-define`). Par défaut, OpenFreeMap (même schéma) en attendant les
/// tuiles Tara auto-hébergées.
abstract final class MapEnv {
  static const tilesUrl = String.fromEnvironment(
    'TARA_TILES_URL',
    defaultValue: 'https://tiles.openfreemap.org/planet',
  );
  static const glyphsUrl = String.fromEnvironment(
    'TARA_GLYPHS_URL',
    defaultValue: 'https://tiles.openfreemap.org/fonts/{fontstack}/{range}.pbf',
  );
}

/// Style MapLibre Tara (sombre ou clair) prêt à charger : rues, quartiers, lieux utiles,
/// numéros, sources des zones, du livreur, de l'étape et de l'itinéraire (vides au départ).
Future<String> loadTaraMapStyle(Brightness brightness) async {
  final raw = await rootBundle.loadString(
    'packages/tara_map/assets/tara-${brightness == Brightness.dark ? 'dark' : 'light'}.json',
  );
  return raw.replaceAll('{{TILES_URL}}', MapEnv.tilesUrl).replaceAll('{{GLYPHS_URL}}', MapEnv.glyphsUrl);
}
