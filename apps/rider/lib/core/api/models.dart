import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:tara_core/api/models.dart';

export 'package:tara_core/api/models.dart';

/// Modèles des réponses de l'API utilisées par l'app livreur. Chaque champ lu ici existe
/// dans le contrat `apps/api/openapi.json` (vérifié par test/api_contract_test.dart).

T _field<T>(Json json, String key) => json[key] as T;
DateTime? _date(Object? value) => value == null ? null : DateTime.parse(value as String);

@immutable
class MobileMoneyOperator {
  const MobileMoneyOperator(this.code, this.name);
  final String code;
  final String name;
}

/// Numéros d'urgence du pays, composés depuis l'écran d'alerte (14).
@immutable
class EmergencyNumbers {
  const EmergencyNumbers({required this.police, required this.fire, required this.medical});

  factory EmergencyNumbers.fromJson(Json? json) => json == null
      ? cameroon
      : EmergencyNumbers(police: _field(json, 'police'), fire: _field(json, 'fire'), medical: _field(json, 'medical'));

  /// Cameroun : police 117, pompiers 118, SAMU 119. Valeurs gardées si le serveur n'en
  /// donne pas encore (réglages enregistrés par une version précédente de l'app).
  static const cameroon = EmergencyNumbers(police: '117', fire: '118', medical: '119');

  final String police;
  final String fire;
  final String medical;
}

/// Appels exigés avant un échec de livraison (réglages du serveur, E6).
@immutable
class FailurePolicy {
  const FailurePolicy({
    this.minCalls = 2,
    this.callSpacing = const Duration(minutes: 5),
    this.decisionTimeout = const Duration(minutes: 15),
  });

  factory FailurePolicy.fromJson(Json? json) => json == null
      ? const FailurePolicy()
      : FailurePolicy(
          minCalls: _field<num>(json, 'minCalls').toInt(),
          callSpacing: Duration(seconds: (_field<num>(json, 'callSpacingMinutes') * 60).round()),
          decisionTimeout: Duration(seconds: (_field<num>(json, 'decisionTimeoutMinutes') * 60).round()),
        );

  final int minCalls;
  final Duration callSpacing;

  /// Délai laissé à l'expéditeur pour choisir avant le retour automatique.
  final Duration decisionTimeout;

  /// Appels au destinataire exigés pour ce motif : absent, injoignable, adresse
  /// introuvable, [minCalls] ; autre motif, un ; colis ou paiement refusé, aucun.
  int callsRequired(String reason) => switch (reason) {
    'RECIPIENT_ABSENT' || 'RECIPIENT_UNREACHABLE' || 'ADDRESS_NOT_FOUND' => minCalls,
    'OTHER' => 1,
    _ => 0,
  };

