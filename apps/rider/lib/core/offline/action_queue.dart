import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../api/api_exception.dart';
import '../api/models.dart';
import '../session/session_store.dart';

/// Action d'une course faite sur le téléphone, envoyée dès que le réseau le permet (E7).
@immutable
class QueuedAction {
  const QueuedAction({
    required this.id,
    required this.orderId,
    required this.kind,
    required this.path,
    required this.body,
    required this.createdAt,
    this.photoPath,
    this.failureCode,
    this.failureMessage,
  });

  factory QueuedAction.fromJson(Json json) => QueuedAction(
    id: json['id']! as String,
    orderId: json['orderId']! as String,
    kind: json['kind']! as String,
    path: json['path']! as String,
    body: Map<String, Object?>.from(json['body']! as Map),
    createdAt: DateTime.parse(json['createdAt']! as String),
    photoPath: json['photoPath'] as String?,
    failureCode: json['failureCode'] as String?,
    failureMessage: json['failureMessage'] as String?,
  );

  /// Identifiant unique, envoyé comme `clientEventId` : le serveur ignore un rejeu.
  final String id;
  final String orderId;

  /// pickup, depart, collect, deliver, fail, retry, return.
  final String kind;
  final String path;
  final Json body;
  final DateTime createdAt;

  /// Photo de preuve encore sur le téléphone ; envoyée avant l'action.
  final String? photoPath;

  /// Refus du serveur (code invalide, statut changé) : l'action attend le livreur ou le support.
  final String? failureCode;
  final String? failureMessage;

  bool get failed => failureCode != null;

  QueuedAction copyWith({
    Json? body,
    String? photoPath,
    bool clearPhoto = false,
    String? failureCode,
    String? failureMessage,
  }) => QueuedAction(
    id: id,
    orderId: orderId,
    kind: kind,
    path: path,
    body: body ?? this.body,
    createdAt: createdAt,
    photoPath: clearPhoto ? null : (photoPath ?? this.photoPath),
    failureCode: failureCode ?? this.failureCode,
    failureMessage: failureMessage ?? this.failureMessage,
  );

  Json toJson() => {
    'id': id,
    'orderId': orderId,
    'kind': kind,
    'path': path,
    'body': body,
    'createdAt': createdAt.toIso8601String(),
    'photoPath': ?photoPath,
    'failureCode': ?failureCode,
    'failureMessage': ?failureMessage,
  };
}

/// Envoi d'une action au serveur ; renvoie la réponse (course mise à jour).
typedef SendAction = Future<Object?> Function(String path, Json body);

/// Envoi d'une photo de preuve ; renvoie sa clé.
typedef UploadPhoto = Future<String> Function(String filePath);

/// File persistante des actions de course (stockage chiffré du téléphone). Les actions
/// partent dans l'ordre où elles ont été faites ; une action refusée bloque les suivantes
/// de la même course, jamais celles des autres courses. Chaque action porte son heure
/// réelle (`occurredAt`) et un identifiant qui rend tout renvoi sans effet.
class ActionQueue extends ChangeNotifier {
  ActionQueue({required this.store, required this.send, required this.upload, this.deletePhoto = _deleteFile});

  static const _key = 'tara.action-queue';

  /// Stockage chiffré du téléphone.
  final KeyValueStore store;
  final SendAction send;
  final UploadPhoto upload;
  final Future<void> Function(String path) deletePhoto;

  List<QueuedAction> _items = const [];
  bool _loaded = false;
  Future<void>? _flushing;

  List<QueuedAction> get items => _items;
  int get pendingCount => _items.where((item) => !item.failed).length;
  List<QueuedAction> get failures => _items.where((item) => item.failed).toList();

  /// Actions encore en attente pour une course (affichage « en attente d'envoi »).
  List<QueuedAction> forOrder(String orderId) => _items.where((item) => item.orderId == orderId).toList();

  Future<void> load() async {
    if (_loaded) return;
    final raw = await store.read(_key);
    _items = raw == null
        ? const []
        : [for (final item in jsonDecode(raw) as List<Object?>) QueuedAction.fromJson(item! as Json)];
    _loaded = true;
    notifyListeners();
  }

  Future<void> _save() async {
    await store.write(_key, jsonEncode([for (final item in _items) item.toJson()]));
    notifyListeners();
  }

