import 'package:tara_rider/core/api/api_client.dart';
import 'package:tara_rider/core/api/models.dart';
import 'package:tara_rider/core/api/rider_api.dart';
import 'package:tara_rider/core/session/session_store.dart';

/// API livreur sans réseau pour les tests d'écrans : encaissement et portefeuille.
class FakeRiderApi extends RiderApi {
  FakeRiderApi() : super(ApiClient(baseUrl: 'http://test.invalid', store: SessionStore(MemoryKeyValueStore())));

  RiderWallet wallet0 = const RiderWallet(earnings: 9000, cashHeld: 37500, cashLimit: 60000);

  /// États successifs renvoyés par GET /collection (le dernier est répété).
  List<Collection> collections = [const Collection(total: 12500, complete: false, paymentId: 'p1')];
  final requests = <(String phone, String operator)>[];

  @override
  Future<RiderWallet> riderWallet() async => wallet0;

  @override
  Future<Collection> collectMobileMoney(String orderId, {required String phone, required String operator}) async {
    requests.add((phone, operator));
    return const Collection(total: 12500, complete: false, paymentId: 'p1', paymentStatus: 'PENDING');
  }

  @override
  Future<Collection> collection(String orderId) async =>
      collections.length > 1 ? collections.removeAt(0) : collections.single;
}
