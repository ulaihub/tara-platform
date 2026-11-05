import '../session/session_store.dart';
import 'api_client.dart';
import 'models.dart';

/// Conditions d'utilisation et confidentialité : textes en vigueur et acceptation signée
/// par un code SMS. [app] : `client` (expéditeurs) ou `rider` (livreurs).
class LegalApi {
  LegalApi(this._api, this._store, {required this.app});

  final ApiClient _api;
  final SessionStore _store;
  final String app;

  /// Conditions propres à l'app ; la politique de confidentialité vaut pour toutes.
  String get termsDocument => app == 'rider' ? 'livreurs' : 'expediteurs';
  static const privacyDocument = 'confidentialite';

  /// Texte complet, lisible sans compte (inscription).
  Future<LegalDocument> document(String name) async =>
      LegalDocument.fromJson(await _api.get('/legal/$name', auth: false) as Json);

  /// Conditions de l'app puis politique de confidentialité, à afficher pour accepter.
  Future<List<LegalDocument>> appDocuments() async =>
      Future.wait([document(termsDocument), document(privacyDocument)]);

  Future<TermsStatus> status() async =>
      TermsStatus.fromJson(await _api.get('/me/terms', query: {'app': app}) as Json);

  /// Code SMS qui signe l'acceptation d'une nouvelle version.
  Future<OtpChallenge> requestCode() async => OtpChallenge.fromJson(await _api.post('/me/terms/code') as Json);

  /// Signature : versions affichées (refusées si elles ne sont plus en vigueur) et code reçu.
  Future<void> accept({
    required String challengeId,
    required String code,
    required Map<String, String> versions,
  }) async {
    await _api.send(
      'POST',
      '/me/terms',
      query: {'app': app},
      body: {
        'challengeId': challengeId,
        'code': code,
        'versions': versions,
        'installationId': await _store.installationId(),
      },
    );
  }
}
