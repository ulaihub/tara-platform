import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:tara_core/money/mobile_money_fees.dart';
import 'package:tara_core/phone/phone_format.dart';
import 'package:tara_core/session/session_store.dart';

import '../../core/api/client_models.dart';
import 'paste_parser.dart';

/// Où en est un client de la liste d'envoi.
enum LineState {
  /// Adresse connue : son colis part dès l'envoi.
  ready,

  /// Pas d'adresse : Tara lui enverra un lien par SMS, son colis partira quand il aura placé
  /// son point.
  waiting,

  /// Nom ou numéro à corriger : il reste dans la liste et ne part pas.
  incomplete,
}

/// Un client de la liste d'envoi, et son colis.
class BulkLine {
  BulkLine({
    String? key,
    this.name = '',
    this.phone = '',
    this.rawPhone,
    this.dropoff,
    this.hint = '',
    this.size,
    this.description = '',
    this.codAmount = 0,
    this.fragile = false,
  }) : key = key ?? _newKey();

  factory BulkLine.parsed(ParsedLine line) => BulkLine(
    name: line.name,
    phone: line.phone ?? '',
    rawPhone: line.rawPhone,
    hint: line.neighborhood ?? line.hint,
    codAmount: line.amount,
  );

  factory BulkLine.fromJson(Map<String, Object?> json) {
    final dropoff = json['dropoff'] as Map<String, Object?>?;
    return BulkLine(
      key: json['key'] as String?,
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      rawPhone: json['rawPhone'] as String?,
      dropoff: dropoff == null ? null : Address.fromJson(dropoff),
      hint: json['hint'] as String? ?? '',
      size: json['size'] as String?,
      description: json['description'] as String? ?? '',
      codAmount: (json['codAmount'] as num?)?.toInt() ?? 0,
      fragile: json['fragile'] == true,
    );
  }

  /// Identifiant local, stable tant que la ligne existe (édition, suppression).
  final String key;
  String name;

  /// Chiffres nationaux (9) du client.
  String phone;

  /// Numéro mal lu dans une liste collée (« 69912 »), montré pour être corrigé.
  String? rawPhone;
  Address? dropoff;

  /// Quartier ou repère lu dans la liste collée, affiché tant qu'aucune adresse n'est choisie.
  String hint;

  /// Taille du colis ; null : la taille par défaut de la liste.
  String? size;
  String description;
  int codAmount;
  bool fragile;

  /// Prix calculé à l'étape « Vérifier et envoyer » (non gardé).
  Quote? quote;
  String? quoteError;

  bool get validName => name.trim().length >= 2;
  bool get validPhone => isCameroonMobile(phone);

  LineState get state => !validName || !validPhone || codAmount > maxCod
      ? LineState.incomplete
      : dropoff == null
      ? LineState.waiting
      : LineState.ready;

  String get firstName => name.trim().split(RegExp(r'\s+')).first;

  /// Montant à encaisser au plus par colis (G5).
  static const maxCod = 500000;

  Map<String, Object?> toJson() => {
    'key': key,
    'name': name,
    'phone': phone,
    'rawPhone': rawPhone,
    'dropoff': dropoff?.toJson(),
    'hint': hint,
    'size': size,
    'description': description,
    'codAmount': codAmount,
    'fragile': fragile,
  };

  /// Colis pour l'API (C4) : adresse connue, ou adresse demandée au client par Tara.
  Map<String, Object?> toApi(String defaultSize) => {
    if (dropoff case final address?) 'dropoffAddressId': address.id else 'askAddress': true,
    'recipientName': name.trim(),
    'recipientPhone': '+237$phone',
    'packageSize': size ?? defaultSize,
    'packageContents': 'OTHER',
    if (description.trim().isNotEmpty) 'packageDescription': description.trim(),
    'isFragile': fragile,
    'codAmount': codAmount,
  };

  static String _newKey() {
    final random = Random();
    return List.generate(12, (_) => random.nextInt(36).toRadixString(36)).join();
  }
}

/// Liste d'envoi d'une boutique (C4) : jusqu'à 100 clients depuis le même point, réglages
/// communs, gardée chiffrée sur le téléphone jusqu'à l'envoi.
class BulkDraft extends ChangeNotifier {
  BulkDraft();

  factory BulkDraft.fromJson(Map<String, Object?> json) {
    final pickup = json['pickup'] as Map<String, Object?>?;
    return BulkDraft()
      .._pickup = pickup == null ? null : Address.fromJson(pickup)
      ..defaultSize = json['defaultSize'] as String? ?? 'M'
      ..feePayer = json['feePayer'] as String? ?? 'SENDER'
      ..paymentMethod = json['paymentMethod'] as String?
      ..payerPhone = json['payerPhone'] as String? ?? ''
      ..lines.addAll([
        for (final line in (json['lines'] as List<Object?>? ?? const []).cast<Map<String, Object?>>())
          BulkLine.fromJson(line),
      ]);
  }

  /// Clients au plus dans un envoi.
  static const max = 100;

