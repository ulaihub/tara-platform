import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tara_core/api/api_exception.dart';
import 'package:tara_core/session/session_store.dart';
import 'package:tara_rider/app/providers.dart';
import 'package:tara_rider/core/api/models.dart';
import 'package:tara_rider/core/location/location_tracker.dart';
import 'package:tara_rider/core/location/online_controller.dart';
import 'package:tara_rider/features/common/status_screen.dart';
import 'package:tara_rider/features/home/home_offline_screen.dart';
import 'package:tara_rider/features/home/home_summary.dart';
import 'package:tara_test/fake_legal_api.dart';

import 'helpers/fonts.dart';
import 'helpers/harness.dart';
import 'screens_auth_golden_test.dart' show scoped, settle;

const summary = HomeSummary(
  fullName: 'Awa Ngono',
  earnings: 8750,
  delivered: 6,
  onlineSeconds: 4 * 3600 + 35 * 60,
  available: 23500,
);

Widget home({OnlineController? online}) => ProviderScope(
  overrides: [
    keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
    homeSummaryProvider.overrideWith((ref) async => summary),
    documentLabelsProvider.overrideWith((ref) async => {}),
    legalApiProvider.overrideWithValue(FakeLegalApi(app: 'rider', status: newVersion('rider'))),
    accountPhoneProvider.overrideWith((ref) async => '+237677123456'),
    if (online != null) onlineControllerProvider.overrideWithValue(online),
  ],
  child: tabs(0, HomeOfflineScreen(onWentOnline: () {}, onDetails: () {}, now: DateTime(2026, 11, 3, 19))),
);

class _Positions implements PositionSource {
  @override
  Future<LocationAccess> ensureAccess() async => LocationAccess.granted;
  @override
  Future<GeoPoint?> current() async => GeoPoint(latitude: 4.05, longitude: 9.7, recordedAt: DateTime.utc(2026, 11, 3));
  @override
  Stream<GeoPoint> watch({
    required Duration interval,
    required String notificationTitle,
    required String notificationText,
  }) => const Stream.empty();
}

/// Serveur qui refuse le passage en ligne : nouvelle version des conditions à signer.
OnlineController termsBlocked() => OnlineController(
  positions: _Positions(),
  setPresence: ({required online, required position}) async => throw const ApiException(
    code: 'RIDER_NOT_ELIGIBLE',
    message: 'Pas encore éligible',
    status: 422,
    details: {'reasons': 'TERMS'},
  ),
  sendPosition: (_) async {},
);

void main() {
  setUpAll(loadAppFonts);

  goldenTest('05 accueil hors ligne : nouvelles conditions à signer', (tester) async {
    const variant = Variant(Brightness.light, ScreenSize.regular, 1);
    await pumpVariant(tester, variant, home(online: termsBlocked()));
    await settle(tester);
    await tester.tap(find.text('Passer en ligne'));
    await settle(tester);
    expect(find.text('Nos conditions ont changé : lisez-les et signez-les pour recevoir des courses.'), findsOneWidget);
    expect(find.text('Pièces à renouveler avant de passer en ligne'), findsNothing);
    await expectLater(capture, matchesGoldenFile('goldens/05_accueil_hors_ligne/conditions_${variant.name}.png'));

    await tester.tap(find.text('Lire et signer'));
    await settle(tester);
    expect(find.text('Nos conditions ont changé'), findsOneWidget);
    await tester.tap(find.text('Plus tard'));
    await settle(tester);
    expect(find.text('Lire et signer'), findsNothing);
  });

  for (final variant in Variant.matrix) {
    goldenTest('05 accueil hors ligne ${variant.name}', (tester) async {
      await pumpVariant(tester, variant, home());
      await settle(tester);
      expect(tester.takeException(), isNull);
      await expectLater(capture, matchesGoldenFile('goldens/05_accueil_hors_ligne/${variant.name}.png'));
    });
  }

  for (final brightness in Brightness.values) {
    goldenTest('dossier en vérification ${brightness.name}', (tester) async {
      await pumpVariant(
        tester,
        Variant(brightness, ScreenSize.regular, 1),
        scoped(
          StatusScreen(
            title: 'Dossier en cours de vérification',
            body: 'Nous vérifions vos pièces, en général sous 48 h. Vous recevrez un SMS dès que vous pourrez prendre des courses.',
            actionLabel: 'Réessayer',
            onAction: () {},
            linkLabel: 'Se déconnecter',
            onLink: () {},
          ),
        ),
      );
      await settle(tester);
      await expectLater(capture, matchesGoldenFile('goldens/00_verification/${brightness.name}.png'));
    });
  }
}
