import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tara_core/api/support_api.dart';
import 'package:tara_core/session/session_store.dart';
import 'package:tara_rider/app/providers.dart';
import 'package:tara_rider/core/api/models.dart';
import 'package:tara_rider/core/location/location_tracker.dart';
import 'package:tara_rider/core/location/online_controller.dart';
import 'package:tara_rider/features/account/account_screen.dart';
import 'package:tara_rider/features/account/close_account_screen.dart';
import 'package:tara_rider/features/account/emergency_contact_screen.dart';
import 'package:tara_rider/features/onboarding/documents_screen.dart';
import 'package:tara_test/fake_support.dart';
import 'package:tara_ui/app_settings.dart';
import 'package:tara_ui/feedback/tara_feedback.dart';
import 'package:tara_ui/tara_effects.dart';

import 'helpers/harness.dart';
import 'helpers/orders.dart';
import 'screens_account_golden_test.dart' show AccountHarness, accountProfile;
import 'screens_auth_golden_test.dart' show settle;

class _Auth extends AuthController {
  int logouts = 0;

  @override
  Future<AuthStatus> build() async => AuthStatus.signedIn;

  @override
  Future<void> logout() async {
    logouts++;
    state = const AsyncData(AuthStatus.signedOut);
  }
}

class _Positions implements PositionSource {
  @override
  Future<LocationAccess> ensureAccess() async => LocationAccess.granted;
  @override
  Future<GeoPoint?> current() async => GeoPoint(latitude: 4.05, longitude: 9.7, recordedAt: DateTime.utc(2026, 11, 4));
  @override
  Stream<GeoPoint> watch({
    required Duration interval,
    required String notificationTitle,
    required String notificationText,
  }) => const Stream.empty();
}

