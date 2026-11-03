import 'package:flutter/foundation.dart';

/// Modèles des réponses de l'API utilisées par l'app livreur. Chaque champ lu ici existe
/// dans le contrat `apps/api/openapi.json` (vérifié par test/api_contract_test.dart).

typedef Json = Map<String, Object?>;

T _field<T>(Json json, String key) => json[key] as T;
DateTime? _date(Object? value) => value == null ? null : DateTime.parse(value as String);

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

@immutable
class MobileMoneyOperator {
  const MobileMoneyOperator(this.code, this.name);
  final String code;
  final String name;
}

/// Réglages de l'app venant du serveur, gardés sur le téléphone pour le hors connexion.
@immutable
class RiderConfig {
  const RiderConfig({
    required this.dialCode,
    required this.currency,
    required this.safetyHotline,
    required this.supportPhone,
    required this.operators,
    required this.offerTimeoutSeconds,
  });
  factory RiderConfig.fromJson(Json json) {
    final country = _field<Json>(json, 'country');
    return RiderConfig(
      dialCode: _field(country, 'dialCode'),
      currency: _field(country, 'currency'),
      safetyHotline: _field(json, 'safetyHotline'),
      supportPhone: _field(json, 'supportPhone'),
      operators: [
        for (final item in _field<List<Object?>>(json, 'mobileMoneyOperators'))
          MobileMoneyOperator(_field((item! as Json), 'code'), _field(item as Json, 'name')),
      ],
      offerTimeoutSeconds: _field<num>(json, 'offerTimeoutSeconds').toInt(),
    );
  }
  static const fields = ['country', 'safetyHotline', 'supportPhone', 'mobileMoneyOperators', 'offerTimeoutSeconds'];

  final String dialCode;
  final String currency;
  final String safetyHotline;
  final String? supportPhone;
  final List<MobileMoneyOperator> operators;
  final int offerTimeoutSeconds;
}

@immutable
class Presence {
  const Presence({required this.online, required this.blockers});
  factory Presence.fromJson(Json json) => Presence(
    online: _field(json, 'online'),
    blockers: [for (final item in _field<List<Object?>>(json, 'blockers')) item! as String],
  );
  static const fields = ['online', 'blockers'];

  final bool online;
  final List<String> blockers;
}

@immutable
class EarningsBucket {
  const EarningsBucket(this.start, this.earnings, this.delivered);
  final DateTime start;
  final int earnings;
  final int delivered;
}

@immutable
class Earnings {
  const Earnings({
    required this.period,
    required this.delivered,
    required this.failed,
    required this.earnings,
    required this.cashCollected,
    required this.onlineSeconds,
    required this.bucket,
    required this.series,
  });
  factory Earnings.fromJson(Json json) => Earnings(
    period: _field(json, 'period'),
    delivered: _field<num>(json, 'delivered').toInt(),
    failed: _field<num>(json, 'failed').toInt(),
    earnings: _field<num>(json, 'earnings').toInt(),
    cashCollected: _field<num>(json, 'cashCollected').toInt(),
    onlineSeconds: _field<num>(json, 'onlineSeconds').toInt(),
    bucket: _field(json, 'bucket'),
    series: [
      for (final item in _field<List<Object?>>(json, 'series'))
        EarningsBucket(
          DateTime.parse(_field((item! as Json), 'start')),
          _field<num>(item as Json, 'earnings').toInt(),
          _field<num>(item, 'delivered').toInt(),
        ),
    ],
  );
  static const fields = [
    'period',
    'delivered',
    'failed',
    'earnings',
    'cashCollected',
    'onlineSeconds',
    'bucket',
    'series',
  ];

  final String period;
  final int delivered;
  final int failed;
  final int earnings;
  final int cashCollected;
  final int onlineSeconds;
  final String bucket;
  final List<EarningsBucket> series;
}

@immutable
class DocumentOption {
  const DocumentOption({required this.type, required this.labelFr, required this.labelEn, required this.asksExpiry});
  final String type;
  final String labelFr;
  final String labelEn;
  final bool asksExpiry;

  String label(String languageCode) => languageCode == 'en' ? labelEn : labelFr;
}

/// Pièce exigée : l'une des options suffit (carte grise OU contrat de location).
@immutable
class DocumentRequirement {
  const DocumentRequirement(this.options);
  factory DocumentRequirement.fromJson(Json json) => DocumentRequirement([
    for (final item in _field<List<Object?>>(json, 'types'))
      DocumentOption(
        type: _field(item! as Json, 'type'),
        labelFr: _field(_field<Json>(item as Json, 'label'), 'fr'),
        labelEn: _field(_field<Json>(item, 'label'), 'en'),
        asksExpiry: _field(item, 'asksExpiry'),
      ),
  ]);
  static const fields = ['types'];

  final List<DocumentOption> options;
}

@immutable
class SafetyAlert {
  const SafetyAlert({required this.id, required this.createdAt, required this.cancelledAt, required this.resolvedAt});
  factory SafetyAlert.fromJson(Json json) => SafetyAlert(
    id: _field(json, 'id'),
    createdAt: DateTime.parse(_field(json, 'createdAt')),
    cancelledAt: _date(json['cancelledAt']),
    resolvedAt: _date(json['resolvedAt']),
  );
  static const fields = ['id', 'createdAt', 'cancelledAt', 'resolvedAt'];

  final String id;
  final DateTime createdAt;
  final DateTime? cancelledAt;
  final DateTime? resolvedAt;
}
