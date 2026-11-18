import 'dart:typed_data';

import 'package:tara_client/core/api/client_api.dart';
import 'package:tara_client/core/api/client_models.dart';
import 'package:tara_core/api/api_client.dart';
import 'package:tara_core/api/api_exception.dart';
import 'package:tara_core/session/session_store.dart';
import 'package:tara_test/fake_pin.dart';

/// API expéditeur sans réseau : compte, nom et boutique enregistrés.
class FakeClientApi extends ClientApi {
  FakeClientApi() : super(ApiClient(baseUrl: 'http://test.invalid', store: SessionStore(MemoryKeyValueStore())));

  final names = <String>[];

  /// Commandes en cours (accueil) et portefeuille renvoyés.
  List<OrderSummary> active = [];
  List<OrderSummary> history = [];
  Wallet wallet0 = const Wallet(customerBalance: 0, merchantBalance: null, payoutSchedule: null);

  /// Réseau coupé : la liste des commandes échoue tant que ce champ est vrai.
  bool offline = false;

  @override
  Future<List<OrderSummary>> orders({required String scope, int limit = 20}) async {
    if (offline) throw const ApiException(code: 'NETWORK', message: 'Pas de réseau', status: 0);
    return scope == 'active' ? active : history;
  }

  @override
  Future<Wallet> wallet() async => wallet0;
  final merchants = <Map<String, String?>>[];

  @override
  Future<Me> me() async => const Me(
    id: '00000000-0000-4000-8000-0000000000aa',
    phone: '+237677123456',
    fullName: null,
    locale: 'FR',
    referralCode: 'TARA-7KQ2PM',
    merchant: null,
  );

  @override
  Future<void> updateName(String fullName) async => names.add(fullName);

  /// Adresses enregistrées, carnet de destinataires et liens de localisation.
  List<Address> saved = [];
  List<Recipient> recents = [];
  final createdAddresses = <Map<String, Object?>>[];
  final createdLinks = <Map<String, String?>>[];

  /// Ce que renvoie la relecture d'un lien (le destinataire a-t-il placé son point ?).
  LocationLink? linkAfter;

  @override
  Future<List<Address>> addresses() async => saved;

  @override
  Future<List<Neighborhood>> neighborhoods() async => [
    for (final (i, name) in ['Akwa', 'Bali', 'Bépanda', 'Bonamoussadi', 'Bonapriso', 'Deïdo', 'Makepe'].indexed)
      Neighborhood(id: '00000000-0000-4000-8000-00000000010$i', name: name),
  ];

  @override
  Future<PointLocation> locate(double latitude, double longitude) async => latitude > 3.9 && latitude < 4.2
      ? const PointLocation(
          inServiceArea: true,
          neighborhood: Neighborhood(id: '00000000-0000-4000-8000-000000000100', name: 'Akwa'),
        )
      : const PointLocation(inServiceArea: false);

  @override
  Future<Address> createAddress({
    required double latitude,
    required double longitude,
    required String landmark,
    String? neighborhoodId,
    String? label,
    String? contactName,
    String? contactPhone,
    String? photoKey,
    String? voiceNoteKey,
  }) async {
    createdAddresses.add({
      'photoKey': ?photoKey,
      'voiceNoteKey': ?voiceNoteKey,
      'latitude': latitude,
      'longitude': longitude,
      'landmark': landmark,
      'neighborhoodId': neighborhoodId,
      'label': label,
      'contactName': contactName,
      'contactPhone': contactPhone,
    });
    final created = fakeAddress('9${createdAddresses.length}', landmark, label: label, neighborhood: 'Akwa');
    if (label != null) saved = [created, ...saved];
    return created;
  }

  @override
  Future<List<Recipient>> recipients({String? query}) async => recents;

  @override
  Future<LocationLink> createLocationLink({String? recipientName, String? recipientPhone}) async {
    createdLinks.add({'recipientName': recipientName, 'recipientPhone': recipientPhone});
    return pendingLink(recipientName);
  }

  @override
  Future<LocationLink> locationLink(String id) async => linkAfter ?? pendingLink(null);

  /// Fichiers envoyés : (chemin, ADDRESS_PHOTO ou VOICE_NOTE).
  final uploads = <(String, String)>[];

