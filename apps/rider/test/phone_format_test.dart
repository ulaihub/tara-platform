import 'package:flutter_test/flutter_test.dart';
import 'package:tara_rider/features/common/phone_format.dart';

void main() {
  test('numéro camerounais : 9 chiffres commençant par 6', () {
    expect(isCameroonMobile('690123456'), isTrue);
    expect(isCameroonMobile('590123456'), isFalse);
    expect(isCameroonMobile('69012345'), isFalse);
  });

  test('affichage groupé, insécable', () {
    expect(displayPhone('+237690123456'), '+237 6 90 12 34 56');
    expect(displayPhone('690123456'), '6 90 12 34 56');
  });

  test('saisie : chiffres seulement, 9 au plus, groupés', () {
    final formatter = PhoneInputFormatter();
    final value = formatter.formatEditUpdate(TextEditingValue.empty, const TextEditingValue(text: '6-90 12a34 56 78'));
    expect(value.text, '6 90 12 34 56');
    expect(value.selection.baseOffset, value.text.length);
  });
}
