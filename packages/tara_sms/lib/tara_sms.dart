import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Code à [length] chiffres dans le texte d'un SMS de Tara : le premier nombre de cette
/// longueur (l'empreinte de l'app, en dernière ligne, vient après). Un autre SMS (Mobile
/// Money, opérateur…) ne donne rien : il ferait perdre un essai et bloquer le numéro.
String? codeInSms(String message, {int length = 6}) => message.toLowerCase().contains('tara')
    ? RegExp('(?<![0-9])[0-9]{$length}(?![0-9])').firstMatch(message)?.group(0)
    : null;

/// Lecture du code SMS sur Android (SMS Retriever de Google), sans permission de lecture
/// des SMS. Sur iOS et dans les tests, rien : le clavier propose déjà le code reçu.
class SmsCodeReader {
  const SmsCodeReader();

  static const _channel = MethodChannel('tara_sms');

  bool get _android => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Empreinte de l'app (11 caractères), à envoyer au serveur avec la demande de code : il
  /// l'ajoute au SMS s'il la connaît. Null hors Android.
  Future<String?> appHash() async {
    if (!_android) return null;
    try {
      return await _channel.invokeMethod<String>('appHash');
    } on Object {
      // Pas de module Android (tests, plateforme sans services Google) : pas de lecture.
      return null;
    }
  }

  /// Attend le SMS du code (5 minutes au plus) et renvoie le code, ou null (délai dépassé,
  /// refus, autre SMS). [autoRead] : le SMS porte l'empreinte de l'app, Android le remet
  /// sans rien demander ; sinon Android montre le SMS et demande « Autoriser ».
  Future<String?> waitForCode({required bool autoRead, int length = 6}) async {
    if (!_android) return null;
    try {
      final message = await _channel.invokeMethod<String>('listen', {'consent': !autoRead});
      return message == null ? null : codeInSms(message, length: length);
    } on Object {
      // Pas de module Android (tests, plateforme sans services Google) : pas de lecture.
      return null;
    }
  }

  /// Arrête l'attente (écran quitté, nouveau code demandé).
  Future<void> cancel() async {
    if (!_android) return;
    try {
      await _channel.invokeMethod<void>('cancel');
    } on Object {
      // Rien à arrêter.
    }
  }
}