  /// Tailles proposées pour toute la liste (un gros objet se règle client par client).
  static const sizes = ['S', 'M', 'L', 'XL'];

  Address? _pickup;
  Address? get pickup => _pickup;
  set pickup(Address? value) {
    _pickup = value;
    notifyListeners();
  }

  /// Taille des colis quand elle n'est pas précisée pour un client.
  String defaultSize = 'M';

  /// SENDER (la boutique paie) ou RECIPIENT (chaque client paie à la livraison).
  String feePayer = 'SENDER';

  /// WALLET (ventes de la boutique, solde Tara), MOMO_MTN, MOMO_ORANGE.
  String? paymentMethod;
  String payerPhone = '';

  /// Taux des frais Mobile Money (réglages de l'app), en points de base.
  int mobileMoneyFeeBps = 0;

  final lines = <BulkLine>[];

  int get room => max - lines.length;
  List<BulkLine> get ready => [
    for (final l in lines)
      if (l.state == LineState.ready) l,
  ];
  List<BulkLine> get waiting => [
    for (final l in lines)
      if (l.state == LineState.waiting) l,
  ];
  List<BulkLine> get incomplete => [
    for (final l in lines)
      if (l.state == LineState.incomplete) l,
  ];

  /// Ce qui part à l'envoi : les prêts, et ceux qui attendent leur point.
  List<BulkLine> get sendable => [
    for (final l in lines)
      if (l.state != LineState.incomplete) l,
  ];

  bool get senderPays => feePayer == 'SENDER';
  bool get momo => senderPays && (paymentMethod?.startsWith('MOMO_') ?? false);

  /// Courses des colis prêts (les colis en attente sont payés quand ils partent).
  int get total => ready.fold(0, (sum, l) => sum + (l.quote?.totalPrice ?? 0));
  int get collectTotal => sendable.fold(0, (sum, l) => sum + l.codAmount);
  bool get allQuoted => ready.every((l) => l.quote != null);
  int get mobileMoneyFeeAmount => momo ? mobileMoneyFee(total, mobileMoneyFeeBps) : 0;
  int get amountToPay => senderPays ? total + mobileMoneyFeeAmount : 0;

  bool get hasPayment =>
      !senderPays ||
      switch (paymentMethod) {
        'MOMO_MTN' || 'MOMO_ORANGE' => isCameroonMobile(payerPhone),
        'WALLET' => true,
        _ => false,
      };

  /// Ajoute des clients au bout de la liste, sans doublon (même numéro et même nom) ni
  /// dépassement des 100. Renvoie le nombre ajouté.
  int addAll(Iterable<BulkLine> added) {
    var count = 0;
    for (final line in added) {
      if (lines.length >= max) break;
      final duplicate =
          line.validPhone &&
          lines.any((l) => l.phone == line.phone && l.name.trim().toLowerCase() == line.name.trim().toLowerCase());
      if (duplicate) continue;
      lines.add(line);
      count++;
    }
    if (count > 0) notifyListeners();
    return count;
  }

  void remove(String key) {
    lines.removeWhere((l) => l.key == key);
    notifyListeners();
  }

  /// Toute modification d'une ligne passe par ici pour rafraîchir les écrans.
  void update(String key, void Function(BulkLine line) change) {
    for (final line in lines) {
      if (line.key == key) change(line);
    }
    notifyListeners();
  }

  /// Après l'envoi : ne restent que les clients à compléter.
  void removeSent() {
    lines.removeWhere((l) => l.state != LineState.incomplete);
    notifyListeners();
  }

  void touch() => notifyListeners();

  /// Partie commune à tous les colis pour l'API (C4).
  Map<String, Object?> sharedJson() => {
    'pickupAddressId': pickup!.id,
    'isExpress': false,
    'feePayer': feePayer,
    // Le client règle à la porte (espèces ou Mobile Money) : jamais le solde.
    'feePaymentMethod': senderPays ? paymentMethod : 'CASH',
  };

  Map<String, Object?> toJson() => {
    'pickup': pickup?.toJson(),
    'defaultSize': defaultSize,
    'feePayer': feePayer,
    'paymentMethod': paymentMethod,
    'payerPhone': payerPhone,
    'lines': [for (final line in lines) line.toJson()],
  };
}

/// Liste d'envoi gardée sur le téléphone, dans le stockage chiffré (elle contient les noms
/// et numéros des clients), une par compte.
class BulkDraftStore {
  BulkDraftStore(this._store, this._userId);

  final KeyValueStore _store;
  final String _userId;

  String get _key => 'bulk_draft:$_userId';

  Future<BulkDraft> load() async {
    try {
      final raw = await _store.read(_key);
      if (raw == null) return BulkDraft();
      return BulkDraft.fromJson(jsonDecode(raw) as Map<String, Object?>);
    } catch (_) {
      // Liste illisible (version précédente) : on repart d'une liste vide.
      return BulkDraft();
    }
  }

  Future<void> save(BulkDraft draft) async {
    if (draft.lines.isEmpty) {
      await _store.delete(_key);
    } else {
      await _store.write(_key, jsonEncode(draft.toJson()));
    }
  }
}
