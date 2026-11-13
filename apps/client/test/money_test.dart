import 'package:flutter_test/flutter_test.dart';
import 'package:tara_core/money/mobile_money_fees.dart';

/// Mêmes exemples que le serveur (mobile-money-fees.spec.ts) : l'app annonce ce qui sera demandé.
void main() {
  test('frais Mobile Money payés par le client', () {
    expect(mobileMoneyFee(1500, 600), 96);
    expect(mobileMoneyFee(6000, 600), 383);
    expect(mobileMoneyFee(10000, 600), 639);
    expect(mobileMoneyFee(1500, 0), 0);
  });

  test('frais de retrait sous le seuil gratuit, rien au-dessus', () {
    expect(withdrawalFee(10000, 250, 20000), 244);
    expect(withdrawalFee(4000, 250, 20000), 98);
    expect(withdrawalFee(20000, 250, 20000), 0);
    expect(withdrawalFee(10000, 0, 20000), 0);
  });
}
