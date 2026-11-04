import 'package:tara_client/core/api/client_api.dart';
import 'package:tara_client/core/api/client_models.dart';
import 'package:tara_core/api/api_client.dart';
import 'package:tara_core/session/session_store.dart';

/// API expéditeur sans réseau : compte, nom et boutique enregistrés.
class FakeClientApi extends ClientApi {
  FakeClientApi() : super(ApiClient(baseUrl: 'http://test.invalid', store: SessionStore(MemoryKeyValueStore())));

  final names = <String>[];

  /// Commandes en cours (accueil) et portefeuille renvoyés.
  List<OrderSummary> active = [];
  List<OrderSummary> history = [];
  Wallet wallet0 = const Wallet(customerBalance: 0, merchantBalance: null, payoutSchedule: null);

  @override
  Future<List<OrderSummary>> orders({required String scope, int limit = 20}) async =>
      scope == 'active' ? active : history;

  @override
  Future<Wallet> wallet() async => wallet0;
  final merchants = <Map<String, String?>>[];

  @override
  Future<Me> me() async => const Me(
    id: '00000000-0000-4000-8000-0000000000aa',
    phone: '+237677123456',
    fullName: null,
    locale: 'FR',
    referralCode: 'TARA-7KQ2PM',
    merchant: null,
  );

  @override
  Future<void> updateName(String fullName) async => names.add(fullName);

  @override
  Future<Merchant> becomeMerchant({
    required String shopName,
    String? category,
    required String payoutPhone,
    required String payoutOperator,
    String? rccm,
    String? niu,
  }) async {
    merchants.add({
      'shopName': shopName,
      'category': category,
      'payoutPhone': payoutPhone,
      'payoutOperator': payoutOperator,
      'rccm': rccm,
      'niu': niu,
    });
    return Merchant(shopName: shopName, category: category, payoutPhone: payoutPhone, payoutOperator: payoutOperator);
  }
}
