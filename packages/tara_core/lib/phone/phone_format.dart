import 'package:flutter/services.dart';

/// Numéro mobile camerounais : 9 chiffres commençant par 6 (sans l'indicatif).
bool isCameroonMobile(String digits) => RegExp(r'^6\d{8}$').hasMatch(digits);

/// Chiffres seuls d'une saisie (« 6 90 00-00 00 » → « 690000000 »).
String digitsOf(String input) => input.replaceAll(RegExp(r'\D'), '');

/// Affichage groupé : « 6 90 00 00 00 », avec l'indicatif s'il est fourni. Espaces
/// insécables : un numéro n'est jamais coupé en fin de ligne.
String displayPhone(String phone) {
  var digits = digitsOf(phone);
  var prefix = '';
  if (digits.length == 12 && digits.startsWith('237')) {
    prefix = '+237\u00A0';
    digits = digits.substring(3);
  }
  if (digits.length != 9) return phone;
  const nb = '\u00A0';
  return '$prefix${digits[0]}$nb${digits.substring(1, 3)}$nb${digits.substring(3, 5)}$nb${digits.substring(5, 7)}$nb${digits.substring(7)}';
}

/// Saisie d'un numéro : chiffres seulement, 9 au plus, groupés à l'affichage
/// (« 6 90 00 00 00 »), curseur gardé en fin de saisie.
class PhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = digitsOf(newValue.text);
    final kept = digits.length > 9 ? digits.substring(0, 9) : digits;
    final buffer = StringBuffer();
    for (var i = 0; i < kept.length; i++) {
      if (i == 1 || i == 3 || i == 5 || i == 7) buffer.write(' ');
      buffer.write(kept[i]);
    }
    final text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}

/// Opérateur deviné d'après le numéro camerounais (modifiable par l'utilisateur) : MTN pour
/// 67, 650-654 et 680-684 ; Orange pour 69, 655-659 et 685-689.
String? guessOperator(String nationalDigits) {
  if (!isCameroonMobile(nationalDigits)) return null;
  final second = nationalDigits[1];
  final third = int.parse(nationalDigits[2]);
  return switch (second) {
    '7' => 'MTN',
    '9' => 'ORANGE',
    '5' || '8' => third <= 4 ? 'MTN' : 'ORANGE',
    _ => null,
  };
}
