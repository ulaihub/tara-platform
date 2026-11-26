/// QR du code d'enlèvement : l'app expéditeur l'affiche, l'app livreur le lit. Il porte la
/// référence de la commande avec le code, pour qu'un QR d'une autre course (ou le QR d'un
/// reçu) soit refusé tout de suite au lieu de compter comme un essai raté.
library;

const _prefix = 'TARA:PK:';

/// « TARA:PK:TR-48301:4821 ».
String pickupQrPayload(String reference, String code) => '$_prefix$reference:$code';

/// Code lu dans le QR s'il est bien un code d'enlèvement pour [reference] ; null sinon
/// (autre course, reçu, QR quelconque).
String? pickupCodeFromQr(String raw, {required String reference}) {
  final text = raw.trim();
  if (!text.startsWith(_prefix)) return null;
  final rest = text.substring(_prefix.length);
  final split = rest.lastIndexOf(':');
  if (split <= 0) return null;
  final ref = rest.substring(0, split);
  final code = rest.substring(split + 1);
  if (ref != reference || !RegExp(r'^\d{4}$').hasMatch(code)) return null;
  return code;
}

/// Le QR est-il un code d'enlèvement Tara, même d'une autre course ?
bool isPickupQr(String raw) => raw.trim().startsWith(_prefix);
