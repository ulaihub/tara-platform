import 'package:tara_core/api/api_client.dart';

import 'client_models.dart';

/// Services de l'API pour l'expéditeur : compte, mode marchand, réglages.
class ClientApi {
  ClientApi(this._api);

  final ApiClient _api;

  Future<Me> me() async => Me.fromJson(await _api.get('/me') as Json);

  /// Commandes de l'expéditeur, la plus récente d'abord : en cours (active) ou terminées
  /// (history).
  Future<List<OrderSummary>> orders({required String scope, int limit = 20}) async {
    final page = await _api.get('/orders', query: {'scope': scope, 'limit': limit}) as Json;
    return [for (final item in page['items']! as List<Object?>) OrderSummary.fromJson(item! as Json)];
  }

  /// Solde Tara de l'expéditeur et, pour un marchand, ventes encaissées à reverser.
  Future<Wallet> wallet() async => Wallet.fromJson(await _api.get('/me/wallet') as Json);

  /// Nom affiché aux livreurs et dans les SMS des destinataires.
  Future<void> updateName(String fullName) => _api.send('PATCH', '/me', body: {'fullName': fullName});

  /// Langue des SMS et notifications (choisie dans l'app).
  Future<void> updateLocale(String languageCode) =>
      _api.send('PATCH', '/me', body: {'locale': languageCode == 'en' ? 'EN' : 'FR'});

  /// Passage en mode marchand (A2) : boutique et numéro Mobile Money des reversements.
  Future<Merchant> becomeMerchant({
    required String shopName,
    String? category,
    required String payoutPhone,
    required String payoutOperator,
    String? rccm,
    String? niu,
  }) async => Merchant.fromJson(
    await _api.put(
      '/me/merchant',
      body: {
        'shopName': shopName,
        'category': ?category,
        'payoutPhone': payoutPhone,
        'payoutOperator': payoutOperator,
        'rccm': ?rccm,
        'niu': ?niu,
      },
    ) as Json,
  );
}
