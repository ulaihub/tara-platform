import 'package:tara_core/phone/phone_format.dart';

/// Ce que Tara a compris d'une ligne collée : un client, son numéro, son quartier et le
/// montant à encaisser. Lu sur le téléphone, sans rien envoyer.
class ParsedLine {
  const ParsedLine({
    required this.source,
    required this.name,
    required this.phone,
    required this.hint,
    required this.neighborhood,
    required this.amount,
    required this.problem,
    this.rawPhone,
  });

  /// La ligne telle qu'elle a été collée.
  final String source;
  final String name;

  /// Numéro national à 9 chiffres (6XXXXXXXX), null s'il manque ou est incomplet.
  final String? phone;

  /// Chiffres d'un numéro trop court (« 69912 »), pour le montrer à corriger.
  final String? rawPhone;

  /// Le reste de la ligne : quartier, repère (« Bonapriso pharmacie »).
  final String hint;

  /// Quartier connu reconnu dans [hint], écrit comme Tara l'écrit (« Deïdo »).
  final String? neighborhood;

  /// Montant à encaisser auprès du client, 0 s'il n'y en a pas.
  final int amount;

  final LineProblem? problem;

  bool get ok => problem == null;
}

enum LineProblem { nameMissing, phoneMissing, phoneIncomplete }

/// Montant le plus haut à encaisser pour un colis (G5) : au-delà, ce n'est pas un montant.
const _maxAmount = 500000;

// Numéro camerounais, avec ou sans indicatif, chiffres séparés ou non par des espaces,
// points ou tirets : « 690112233 », « 6 99 88 77 66 », « +237 690-55-44-33 ».
final _phone = RegExp(r'(?:(?:\+|00)?237[\s.\-]*)?6(?:[\s.\-]*\d){8}(?!\d)');
// Début de numéro trop court : un 6 suivi de 3 à 7 chiffres.
final _shortPhone = RegExp(r'(?<!\d)6\d{3,7}(?!\d)');
// Montant : « 12500 », « 12 500 », « 12.500 », « 12500F », « 15 000 FCFA », « 15k ».
final _amount = RegExp(
  r'(?<![\d.])(\d{1,3}(?:[ .  ]\d{3})+|\d{3,6})\s*(k|K|f|F|fr|FR|frs|FCFA|fcfa|cfa|CFA|xaf|XAF)?(?![\d])',
);
final _kilo = RegExp(r'(?<![\d.])(\d{1,3})\s*[kK](?![a-zA-Z\d])');
// Horodatage d'un message WhatsApp transféré : « [17/11 09:12] » ou « 17/11/2026 09:12 - ».
final _whatsappStamp = RegExp(r'^\s*\[?\d{1,2}/\d{1,2}(?:/\d{2,4})?,?\s+\d{1,2}:\d{2}\]?\s*(?:-\s*)?');

/// Lit une liste collée (WhatsApp, notes) : une ligne par client. Les lignes vides sont
/// ignorées ; au plus [limit] lignes sont lues. [neighborhoods] : quartiers connus de Tara,
/// pour écrire le quartier comme il faut.
List<ParsedLine> parseList(String text, {List<String> neighborhoods = const [], int limit = 100}) {
  final lines = text
      .split(RegExp(r'\r?\n'))
      .map((line) => line.replaceFirst(_whatsappStamp, '').trim())
      .where((line) => line.isNotEmpty);
  return [for (final line in lines.take(limit)) parseLine(line, neighborhoods: neighborhoods)];
}

