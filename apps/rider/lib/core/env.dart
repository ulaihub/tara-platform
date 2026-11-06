/// Réglages fixés à la compilation (`--dart-define`).
abstract final class Env {
  /// Adresse de l'API. Par défaut, l'API locale vue depuis l'émulateur Android.
  static const apiUrl = String.fromEnvironment('TARA_API_URL', defaultValue: 'http://10.0.2.2:3000');
}
