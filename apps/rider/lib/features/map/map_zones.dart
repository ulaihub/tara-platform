import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tara_map/landmarks.dart';

import '../../app/providers.dart';
import '../../core/api/models.dart';

/// Zones à dessiner (zone de service, zones interdites aux motos), gardées sur le téléphone :
/// elles restent visibles hors connexion. Rafraîchies à chaque ouverture de la carte.
class MapZonesController extends AsyncNotifier<Json> {
  static const _key = 'tara.map-zones';
  static const empty = <String, Object?>{'type': 'FeatureCollection', 'features': <Object?>[]};

  @override
  Future<Json> build() async {
    final cached = await ref.read(keyValueStoreProvider).read(_key);
    unawaited(refresh());
    return cached == null ? empty : jsonDecode(cached) as Json;
  }

  Future<void> refresh() async {
    try {
      final json = await ref.read(apiClientProvider).get('/map/zones') as Json;
      await ref.read(keyValueStoreProvider).write(_key, jsonEncode(json));
      state = AsyncData(json);
    } catch (_) {
      // Hors connexion : on garde les dernières zones connues.
    }
  }
}

final mapZonesProvider = AsyncNotifierProvider<MapZonesController, Json>(MapZonesController.new);

/// Zones avec le libellé affiché sur la carte, dans la langue du livreur.
Json labelledZones(Json zones, String noMotoLabel) => {
  'type': 'FeatureCollection',
  'features': [
    for (final feature in (zones['features'] as List<Object?>? ?? const []))
      {
        ...(feature! as Json),
        'properties': {...((feature as Json)['properties'] as Json? ?? const {}), 'label': noMotoLabel},
      },
  ],
};

/// Repères de Douala (carrefours, lieux connus) ajoutés par l'équipe : chargés une fois ;
/// sans réseau, la carte s'en passe.
final landmarksProvider = FutureProvider<List<Landmark>>((ref) async {
  try {
    final json = await ref.watch(apiClientProvider).get('/map/landmarks') as Json;
    return [for (final item in json['items']! as List<Object?>) Landmark.fromJson(item! as Json)];
  } catch (_) {
    return const [];
  }
});