  @override
  Future<String> uploadMedia(String filePath, String kind, {String? mimeType}) async {
    uploads.add((filePath, kind));
    return 'address/${kind.toLowerCase()}-${uploads.length}';
  }

  /// Réponse de l'analyse de la photo du colis (par défaut : carton moyen).
  ParcelAnalysis? parcelAnalysis;

  /// Refus renvoyé par l'analyse (indisponible, trop de photos).
  ApiException? parcelAnalysisError;
  final analyzed = <String>[];

  @override
  Future<ParcelAnalysis> analyzeParcel(String photoKey) async {
    analyzed.add(photoKey);
    if (parcelAnalysisError case final error?) throw error;
    return parcelAnalysis ??
        ParcelAnalysis(
          photoKey: photoKey,
          isParcel: true,
          size: 'M',
          contents: 'OTHER',
          description: 'Carton fermé',
          fragile: false,
          prohibited: const [],
          confidence: 'medium',
        );
  }

  /// Adresses retirées du carnet.
  final deletedAddresses = <String>[];

  @override
  Future<void> deleteAddress(String id) async {
    deletedAddresses.add(id);
    saved = [
      for (final address in saved)
        if (address.id != id) address,
    ];
  }

  /// Adresses demandées depuis l'accueil.
  List<LocationLink> links = [];

  @override
  Future<List<LocationLink>> locationLinks() async => links;

  // --- Prix, commande, paiement ------------------------------------------------------

  final quotes = <Map<String, Object?>>[];
  final created = <({String key, Map<String, Object?> body, bool batch})>[];
  final paid = <({String orderId, String phone, String operator})>[];
  final cancelled = <String>[];

  /// Refus renvoyé à la prochaine création de commande.
  ApiException? createError;

  /// États successifs du paiement relu (le dernier est répété).
  List<String> paymentStatuses = ['PENDING'];

  /// Tarif pro de la boutique (points de base), comme le calcule le serveur.
  int proDiscountBps = 0;

  @override
  Future<Quote> quote({
    required String pickupAddressId,
    required String dropoffAddressId,
    required String packageSize,
    bool loadingHelp = false,
    DateTime? scheduledFor,
    String? promoCode,
  }) async {
    quotes.add({
      'dropoff': dropoffAddressId,
      'size': packageSize,
      'promo': promoCode,
      'at': scheduledFor,
      'loadingHelp': loadingHelp,
    });
    if (promoCode != null && promoCode != 'BIENVENUE') {
      throw const ApiException(code: 'PROMO_INVALID', message: 'Code promo inconnu.', status: 422);
    }
    // Gros objet : grille tricycle, manutention si l'expéditeur demande de l'aide.
    final bulky = packageSize == 'BULKY';
    final surcharges = [
      if (packageSize == 'XL') (code: 'HEAVY_PARCEL', amount: 500),
      if (bulky && loadingHelp) (code: 'HANDLING', amount: 1500),
      if (scheduledFor != null && (scheduledFor.hour >= 20 || scheduledFor.hour < 6)) (code: 'NIGHT', amount: 300),
    ];
    final base = bulky ? 3000 : 1200;
    final subtotal = base + surcharges.fold<int>(0, (sum, s) => sum + s.amount);
    // Le plus avantageux du code promo et du tarif pro (arrondi à 50 F), jamais les deux.
    final promoDiscount = promoCode == null ? 0 : 500;
    final proDiscount = (subtotal * proDiscountBps / 10000 / 50).round() * 50;
    final pro = proDiscount > promoDiscount;
    final discount = pro ? proDiscount : promoDiscount;
    return Quote(
      distanceMeters: 4200,
      estimatedMinutes: 18,
      basePrice: base,
      surcharges: surcharges,
      discountTotal: discount,
      totalPrice: subtotal - discount,
      promoCode: pro ? null : promoCode,
      discountSource: pro ? 'VOLUME' : (promoDiscount > 0 ? 'PROMO' : null),
      proDiscountBps: pro ? proDiscountBps : 0,
      vehicleType: bulky ? 'TRICYCLE' : 'MOTORBIKE',
      retryFee: bulky ? 1500 : 500,
      returnFee: base ~/ 2,
    );
  }

  PlacedOrder _placed(int i, Map<String, Object?> item, {int? batchNumber}) => PlacedOrder(
    id: '00000000-0000-4000-8000-00000000050$i',
    reference: 'TR-4830$i',
    status: 'SEARCHING_RIDER',
    totalPrice: item['packageSize'] == 'XL' ? 1700 : 1200,
    batchNumber: batchNumber,
  );