  /// Heure à partir de laquelle les appels suffisent (null : déjà suffisants, ou il manque
  /// des appels). [missing] : appels encore à passer.
  ({int missing, DateTime? readyAt}) progress(String reason, List<DateTime> recipientCalls) {
    final required = callsRequired(reason);
    final times = [...recipientCalls]..sort();
    final missing = math.max(0, required - times.length);
    if (required < 2 || times.isEmpty) return (missing: missing, readyAt: null);
    final readyAt = times.first.add(callSpacing);
    // Le dernier appel doit venir au moins [callSpacing] après le premier.
    if (missing == 0 && times.last.isBefore(readyAt)) return (missing: 1, readyAt: readyAt);
    return (missing: missing, readyAt: missing > 0 ? readyAt : null);
  }
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
    this.emergencyNumbers = EmergencyNumbers.cameroon,
    this.failurePolicy = const FailurePolicy(),
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
      emergencyNumbers: EmergencyNumbers.fromJson(json['emergencyNumbers'] as Json?),
      failurePolicy: FailurePolicy.fromJson(json['failurePolicy'] as Json?),
    );
  }
  static const fields = [
    'country',
    'safetyHotline',
    'supportPhone',
    'mobileMoneyOperators',
    'offerTimeoutSeconds',
    'emergencyNumbers',
    'failurePolicy',
  ];

  final String dialCode;
  final String currency;
  final String safetyHotline;
  final String? supportPhone;
  final List<MobileMoneyOperator> operators;
  final int offerTimeoutSeconds;
  final EmergencyNumbers emergencyNumbers;
  final FailurePolicy failurePolicy;
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
  const SafetyAlert({
    required this.id,
    required this.createdAt,
    required this.cancelledAt,
    required this.resolvedAt,
    this.acknowledgedAt,
    this.policeCalledAt,
    this.neighborhood,
    this.plate,
  });
  factory SafetyAlert.fromJson(Json json) => SafetyAlert(
    id: _field(json, 'id'),
    createdAt: DateTime.parse(_field(json, 'createdAt')),
    cancelledAt: _date(json['cancelledAt']),
    resolvedAt: _date(json['resolvedAt']),
    acknowledgedAt: _date(json['acknowledgedAt']),
    policeCalledAt: _date(json['policeCalledAt']),
    neighborhood: json['neighborhood'] as String?,
    plate: json['riderPlate'] as String?,
  );
  static const fields = [
    'id',
    'createdAt',
    'cancelledAt',
    'resolvedAt',
    'acknowledgedAt',
    'policeCalledAt',
    'neighborhood',
    'riderPlate',
  ];

  final String id;
  final DateTime createdAt;
  final DateTime? cancelledAt;
  final DateTime? resolvedAt;

  /// Prise en charge par un agent Tara.
  final DateTime? acknowledgedAt;

  /// Police appelée par l'agent Tara.
  final DateTime? policeCalledAt;

  /// Quartier où se trouve le livreur, s'il est connu.
  final String? neighborhood;

  /// Immatriculation de la moto, à donner à la police.
  final String? plate;
}

@immutable
class KycDocument {
  const KycDocument({required this.type, required this.status, required this.rejectionReason});
  final String type;

  /// PENDING, APPROVED, REJECTED ou EXPIRED.
  final String status;
  final String? rejectionReason;
}

/// Dossier du livreur : statut de validation, pièces envoyées et manquantes.
@immutable
class RiderProfile {
  const RiderProfile({
    required this.status,
    required this.vehicleType,
    required this.documents,
    required this.missingDocuments,
    required this.emergencyContactName,
    required this.emergencyContactPhone,
    this.plateNumber,
  });
  factory RiderProfile.fromJson(Json json) {
    final contact = json['emergencyContact'] as Json?;
    return RiderProfile(
      status: _field(json, 'status'),
      vehicleType: _field(json, 'vehicleType'),
      documents: [
        for (final item in _field<List<Object?>>(json, 'documents'))
          KycDocument(
            type: _field(item! as Json, 'type'),
            status: _field(item as Json, 'status'),
            rejectionReason: _field(item, 'rejectionReason'),
          ),
      ],
      missingDocuments: [for (final item in _field<List<Object?>>(json, 'missingDocuments')) item! as String],
      emergencyContactName: contact?['name'] as String?,
      emergencyContactPhone: contact?['phone'] as String?,
      plateNumber: json['plateNumber'] as String?,
    );
  }
  static const fields = ['status', 'vehicleType', 'plateNumber', 'documents', 'missingDocuments', 'emergencyContact'];

  /// PENDING (en attente de validation), ACTIVE, SUSPENDED ou REJECTED.
  final String status;
  final String vehicleType;
  final List<KycDocument> documents;
  final List<String> missingDocuments;
  final String? emergencyContactName;
  final String? emergencyContactPhone;

  /// Immatriculation du véhicule (facultative à l'inscription).
  final String? plateNumber;

  bool get isActive => status == 'ACTIVE';
}

