import 'package:flutter_test/flutter_test.dart';
import 'package:tara_rider/design/format.dart';

void main() {
  test('montants : milliers séparés par une espace insécable, signe moins typographique', () {
    expect(formatAmount(0), '0');
    expect(formatAmount(950), '950');
    expect(formatAmount(12500), '12 500');
    expect(formatAmount(1250000), '1 250 000');
    expect(formatAmount(-3000), '−3 000');
  });

  test('distances arrondies, unité insécable', () {
    expect(formatDistance(847), '850 m');
    expect(formatDistance(2400), '2,4 km');
    expect(formatDistance(2400, decimalSeparator: '.'), '2.4 km');
    expect(formatDistance(12600), '13 km');
  });

  test('durées', () {
    expect(formatMinutes(const Duration(minutes: 12)), '12 min');
    expect(formatMinutes(const Duration(seconds: 20)), '1 min');
    expect(formatCountdown(const Duration(seconds: 42)), '0:42');
    expect(formatCountdown(const Duration(minutes: 2, seconds: 5)), '2:05');
    expect(formatOnline(45 * 60), '45\u00A0min');
    expect(formatOnline(2 * 3600 + 5 * 60), '2\u00A0h\u00A005');
  });
}