  /// Prix d'une liste d'envoi : un colis vers [unpricedAddressId] n'a pas de prix (hors zone).
  String? unpricedAddressId;

  /// Réserves du soir choisies par la boutique.
  final reserves = <int>[];

  @override
  Future<void> setPayoutReserve(int amount) async {
    reserves.add(amount);
    wallet0 = Wallet(
      customerBalance: wallet0.customerBalance,
      merchantBalance: wallet0.merchantBalance,
      payoutSchedule: wallet0.payoutSchedule,
      todaySales: wallet0.todaySales,
      todayDeliveries: wallet0.todayDeliveries,
      plan: wallet0.plan,
      payoutPhone: wallet0.payoutPhone,
      payoutReserve: amount,
    );
  }

  @override
  Future<BatchQuote> quoteMany({
    required String pickupAddressId,
    required List<({String dropoffAddressId, String packageSize})> items,
    DateTime? scheduledFor,
  }) async {
    final quoted = [
      for (final item in items)
        item.dropoffAddressId == unpricedAddressId
            ? (quote: null, error: 'Cette adresse est hors de la zone desservie.')
            : (
                quote: await quote(
                  pickupAddressId: pickupAddressId,
                  dropoffAddressId: item.dropoffAddressId,
                  packageSize: item.packageSize,
                ),
                error: null,
              ),
    ];
    return BatchQuote(items: quoted, totalPrice: quoted.fold(0, (sum, i) => sum + (i.quote?.totalPrice ?? 0)));
  }

  /// Colis qui attendent l'adresse de leur client, et ce que l'expéditeur en a fait.
  List<PendingDelivery> pendingList = [];
  final pendingActions = <String>[];

  @override
  Future<List<PendingDelivery>> pendingDeliveries() async => pendingList;

  PendingDelivery _pendingWith(String id, {String? status, String? orderId}) {
    final p = pendingList.firstWhere((p) => p.id == id);
    return PendingDelivery(
      id: p.id,
      batchId: p.batchId,
      batchNumber: p.batchNumber,
      recipientName: p.recipientName,
      recipientPhone: p.recipientPhone,
      status: status ?? p.status,
      blockedReason: status == null ? p.blockedReason : null,
      linkUrl: p.linkUrl,
      linkExpiresAt: p.linkExpiresAt,
      orderId: orderId,
      codAmount: p.codAmount,
    );
  }

  @override
  Future<PendingDelivery> resendPending(String id) async {
    pendingActions.add('resend:$id');
    return _pendingWith(id, status: 'WAITING');
  }

  @override
  Future<PendingDelivery> cancelPending(String id) async {
    pendingActions.add('cancel:$id');
    pendingList = [
      for (final p in pendingList)
        if (p.id != id) p,
    ];
    return PendingDelivery(
      id: id,
      batchId: '',
      batchNumber: 0,
      recipientName: '',
      recipientPhone: '',
      status: 'CANCELLED',
      blockedReason: null,
      linkUrl: '',
      linkExpiresAt: DateTime(2026),
      orderId: null,
      codAmount: 0,
    );
  }

  @override
  Future<PendingDelivery> releasePending(String id, {String? feePaymentMethod}) async {
    pendingActions.add('release:$id:${feePaymentMethod ?? 'WALLET'}');
    return _pendingWith(id, status: 'RELEASED', orderId: '00000000-0000-4000-8000-000000000777');
  }

  @override
  Future<Placement> createOrder({
    required String idempotencyKey,
    required Map<String, Object?> shared,
    required Map<String, Object?> delivery,
    String? promoCode,
  }) async {
    created.add((key: idempotencyKey, body: {...shared, ...delivery, 'promoCode': ?promoCode}, batch: false));
    final error = createError;
    if (error != null) {
      createError = null;
      throw error;
    }
    return Placement(orders: [_placed(1, delivery)], pickupCode: '4821');
  }

