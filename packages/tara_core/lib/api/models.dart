import 'package:flutter/foundation.dart';

/// Modèles partagés par les apps Tara (connexion, session, position). Chaque champ lu ici
/// existe dans le contrat `apps/api/openapi.json`.

typedef Json = Map<String, Object?>;

T _field<T>(Json json, String key) => json[key] as T;

/// Heure au format attendu par l'API : UTC, à la milliseconde (pas de microsecondes).
String isoUtc(DateTime value) =>
    DateTime.fromMillisecondsSinceEpoch(value.millisecondsSinceEpoch, isUtc: true).toIso8601String();

@immutable
class OtpChallenge {
  const OtpChallenge({required this.challengeId, required this.expiresAt, required this.resendAfterSeconds});
  factory OtpChallenge.fromJson(Json json) => OtpChallenge(
    challengeId: _field(json, 'challengeId'),
    expiresAt: DateTime.parse(_field(json, 'expiresAt')),
    resendAfterSeconds: _field<num>(json, 'resendAfterSeconds').toInt(),
  );
  static const fields = ['challengeId', 'expiresAt', 'resendAfterSeconds'];

  final String challengeId;
  final DateTime expiresAt;
  final int resendAfterSeconds;
}

@immutable
class SessionUser {
  const SessionUser({
    required this.id,
    required this.phone,
    required this.fullName,
    required this.roles,
    required this.locale,
  });
  factory SessionUser.fromJson(Json json) => SessionUser(
    id: _field(json, 'id'),
    phone: _field(json, 'phone'),
    fullName: _field(json, 'fullName'),
    roles: [for (final role in _field<List<Object?>>(json, 'roles')) role! as String],
    locale: _field(json, 'locale'),
  );
  static const fields = ['id', 'phone', 'fullName', 'roles', 'locale'];

  final String id;
  final String phone;
  final String? fullName;
  final List<String> roles;
  final String locale;

  bool get isRider => roles.contains('RIDER');
}

@immutable
class AuthSession {
  const AuthSession({required this.isNewUser, required this.user});
  factory AuthSession.fromJson(Json json) =>
      AuthSession(isNewUser: _field(json, 'isNewUser'), user: SessionUser.fromJson(_field(json, 'user')));
  static const fields = ['accessToken', 'refreshToken', 'expiresIn', 'isNewUser', 'user'];

  final bool isNewUser;
  final SessionUser user;
}

/// Position du téléphone, envoyée avec la présence, les positions et les actions.
@immutable
class GeoPoint {
  const GeoPoint({
    required this.latitude,
    required this.longitude,
    required this.recordedAt,
    this.heading,
    this.speed,
    this.accuracy,
    this.mocked = false,
  });

  final double latitude;
  final double longitude;
  final DateTime recordedAt;
  final double? heading;
  final double? speed;
  final double? accuracy;

  /// Position simulée par une application (signalée par Android) : le support est alerté.
  final bool mocked;

  Json toJson() => {
    'latitude': latitude,
    'longitude': longitude,
    if (heading != null) 'heading': heading,
    if (speed != null) 'speed': speed,
    if (accuracy != null) 'accuracy': accuracy,
    'recordedAt': isoUtc(recordedAt),
    if (mocked) 'mocked': true,
  };

  /// Point de trajet gardé sur le téléphone sans réseau (POST /rider/orders/{id}/track).
  Json toTrackJson() => {
    'latitude': latitude,
    'longitude': longitude,
    'recordedAt': isoUtc(recordedAt),
    if (accuracy != null) 'accuracy': accuracy,
    if (speed != null) 'speed': speed,
    if (mocked) 'mocked': true,
  };
}

/// Texte juridique en vigueur (conditions, confidentialité), en Markdown simple.
@immutable
class LegalDocument {
  const LegalDocument({required this.document, required this.version, required this.title, required this.markdown});
  factory LegalDocument.fromJson(Json json) => LegalDocument(
    document: _field(json, 'document'),
    version: _field(json, 'version'),
    title: _field(json, 'title'),
    markdown: _field(json, 'markdown'),
  );
  static const fields = ['document', 'version', 'title', 'markdown'];

  /// expediteurs, livreurs, destinataires ou confidentialite.
  final String document;

  /// « 2026-11 » : renvoyée telle quelle à l'acceptation.
  final String version;
  final String title;
  final String markdown;
}

/// Textes à accepter (nouvelle version) et versions déjà acceptées, avec leur date.
@immutable
class TermsStatus {
  const TermsStatus({required this.required, required this.accepted});
  factory TermsStatus.fromJson(Json json) => TermsStatus(
    required: {
      for (final item in _field<List<Object?>>(json, 'required').cast<Json>())
        item['document']! as String: item['version']! as String,
    },
    accepted: [for (final item in _field<List<Object?>>(json, 'accepted').cast<Json>()) AcceptedTerms.fromJson(item)],
  );
  static const fields = ['required', 'accepted'];

  /// Document → version en vigueur, pour chaque texte à accepter (vide si tout est à jour).
  final Map<String, String> required;
  final List<AcceptedTerms> accepted;

  bool get upToDate => required.isEmpty;
}

@immutable
class AcceptedTerms {
  const AcceptedTerms({required this.document, required this.version, required this.acceptedAt});
  factory AcceptedTerms.fromJson(Json json) => AcceptedTerms(
    document: _field(json, 'document'),
    version: _field(json, 'version'),
    acceptedAt: DateTime.parse(_field(json, 'acceptedAt')),
  );

  final String document;
  final String version;
  final DateTime acceptedAt;
}