/// Proposition de course (D1, E1) : zone de livraison approximative seulement.
@immutable
class Offer {
  const Offer({
    required this.id,
    required this.orderId,
    required this.expiresAt,
    required this.approachMeters,
    required this.pickupName,
    required this.pickupNeighborhood,
    required this.dropoffNeighborhood,
    required this.dropoffCity,
    required this.distanceMeters,
    required this.estimatedMinutes,
    required this.riderEarning,
    required this.codAmount,
    required this.cashFee,
    required this.packageSize,
    required this.isFragile,
    required this.isExpress,
    this.loadingHelp = false,
  });

  factory Offer.fromJson(Json json) {
    final pickup = _field<Json>(json, 'pickup');
    final dropoff = _field<Json>(json, 'dropoff');
    return Offer(
      id: _field(json, 'id'),
      orderId: _field(json, 'orderId'),
      expiresAt: DateTime.parse(_field(json, 'expiresAt')),
      approachMeters: (json['approachMeters'] as num?)?.toInt(),
      pickupName: (pickup['shopName'] as String?) ?? _field<String>(pickup, 'landmark'),
      pickupNeighborhood: pickup['neighborhood'] as String?,
      dropoffNeighborhood: dropoff['neighborhood'] as String?,
      dropoffCity: _field(dropoff, 'city'),
      distanceMeters: _field<num>(json, 'distanceMeters').toInt(),
      estimatedMinutes: _field<num>(json, 'estimatedMinutes').toInt(),
      riderEarning: _field<num>(json, 'riderEarning').toInt(),
      codAmount: _field<num>(json, 'codAmount').toInt(),
      cashFee: _field<num>(json, 'cashFee').toInt(),
      packageSize: _field(json, 'packageSize'),
      isFragile: _field(json, 'isFragile'),
      isExpress: _field(json, 'isExpress'),
      loadingHelp: json['loadingHelp'] == true,
    );
  }
  static const fields = [
    'id',
    'orderId',
    'expiresAt',
    'approachMeters',
    'pickup',
    'dropoff',
    'distanceMeters',
    'estimatedMinutes',
    'riderEarning',
    'codAmount',
    'cashFee',
    'packageSize',
    'isFragile',
    'isExpress',
    'loadingHelp',
  ];

  final String id;
  final String orderId;
  final DateTime expiresAt;
  final int? approachMeters;

  /// Nom de la boutique (commerçant) ou repère du lieu d'enlèvement.
  final String pickupName;
  final String? pickupNeighborhood;
  final String? dropoffNeighborhood;
  final String dropoffCity;
  final int distanceMeters;
  final int estimatedMinutes;
  final int riderEarning;
  final int codAmount;
  final int cashFee;
  final String packageSize;
  final bool isFragile;
  final bool isExpress;

  /// Gros objet : l'expéditeur a payé l'aide au chargement, le livreur vient à deux.
  final bool loadingHelp;

  /// Gros objet (BULKY) : réservé aux tricycles et aux voitures.
  bool get bulky => packageSize == 'BULKY';

  /// Espèces que le livreur aura à encaisser (montant du colis et frais réglés en espèces).
  int get cashToCollect => codAmount + cashFee;
}

/// Adresse d'une course : point, quartier et repère écrit (B1).
@immutable
class OrderAddress {
  const OrderAddress({
    required this.city,
    required this.landmark,
    required this.latitude,
    required this.longitude,
    required this.motorbikeRestricted,
    this.label,
    this.contactName,
    this.contactPhone,
    this.neighborhood,
    this.hasPhoto = false,
    this.hasVoiceNote = false,
  });

  factory OrderAddress.fromJson(Json json) => OrderAddress(
    label: json['label'] as String?,
    contactName: json['contactName'] as String?,
    contactPhone: json['contactPhone'] as String?,
    city: _field(json, 'city'),
    neighborhood: (json['neighborhood'] as Json?)?['name'] as String?,
    landmark: _field(json, 'landmark'),
    latitude: _field<num>(json, 'latitude').toDouble(),
    longitude: _field<num>(json, 'longitude').toDouble(),
    motorbikeRestricted: _field(json, 'motorbikeRestricted'),
    hasPhoto: json['photoKey'] != null,
    hasVoiceNote: json['voiceNoteKey'] != null,
  );

