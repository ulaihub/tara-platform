import 'package:tara_core/codes/pickup_qr.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('le QR porte la référence et le code, lu seulement pour la bonne course', () {
    final qr = pickupQrPayload('TR-48301', '4821');
    expect(qr, 'TARA:PK:TR-48301:4821');
    expect(pickupCodeFromQr(qr, reference: 'TR-48301'), '4821');
    expect(pickupCodeFromQr(' $qr\n', reference: 'TR-48301'), '4821');
    // Autre course, reçu, QR quelconque, code mal formé : rien.
    expect(pickupCodeFromQr(qr, reference: 'TR-50000'), isNull);
    expect(isPickupQr(qr), isTrue);
    expect(pickupCodeFromQr('https://tara.cm/r/TR-48301K-4F8M2XQA', reference: 'TR-48301'), isNull);
    expect(isPickupQr('https://tara.cm/r/TR-48301K-4F8M2XQA'), isFalse);
    expect(pickupCodeFromQr('TARA:PK:TR-48301:48a1', reference: 'TR-48301'), isNull);
    expect(pickupCodeFromQr('TARA:PK:4821', reference: 'TR-48301'), isNull);
  });
}
