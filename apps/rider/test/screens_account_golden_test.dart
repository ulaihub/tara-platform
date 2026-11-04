import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:tara_core/api/api_exception.dart';
import 'package:tara_core/session/session_store.dart';
import 'package:tara_rider/app/providers.dart';
import 'package:tara_rider/core/api/models.dart';
import 'package:tara_rider/core/course/active_order.dart';
import 'package:tara_rider/core/offline/action_queue.dart';
import 'package:tara_rider/features/account/account_screen.dart';
import 'package:tara_rider/features/account/emergency_contact_screen.dart';
import 'package:tara_rider/features/onboarding/documents_controller.dart';
import 'package:tara_rider/features/onboarding/documents_screen.dart';

import 'helpers/fake_rider_api.dart';
import 'helpers/fonts.dart';
import 'helpers/harness.dart';
import 'screens_auth_golden_test.dart' show settle;
import 'screens_onboarding_golden_test.dart' show FakeDocuments, requirement;

final accountRequirements = [
  requirement([('NATIONAL_ID_FRONT', 'CNI (recto)', 'National ID (front)', true)]),
  requirement([('NATIONAL_ID_BACK', 'CNI (verso)', 'National ID (back)', false)]),
  requirement([('DRIVING_LICENSE', 'Permis de conduire', 'Driving licence', true)]),
  requirement([
    ('VEHICLE_REGISTRATION', 'Carte grise', 'Vehicle registration', false),
    ('VEHICLE_RENTAL_CONTRACT', 'Contrat de location', 'Rental contract', true),
  ]),
  requirement([('INSURANCE', 'Assurance', 'Insurance', true)]),
  requirement([('SELFIE', 'Photo du visage', 'Selfie', false)]),
  requirement([('CRIMINAL_RECORD', 'Casier judiciaire', 'Criminal record', false)]),
];

/// Dossier du livreur : pièces validées, sauf la carte grise refusée si [rejected].
RiderProfile accountProfile({bool rejected = true, String? contactName = 'Paul Ekwalla'}) => RiderProfile(
  status: 'ACTIVE',
  vehicleType: 'MOTORBIKE',
  plateNumber: 'LT 482 KQ',
  documents: [
    for (final group in accountRequirements)
      KycDocument(
        type: group.options.first.type,
        status: rejected && group.options.first.type == 'VEHICLE_REGISTRATION' ? 'REJECTED' : 'APPROVED',
        rejectionReason: rejected && group.options.first.type == 'VEHICLE_REGISTRATION'
            ? 'Photo floue : reprenez-la en pleine lumière.'
            : null,
      ),
  ],
  missingDocuments: const [],
  emergencyContactName: contactName,
  emergencyContactPhone: contactName == null ? null : '+237699112233',
);

/// Services du profil, sans réseau ni minuterie.
class AccountHarness {
  AccountHarness({bool rejected = true, String? contactName = 'Paul Ekwalla'})
    : api = FakeRiderApi(),
      documents = DocumentsState(
        requirements: accountRequirements,
        profile: accountProfile(rejected: rejected, contactName: contactName),
      ) {
    store.values['tara.rider-config'] = jsonEncode({
      'country': {'code': 'CM', 'dialCode': '+237', 'currency': 'XAF'},
      'safetyHotline': '+237640114064',
      'supportPhone': '+237233420000',
      'mobileMoneyOperators': [
        {'code': 'MTN', 'name': 'MTN MoMo'},
        {'code': 'ORANGE', 'name': 'Orange Money'},
      ],
      'offerTimeoutSeconds': 30,
    });
  }

  final store = MemoryKeyValueStore();
  final FakeRiderApi api;
  final DocumentsState documents;
  late final queue = ActionQueue(store: store, send: (_, _) async => null, upload: (path) async => path);
  late final active = ActiveOrderController(
    store: store,
    fetchActive: () async => [],
    fetchOrder: (_) async => throw const ApiException(code: ApiException.network, message: ''),
    hasPendingActions: (id) => queue.forOrder(id).any((a) => !a.failed),
  );

  List<Override> get overrides => [
    keyValueStoreProvider.overrideWithValue(store),
    riderApiProvider.overrideWithValue(api),
    documentsControllerProvider.overrideWith(() => FakeDocuments(documents)),
    appVersionProvider.overrideWith((ref) async => '1.0.0 (12)'),
    actionQueueProvider.overrideWithValue(queue),
    activeOrderProvider.overrideWithValue(active),
  ];

  Widget screen({List<Override> extra = const []}) => ProviderScope(
    overrides: [...overrides, ...extra],
    child: tabs(2, AccountScreen(pickPhoto: ({required selfie}) async => null)),
  );
}

void main() {
  setUpAll(loadAppFonts);

  for (final variant in Variant.matrix) {
    goldenTest('16 profil ${variant.name}', (tester) async {
      await pumpVariant(tester, variant, AccountHarness().screen());
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('1 pièce à renvoyer'), findsOneWidget);
      await expectLater(capture, matchesGoldenFile('goldens/16_profil/${variant.name}.png'));
    });

    goldenTest('16 contact d’urgence ${variant.name}', (tester) async {
      await pumpVariant(tester, variant, AccountHarness().screen());
      await settle(tester);
      await tester.scrollUntilVisible(find.text('Modifier'), 120, scrollable: find.byType(Scrollable).first);
      await settle(tester);
      await tester.tap(find.text('Modifier'));
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.byType(EmergencyContactScreen), findsOneWidget);
      await expectLater(capture, matchesGoldenFile('goldens/16_contact_urgence/${variant.name}.png'));
    });

    goldenTest('16 pièces depuis le profil ${variant.name}', (tester) async {
      await pumpVariant(tester, variant, AccountHarness().screen());
      await settle(tester);
      await tester.scrollUntilVisible(find.text('Renvoyer'), 120, scrollable: find.byType(Scrollable).first);
      await settle(tester);
      await tester.tap(find.text('Renvoyer'));
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.byType(DocumentsScreen), findsOneWidget);
      await expectLater(capture, matchesGoldenFile('goldens/16_pieces_profil/${variant.name}.png'));
    });
  }

  for (final brightness in Brightness.values) {
    goldenTest('16 profil complet ${brightness.name}', (tester) async {
      await pumpVariant(
        tester,
        Variant(brightness, ScreenSize.regular, 1),
        AccountHarness(rejected: false).screen(),
        surface: const Size(390, 1640),
      );
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('Toutes vos pièces sont validées'), findsOneWidget);
      await expectLater(capture, matchesGoldenFile('goldens/16_profil/complet_${brightness.name}.png'));
    });
  }
}