  static const fields = [
    'photoKey',
    'voiceNoteKey',
    'label',
    'contactName',
    'contactPhone',
    'city',
    'neighborhood',
    'landmark',
    'latitude',
    'longitude',
    'motorbikeRestricted',
  ];

  final String? label;
  final String? contactName;
  final String? contactPhone;
  final String city;
  final String? neighborhood;
  final String landmark;
  final double latitude;
  final double longitude;

  /// Dans une zone interdite aux motos (B6) : finir à pied.
  final bool motorbikeRestricted;

  /// Photo de la façade et note vocale laissées par l'expéditeur (B2).
  final bool hasPhoto;
  final bool hasVoiceNote;

  /// « Akwa · face à la pharmacie » : quartier puis repère.
  String get line => [?neighborhood, landmark].join(' · ');
}

/// Expéditeur ou destinataire : contacts visibles seulement pendant la course.
@immutable
class OrderParty {
  const OrderParty({this.name, this.phone});

  factory OrderParty.fromJson(Json json) => OrderParty(name: json['name'] as String?, phone: json['phone'] as String?);

  final String? name;
  final String? phone;
}

/// Course attribuée au livreur (E2). Gardée telle quelle sur le téléphone pour l'usage
/// hors connexion ([raw]).
@immutable
class RiderOrder {
  const RiderOrder({
    required this.raw,
    required this.id,
    required this.reference,
    required this.status,
    required this.packageSize,
    required this.isFragile,
    required this.isExpress,
    required this.pickup,
    required this.dropoff,
    required this.sender,
    required this.recipient,
    required this.riderEarning,
    required this.collectAtPickup,
    required this.collectAtDelivery,
    required this.awaitingSupportValidation,
    this.loadingHelp = false,
    this.instructions,
    this.googleMapsUrl,
    this.wazeUrl,
    this.failureDecision,
    this.failureReason,
    this.failedAt,
    this.failureDecisionDueAt,
    this.completedAt,
    this.collectedAmount,
    this.collectedMethod,
  });

  factory RiderOrder.fromJson(Json json) {
    final navigation = json['navigation'] as Json?;
    return RiderOrder(
      raw: json,
      id: _field(json, 'id'),
      reference: _field(json, 'reference'),
      status: _field(json, 'status'),
      packageSize: _field(json, 'packageSize'),
      isFragile: _field(json, 'isFragile'),
      isExpress: _field(json, 'isExpress'),
      loadingHelp: json['loadingHelp'] == true,
      instructions: json['instructions'] as String?,
      pickup: OrderAddress.fromJson(_field(json, 'pickup')),
      dropoff: OrderAddress.fromJson(_field(json, 'dropoff')),
      sender: OrderParty.fromJson(_field(json, 'sender')),
      recipient: OrderParty.fromJson(_field(json, 'recipient')),
      riderEarning: _field<num>(json, 'riderEarning').toInt(),
      collectAtPickup: _field<num>(json, 'collectAtPickup').toInt(),
      collectAtDelivery: _field<num>(json, 'collectAtDelivery').toInt(),
      googleMapsUrl: navigation?['googleMaps'] as String?,
      wazeUrl: navigation?['waze'] as String?,
      failureDecision: json['failureDecision'] as String?,
      failureReason: json['failureReason'] as String?,
      failedAt: _date(json['failedAt']),
      failureDecisionDueAt: _date(json['failureDecisionDueAt']),
      completedAt: _date(json['completedAt']),
      collectedAmount: ((json['collected'] as Json?)?['amount'] as num?)?.toInt(),
      collectedMethod: (json['collected'] as Json?)?['method'] as String?,
      awaitingSupportValidation: _field(json, 'awaitingSupportValidation'),
    );
  }

