import 'package:flutter_test/flutter_test.dart';
import 'package:tara_core/session/session_store.dart';
import 'package:tara_rider/core/api/models.dart';
import 'package:tara_rider/core/course/call_journal.dart';

void main() {
  const policy = FailurePolicy();
  final t0 = DateTime(2026, 11, 3, 18, 42);

  group('appels exigés selon le motif', () {
    test('absent, injoignable, adresse introuvable : 2 appels à 5 min d’écart', () {
      for (final reason in ['RECIPIENT_ABSENT', 'RECIPIENT_UNREACHABLE', 'ADDRESS_NOT_FOUND']) {
        expect(policy.progress(reason, []), (missing: 2, readyAt: null));
      }
      expect(policy.progress('RECIPIENT_ABSENT', [t0]), (missing: 1, readyAt: DateTime(2026, 11, 3, 18, 47)));
      // Deux appels trop rapprochés : il en faut un troisième, après 18:47.
      expect(policy.progress('RECIPIENT_ABSENT', [t0, t0.add(const Duration(minutes: 2))]), (
        missing: 1,
        readyAt: DateTime(2026, 11, 3, 18, 47),
      ));
      expect(policy.progress('RECIPIENT_ABSENT', [t0.add(const Duration(minutes: 5)), t0]), (
        missing: 0,
        readyAt: null,
      ));
    });

    test('autre motif : un appel ; colis ou paiement refusé : aucun', () {
      expect(policy.progress('OTHER', []).missing, 1);
      expect(policy.progress('OTHER', [t0]).missing, 0);
      expect(policy.progress('REFUSED', []).missing, 0);
      expect(policy.progress('PAYMENT_REFUSED', []).missing, 0);
    });

    test('règles venues du serveur', () {
      final custom = FailurePolicy.fromJson({'minCalls': 3, 'callSpacingMinutes': 2.5, 'decisionTimeoutMinutes': 20});
      expect(custom.callsRequired('RECIPIENT_ABSENT'), 3);
      expect(custom.callSpacing, const Duration(seconds: 150));
      expect(custom.decisionTimeout, const Duration(minutes: 20));
    });
  });

  group('journal des appels', () {
    late MemoryKeyValueStore store;
    late DateTime clock;
    late List<String> dialed;

    CallJournal journal() => CallJournal(store: store, dial: (phone) async => dialed.add(phone), now: () => clock);

    setUp(() {
      store = MemoryKeyValueStore();
      clock = t0;
      dialed = [];
    });

    test('appel noté puis composé ; durée mesurée au retour dans l’app', () async {
      final calls = journal();
      await calls.call('o1', to: 'RECIPIENT', phone: '+237690000202');
      expect(dialed, ['+237690000202']);
      expect(calls.forOrder('o1').single.durationSeconds, isNull);

      clock = t0.add(const Duration(seconds: 32));
      await calls.resumed();
      expect(calls.forOrder('o1').single.durationSeconds, 32);
      expect(calls.forOrder('o1').single.toApi(), {
        'to': 'RECIPIENT',
        'at': t0.toUtc().toIso8601String(),
        'durationSeconds': 32,
      });
      // Retour dans l'app sans appel en cours : rien ne change.
      clock = t0.add(const Duration(minutes: 3));
      await calls.resumed();
      expect(calls.forOrder('o1').single.durationSeconds, 32);
    });

    test('gardé sur le téléphone ; seule la course en cours garde ses appels', () async {
      final first = journal();
      await first.call('o1', to: 'RECIPIENT', phone: '1');
      clock = t0.add(const Duration(minutes: 6));
      await first.call('o1', to: 'RECIPIENT', phone: '1');
      await first.call('o2', to: 'SENDER', phone: '2');

      final reopened = journal();
      await reopened.load();
      expect(reopened.recipientCalls('o1'), [t0, t0.add(const Duration(minutes: 6))]);
      await reopened.retainOnly('o1');
      expect(reopened.forOrder('o2'), isEmpty);
      await reopened.retainOnly(null);
      expect(reopened.forOrder('o1'), isEmpty);
    });
  });
}
