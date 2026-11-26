import 'package:tara_core/session/session_store.dart';

/// Code d'enlèvement d'une commande, gardé sur le téléphone de l'expéditeur (stockage
/// chiffré) pour le montrer dans le suivi jusqu'à l'enlèvement ; le serveur, lui, n'en
/// garde que l'empreinte.
class PickupCodes {
  const PickupCodes(this._store);
  final KeyValueStore _store;

  static String _key(String orderId) => 'tara.pickup-code.$orderId';

  Future<void> remember(String orderId, String code) => _store.write(_key(orderId), code);

  Future<String?> read(String orderId) => _store.read(_key(orderId));

  /// Colis enlevé (ou commande finie) : le code ne sert plus.
  Future<void> forget(String orderId) => _store.delete(_key(orderId));
}