  static const fields = [
    'id',
    'reference',
    'status',
    'packageSize',
    'isFragile',
    'isExpress',
    'loadingHelp',
    'instructions',
    'pickup',
    'dropoff',
    'sender',
    'recipient',
    'riderEarning',
    'collectAtPickup',
    'collectAtDelivery',
    'navigation',
    'failureDecision',
    'failureReason',
    'failedAt',
    'failureDecisionDueAt',
    'awaitingSupportValidation',
    'completedAt',
    'collected',
  ];

  /// Réponse de l'API telle quelle (sauvegarde sur le téléphone).
  final Json raw;
  final String id;
  final String reference;

  /// ASSIGNED, PICKED_UP, IN_DELIVERY, DELIVERY_FAILED, DELIVERED, RETURNED, CANCELLED.
  final String status;
  final String packageSize;
  final bool isFragile;
  final bool isExpress;

  /// Gros objet : l'expéditeur a payé l'aide au chargement, le livreur vient à deux.
  final bool loadingHelp;
  final String? instructions;
  final OrderAddress pickup;
  final OrderAddress dropoff;
  final OrderParty sender;
  final OrderParty recipient;
  final int riderEarning;

  /// Espèces à encaisser auprès de l'expéditeur à l'enlèvement (frais payés en espèces).
  final int collectAtPickup;

  /// À encaisser auprès du destinataire (frais à sa charge et montant du colis).
  final int collectAtDelivery;
  final String? googleMapsUrl;
  final String? wazeUrl;

  /// Choix de l'expéditeur après un échec : RETRY (nouvelle tentative) ou RETURN (retour).
  final String? failureDecision;

  /// Motif du dernier échec (RECIPIENT_ABSENT, RECIPIENT_UNREACHABLE, ADDRESS_NOT_FOUND,
  /// REFUSED, PAYMENT_REFUSED, OTHER) et son heure.
  final String? failureReason;
  final DateTime? failedAt;

  /// Échec sans décision : heure du retour automatique.
  final DateTime? failureDecisionDueAt;

  /// Fin de la course (livrée, rendue ou annulée), pour l'historique.
  final DateTime? completedAt;

  /// Argent encaissé auprès du destinataire : montant et moyen (CASH ou MOBILE_MONEY).
  final int? collectedAmount;
  final String? collectedMethod;
  final bool awaitingSupportValidation;

  /// Toujours en cours pour le livreur (sinon : terminée, annulée ou réattribuée).
  bool get inProgress => const {'ASSIGNED', 'PICKED_UP', 'IN_DELIVERY', 'DELIVERY_FAILED'}.contains(status);

  /// Statut changé sur le téléphone, avant la confirmation du serveur (action en file).
  RiderOrder withStatus(String status) => RiderOrder.fromJson({...raw, 'status': status});

  /// Champs changés sur le téléphone (ex. livraison déclarée, en attente du support).
  RiderOrder withChanges(Json changes) => RiderOrder.fromJson({...raw, ...changes});

  /// Livraison enregistrée sur le téléphone, pas encore reçue par le serveur (sans réseau).
  /// Champ propre à l'app : jamais renvoyé par l'API.
  bool get deliveryQueued => raw[deliveryQueuedKey] == true;
  static const deliveryQueuedKey = '_deliveryQueued';

  /// Retour enregistré sur le téléphone, pas encore reçu par le serveur (sans réseau).
  bool get returnQueued => raw[returnQueuedKey] == true;
  static const returnQueuedKey = '_returnQueued';

  /// Refus du colis (non conforme) enregistré sur le téléphone, pas encore reçu par le serveur.
  bool get refusalQueued => raw[refusalQueuedKey] == true;
  static const refusalQueuedKey = '_refusalQueued';

  /// Gros objet (BULKY) : réservé aux tricycles et aux voitures.
  bool get bulky => packageSize == 'BULKY';
}

/// Itinéraire vers la prochaine étape de la course, à dessiner sur la carte.
@immutable
class RiderRoute {
  const RiderRoute({
    required this.stop,
    required this.meters,
    required this.estimate,
    required this.path,
    this.seconds,
  });

