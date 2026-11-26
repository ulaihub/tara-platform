import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// Repère de Douala ajouté par l'équipe Tara (carrefour, rond-point, lieu connu de tous) que
/// la carte OpenStreetMap ne nomme pas (`GET /map/landmarks`).
@immutable
class Landmark {
  const Landmark({required this.id, required this.name, required this.latitude, required this.longitude});

  factory Landmark.fromJson(Map<String, Object?> json) => Landmark(
    id: json['id']! as String,
    name: json['name']! as String,
    latitude: (json['latitude']! as num).toDouble(),
    longitude: (json['longitude']! as num).toDouble(),
  );

  final String id;
  final String name;
  final double latitude;
  final double longitude;
}

/// Repères pour la source `tara-landmarks` du style Tara.
Map<String, Object?> landmarksGeoJson(List<Landmark> landmarks) => {
  'type': 'FeatureCollection',
  'features': [
    for (final landmark in landmarks)
      {
        'type': 'Feature',
        'properties': {'id': landmark.id, 'name': landmark.name},
        'geometry': {
          'type': 'Point',
          'coordinates': [landmark.longitude, landmark.latitude],
        },
      },
  ],
};

/// Repère le plus proche d'un point, à moins de [maxMeters] ; null sinon.
({Landmark landmark, int meters})? nearestLandmark(
  double latitude,
  double longitude,
  List<Landmark> landmarks, {
  double maxMeters = 250,
}) {
  ({Landmark landmark, int meters})? best;
  for (final landmark in landmarks) {
    final meters = _distance(latitude, longitude, landmark.latitude, landmark.longitude);
    if (meters <= maxMeters && (best == null || meters < best.meters)) {
      best = (landmark: landmark, meters: meters.round());
    }
  }
  return best;
}

double _distance(double lat1, double lng1, double lat2, double lng2) {
  const earth = 6371000.0;
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLng = rad(lng2 - lng1);
  final a =
      math.pow(math.sin(dLat / 2), 2) + math.cos(rad(lat1)) * math.cos(rad(lat2)) * math.pow(math.sin(dLng / 2), 2);
  return 2 * earth * math.asin(math.sqrt(a));
}