  @override
  Future<Placement> createBatch({
    required String idempotencyKey,
    required Map<String, Object?> shared,
    required List<Map<String, Object?>> deliveries,
  }) async {
    created.add((key: idempotencyKey, body: {...shared, 'items': deliveries}, batch: true));
    const batchId = '00000000-0000-4000-8000-000000000600';
    // Un colis sans adresse attend son client ; les autres partent tout de suite.
    return Placement(
      orders: [
        for (final (i, d) in deliveries.indexed)
          if (d['askAddress'] != true) _placed(i + 1, d, batchNumber: i + 1),
      ],
      pending: [
        for (final (i, d) in deliveries.indexed)
          if (d['askAddress'] == true)
            PendingDelivery(
              id: '00000000-0000-4000-8000-00000000070${i + 1}',
              batchId: batchId,
              batchNumber: i + 1,
              recipientName: d['recipientName']! as String,
              recipientPhone: d['recipientPhone']! as String,
              status: 'WAITING',
              blockedReason: null,
              linkUrl: 'https://tara.test/l/lien${i + 1}',
              linkExpiresAt: DateTime(2026, 11, 7, 10),
              orderId: null,
              codAmount: (d['codAmount'] as int?) ?? 0,
            ),
      ],
      pickupCode: '7302',
      batchId: batchId,
    );
  }

  @override
  Future<Payment> payOrder(String orderId, {required String phone, required String operator}) async {
    paid.add((orderId: orderId, phone: phone, operator: operator));
    return const Payment(
      id: '00000000-0000-4000-8000-000000000700',
      status: 'PENDING',
      amount: 1200,
      failureReason: null,
    );
  }

  final batchPaid = <({String batchId, String phone, String operator})>[];

  @override
  Future<Payment> payBatch(String batchId, {required String phone, required String operator}) async {
    batchPaid.add((batchId: batchId, phone: phone, operator: operator));
    return const Payment(
      id: '00000000-0000-4000-8000-000000000701',
      status: 'PENDING',
      amount: 2900,
      failureReason: null,
    );
  }

  @override
  Future<Payment> payment(String id) async {
    final status = paymentStatuses.length > 1 ? paymentStatuses.removeAt(0) : paymentStatuses.first;
    return Payment(id: id, status: status, amount: 1200, failureReason: null);
  }

  @override
  Future<void> cancelOrder(String orderId, String reason) async => cancelled.add(orderId);

  /// Commandes suivies, par identifiant (modifiées par les tests au fil des étapes).
  final tracked = <String, TrackedOrder>{};

  @override
  Future<TrackedOrder> order(String id) async => tracked[id]!;

  @override
  Future<String> newPickupCode(String orderId) async => '5190';

  /// Notes données : (commande, étoiles, mot).
  final ratings = <(String, int, String?)>[];

  @override
  Future<OrderRating> rateRider(String orderId, {required int score, String? comment}) async {
    ratings.add((orderId, score, comment));
    return OrderRating(score: score, comment: comment, at: DateTime(2026, 11, 4, 10, 40));
  }

  /// Choix après un échec : (commande, RETRY ou RETURN).
  final decisions = <(String, String)>[];

  /// Erreur renvoyée au prochain choix (déjà décidé ailleurs, solde insuffisant…), null sinon.
  Object? decisionError;

  @override
  Future<void> failureDecision(String orderId, String decision) async {
    if (decisionError case final error?) {
      decisionError = null;
      throw error;
    }
    decisions.add((orderId, decision));
  }

  /// Mouvements par compte (`customer`, `merchant`), servis par pages de [linesPage].
  final lines = <String, List<WalletLine>>{'customer': [], 'merchant': []};
  int linesPage = 20;

  @override
  Future<({List<WalletLine> items, String? nextCursor})> walletLines({
    required String account,
    String? cursor,
    int limit = 20,
  }) async {
    final all = lines[account]!;
    final start = cursor == null ? 0 : all.indexWhere((line) => line.id == cursor) + 1;
    final page = all.skip(start).take(linesPage).toList();
    final more = start + page.length < all.length;
    return (items: page, nextCursor: more ? page.last.id : null);
  }

  List<Payout> payoutList = [];

  @override
  Future<List<Payout>> payouts({int limit = 10}) async => payoutList;

  /// Reversements immédiats et retraits demandés : (numéro, opérateur) pour un retrait.
  int payoutsNow = 0;
  final withdrawals = <(String, String)>[];

  /// Code secret contrôlé comme le serveur ; preuves reçues (retraits, suppression).
  FakePinApi? pins;
  final proofs = <PinProof?>[];

