import 'package:tara_rider/core/api/api_client.dart';
import 'package:tara_rider/core/api/api_exception.dart';
import 'package:tara_rider/core/api/models.dart';
import 'package:tara_rider/core/api/rider_api.dart';
import 'package:tara_rider/core/session/session_store.dart';

/// API livreur sans réseau pour les tests d'écrans : encaissement et portefeuille.
class FakeRiderApi extends RiderApi {
  FakeRiderApi() : super(ApiClient(baseUrl: 'http://test.invalid', store: SessionStore(MemoryKeyValueStore())));

  RiderWallet wallet0 = const RiderWallet(
    earnings: 42000,
    reserved: 12500,
    available: 29500,
    cashHeld: 0,
    cashLimit: 50000,
  );

  /// États successifs renvoyés par GET /collection (le dernier est répété).
  List<Collection> collections = [const Collection(total: 12500, complete: false, paymentId: 'p1')];
  final requests = <(String phone, String operator)>[];

  @override
  Future<RiderWallet> riderWallet() async => wallet0;

  /// Gains par période (GET /rider/earnings) et périodes demandées.
  final earningsByPeriod = <String, Earnings>{};
  final periods = <String>[];

  @override
  Future<Earnings> earnings(String period) async {
    periods.add(period);
    return earningsByPeriod[period]!;
  }

  /// Courses terminées (GET /rider/orders?scope=history).
  List<RiderOrder> finished = [];

  @override
  Future<List<RiderOrder>> history() async => finished;

  @override
  Future<Json> me() async => {'phone': '+237677123456'};

  /// Dépôts demandés, et états successifs du paiement (le dernier est répété).
  final deposits = <(int amount, String phone, String operator, String key)>[];
  List<String> paymentStatuses = ['PENDING'];

  @override
  Future<PaymentRequest> depositCash({
    required int amount,
    required String phone,
    required String operator,
    required String idempotencyKey,
  }) async {
    deposits.add((amount, phone, operator, idempotencyKey));
    return PaymentRequest(id: 'dep1', status: 'PENDING', amount: amount);
  }

  /// Recharges demandées ; [topUpErrors] : erreurs renvoyées d'abord, une par demande.
  final topUps = <(int amount, String phone, String operator, String key)>[];
  final topUpErrors = <ApiException>[];

  @override
  Future<PaymentRequest> topUp({
    required int amount,
    required String phone,
    required String operator,
    required String idempotencyKey,
  }) async {
    topUps.add((amount, phone, operator, idempotencyKey));
    if (topUpErrors.isNotEmpty) throw topUpErrors.removeAt(0);
    return PaymentRequest(id: 'top1', status: 'PENDING', amount: amount);
  }

  @override
  Future<PaymentRequest> payment(String id) async => PaymentRequest(
    id: id,
    status: paymentStatuses.length > 1 ? paymentStatuses.removeAt(0) : paymentStatuses.single,
    amount: 0,
  );

  @override
  Future<Collection> collectMobileMoney(String orderId, {required String phone, required String operator}) async {
    requests.add((phone, operator));
    return const Collection(total: 12500, complete: false, paymentId: 'p1', paymentStatus: 'PENDING');
  }

  @override
  Future<Collection> collection(String orderId) async =>
      collections.length > 1 ? collections.removeAt(0) : collections.single;
}
