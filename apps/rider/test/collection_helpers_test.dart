import 'package:flutter_test/flutter_test.dart';
import 'package:tara_rider/features/course/collection_screen.dart';

void main() {
  test('montants reçus proposés : l’exact, puis les trois multiples de 5 000 au-dessus', () {
    expect(receivedAmounts(12500), [12500, 15000, 20000, 25000]);
    expect(receivedAmounts(10000), [10000, 15000, 20000, 25000]);
    expect(receivedAmounts(1500), [1500, 5000, 10000, 15000]);
  });

  test('opérateur deviné d’après le numéro, sinon aucun', () {
    expect(guessOperator('677123456'), 'MTN');
    expect(guessOperator('652123456'), 'MTN');
    expect(guessOperator('682123456'), 'MTN');
    expect(guessOperator('699123456'), 'ORANGE');
    expect(guessOperator('656123456'), 'ORANGE');
    expect(guessOperator('688123456'), 'ORANGE');
    expect(guessOperator('622123456'), isNull);
    expect(guessOperator('69912'), isNull);
  });
}
