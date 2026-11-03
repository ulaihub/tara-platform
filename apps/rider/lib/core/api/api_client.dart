import 'dart:async';

import 'package:dio/dio.dart';

import '../session/session_store.dart';
import 'api_exception.dart';

/// Client HTTP de l'API Tara (`/v1`). Ajoute le jeton d'accès et la langue, renouvelle le
/// jeton une seule fois même si plusieurs requêtes échouent en même temps, et transforme
/// toute erreur en [ApiException].
class ApiClient {
  ApiClient({required String baseUrl, required this.store, String Function()? locale, this.onSessionExpired, Dio? dio})
    : _locale = locale ?? (() => 'fr'),
      dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: '$baseUrl/v1',
              connectTimeout: const Duration(seconds: 10),
              sendTimeout: const Duration(seconds: 30),
              receiveTimeout: const Duration(seconds: 20),
              contentType: Headers.jsonContentType,
            ),
          );

  final Dio dio;
  final SessionStore store;
  final String Function() _locale;

  /// Session refusée par le serveur (déconnexion, jeton révoqué) : retour à l'accueil.
  final void Function()? onSessionExpired;

  /// Renouvellement en cours, partagé par toutes les requêtes qui l'attendent.
  Future<StoredSession>? _refreshing;

  /// Marge avant l'expiration du jeton d'accès : on le renouvelle avant qu'il soit refusé.
  static const _refreshMargin = Duration(seconds: 30);

  Future<Object?> get(String path, {Map<String, Object?>? query, bool auth = true}) =>
      send('GET', path, query: query, auth: auth);

  Future<Object?> post(String path, {Object? body, bool auth = true, Map<String, String>? headers}) =>
      send('POST', path, body: body, auth: auth, headers: headers);

  Future<Object?> put(String path, {Object? body}) => send('PUT', path, body: body);

  Future<Object?> delete(String path) => send('DELETE', path);

  Future<Object?> send(
    String method,
    String path, {
    Object? body,
    Map<String, Object?>? query,
    bool auth = true,
    Map<String, String>? headers,
  }) async {
    var session = auth ? await store.read() : null;
    if (session != null && session.accessExpiresAt.isBefore(DateTime.now().add(_refreshMargin))) {
      session = await _refresh(session);
    }
    try {
      return await _request(method, path, body, query, session, headers);
    } on ApiException catch (error) {
      if (error.status != 401 || session == null) rethrow;
      // Jeton refusé (révoqué, horloge du téléphone décalée) : un renouvellement, un essai.
      session = await _refresh(session);
      // Un formulaire (photo) ne s'envoie qu'une fois : on en rejoue une copie.
      final retryBody = body is FormData ? body.clone() : body;
      return _request(method, path, retryBody, query, session, headers);
    }
  }

  Future<Object?> _request(
    String method,
    String path,
    Object? body,
    Map<String, Object?>? query,
    StoredSession? session,
    Map<String, String>? headers,
  ) async {
    try {
      final response = await dio.request<Object?>(
        path,
        data: body,
        queryParameters: query,
        options: Options(
          method: method,
          headers: {
            'Accept-Language': _locale(),
            if (session != null) 'Authorization': 'Bearer ${session.accessToken}',
            ...?headers,
          },
        ),
      );
      return response.data;
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }

  Future<StoredSession> _refresh(StoredSession current) =>
      _refreshing ??= _doRefresh(current).whenComplete(() => _refreshing = null);

  Future<StoredSession> _doRefresh(StoredSession current) async {
    try {
      final tokens = await _request('POST', '/auth/refresh', {'refreshToken': current.refreshToken}, null, null, null);
      final next = StoredSession.fromTokens(tokens! as Map<String, Object?>);
      await store.write(next);
      return next;
    } on ApiException catch (error) {
      // Sans réseau, la session reste : on réessaiera plus tard.
      if (error.isNetwork) rethrow;
      await store.clear();
      onSessionExpired?.call();
      throw const ApiException(code: 'SESSION_EXPIRED', message: '', status: 401);
    }
  }
}