  /// Empreinte absente par défaut ; lecture du SMS pilotée par le test.
  FakeBiometrics biometrics = FakeBiometrics(present: false);
  final sms = FakeSmsCodeReader();

  void _check(PinProof? proof) {
    if (proof != null) pins?.check(proof);
    proofs.add(proof);
  }

  @override
  Future<Payout> payoutNow({required String key, PinProof? proof}) async {
    _check(proof);
    payoutsNow++;
    return Payout(
      id: 'payout-now',
      beneficiary: 'MERCHANT',
      amount: wallet0.merchantBalance ?? 0,
      status: 'PENDING',
      requestedAt: DateTime(2026, 11, 4, 10, 30),
      completedAt: null,
    );
  }

  @override
  Future<Payout> withdraw({
    required String phone,
    required String operator,
    required String key,
    PinProof? proof,
  }) async {
    _check(proof);
    withdrawals.add((phone, operator));
    return Payout(
      id: 'withdraw',
      beneficiary: 'CUSTOMER',
      amount: wallet0.customerBalance,
      status: 'PENDING',
      requestedAt: DateTime(2026, 11, 4, 10, 30),
      completedAt: null,
    );
  }

  /// Copies de données demandées.
  int exports = 0;

  @override
  Future<Json> exportData() async {
    exports++;
    return {
      'user': {'phone': '+237677123456', 'fullName': 'Awa Ngono'},
    };
  }

  /// [deletionErrors] : refus renvoyés d'abord, un par demande de suppression.
  final deletionErrors = <ApiException>[];

  /// Suppressions confirmées, avec la preuve du code secret.
  final deletions = <PinProof>[];

  @override
  Future<void> deleteAccount({required PinProof proof}) async {
    _check(proof);
    if (deletionErrors.isNotEmpty) throw deletionErrors.removeAt(0);
    deletions.add(proof);
  }

  /// Relevés téléchargés (mois AAAA-MM).
  final statements = <String>[];

  @override
  Future<Uint8List> statement(String month) async {
    statements.add(month);
    return Uint8List.fromList('%PDF-1.4 relevé $month'.codeUnits);
  }

  /// Recharges demandées : (montant, numéro, opérateur).
  final topUps = <(int, String, String)>[];

  @override
  Future<Payment> topUp({
    required int amount,
    required String phone,
    required String operator,
    required String key,
  }) async {
    topUps.add((amount, phone, operator));
    return Payment(id: 'topup-${topUps.length}', status: 'PENDING', amount: amount, failureReason: null);
  }

  @override
  Future<Merchant> becomeMerchant({
    required String shopName,
    String? category,
    required String payoutPhone,
    required String payoutOperator,
    String? rccm,
    String? niu,
  }) async {
    merchants.add({
      'shopName': shopName,
      'category': category,
      'payoutPhone': payoutPhone,
      'payoutOperator': payoutOperator,
      'rccm': rccm,
      'niu': niu,
    });
    return Merchant(shopName: shopName, category: category, payoutPhone: payoutPhone, payoutOperator: payoutOperator);
  }
}

/// Adresse de test : point dans Douala, quartier et repère.
Address fakeAddress(
  String id,
  String landmark, {
  String? label,
  String? neighborhood,
  bool verified = false,
  double latitude = 4.05,
  double longitude = 9.70,
}) => Address(
  id: '00000000-0000-4000-8000-0000000002${id.padLeft(2, '0')}',
  label: label,
  contactName: null,
  contactPhone: null,
  neighborhood: neighborhood == null
      ? null
      : Neighborhood(id: '00000000-0000-4000-8000-000000000199', name: neighborhood),
  landmark: landmark,
  latitude: latitude,
  longitude: longitude,
  verified: verified,
  motorbikeRestricted: false,
);

/// Lien de localisation envoyé, en attente du destinataire (ou rempli si [address]).
LocationLink pendingLink(String? name, {Address? address, String? phone, String status = 'PENDING'}) => LocationLink(
  id: '00000000-0000-4000-8000-000000000301',
  url: 'https://tara.cm/l/Q7mK2pXa9RtL4vNe',
  recipientName: name,
  recipientPhone: phone,
  status: address == null ? status : 'SUBMITTED',
  expiresAt: DateTime.utc(2026, 11, 7, 10),
  address: address,
);
