import 'package:flutter/widgets.dart';

/// Couleurs de véhicule proposées au livreur (même liste que le serveur), avec la teinte
/// de la pastille montrée à côté du nom.
const vehicleColors = <String, Color>{
  'BLACK': Color(0xFF1B1B1F),
  'RED': Color(0xFFD62B2B),
  'BLUE': Color(0xFF2357C9),
  'WHITE': Color(0xFFF4F4F2),
  'GREY': Color(0xFF8C8F96),
  'GREEN': Color(0xFF2E8B4E),
  'YELLOW': Color(0xFFF2C230),
  'ORANGE': Color(0xFFF07A1E),
  'BROWN': Color(0xFF7A4B2A),
  'VIOLET': Color(0xFF7446B8),
};

const _colorNames = {
  'fr': {
    'BLACK': 'Noire',
    'RED': 'Rouge',
    'BLUE': 'Bleue',
    'WHITE': 'Blanche',
    'GREY': 'Grise',
    'GREEN': 'Verte',
    'YELLOW': 'Jaune',
    'ORANGE': 'Orange',
    'BROWN': 'Marron',
    'VIOLET': 'Violette',
  },
  'en': {
    'BLACK': 'Black',
    'RED': 'Red',
    'BLUE': 'Blue',
    'WHITE': 'White',
    'GREY': 'Grey',
    'GREEN': 'Green',
    'YELLOW': 'Yellow',
    'ORANGE': 'Orange',
    'BROWN': 'Brown',
    'VIOLET': 'Purple',
  },
};

/// Marques courantes au Cameroun (même liste que le serveur).
const vehicleBrands = [
  'NANFANG',
  'HAOJUE',
  'SANYA',
  'LIFAN',
  'DAYUN',
  'JIALING',
  'KYMCO',
  'HONDA',
  'YAMAHA',
  'SUZUKI',
  'TVS',
  'BAJAJ',
  'OTHER',
];

/// « Rouge », « Red »…
String vehicleColorName(String code, Locale locale) =>
    (_colorNames[locale.languageCode] ?? _colorNames['fr']!)[code] ?? code;

/// « Nanfang », « TVS » ; « Autre » pour OTHER.
String vehicleBrandName(String code, Locale locale) {
  if (code == 'OTHER') return locale.languageCode == 'en' ? 'Other' : 'Autre';
  if (code.length <= 3) return code;
  return code[0] + code.substring(1).toLowerCase();
}
