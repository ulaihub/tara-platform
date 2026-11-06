import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tara_rider/core/api/api_exception.dart';
import 'package:tara_rider/core/safety/safety_alert.dart';

import 'helpers/harness.dart';
import 'screens_auth_golden_test.dart' show settle;
import 'screens_safety_golden_test.dart' show acknowledged, safetyAlert, sos;

void main() {
  Future<void> hold(WidgetTester tester, Duration duration) async {
    final gesture = await tester.startGesture(tester.getCenter(find.text('SOS')));
    for (var t = Duration.zero; t < duration; t += const Duration(milliseconds: 250)) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    await gesture.up();
    await settle(tester);
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text));
    await tester.tap(find.text(text));
    await settle(tester);
  }

  testWidgets('relâché avant 3 s : rien ne part', (tester) async {
    final sent = <PendingAlert>[];
    final safety = safetyAlert(
      send: (alert) async {
        sent.add(alert);
        return acknowledged;
      },
    );
    await pumpVariant(tester, Variant.matrix.first, sos(safety));
    await settle(tester);
    await hold(tester, const Duration(seconds: 2));
    expect(sent, isEmpty);
    expect(find.text('Besoin d’aide ?'), findsOneWidget);
  });

  testWidgets('maintenu 3 s : alerte envoyée avec la course ; Tara, police et secours en un geste', (tester) async {
    final sent = <PendingAlert>[];
    final launched = <Uri>[];
    final safety = safetyAlert(
      send: (alert) async {
        sent.add(alert);
        return acknowledged;
      },
    );
    await pumpVariant(tester, Variant.matrix.first, sos(safety, launched: launched));
    await settle(tester);
    await hold(tester, const Duration(milliseconds: 3250));

    expect(sent.single.orderId, '00000000-0000-4000-8000-000000000002');
    expect(find.text('Alerte envoyée'), findsOneWidget);
    expect(find.textContaining('Un agent Tara a pris en charge'), findsOneWidget);
    expect(find.text('Akwa'), findsOneWidget);

    await tapText(tester, 'Police · 117');
    await tapText(tester, 'Pompiers 118');
    await tapText(tester, 'SAMU 119');
    await tapText(tester, 'Support Tara');
    expect(launched.map((uri) => uri.toString()), ['tel:117', 'tel:118', 'tel:119', 'tel:+237640114064']);
  });

  testWidgets('sans réseau : SMS pré-rempli pour la ligne Tara, avec la position et la course', (tester) async {
    final launched = <Uri>[];
    final safety = safetyAlert(
      send: (_) async => throw const ApiException(code: ApiException.network, message: ''),
    );
    await pumpVariant(tester, Variant.matrix.first, sos(safety, launched: launched));
    await settle(tester);
    await hold(tester, const Duration(milliseconds: 3250));
    expect(find.text('Pas d’internet'), findsOneWidget);

    await tapText(tester, 'Envoyer l’alerte par SMS');
    final sms = launched.single;
    expect(sms.scheme, 'sms');
    expect(sms.path, '+237640114064');
    final body = Uri.decodeComponent(sms.query.substring('body='.length));
    expect(
      body,
      "SOS Tara : j'ai besoin d'aide. Position : https://maps.google.com/?q=4.05110,9.69420 Course TR-48213.",
    );
    await tester.pumpWidget(const SizedBox());
    safety.dispose();
  });

  testWidgets('annulation : retour à l’écran de départ ; fermer revient à l’écran précédent', (tester) async {
    final cancelled = <String>[];
    var closed = false;
    final safety = safetyAlert(
      cancel: (id) async {
        cancelled.add(id);
        return acknowledged;
      },
    );
    await safety.raise();
    await pumpVariant(tester, Variant.matrix.first, sos(safety, onClose: () => closed = true));
    await settle(tester);
    await tapText(tester, 'Annuler l’alerte');
    expect(cancelled, [acknowledged.id]);
    expect(find.text('Besoin d’aide ?'), findsOneWidget);

    await tester.ensureVisible(find.bySemanticsLabel('Fermer'));
    await tester.tap(find.bySemanticsLabel('Fermer'));
    expect(closed, isTrue);
  });
}
