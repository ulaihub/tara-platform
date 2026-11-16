import '../session/session_store.dart';
import 'api_client.dart';
import 'models.dart';

/// Conditions d'utilisation et confidentialité : textes en vigueur et acceptation par
/// l'utilisateur connecté. [app] : `client` (expéditeurs) ou `rider` (livreurs).
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
  Future<List<LegalDocument>> appDocuments() async => Future.wait([document(termsDocument), document(privacyDocument)]);

  Future<TermsStatus> status() async => TermsStatus.fromJson(await _api.get('/me/terms', query: {'app': app}) as Json);

  /// Acceptation d'une nouvelle version : textes lus, case cochée ; la session suffit.
  /// [versions] : celles affichées (refusées si elles ne sont plus en vigueur).
  Future<void> accept({required Map<String, String> versions}) async {
    await _api.send(
      'POST',
      '/me/terms',
      query: {'app': app},
      body: {'versions': versions, 'installationId': await _store.installationId()},
    );
  }
}
