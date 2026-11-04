/// Réglages fixés à la compilation (`--dart-define`).
abstract final class Env {
  /// Adresse de l'API. Par défaut, l'API locale vue depuis l'émulateur Android.
  static const apiUrl = String.fromEnvironment('TARA_API_URL', defaultValue: 'http://10.0.2.2:3000');

  /// Pages légales (conditions d'utilisation, confidentialité) ; vides : liens inactifs.
  static const termsUrl = String.fromEnvironment('TARA_TERMS_URL');
  static const privacyUrl = String.fromEnvironment('TARA_PRIVACY_URL');

  /// Version des conditions acceptées à la création du compte (consentement enregistré).
  static const termsVersion = '2026-11';
}