  factory RiderRoute.fromJson(Json json) => RiderRoute(
    stop: _field(json, 'stop'),
    meters: _field<num>(json, 'meters').toInt(),
    seconds: (json['seconds'] as num?)?.toInt(),
    estimate: json['source'] == 'estimate',
    path: [
      for (final point in _field<List<Object?>>(json, 'path'))
        [for (final value in point! as List<Object?>) (value! as num).toDouble()],
    ],
  );

  static const fields = ['stop', 'meters', 'seconds', 'source', 'path'];

  /// PICKUP (vendeur) ou DROPOFF (destinataire).
  final String stop;
  final int meters;
  final int? seconds;

  /// Ligne droite et distance estimées (calculateur d'itinéraires indisponible).
  final bool estimate;

  /// Paires [longitude, latitude].
  final List<List<double>> path;

  /// Minutes arrondies au supérieur, au moins 1.
  int? get minutes => seconds == null ? null : (seconds! / 60).ceil().clamp(1, 600);
}

/// Ce qui reste à encaisser auprès du destinataire (E5).
@immutable
class Collection {
  const Collection({required this.total, required this.complete, this.paymentId, this.paymentStatus});

  factory Collection.fromJson(Json json) {
    final payment = json['payment'] as Json?;
    return Collection(
      total: _field<num>(_field<Json>(json, 'due'), 'total').toInt(),
      complete: _field(json, 'complete'),
      paymentId: payment?['id'] as String?,
      paymentStatus: payment?['status'] as String?,
    );
  }

  static const fields = ['due', 'complete', 'payment'];

  final int total;
  final bool complete;

  /// Demande Mobile Money en attente de la validation du client.
  final String? paymentId;
  final String? paymentStatus;
}

/// Portefeuille du livreur : gains et espèces détenues (plafond D4).
@immutable
class RiderWallet {
  const RiderWallet({
    required this.earnings,
    required this.cashHeld,
    required this.cashLimit,
    required this.available,
    this.reserved = 0,
    this.cashDueBy,
    this.cashOverdue = false,
  });

  factory RiderWallet.fromJson(Json json) => RiderWallet(
    earnings: _field<num>(json, 'earnings').toInt(),
    reserved: _field<num>(json, 'reserved').toInt(),
    available: _field<num>(json, 'available').toInt(),
    cashHeld: _field<num>(json, 'cashHeld').toInt(),
    cashLimit: _field<num>(json, 'cashLimit').toInt(),
    cashDueBy: _date(json['cashDueBy']),
    cashOverdue: json['cashOverdue'] == true,
  );

  static const fields = ['earnings', 'reserved', 'cashHeld', 'cashLimit', 'available', 'cashDueBy', 'cashOverdue'];

  /// Solde prépayé (G5) : gains et recharges, moins l'argent encaissé en espèces.
  final int earnings;

  /// Mis de côté pour les courses avec encaissement en cours.
  final int reserved;

  /// Disponible : solde moins l'argent mis de côté et les anciennes espèces dues. Une
  /// course avec encaissement n'est proposée que si ce montant la couvre.
  final int available;

  /// Espèces encaissées avant le solde prépayé et pas encore déposées (dues à Tara).
  final int cashHeld;
  final int cashLimit;

  /// Heure limite de dépôt (24 h après l'encaissement le plus ancien non déposé).
  final DateTime? cashDueBy;

  /// Délai dépassé : plus de courses jusqu'au dépôt.
  final bool cashOverdue;
}

/// Paiement Mobile Money demandé au téléphone du payeur (recharge du solde, dépôt d'espèces, G5).
@immutable
class PaymentRequest {
  const PaymentRequest({required this.id, required this.status, required this.amount});
  factory PaymentRequest.fromJson(Json json) => PaymentRequest(
    id: _field(json, 'id'),
    status: _field(json, 'status'),
    amount: _field<num>(json, 'amount').toInt(),
  );
  static const fields = ['id', 'status', 'amount'];

  final String id;

  /// PENDING, SUCCEEDED, FAILED ou CANCELLED.
  final String status;
  final int amount;
}
