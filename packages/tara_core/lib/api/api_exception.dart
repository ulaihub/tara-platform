import 'dart:convert';

import 'package:dio/dio.dart';

/// Erreur renvoyée par l'API (`{ error: { code, message, details } }`) ou par le réseau.
/// Le message vient du serveur, déjà dans la langue du livreur (en-tête Accept-Language).
class ApiException implements Exception {
  const ApiException({required this.code, required this.message, this.status, this.details = const {}});

  factory ApiException.fromDio(DioException error) {
    final response = error.response;
    if (response == null) {
      return ApiException(code: network, message: error.message ?? 'Réseau indisponible');
    }
    final body = _decoded(response.data);
    final payload = body is Map ? body['error'] : null;
    if (payload is Map) {
      final details = payload['details'];
      return ApiException(
        code: payload['code']?.toString() ?? 'UNKNOWN',
        message: payload['message']?.toString() ?? '',
        status: response.statusCode,
        details: details is Map ? details.map((key, value) => MapEntry(key.toString(), value as Object?)) : const {},
      );
    }
    return ApiException(code: 'HTTP_${response.statusCode}', message: '', status: response.statusCode);
  }

  /// Réponse en octets (téléchargement d'un fichier) : l'erreur JSON est relue.
  static Object? _decoded(Object? data) {
    if (data is! List<int>) return data;
    try {
      return jsonDecode(utf8.decode(data));
    } catch (_) {
      return null;
    }
  }

  /// Pas de réseau, délai dépassé : l'action peut être mise en file et rejouée.
  static const network = 'NETWORK';

  final String code;
  final String message;
  final int? status;
  final Map<String, Object?> details;

  bool get isNetwork => code == network;

  @override
  String toString() => 'ApiException($code, $status): $message';
}
