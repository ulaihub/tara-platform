import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';
import 'package:local_auth_darwin/local_auth_darwin.dart';

/// Textes de la fenêtre du capteur, dans la langue de l'app.
class BiometricPrompt {
  const BiometricPrompt({required this.reason, required this.title, required this.cancel});

  /// Ce que l'empreinte confirme, ex. « Pour retirer 5 000 F ».
  final String reason;
  final String title;
  final String cancel;
}

/// Empreinte digitale ou visage du téléphone. L'empreinte elle-même reste dans le téléphone :
/// l'app sait seulement si la personne l'a confirmée.
abstract class Biometrics {
  /// Capteur présent et au moins une empreinte (ou un visage) enregistrée.
  Future<bool> available();

  /// Demande l'empreinte ; false si elle est refusée, annulée ou indisponible.
  Future<bool> confirm(BiometricPrompt prompt);
}

class DeviceBiometrics implements Biometrics {
  DeviceBiometrics([LocalAuthentication? auth]) : _auth = auth ?? LocalAuthentication();

  final LocalAuthentication _auth;

  @override
  Future<bool> available() async {
    try {
      return await _auth.canCheckBiometrics && (await _auth.getAvailableBiometrics()).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> confirm(BiometricPrompt prompt) async {
    try {
      return await _auth.authenticate(
        localizedReason: prompt.reason,
        // Pas de repli sur le code de verrouillage du téléphone : c'est le code secret Tara
        // qui le remplace.
        biometricOnly: true,
        persistAcrossBackgrounding: true,
        authMessages: [
          AndroidAuthMessages(signInTitle: prompt.title, cancelButton: prompt.cancel),
          IOSAuthMessages(cancelButton: prompt.cancel),
        ],
      );
    } catch (_) {
      return false;
    }
  }
}

/// Téléphone sans capteur, tests.
class NoBiometrics implements Biometrics {
  const NoBiometrics();
  @override
  Future<bool> available() async => false;
  @override
  Future<bool> confirm(BiometricPrompt prompt) async => false;
}
