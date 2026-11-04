import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tara_core/api/api_exception.dart';
import 'package:tara_core/session/session_store.dart';
import 'package:tara_rider/app/providers.dart';
import 'package:tara_rider/core/api/models.dart';
import 'package:tara_rider/core/safety/safety_alert.dart';
import 'package:tara_rider/features/safety/sos_screen.dart';

import 'helpers/fonts.dart';
import 'helpers/harness.dart';
import 'screens_auth_golden_test.dart' show settle;

final here = GeoPoint(latitude: 4.0511, longitude: 9.6942, accuracy: 8, recordedAt: DateTime.utc(2026, 11, 4, 9));

/// Alerte telle que l'équipe Tara l'a prise en charge (quartier et plaque connus).
final acknowledged = SafetyAlert.fromJson({
  'id': '00000000-0000-4000-8000-0000000000a1',
  'createdAt': '2026-11-04T09:00:00.000Z',
  'cancelledAt': null,
  'resolvedAt': null,
  'acknowledgedAt': '2026-11-04T09:01:00.000Z',
  'policeCalledAt': null,
  'neighborhood': 'Akwa',
  'riderPlate': 'LT 482 AB',
});

/// Alerte sans minuterie ni réseau ; [send] décide de l'issue de l'envoi.
SafetyAlertController safetyAlert({
  Future<SafetyAlert> Function(PendingAlert alert)? send,
  Future<SafetyAlert> Function(String id)? cancel,
  GeoPoint? position,
}) => SafetyAlertController(
  store: MemoryKeyValueStore(),
  send: send ?? (_) async => acknowledged,
  cancel: cancel ?? (_) async => acknowledged,
  locate: () async => position ?? here,
  retryEvery: const Duration(hours: 1),
);

Widget sos(SafetyAlertController safety, {List<Uri>? launched, VoidCallback? onClose}) => ProviderScope(
  overrides: [
    keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
    safetyAlertProvider.overrideWithValue(safety),
    launcherProvider.overrideWithValue((uri) async {
      launched?.add(uri);
      return true;
    }),
  ],
  child: SosScreen(
    orderId: '00000000-0000-4000-8000-000000000002',
    orderReference: 'TR-48213',
    onClose: onClose ?? () {},
  ),
);

void main() {
  setUpAll(loadAppFonts);

  for (final variant in Variant.matrix) {
    goldenTest('14 alerte ${variant.name}', (tester) async {
      final safety = safetyAlert();
      await pumpVariant(tester, variant, sos(safety));
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('Besoin d’aide ?'), findsOneWidget);
      expect(find.text('Police · 117'), findsOneWidget);
      await expectLater(capture, matchesGoldenFile('goldens/14_alerte/${variant.name}.png'));
    });

    goldenTest('14 alerte envoyée ${variant.name}', (tester) async {
      final safety = safetyAlert();
      await safety.raise(orderId: 'o1');
      await pumpVariant(tester, variant, sos(safety));
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('Moto LT 482 AB'), findsOneWidget);
      expect(find.text('Annuler l’alerte'), findsOneWidget);
      await expectLater(capture, matchesGoldenFile('goldens/14_alerte_envoyee/${variant.name}.png'));
    });

    goldenTest('14 alerte sans réseau ${variant.name}', (tester) async {
      final safety = safetyAlert(
        send: (_) async => throw const ApiException(code: ApiException.network, message: ''),
      );
      await safety.raise(orderId: 'o1');
      await pumpVariant(tester, variant, sos(safety));
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('Envoyer l’alerte par SMS'), findsOneWidget);
      await expectLater(capture, matchesGoldenFile('goldens/14_alerte_sans_reseau/${variant.name}.png'));
      await tester.pumpWidget(const SizedBox());
      safety.dispose();
    });
  }
}
