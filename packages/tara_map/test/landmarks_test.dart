import 'package:flutter_test/flutter_test.dart';
import 'package:tara_map/landmarks.dart';

void main() {
  const a = Landmark(id: 'a', name: 'Carrefour Exemple A', latitude: 4.0500, longitude: 9.7000);
  const b = Landmark(id: 'b', name: 'Rond-point Exemple B', latitude: 4.0510, longitude: 9.7000);

  test('propose le repère le plus proche, à moins de 250 m', () {
    final near = nearestLandmark(4.0502, 9.7000, [b, a]);
    expect(near?.landmark.name, 'Carrefour Exemple A');
    expect(near?.meters, inInclusiveRange(20, 25));
  });

  test('aucun repère trop loin', () {
    expect(nearestLandmark(4.0600, 9.7000, [a, b]), isNull);
    expect(nearestLandmark(4.05, 9.7, const []), isNull);
  });

  test('lit la réponse de l’API et la met en GeoJSON pour la carte', () {
    final landmark = Landmark.fromJson({'id': 'x', 'name': 'Lieu', 'latitude': 4.05, 'longitude': 9.7});
    final geo = landmarksGeoJson([landmark]);
    final feature = (geo['features']! as List).single as Map;
    expect((feature['geometry'] as Map)['coordinates'], [9.7, 4.05]);
    expect((feature['properties'] as Map)['name'], 'Lieu');
  });
}