ParsedLine parseLine(String source, {List<String> neighborhoods = const []}) {
  var rest = source;
  String? phone;
  String? rawPhone;
  var nameText = '';

  final match = _phone.firstMatch(rest);
  if (match != null) {
    final digits = digitsOf(match.group(0)!);
    phone = digits.substring(digits.length - 9);
    nameText = rest.substring(0, match.start);
    rest = rest.substring(match.end);
  } else {
    final short = _shortPhone.firstMatch(rest);
    if (short != null) {
      rawPhone = short.group(0);
      nameText = rest.substring(0, short.start);
      rest = rest.substring(short.end);
    }
  }

  // Montant : le dernier nombre de la ligne (hors numéro), dans les limites d'un colis.
  var amount = 0;
  final kilo = _kilo.allMatches(rest).lastOrNull;
  final plain = _amount.allMatches(rest).where((m) {
    final value = int.parse(digitsOf(m.group(1)!));
    return value >= 100 && value <= _maxAmount;
  }).lastOrNull;
  if (kilo != null && (plain == null || kilo.start > plain.start)) {
    amount = int.parse(kilo.group(1)!) * 1000;
    rest = rest.replaceRange(kilo.start, kilo.end, ' ');
  } else if (plain != null) {
    amount = int.parse(digitsOf(plain.group(1)!));
    rest = rest.replaceRange(plain.start, plain.end, ' ');
  }
  if (amount > _maxAmount) amount = 0;

  // Nom : avant le numéro ; si le numéro vient en premier, le premier mot qui suit.
  var name = _clean(nameText);
  var hint = _clean(rest);
  if (phone == null && rawPhone == null) {
    // Pas de numéro du tout : le début de la ligne est le nom, la suite le quartier.
    final words = hint.split(' ');
    name = words.take(2).join(' ');
    hint = words.skip(2).join(' ');
  } else if (name.isEmpty && hint.isNotEmpty) {
    final words = hint.split(' ');
    name = words.first;
    hint = words.skip(1).join(' ');
  }
  if (!RegExp(r'\p{L}', unicode: true).hasMatch(name)) name = '';

  final problem = phone == null
      ? (rawPhone == null ? LineProblem.phoneMissing : LineProblem.phoneIncomplete)
      : name.length < 2
      ? LineProblem.nameMissing
      : null;
  return ParsedLine(
    source: source,
    name: _capitalize(name),
    phone: phone,
    rawPhone: rawPhone,
    hint: hint,
    neighborhood: matchNeighborhood(hint, neighborhoods),
    amount: amount,
    problem: problem,
  );
}

/// Quartier connu nommé dans [hint] (sans tenir compte des accents ni des majuscules) :
/// « deido immeuble bleu » → « Deïdo ».
String? matchNeighborhood(String hint, List<String> neighborhoods) {
  if (hint.isEmpty || neighborhoods.isEmpty) return null;
  final words = _fold(hint).split(RegExp(r'[^a-z0-9]+')).where((w) => w.isNotEmpty).toList();
  String? best;
  var bestLength = 0;
  for (final name in neighborhoods) {
    final parts = _fold(name).split(RegExp(r'[^a-z0-9]+')).where((w) => w.isNotEmpty).toList();
    if (parts.isEmpty) continue;
    for (var i = 0; i + parts.length <= words.length; i++) {
      var same = true;
      for (var j = 0; j < parts.length; j++) {
        if (words[i + j] != parts[j]) {
          same = false;
          break;
        }
      }
      if (same && parts.join().length > bestLength) {
        best = name;
        bestLength = parts.join().length;
      }
    }
  }
  return best;
}

String _clean(String text) => text.replaceAll(RegExp(r'[,;:|/\\*•\-–—_]+'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();

String _capitalize(String name) => name
    .split(' ')
    .where((word) => word.isNotEmpty)
    .map((word) => word.length == 1 ? word.toUpperCase() : '${word[0].toUpperCase()}${word.substring(1)}')
    .join(' ');

const _accents = {
  'à': 'a', 'â': 'a', 'ä': 'a', 'á': 'a', 'ç': 'c', 'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e', //
  'î': 'i', 'ï': 'i', 'í': 'i', 'ô': 'o', 'ö': 'o', 'ó': 'o', 'ù': 'u', 'û': 'u', 'ü': 'u', 'ú': 'u',
};

String _fold(String text) => text.toLowerCase().split('').map((ch) => _accents[ch] ?? ch).join();
