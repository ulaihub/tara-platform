import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tara_rider/app/providers.dart';
import 'package:tara_rider/core/api/models.dart';
import 'package:tara_rider/core/session/session_store.dart';
import 'package:tara_rider/features/onboarding/documents_controller.dart';
import 'package:tara_rider/features/onboarding/documents_screen.dart';
import 'package:tara_rider/features/onboarding/profile_screen.dart';

import 'helpers/fonts.dart';
import 'helpers/harness.dart';
import 'screens_auth_golden_test.dart' show scoped, settle;

void main() {
  setUpAll(loadAppFonts);
  documentsGoldens();

  for (final variant in Variant.matrix) {
    goldenTest('03 profil ${variant.name}', (tester) async {
      await pumpVariant(tester, variant, scoped(ProfileScreen(onDone: () {}, onBack: () {})));
      await settle(tester);
      expect(tester.takeException(), isNull);
      await expectLater(capture, matchesGoldenFile('goldens/03_profil/${variant.name}.png'));
    });
  }

  // Écran entier (défilement déplié) avec les erreurs de saisie, pour la revue.
  for (final brightness in Brightness.values) {
    goldenTest('03 profil complet ${brightness.name}', (tester) async {
      final variant = Variant(brightness, ScreenSize.regular, 1);
      await pumpVariant(
        tester,
        variant,
        scoped(ProfileScreen(onDone: () {}, onBack: () {})),
        surface: const Size(390, 1560),
      );
      await tester.enterText(find.byType(EditableText).at(0), 'Awa');
      await tester.enterText(find.byType(EditableText).at(5), 'Mama');
      await tester.tap(find.text('Continuer'));
      await settle(tester);
      expect(find.text('Obligatoire'), findsWidgets);
      await expectLater(capture, matchesGoldenFile('goldens/03_profil/complet_erreurs_${brightness.name}.png'));
    });
  }
}

class FakeDocuments extends DocumentsController {
  FakeDocuments(this.fixed);
  final DocumentsState fixed;
  @override
  Future<DocumentsState> build() async => fixed;
}

DocumentRequirement requirement(List<(String, String, String, bool)> options) => DocumentRequirement([
  for (final (type, fr, en, expiry) in options)
    DocumentOption(type: type, labelFr: fr, labelEn: en, asksExpiry: expiry),
]);

final sampleDocuments = DocumentsState(
  requirements: [
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
  ],
  profile: const RiderProfile(
    status: 'PENDING',
    vehicleType: 'MOTORBIKE',
    documents: [
      KycDocument(type: 'NATIONAL_ID_FRONT', status: 'APPROVED', rejectionReason: null),
      KycDocument(type: 'NATIONAL_ID_BACK', status: 'PENDING', rejectionReason: null),
      KycDocument(
        type: 'VEHICLE_REGISTRATION',
        status: 'REJECTED',
        rejectionReason: 'Photo floue : reprenez-la en pleine lumière.',
      ),
      KycDocument(type: 'CRIMINAL_RECORD', status: 'EXPIRED', rejectionReason: null),
    ],
    missingDocuments: [],
    emergencyContactName: null,
    emergencyContactPhone: null,
  ),
  uploads: const {'DRIVING_LICENSE': .62},
);

Widget documents() => ProviderScope(
  overrides: [
    keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
    documentsControllerProvider.overrideWith(() => FakeDocuments(sampleDocuments)),
  ],
  child: DocumentsScreen(onDone: () {}, onBack: () {}),
);

void documentsGoldens() {
  for (final variant in Variant.matrix) {
    goldenTest('04 pièces ${variant.name}', (tester) async {
      await pumpVariant(tester, variant, documents());
      await settle(tester);
      expect(tester.takeException(), isNull);
      await expectLater(capture, matchesGoldenFile('goldens/04_pieces/${variant.name}.png'));
    });
  }
  for (final brightness in Brightness.values) {
    goldenTest('04 pièces complet ${brightness.name}', (tester) async {
      await pumpVariant(
        tester,
        Variant(brightness, ScreenSize.regular, 1),
        documents(),
        surface: const Size(390, 1500),
      );
      await settle(tester);
      await expectLater(capture, matchesGoldenFile('goldens/04_pieces/complet_${brightness.name}.png'));
    });
  }
}