  /// Ajoute une action (heure et identifiant fixés maintenant) puis tente l'envoi.
  Future<QueuedAction> enqueue({
    required String orderId,
    required String kind,
    required Json body,
    String? photoPath,
    DateTime? now,
  }) async {
    await load();
    final id = _uuidV4();
    final action = QueuedAction(
      id: id,
      orderId: orderId,
      kind: kind,
      path: '/rider/orders/$orderId/$kind',
      body: {...body, 'clientEventId': id, 'occurredAt': isoUtc(now ?? DateTime.now())},
      createdAt: now ?? DateTime.now(),
      photoPath: photoPath,
    );
    _items = [..._items, action];
    await _save();
    unawaited(flush());
    return action;
  }

  /// Envoie ce qui peut l'être. Un seul envoi à la fois ; sans réseau, on s'arrête et on
  /// réessaiera au prochain déclencheur (retour du réseau, minuterie, retour dans l'app).
  Future<void> flush() {
    final running = _flushing;
    if (running != null) return running;
    final started = _flush().whenComplete(() {
      _flushing = null;
      notifyListeners();
    });
    _flushing = started;
    notifyListeners();
    return started;
  }

  /// Envoi en cours (écran hors connexion : « Envoi… »).
  bool get syncing => _flushing != null;

  Future<void> _flush() async {
    await load();
    final blockedOrders = {
      for (final item in _items)
        if (item.failed) item.orderId,
    };
    for (final original in List.of(_items)) {
      if (original.failed || blockedOrders.contains(original.orderId)) continue;
      var action = original;
      try {
        if (action.photoPath != null && action.body['photoKey'] == null) {
          final key = await upload(action.photoPath!);
          action = action.copyWith(body: {...action.body, 'photoKey': key});
          _replace(action);
          await _save();
        }
        await send(action.path, action.body);
        _items = _items.where((item) => item.id != action.id).toList();
        await _save();
        if (action.photoPath != null) await deletePhoto(action.photoPath!);
      } on ApiException catch (error) {
        if (_transient(error)) return;
        if (_alreadySettled(action, error)) {
          // Rien à refaire (déjà payé par Mobile Money entre-temps) : l'action est retirée
          // et ne bloque pas la livraison qui la suit.
          _items = _items.where((item) => item.id != action.id).toList();
          await _save();
          continue;
        }
        _replace(action.copyWith(failureCode: error.code, failureMessage: error.message));
        blockedOrders.add(action.orderId);
        await _save();
      }
    }
  }

  /// Le livreur abandonne une action refusée (après appel au support) : elle est retirée.
  /// [keepPhoto] : la photo sert à l'action qui la remplace.
  Future<void> discard(String id, {bool keepPhoto = false}) async {
    final action = _items.where((item) => item.id == id).firstOrNull;
    _items = _items.where((item) => item.id != id).toList();
    await _save();
    if (!keepPhoto && action?.photoPath != null) await deletePhoto(action!.photoPath!);
  }

  /// Le livreur a corrigé l'action (code ressaisi) : elle repart.
  Future<void> retry(String id, {Json? body}) async {
    final action = _items.where((item) => item.id == id).firstOrNull;
    if (action == null) return;
    _replace(
      QueuedAction(
        id: action.id,
        orderId: action.orderId,
        kind: action.kind,
        path: action.path,
        body: {...action.body, ...?body},
        createdAt: action.createdAt,
        photoPath: action.photoPath,
      ),
    );
    await _save();
    await flush();
  }

  /// Refus qui veut dire « déjà fait » : encaissement alors que tout est déjà payé.
  static bool _alreadySettled(QueuedAction action, ApiException error) =>
      action.kind == 'collect' && error.code == 'COLLECTION_NOT_EXPECTED';

  void _replace(QueuedAction action) => _items = [for (final item in _items) item.id == action.id ? action : item];

  /// Réseau absent, serveur indisponible ou trop sollicité, session à renouveler : on réessaie.
  static bool _transient(ApiException error) =>
      error.isNetwork ||
      error.status == null ||
      error.status! >= 500 ||
      error.status == 408 ||
      error.status == 429 ||
      error.code == 'SESSION_EXPIRED';

  static Future<void> _deleteFile(String path) async {
    try {
      await File(path).delete();
    } catch (_) {
      // Déjà supprimée : rien à faire.
    }
  }
}

/// Identifiant unique d'un envoi (UUID v4) : un rejeu au retour du réseau n'est pas doublé.
String newEventId() => _uuidV4();

String _uuidV4() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
