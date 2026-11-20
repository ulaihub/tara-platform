import 'package:flutter_test/flutter_test.dart';
import 'package:tara_client/features/orders/order_row.dart';

void main() {
  test('lieu précis : repère puis quartier, sans répéter le quartier', () {
    expect(precisePlace('Collège des Nations', 'Bonapriso'), 'Collège des Nations, Bonapriso');
    expect(precisePlace('Rond-point Deïdo', 'Deïdo'), 'Rond-point Deïdo');
    expect(precisePlace('Carrefour Nkongmondo', null), 'Carrefour Nkongmondo');
    expect(precisePlace('  ', 'Akwa'), 'Akwa');
  });
}