void main() {
  Future<void> show(WidgetTester tester, String text) async {
    await tester.scrollUntilVisible(find.text(text), 120, scrollable: find.byType(Scrollable).first);
    await settle(tester);
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    // Amené dans le haut de l'écran, loin de la barre d'onglets en verre.
    await Scrollable.ensureVisible(tester.element(find.text(text).last), alignment: .3);
    await tester.pump();
    // Défilement terminé : sinon le toucher arrête la liste au lieu d'atteindre le bouton.
    await settle(tester);
    await tester.tap(find.text(text).last);
    await settle(tester);
  }

  AppSettings settingsOf(WidgetTester tester) => AppSettingsScope.of(tester.element(find.byType(AccountScreen)));

  group('réglages gardés sur le téléphone', () {
    test('thème, langue, effets et transparence relus au démarrage suivant', () async {
      final store = MemoryKeyValueStore();
      final first = await AppSettings.load(store);
      first
        ..themeMode = ThemeMode.dark
        ..locale = const Locale('en');
      first.effects.preference = EffectsPreference.reduced;
      first.effects.glassLevel = GlassLevel.opaque;
      first.sounds = false;
      await Future<void>.delayed(Duration.zero);

      final next = await AppSettings.load(store);
      expect(next.sounds, isFalse);
      expect(next.themeMode, ThemeMode.dark);
      expect(next.locale, const Locale('en'));
      expect(next.effects.preference, EffectsPreference.reduced);
      expect(next.effects.glassLevel, GlassLevel.opaque);
      expect(next.languageCode(const Locale('fr')), 'en');
    });

    test('réglages illisibles : ceux du téléphone', () async {
      final store = MemoryKeyValueStore()..values['settings.display'] = '{pas du json';
      final settings = await AppSettings.load(store);
      expect(settings.themeMode, ThemeMode.system);
      expect(settings.effects.glassLevel, GlassLevel.balanced);
      expect(settings.sounds, isTrue);
      expect(settings.locale, isNull);
      expect(settings.languageCode(const Locale('en', 'CM')), 'en');
      expect(settings.languageCode(const Locale('de')), 'fr');
    });
  });

  testWidgets('affichage : thème et effets appliqués, langue envoyée au serveur', (tester) async {
    final harness = AccountHarness();
    await pumpVariant(tester, Variant.matrix.first, harness.screen());
    await settle(tester);
    // Réglages d'affichage amenés en haut de l'écran, au-dessus de la barre d'onglets.
    await show(tester, 'Clair');

    await tapText(tester, 'Clair');
    expect(settingsOf(tester).themeMode, ThemeMode.light);

    await tapText(tester, 'Réduites');
    expect(settingsOf(tester).effects.preference, EffectsPreference.reduced);

    await show(tester, 'Opaque');
    await tapText(tester, 'Opaque');
    expect(settingsOf(tester).effects.glassLevel, GlassLevel.opaque);
    await tapText(tester, 'Verre');
    expect(settingsOf(tester).effects.glassLevel, GlassLevel.clear);

    // La langue est dans « Langue et sons ».
    await show(tester, 'Langue et sons');
    await tapText(tester, 'Langue et sons');
    await tapText(tester, 'English');
    expect(settingsOf(tester).locale, const Locale('en'));
    expect(harness.api.locales, ['en']);
  });

  testWidgets('sons : coupés puis remis, un exemple se fait entendre', (tester) async {
    final harness = AccountHarness();
    await pumpVariant(tester, Variant.matrix.first, harness.screen());
    await settle(tester);
    await show(tester, 'Langue et sons');
    await tapText(tester, 'Langue et sons');

    await tapText(tester, 'Sons');
    expect(settingsOf(tester).sounds, isFalse);
    final context = tester.element(find.byType(AccountScreen));
    TaraFeedback.play(context, TaraSound.delivered);
    expect(sounds.played, isEmpty);

    await tapText(tester, 'Sons');
    expect(settingsOf(tester).sounds, isTrue);
    expect(sounds.played, [TaraSound.received]);
  });

  testWidgets('pièce refusée : signalée avec son motif, renvoyée depuis le profil', (tester) async {
    await pumpVariant(tester, Variant.matrix.first, AccountHarness().screen());
    await settle(tester);
    expect(find.text('1 pièce à renvoyer'), findsOneWidget);
    expect(find.text('Carte grise · Refusée'), findsOneWidget);

    await tapText(tester, 'Renvoyer');
    expect(find.byType(DocumentsScreen), findsOneWidget);
    expect(find.text('Photo floue : reprenez-la en pleine lumière.'), findsOneWidget);
    // La pièce à renvoyer d'abord.
    final cards = tester.getTopLeft(find.text('Carte grise')).dy;
    expect(cards, lessThan(tester.getTopLeft(find.text('CNI (recto)')).dy));

    await tapText(tester, 'Fermer');
    expect(find.byType(DocumentsScreen), findsNothing);
  });

  testWidgets('contact d’urgence : numéro vérifié, enregistré, affiché', (tester) async {
    final harness = AccountHarness(contactName: null);
    harness.api.profileAfter = (name, phone) => accountProfile(contactName: name);
    await pumpVariant(tester, Variant.matrix.first, harness.screen());
    await settle(tester);
    expect(find.text('Prévenu automatiquement si vous déclenchez une alerte.'), findsOneWidget);

    await tapText(tester, 'Contact d’urgence');
    expect(find.byType(EmergencyContactScreen), findsOneWidget);
    expect(find.text('Retirer ce contact'), findsNothing);
    await tester.enterText(find.byType(EditableText).at(0), 'Marie Ngo');
    await tester.enterText(find.byType(EditableText).at(1), '6123');
    await tapText(tester, 'Enregistrer');
    expect(find.text('Numéro de mobile camerounais à 9 chiffres, commençant par 6.'), findsOneWidget);
    expect(harness.api.contacts, isEmpty);

    await tester.enterText(find.byType(EditableText).at(1), '699112233');
    await tapText(tester, 'Enregistrer');
    expect(harness.api.contacts.single, ('Marie Ngo', '+237699112233'));
    expect(find.byType(EmergencyContactScreen), findsNothing);
    expect(find.text('Marie Ngo · 6 99 •• •• 33'), findsOneWidget);
  });

  testWidgets('déconnexion : confirmée, hors ligne d’abord', (tester) async {
    final harness = AccountHarness();
    final auth = _Auth();
    var offline = 0;
    final online = OnlineController(
      positions: _Positions(),
      setPresence: ({required online, required position}) async {
        if (!online) offline++;
        return Presence(online: online, blockers: const []);
      },
      sendPosition: (_) async {},
    );
    await online.goOnline();
    await pumpVariant(
      tester,
      Variant.matrix.first,
      harness.screen(
        extra: [authControllerProvider.overrideWith(() => auth), onlineControllerProvider.overrideWithValue(online)],
      ),
    );
    await settle(tester);
    await show(tester, 'Se déconnecter');
    await tapText(tester, 'Se déconnecter');
    expect(
      find.text('Vous ne recevrez plus de courses sur ce téléphone jusqu’à votre prochaine connexion.'),
      findsOneWidget,
    );
    expect(auth.logouts, 0);

    await tapText(tester, 'Annuler');
    expect(
      find.text('Vous ne recevrez plus de courses sur ce téléphone jusqu’à votre prochaine connexion.'),
      findsNothing,
    );

    await tapText(tester, 'Se déconnecter');
    await tapText(tester, 'Se déconnecter');
    // L'arrêt du suivi de position se termine hors du temps simulé du test.
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await settle(tester);
    expect(offline, 1);
    expect(auth.logouts, 1);
  });

  testWidgets('déconnexion refusée pendant une course', (tester) async {
    final harness = AccountHarness();
    await harness.active.start(order(status: 'IN_DELIVERY'));
    final auth = _Auth();
    await pumpVariant(
      tester,
      Variant.matrix.first,
      harness.screen(extra: [authControllerProvider.overrideWith(() => auth)]),
    );
    await settle(tester);
    await show(tester, 'Terminez votre course avant de vous déconnecter.');
    await tester.tap(find.text('Se déconnecter'), warnIfMissed: false);
    await settle(tester);
    expect(auth.logouts, 0);
  });

  testWidgets('télécharger mes données : copie en fichier JSON, par la feuille de partage', (tester) async {
    final harness = AccountHarness();
    final shared = <(String name, String mimeType, Object? data)>[];
    await pumpVariant(
      tester,
      Variant.matrix.first,
      harness.screen(
        extra: [
          shareFileProvider.overrideWithValue((bytes, name, mimeType, text) async {
            shared.add((name, mimeType, jsonDecode(utf8.decode(bytes))));
          }),
        ],
      ),
    );
    await settle(tester);
    await show(tester, 'Télécharger mes données');
    await tapText(tester, 'Télécharger mes données');
    expect(harness.api.exports, 1);
    expect(shared.single.$1, matches(RegExp(r'^tara-donnees-\d{4}-\d{2}-\d{2}\.json$')));
    expect(shared.single.$2, 'application/json');
    expect((shared.single.$3! as Map)['user'], {'phone': '+237677123456', 'fullName': 'Awa Ngono'});
  });

  testWidgets('fermer mon compte : bloqué tant qu’il reste de l’argent, puis demandé au support', (tester) async {
    final harness = AccountHarness();
    harness.api.wallet0 = const RiderWallet(earnings: 2000, available: 2000, cashHeld: 0, cashLimit: 25000);
    final support = FakeSupportBackend();
    await pumpVariant(
      tester,
      Variant.matrix.first,
      harness.screen(extra: [supportBackendProvider.overrideWithValue(support)]),
    );
    await settle(tester);
    await show(tester, 'Fermer mon compte');
    await tapText(tester, 'Fermer mon compte');
    expect(find.byType(CloseAccountScreen), findsOneWidget);
    expect(
      find.text('Il vous reste 2\u00a0000\u00a0F : retirez-les d’abord vers votre Mobile Money (onglet Activité).'),
      findsOneWidget,
    );
    await tester.tap(find.text('Demander la fermeture'), warnIfMissed: false);
    await settle(tester);
    expect(support.opened, isEmpty);

    // Solde retiré : la demande part au service client.
    harness.api.wallet0 = const RiderWallet(earnings: 0, available: 0, cashHeld: 0, cashLimit: 25000);
    await tester.tap(find.bySemanticsLabel('Retour').last);
    await settle(tester);
    await tapText(tester, 'Fermer mon compte');
    await tapText(tester, 'Demander la fermeture');
    expect(support.opened.single.category, SupportCategory.other);
    expect(support.opened.single.subject, 'Fermeture de mon compte livreur');
    expect(find.text('Demande envoyée. L’équipe Tara vous répond dans « Écrire au service client ».'), findsOneWidget);
    await tapText(tester, 'Fermer');
    expect(find.byType(CloseAccountScreen), findsNothing);
  });
}
