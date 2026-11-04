import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Session du livreur gardée dans le stockage chiffré du téléphone (Keystore Android,
/// trousseau iOS). Jamais dans les préférences en clair ni dans les sauvegardes.
@immutable
class StoredSession {
  const StoredSession({required this.accessToken, required this.refreshToken, required this.accessExpiresAt});

  factory StoredSession.fromJson(Map<String, Object?> json) => StoredSession(
    accessToken: json['accessToken']! as String,
    refreshToken: json['refreshToken']! as String,
    accessExpiresAt: DateTime.parse(json['accessExpiresAt']! as String),
  );

  /// Jetons reçus de l'API : `expiresIn` en secondes.
  factory StoredSession.fromTokens(Map<String, Object?> json, {DateTime? now}) => StoredSession(
    accessToken: json['accessToken']! as String,
    refreshToken: json['refreshToken']! as String,
    accessExpiresAt: (now ?? DateTime.now()).add(Duration(seconds: (json['expiresIn']! as num).toInt())),
  );

  final String accessToken;
  final String refreshToken;
  final DateTime accessExpiresAt;

  Map<String, Object?> toJson() => {
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'accessExpiresAt': accessExpiresAt.toIso8601String(),
  };
}

/// Accès au stockage, remplaçable dans les tests.
abstract class KeyValueStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class SecureKeyValueStore implements KeyValueStore {
  const SecureKeyValueStore([this._storage = const FlutterSecureStorage()]);
  final FlutterSecureStorage _storage;
  @override
  Future<String?> read(String key) => _storage.read(key: key);
  @override
  Future<void> write(String key, String value) => _storage.write(key: key, value: value);
  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

class MemoryKeyValueStore implements KeyValueStore {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
  @override
  Future<void> delete(String key) async => values.remove(key);
}

class SessionStore {
  SessionStore([this._store = const SecureKeyValueStore()]);

  static const _sessionKey = 'tara.session';
  static const _installationKey = 'tara.installation';

  final KeyValueStore _store;
  StoredSession? _cached;
  bool _loaded = false;

  Future<StoredSession?> read() async {
    if (_loaded) return _cached;
    final raw = await _store.read(_sessionKey);
    _cached = raw == null ? null : StoredSession.fromJson(jsonDecode(raw) as Map<String, Object?>);
    _loaded = true;
    return _cached;
  }

  Future<void> write(StoredSession session) async {
    _cached = session;
    _loaded = true;
    await _store.write(_sessionKey, jsonEncode(session.toJson()));
  }

  Future<void> clear() async {
    _cached = null;
    _loaded = true;
    await _store.delete(_sessionKey);
  }

  /// Identifiant de cette installation (appareils et notifications) : 128 bits aléatoires,
  /// créé au premier lancement, sans lien avec le matériel.
  Future<String> installationId() async {
    final existing = await _store.read(_installationKey);
    if (existing != null) return existing;
    final random = Random.secure();
    final id = List.generate(16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
    await _store.write(_installationKey, id);
    return id;
  }
}
