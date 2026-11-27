import 'dart:async';
import 'dart:math' as math;
import 'dart:math' show Random;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:tara_core/api/api_exception.dart';
import 'package:tara_core/api/order_chat_api.dart';
import 'package:tara_core/money/mobile_money_fees.dart';
import 'package:tara_core/phone/phone_format.dart';
import 'package:tara_core/realtime/realtime_client.dart';
import 'package:tara_map/pin_picker_map.dart';
import 'package:tara_ui/components/buttons.dart';
import 'package:tara_ui/components/glass.dart';
import 'package:tara_ui/components/inputs.dart';
import 'package:tara_ui/components/layout.dart';
import 'package:tara_ui/components/operator_logo.dart';
import 'package:tara_ui/components/order_chat.dart';
import 'package:tara_ui/components/star_rating.dart';
import 'package:tara_ui/feedback/tara_feedback.dart';
import 'package:tara_ui/format.dart';
import 'package:tara_ui/motion/confetti.dart';
import 'package:tara_ui/motion/effects.dart';
import 'package:tara_ui/motion/liquid_background.dart';
import 'package:tara_ui/motion/liquid_wave.dart';
import 'package:tara_ui/tara_colors.dart';
import 'package:tara_ui/tara_icons.dart';
import 'package:tara_ui/tara_typography.dart';
import 'package:tara_ui/vehicle_labels.dart';

import '../../app/providers.dart';
import '../../core/api/client_models.dart';
import '../../core/orders/pickup_codes.dart';
import '../../l10n/app_localizations.dart';
import '../common/error_text.dart';
import '../common/pickup_qr.dart';
import '../home/home_screen.dart';
import '../order/address_editor.dart' show SheetPanel;
import '../order/pickup_step.dart' show AddressChoice;
import '../support/support.dart';
import 'tracking_map.dart';

/// Vitesse moyenne d'une moto dans Douala, pour une estimation prudente de l'arrivée.
const _metersPerMinute = 300.0;

/// Suivi d'une commande (F1) : carte (ondes pendant la recherche, moto qui avance), étape
/// en cours, livreur à appeler. Chaque étape s'annonce par un son ; à la livraison,
/// fanfare, confettis et récapitulatif à partager.
class TrackingScreen extends ConsumerStatefulWidget {
  const TrackingScreen({super.key, required this.orderId, required this.onBack, this.now});

  final String orderId;
  final VoidCallback onBack;

  /// Horloge (tests).
  final DateTime Function()? now;

  @override
  ConsumerState<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends ConsumerState<TrackingScreen> {
  final _recap = GlobalKey();
  TrackedOrder? _order;
  String? _error;
  MapPoint? _rider;
  double? _heading;
  bool _celebrate = false;
  String? _pickupCode;

  /// Code d'enlèvement gardé sur le téléphone depuis la commande.
  String? _storedCode;
  bool _confirmCancel = false;
  bool _busy = false;

  /// Après un échec : RETRY ou RETURN, choisi avant de glisser pour confirmer.
  String? _choice;

  /// Note du livreur une fois livré (F4) : étoiles et mot facultatif.
  int _stars = 0;
  final _comment = TextEditingController();

  /// Nouvelle tentative que le solde ne couvre pas (E6) : montant à recharger d'abord, puis
  /// la tentative est confirmée dès le paiement validé.
  int? _topUp;

  /// Ce que la recharge paie : RETRY (nouvelle tentative), RETURN (retour sans dette) ou
  /// OFFICE (frais du colis gardé au bureau Tara).
  String _topUpFor = 'RETRY';

  /// Retour sans dette : frais, part du solde et reste à payer (échec, colis au bureau).
  ReturnQuote? _quote;

  /// Frais du bureau payés pendant cette visite : le code de retrait est parti par SMS.
  bool _officeCodeSent = false;
  String _topUpOperator = 'MTN';
  final _topUpPhone = TextEditingController();
  String? _topUpPayment;
  bool _topUpFailed = false;
  Timer? _topUpPoll;

  /// Paiement Mobile Money des frais relancé depuis le suivi (demande manquée ou refusée),
  /// sur le numéro saisi (celui du compte par défaut).
  final _payPhone = TextEditingController();
  String? _orderPayment;
  bool _orderPayFailed = false;
  Timer? _orderPayPoll;
  StreamSubscription<RealtimeEvent>? _events;
  late final RealtimeClient _realtime;
  Timer? _refresh;

  /// Messages du livreur reçus en direct (conversation ouverte) ; non lus sinon.
  final _chatIncoming = StreamController<OrderChatMessage>.broadcast();
  bool _chatOpen = false;
  int _unread = 0;

  /// Photo du livreur, chargée une fois par livreur (une nouvelle après une réattribution).
  Uint8List? _riderPhoto;
  String? _photoOf;

  /// Photo de remise (livré) ou du lieu (livraison impossible), chargée une fois par étape.
  Uint8List? _proofPhoto;
  String? _proofOf;

  /// Trajet du colis sur les rues ; null tant qu'il n'est pas reçu (ou ligne droite seulement).
  List<List<double>>? _route;

  DateTime get _now => (widget.now ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    unawaited(_loadRoute());
    unawaited(_loadPickupCode());
    _realtime = ref.read(realtimeProvider)..connect();
    _events = _realtime.stream.listen(_onEvent);
    _realtime.subscribeOrder(widget.orderId, onAck: _onAck);
    // Après une coupure, le serveur a oublié l'abonnement : on se réabonne et on relit
    // l'étape, sinon l'écran resterait figé sur l'ancienne.
    _realtime.connected.addListener(_onConnection);
    _lifecycle = AppLifecycleListener(onResume: () => unawaited(_load()));
    // Temps réel coupé : l'étape est relue de temps en temps.
    _refresh = Timer.periodic(const Duration(seconds: 15), (_) => unawaited(_load()));
  }

  late final AppLifecycleListener _lifecycle;
  bool _wasConnected = false;

  void _onConnection() {
    final connected = _realtime.connected.value;
    if (connected && _wasConnected == false && mounted) {
      _realtime.subscribeOrder(widget.orderId, onAck: _onAck);
      unawaited(_load());
    }
    _wasConnected = connected;
  }

  @override
  void dispose() {
    unawaited(_events?.cancel());
    _refresh?.cancel();
    _realtime.connected.removeListener(_onConnection);
    unawaited(_chatIncoming.close());
    _lifecycle.dispose();
    _realtime.unsubscribeOrder(widget.orderId);
    _comment.dispose();
    _topUpPhone.dispose();
    _topUpPoll?.cancel();
    _payPhone.dispose();
    _orderPayPoll?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final order = await ref.read(clientApiProvider).order(widget.orderId);
      if (!mounted) return;
      final before = _order?.status;
      if (order.awaitingPayment) _prefillPhone(_payPhone);
      setState(() {
        _order = order;
        _error = null;
      });
      if (before != null && before != order.status) _announce(order.status);
      unawaited(_loadRiderPhoto(order));
      unawaited(_loadProofPhoto(order));
      unawaited(_loadQuote(order));
      // Colis parti (ou commande finie) : le code d'enlèvement ne sert plus.
      if (!const ['CREATED', 'SEARCHING_RIDER', 'ASSIGNED'].contains(order.status) && _storedCode != null) {
        unawaited(PickupCodes(ref.read(keyValueStoreProvider)).forget(widget.orderId));
        _storedCode = null;
      }
    } catch (error) {
      if (mounted && _order == null) setState(() => _error = errorMessage(context, error));
    }
  }

  /// Retour sans dette : le prix du retour est annoncé avant de choisir, puis au bureau.
  Future<void> _loadQuote(TrackedOrder order) async {
    final wanted =
        (order.status == 'DELIVERY_FAILED' && order.failure?.decision == null) ||
        (order.status == 'HELD_AT_OFFICE' && order.office?.paidAt == null);
    if (!wanted) {
      if (_quote != null && mounted) setState(() => _quote = null);
      return;
    }
    try {
      final quote = await ref.read(clientApiProvider).returnQuote(order.id);
      if (mounted) setState(() => _quote = quote);
    } catch (_) {
      // Serveur d'avant ou réseau : les frais figés à la commande restent affichés.
    }
  }

  /// Colis gardé au bureau Tara : frais payés avec le solde ; s'il ne suffit pas, la
  /// recharge du reste est proposée, puis le paiement repart tout seul.
  Future<void> _payOffice() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(clientApiProvider).payOffice(widget.orderId);
      if (!mounted) return;
      TaraFeedback.play(context, TaraSound.sent);
      setState(() => _officeCodeSent = true);
      ref
        ..invalidate(activeOrdersProvider)
        ..invalidate(walletProvider);
      await _load();
    } catch (error) {
      if (!mounted) return;
      if (error is ApiException && error.code == 'RETURN_PAYMENT_REQUIRED') {
        _askTopUp((error.details['amount'] as num?)?.toInt() ?? _quote?.toPay ?? 0, 'OFFICE');
        return;
      }
      setState(() => _error = errorMessage(context, error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _loadRoute() async {
    try {
      final route = await ref.read(clientApiProvider).orderRoute(widget.orderId);
      if (mounted && route.onRoads) setState(() => _route = route.path);
    } catch (_) {
      // Pas de trajet (réseau, serveur d'avant) : la ligne droite reste.
    }
  }

  Future<void> _loadProofPhoto(TrackedOrder order) async {
    final has = order.delivery?.hasPhoto ?? order.failure?.hasPhoto ?? false;
    final key = has ? '${order.status}|${order.failure?.at}' : null;
    if (key == _proofOf) return;
    _proofOf = key;
    if (key == null) {
      if (mounted) setState(() => _proofPhoto = null);
      return;
    }
    try {
      final bytes = await ref.read(clientApiProvider).proofPhoto(order.id);
      if (mounted) setState(() => _proofPhoto = bytes);
    } catch (_) {
      // Photo effacée (90 jours) ou réseau : la vignette reste neutre.
    }
  }

  Future<void> _loadRiderPhoto(TrackedOrder order) async {
    final rider = order.rider;
    final key = rider == null ? null : '${rider.name}|${rider.plateNumber}';
    if (key == _photoOf) return;
    _photoOf = key;
    if (rider == null || !rider.hasPhoto) {
      if (mounted) setState(() => _riderPhoto = null);
      return;
    }
    try {
      final bytes = await ref.read(clientApiProvider).riderPhoto(order.id);
      if (mounted) setState(() => _riderPhoto = bytes);
    } catch (_) {
      // Sans photo : les initiales restent.
    }
  }

  Future<void> _openChat(TrackedOrder order) async {
    final l = AppLocalizations.of(context);
    final rider = order.rider;
    if (rider == null) return;
    final api = ref.read(orderChatApiProvider);
    final when = DateFormat('HH:mm', l.localeName);
    setState(() {
      _chatOpen = true;
      _unread = 0;
    });
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => OrderChatScreen(
          load: () => api.conversation(order.id),
          send: (body) => api.send(order.id, body),
          incoming: _chatIncoming.stream,
          onBack: () => Navigator.of(context).pop(),
          strings: OrderChatStrings(
            back: l.back,
            title: rider.name,
            subtitle: l.chatSubtitle(order.reference),
            hint: l.chatHint,
            send: l.chatSend,
            empty: l.chatEmpty,
            closed: l.chatClosed,
            read: l.chatRead,
            quickReplies: [l.chatQuick1, l.chatQuick2, l.chatQuick3, l.chatQuick4],
            when: when.format,
            errorText: (error) => errorMessage(context, error),
          ),
        ),
      ),
    );
    if (mounted) setState(() => _chatOpen = false);
  }

  void _onAck(Json ack) {
    final position = ack['position'];
    if (position is Map && mounted) _move(Map<String, Object?>.from(position));
  }

  void _move(Json position) {
    final latitude = (position['latitude'] as num?)?.toDouble();
    final longitude = (position['longitude'] as num?)?.toDouble();
    if (latitude == null || longitude == null) return;
    setState(() {
      _rider = MapPoint(latitude, longitude);
      _heading = (position['heading'] as num?)?.toDouble();
    });
  }

  void _onEvent(RealtimeEvent event) {
    if (event.payload['orderId'] != widget.orderId) return;
    switch (event.name) {
      case 'rider.position':
        _move(event.payload);
      case 'order.message':
        // Message du livreur, en direct : dans la conversation si elle est ouverte,
        // sinon pastille sur le bouton « Écrire ».
        final message = event.payload['message'];
        if (message is Map) {
          _chatIncoming.add(OrderChatMessage.fromJson(Map<String, Object?>.from(message)));
          if (!_chatOpen && mounted) {
            TaraFeedback.play(context, TaraSound.received);
            setState(() => _unread += 1);
          }
        }
      case 'order.status':
        final status = event.payload['status'];
        final order = _order;
        if (status is String && order != null && status != order.status) {
          setState(() => _order = order.withStatus(status));
          _announce(status);
        }
        // Livreur, heures des étapes : relus.
        unawaited(_load());
    }
  }

  /// Chaque étape s'annonce : livreur trouvé, colis récupéré, livré (fanfare, confettis).
  void _announce(String status) {
    switch (status) {
      case 'ASSIGNED':
        TaraFeedback.play(context, TaraSound.received);
      case 'PICKED_UP':
        TaraFeedback.play(context, TaraSound.pickedUp);
      case 'DELIVERED':
        TaraFeedback.play(context, TaraSound.delivered);
        setState(() => _celebrate = true);
        ref
          ..invalidate(activeOrdersProvider)
          ..invalidate(walletProvider);
      case 'DELIVERY_FAILED':
        TaraFeedback.play(context, TaraSound.error);
    }
  }

  /// Code d'enlèvement donné à la commande, gardé sur le téléphone.
  Future<void> _loadPickupCode() async {
    final code = await PickupCodes(ref.read(keyValueStoreProvider)).read(widget.orderId);
    if (code != null && mounted) setState(() => _storedCode = code);
  }

  Future<void> _newPickupCode() async {
    setState(() => _busy = true);
    try {
      final code = await ref.read(clientApiProvider).newPickupCode(widget.orderId);
      unawaited(PickupCodes(ref.read(keyValueStoreProvider)).remember(widget.orderId, code));
      if (mounted) setState(() => _pickupCode = code);
    } catch (error) {
      if (mounted) setState(() => _error = errorMessage(context, error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Choix de l'expéditeur après un échec (E6). Déjà décidé ailleurs (retour automatique,
  /// support) : l'écran relu montre la décision prise.
  Future<void> _decide() async {
    final choice = _choice;
    if (choice == null) return;
    setState(() => _busy = true);
    try {
      await ref.read(clientApiProvider).failureDecision(widget.orderId, choice);
      if (!mounted) return;
      TaraFeedback.play(context, TaraSound.sent);
      ref.invalidate(activeOrdersProvider);
      await _load();
    } catch (error) {
      if (!mounted) return;
      if (error is ApiException && error.code == 'RETRY_PAYMENT_REQUIRED') {
        _askTopUp((error.details['amount'] as num?)?.toInt() ?? _order?.retryFee ?? 0, 'RETRY');
        return;
      }
      // Retour sans dette : le solde ne couvre pas tout, le reste se paie d'abord.
      if (error is ApiException && error.code == 'RETURN_PAYMENT_REQUIRED') {
        _askTopUp((error.details['amount'] as num?)?.toInt() ?? _quote?.toPay ?? 0, 'RETURN');
        return;
      }
      final message = errorMessage(context, error);
      await _load();
      if (mounted) setState(() => _error = message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Relance le paiement Mobile Money des frais, sur le numéro saisi et l'opérateur choisi à
  /// la commande ; la commande part chercher un livreur dès que le paiement arrive.
  Future<void> _payOrder(TrackedOrder order) async {
    final phone = digitsOf(_payPhone.text);
    if (!isCameroonMobile(phone)) {
      setState(() => _error = AppLocalizations.of(context).phoneInvalid);
      return;
    }
    setState(() {
      _busy = true;
      _orderPayFailed = false;
      _error = null;
    });
    try {
      final payment = await ref
          .read(clientApiProvider)
          .payOrder(
            order.id,
            phone: '+237$phone',
            operator: order.feePaymentMethod == 'MOMO_ORANGE' ? 'ORANGE' : 'MTN',
          );
      if (!mounted) return;
      setState(() => _orderPayment = payment.id);
      _orderPayPoll?.cancel();
      _orderPayPoll = Timer.periodic(const Duration(seconds: 3), (_) => unawaited(_checkOrderPayment()));
      if (payment.status != 'PENDING') unawaited(_checkOrderPayment());
    } catch (error) {
      if (mounted) setState(() => _error = errorMessage(context, error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _checkOrderPayment() async {
    final id = _orderPayment;
    if (id == null) return;
    final Payment payment;
    try {
      payment = await ref.read(clientApiProvider).payment(id);
    } on ApiException {
      return; // Réseau : nouvel essai au prochain tour.
    }
    if (!mounted || _orderPayment != id) return;
    switch (payment.status) {
      case 'SUCCEEDED':
        _orderPayPoll?.cancel();
        setState(() => _orderPayment = null);
        await _load();
      case 'FAILED' || 'CANCELLED':
        _orderPayPoll?.cancel();
        setState(() {
          _orderPayment = null;
          _orderPayFailed = true;
        });
    }
  }

  /// Numéro du compte proposé pour payer, s'il est connu et le champ encore vide.
  void _prefillPhone(TextEditingController field) {
    final me = ref.read(meProvider).value;
    if (field.text.isEmpty && me != null) {
      final local = digitsOf(me.phone).replaceFirst(RegExp(r'^237(?=\d{9}$)'), '');
      field.text = PhoneInputFormatter().formatEditUpdate(TextEditingValue.empty, TextEditingValue(text: local)).text;
    }
  }

  void _askTopUp(int amount, String purpose) {
    _prefillPhone(_topUpPhone);
    setState(() {
      _topUpFor = purpose;
      _topUp = amount;
      _topUpFailed = false;
      _error = null;
    });
  }

  Future<void> _payTopUp() async {
    final amount = _topUp;
    final phone = digitsOf(_topUpPhone.text);
    if (amount == null) return;
    if (!isCameroonMobile(phone)) {
      setState(() => _error = AppLocalizations.of(context).phoneInvalid);
      return;
    }
    setState(() {
      _busy = true;
      _topUpFailed = false;
      _error = null;
    });
    try {
      final random = Random.secure();
      final key = List.generate(16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
      final payment = await ref
          .read(clientApiProvider)
          .topUp(amount: amount, phone: phone, operator: _topUpOperator, key: key);
      if (!mounted) return;
      setState(() => _topUpPayment = payment.id);
      _topUpPoll?.cancel();
      _topUpPoll = Timer.periodic(const Duration(seconds: 3), (_) => unawaited(_checkTopUp()));
      if (payment.status != 'PENDING') unawaited(_checkTopUp());
    } catch (error) {
      if (mounted) setState(() => _error = errorMessage(context, error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Recharge validée : la nouvelle tentative, le retour ou le paiement du bureau est
  /// confirmé dans la foulée.
  Future<void> _checkTopUp() async {
    final id = _topUpPayment;
    if (id == null) return;
    final Payment payment;
    try {
      payment = await ref.read(clientApiProvider).payment(id);
    } on ApiException {
      return; // Réseau : nouvel essai au prochain tour.
    }
    if (!mounted || _topUpPayment != id) return;
    switch (payment.status) {
      case 'SUCCEEDED':
        _topUpPoll?.cancel();
        final purpose = _topUpFor;
        setState(() {
          _topUp = null;
          _topUpPayment = null;
          if (purpose != 'OFFICE') _choice = purpose;
        });
        if (purpose == 'OFFICE') {
          await _payOffice();
        } else {
          await _decide();
        }
      case 'FAILED' || 'CANCELLED':
        _topUpPoll?.cancel();
        setState(() {
          _topUpPayment = null;
          _topUpFailed = true;
        });
    }
  }

  void _cancelTopUp() {
    _topUpPoll?.cancel();
    setState(() {
      _topUp = null;
      _topUpPayment = null;
      _topUpFailed = false;
      // Tentative trop chère : le retour est proposé à la place.
      _choice = switch (_topUpFor) {
        'RETRY' => 'RETURN',
        'RETURN' => null,
        _ => _choice,
      };
    });
  }

  Future<void> _rate() async {
    if (_stars == 0) return;
    setState(() => _busy = true);
    try {
      final given = await ref
          .read(clientApiProvider)
          .rateRider(widget.orderId, score: _stars, comment: _comment.text.trim());
      if (!mounted) return;
      TaraFeedback.play(context, TaraSound.sent);
      setState(() {
        _order = _order?.withRating(given);
        _error = null;
      });
    } catch (error) {
      if (mounted) setState(() => _error = errorMessage(context, error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel() async {
    final l = AppLocalizations.of(context);
    if (!_confirmCancel) {
      setState(() => _confirmCancel = true);
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(clientApiProvider).cancelOrder(widget.orderId, l.cancelReasonSender);
      ref.invalidate(activeOrdersProvider);
      await _load();
    } catch (error) {
      if (mounted) setState(() => _error = errorMessage(context, error));
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _confirmCancel = false;
        });
      }
    }
  }

  /// Le récapitulatif part en image (WhatsApp, SMS…), avec une ligne de texte.
  Future<void> _share(TrackedOrder order) async {
    final l = AppLocalizations.of(context);
    final delivered = order.reachedAt('DELIVERED') ?? _now;
    final text = l.recapShareText(order.reference, order.recipientName, formatClock(delivered));
    Uint8List? png;
    try {
      final boundary = _recap.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      final image = await boundary?.toImage(pixelRatio: 3);
      final bytes = await image?.toByteData(format: ui.ImageByteFormat.png);
      png = bytes?.buffer.asUint8List();
    } catch (_) {
      // Image impossible : le texte part seul.
    }
    await ref.read(shareProvider)(text, png);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final order = _order;
    final height = MediaQuery.sizeOf(context).height;
    final delivered = order?.status == 'DELIVERED';
    final deciding = order != null && _deciding(order);
    // Colis gardé au bureau Tara (ou non réclamé) : page entière, comme l'échec.
    final atOffice = order != null && const ['HELD_AT_OFFICE', 'UNCLAIMED'].contains(order.status);
    final panel = height * (delivered ? .66 : (deciding ? .62 : .48));
    final top = MediaQuery.paddingOf(context).top + 72;
    // Livré, ou livraison impossible à trancher : page entière sans carte (maquettes).
    if (order != null && (delivered || deciding || atOffice)) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) widget.onBack();
        },
        child: TaraScreen(
          blobs: _pageBlobs,
          safeBottom: false,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                    child: Row(
                      children: [
                        GlassIconButton(icon: TaraIcons.chevronLeft, label: l.back, onPressed: widget.onBack),
                        const SizedBox(width: 10),
                        Expanded(child: _Header(order: order)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: atOffice
                        ? _OfficePage(
                            order: order,
                            now: _now,
                            quote: _quote,
                            busy: _busy,
                            error: _error,
                            topUp: _topUpState(),
                            code: _pickupCode,
                            codeSent: _officeCodeSent,
                            onPay: () => unawaited(_payOffice()),
                            onNewCode: () => unawaited(_newPickupCode()),
                            onReport: () => unawaited(
                              reportProblem(context, ref, orderId: order.id, orderReference: order.reference),
                            ),
                          )
                        : delivered
                        ? _DeliveredPage(
                            order: order,
                            now: _now,
                            photo: _proofPhoto,
                            stars: _stars,
                            comment: _comment,
                            busy: _busy,
                            error: _error,
                            onStars: (stars) => setState(() => _stars = stars),
                            onRate: () => unawaited(_rate()),
                            onReceipt: () => unawaited(_showReceipt(order)),
                          )
                        : _DecidePage(
                            order: order,
                            now: _now,
                            photo: _proofPhoto,
                            choice: _choice,
                            busy: _busy,
                            error: _error,
                            onChoose: (choice) => setState(() => _choice = choice),
                            onDecide: () => unawaited(_decide()),
                            topUp: _topUpState(),
                            quote: _quote,
                            onCallRecipient: () =>
                                unawaited(ref.read(launcherProvider)(Uri(scheme: 'tel', path: order.recipientPhone))),
                          ),
                  ),
                ],
              ),
              if (_celebrate) const Positioned.fill(child: Confetti()),
            ],
          ),
        ),
      );
    }
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) widget.onBack();
      },
      child: TaraScreen(
        safeTop: false,
        safeBottom: false,
        background: Positioned.fill(
          child: order == null
              ? ColoredBox(color: c.mapGround)
              : TrackingMap(
                  pickup: MapPoint(order.pickup.latitude, order.pickup.longitude),
                  dropoff: MapPoint(order.dropoff.latitude, order.dropoff.longitude),
                  rider: _riderShown(order),
                  heading: _heading,
                  searching: order.status == 'SEARCHING_RIDER' && !_scheduledLater(order),
                  toDropoff:
                      const ['PICKED_UP', 'IN_DELIVERY', 'DELIVERED'].contains(order.status) ||
                      (order.status == 'DELIVERY_FAILED' && order.failure?.decision != 'RETURN'),
                  framePadding: EdgeInsets.only(top: top, bottom: panel - 20),
                  route: _route,
                  landmarks: ref.watch(landmarksProvider).value ?? const [],
                ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Row(
                    children: [
                      GlassIconButton(icon: TaraIcons.chevronLeft, label: l.back, onPressed: widget.onBack),
                      const SizedBox(width: 10),
                      if (order != null) Expanded(child: _Header(order: order)),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: panel,
              child: SheetPanel(
                child: order == null
                    ? Center(
                        child: _error == null
                            ? const GooLoader()
                            : Padding(padding: const EdgeInsets.all(24), child: ErrorLine(_error!)),
                      )
                    : _Panel(
                        order: order,
                        now: _now,
                        waiting: ref.watch(appConfigProvider).value?.waiting ?? const WaitingRules(),
                        rider: _rider,
                        // Code d'enlèvement : celui de la commande tant que le colis n'est pas parti.
                        pickupCode:
                            _pickupCode ??
                            (const ['CREATED', 'SEARCHING_RIDER', 'ASSIGNED'].contains(order.status)
                                ? _storedCode
                                : null),
                        confirmCancel: _confirmCancel,
                        busy: _busy,
                        error: _error,
                        onNewPickupCode: () => unawaited(_newPickupCode()),
                        onCancel: () => unawaited(_cancel()),
                        pay: _PayState(
                          // Frais Mobile Money en plus, comme à la commande (payés par l'expéditeur).
                          amount:
                              order.totalPrice +
                              mobileMoneyFee(
                                order.totalPrice,
                                ref.watch(appConfigProvider).value?.mobileMoneyFeeBps ?? 0,
                              ),
                          phone: _payPhone,
                          pending: _orderPayment != null,
                          failed: _orderPayFailed,
                          onPay: () => unawaited(_payOrder(order)),
                        ),
                        onCall: (phone) => unawaited(ref.read(launcherProvider)(Uri(scheme: 'tel', path: phone))),
                        onMessage: () => unawaited(_openChat(order)),
                        unread: _unread,
                        riderPhoto: _riderPhoto,
                        onReport: () =>
                            unawaited(reportProblem(context, ref, orderId: order.id, orderReference: order.reference)),
                      ),
              ),
            ),
            if (_celebrate) const Positioned.fill(child: Confetti()),
          ],
        ),
      ),
    );
  }

  _TopUpState? _topUpState() => _topUp == null
      ? null
      : _TopUpState(
          purpose: _topUpFor,
          amount: _topUp!,
          operator: _topUpOperator,
          phone: _topUpPhone,
          pending: _topUpPayment != null,
          failed: _topUpFailed,
          onOperator: (value) => setState(() => _topUpOperator = value),
          onPay: () => unawaited(_payTopUp()),
          onCancel: _cancelTopUp,
        );

  /// Fond liquide des pages sans carte (maquettes Livré, Livraison impossible).
  static const _pageBlobs = [
    BlobSpec(alignment: Alignment(-.74, -.76), size: 320, colors: BlobSpec.soft, blur: 46),
    BlobSpec(
      alignment: Alignment(.74, -.05),
      size: 280,
      colors: BlobSpec.warm,
      blur: 46,
      opacity: .5,
      delay: Duration(seconds: 5),
    ),
    BlobSpec(
      alignment: Alignment(-.64, .78),
      size: 260,
      colors: BlobSpec.soft,
      blur: 46,
      opacity: .67,
      delay: Duration(seconds: 10),
    ),
  ];

  /// « Reçu » : le récapitulatif à partager en image.
  Future<void> _showReceipt(TrackedOrder order) async {
    final l = AppLocalizations.of(context);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SheetPanel(
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                RepaintBoundary(
                  key: _recap,
                  child: _Recap(order: order),
                ),
                const SizedBox(height: 14),
                PrimaryButton(label: l.shareRecap, icon: TaraIcons.send, onPressed: () => unawaited(_share(order))),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// La moto n'est montrée que pendant la course.
  MapPoint? _riderShown(TrackedOrder order) =>
      const ['ASSIGNED', 'PICKED_UP', 'IN_DELIVERY', 'DELIVERY_FAILED'].contains(order.status) ? _rider : null;

  bool _scheduledLater(TrackedOrder order) => order.scheduledFor?.isAfter(_now) ?? false;

  static bool _deciding(TrackedOrder order) => order.status == 'DELIVERY_FAILED' && order.failure?.decision == null;
}

/// Panneau du bas : étape en cours, progression, livreur, destinataire, actions ; une fois
/// livré, le récapitulatif à partager.
class _Panel extends StatelessWidget {
  const _Panel({
    required this.order,
    required this.now,
    this.waiting = const WaitingRules(),
    required this.rider,
    required this.pickupCode,
    required this.confirmCancel,
    required this.busy,
    required this.error,
    required this.onNewPickupCode,
    required this.onCancel,
    this.pay,
    required this.onCall,
    required this.onReport,
    required this.onMessage,
    this.unread = 0,
    this.riderPhoto,
  });

  /// Conversation avec le livreur ; messages pas encore lus.
  final VoidCallback onMessage;
  final int unread;
  final Uint8List? riderPhoto;

  final TrackedOrder order;
  final DateTime now;

  /// Attente gratuite puis payante quand le livreur est arrivé (D).
  final WaitingRules waiting;
  final MapPoint? rider;
  final String? pickupCode;
  final bool confirmCancel;
  final bool busy;
  final String? error;
  final VoidCallback onNewPickupCode;
  final VoidCallback onCancel;

  /// Frais Mobile Money pas encore payés : numéro qui paie, demande envoyée ou refusée.
  final _PayState? pay;
  final ValueChanged<String> onCall;

  /// « Signaler un problème » : demande au service client sur cette commande.
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final o = order;
    final recipientFirst = o.recipientName.trim().split(RegExp(r'\s+')).first;
    final riderName = o.rider?.name ?? '';
    final pickedUpAt = o.reachedAt('PICKED_UP');
    final deliveredAt = o.reachedAt('DELIVERED');
    final scheduled = o.scheduledFor != null && o.scheduledFor!.isAfter(now);
    final failure = o.status == 'DELIVERY_FAILED' ? o.failure : null;
    final deciding = o.status == 'DELIVERY_FAILED' && failure?.decision == null;
    final returning = failure?.decision == 'RETURN';
    final (title, body) = switch (o.status) {
      _ when o.awaitingPayment => (l.trackAwaitingPayment, l.trackAwaitingPaymentBody),
      _ when scheduled && const ['CREATED', 'SEARCHING_RIDER'].contains(o.status) => (
        l.trackScheduled,
        l.scheduledPickup(formatClock(o.scheduledFor!)),
      ),
      'CREATED' || 'SEARCHING_RIDER' => (l.trackSearching, l.trackSearchingBody),
      // Le livreur est sur place : l'attente gratuite a une fin, annoncée (D).
      'ASSIGNED' when o.riderArrivedAt != null => (
        l.trackRiderWaiting(riderName),
        l.trackRiderWaitingBody(
          formatClock(o.riderArrivedAt!.add(Duration(minutes: waiting.freeMinutes))),
          '${formatAmount(waiting.feePerStep)}\u00a0F',
          waiting.stepMinutes,
          '${formatAmount(waiting.maxFee)}\u00a0F',
        ),
      ),
      // Tournée (2c) : le même livreur emporte plusieurs colis de l'envoi, tous à lui donner.
      'ASSIGNED' when o.tourNumbers.length > 1 => (
        l.trackAssignedTour(riderName, _numbers(l, o.tourNumbers)),
        l.trackAssignedTourBody(o.tourNumbers.length),
      ),
      'ASSIGNED' => switch (o.batchNumber) {
        // Plusieurs colis : lequel donner à ce livreur.
        final number? => (l.trackAssignedParcel(riderName, number), l.trackAssignedParcelBody(number)),
        null => (l.trackAssigned(riderName), l.trackAssignedBody),
      },
      'PICKED_UP' ||
      'IN_DELIVERY' => (l.trackOnTheWay(recipientFirst), l.trackOnTheWayBody(formatClock(pickedUpAt ?? now))),
      'DELIVERY_FAILED' when failure?.decision == 'RETRY' => (
        l.trackRetrying,
        l.trackRetryingBody(riderName, recipientFirst),
      ),
      'DELIVERY_FAILED' when returning => (l.trackReturning, l.trackReturningBody(riderName)),
      // Retour non payé à temps : le colis part au bureau Tara.
      'DELIVERY_FAILED' when failure?.decision == 'OFFICE' => (
        l.trackToOffice,
        l.trackToOfficeBody(riderName, '${formatAmount(o.office?.due ?? o.returnFee)}\u00a0F'),
      ),
      'DELIVERY_FAILED' when failure != null => (
        l.trackFailed,
        l.failureReported(_reason(l, failure.reason), riderName, formatClock(failure.at)),
      ),
      'DELIVERY_FAILED' => (l.trackFailed, l.trackFailedBody),
      'DELIVERED' => (l.trackDelivered, l.trackDeliveredBody(recipientFirst, formatClock(deliveredAt ?? now))),
      'RETURNED' => (l.trackReturned, l.trackReturnedBody(formatClock(o.reachedAt('RETURNED') ?? now))),
      // Livreur parti après l'attente maximale (D) : annulation et attente facturées.
      'CANCELLED' when o.senderAbsent => (
        l.trackSenderAbsent,
        l.trackSenderAbsentBody(waiting.maxMinutes, '${formatAmount(waiting.absentFee)}\u00a0F'),
      ),
      // Colis non conforme refusé à l'enlèvement : le motif et le déplacement facturé.
      'CANCELLED' when o.refusalReason != null => (
        l.trackRefused,
        l.trackRefusedBody(o.refusalReason!, '${formatAmount(o.retryFee)} F'),
      ),
      _ => (l.trackCancelled, ''),
    };
    final eta = _eta(o);
    // Course en cours (maquette) : la barre d'avancée en tête du panneau.
    final flowing = const ['CREATED', 'SEARCHING_RIDER', 'ASSIGNED', 'PICKED_UP', 'IN_DELIVERY'].contains(o.status);
    final content = <Widget>[
      if (flowing) ...[_FlowSteps(order: o), const SizedBox(height: 12)],
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Semantics(
              header: true,
              liveRegion: true,
              child: Text(title, style: TaraText.titlePanel.copyWith(color: c.textPrimary, fontSize: 19)),
            ),
          ),
          if (deciding && failure?.decisionDueAt != null) ...[
            const SizedBox(width: 10),
            InfoPill(label: l.failureDue(formatClock(failure!.decisionDueAt!)), icon: TaraIcons.clock),
          ] else if (eta != null) ...[
            const SizedBox(width: 10),
            // Minutes avant l'arrivée (maquette) : pastille orange.
            Semantics(
              label: l.trackEta(eta),
              excludeSemantics: true,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color.fromRGBO(255, 177, 92, .14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  l.etaMinutes(eta),
                  style: TaraText.label.copyWith(color: c.accentText, fontSize: 13, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ],
      ),
      if (body.isNotEmpty) ...[
        const SizedBox(height: 4),
        Text(body, style: TaraText.label.copyWith(color: c.textSecondary, fontSize: 13)),
      ],
      if (deciding && (failure?.note?.isNotEmpty ?? false)) ...[
        const SizedBox(height: 4),
        Text(
          l.riderNoteQuoted(failure!.note!),
          style: TaraText.label.copyWith(color: c.textPrimary, fontStyle: FontStyle.italic),
        ),
      ],
      const SizedBox(height: 16),
      // Livré : le récapitulatif reprend les heures, la frise laisse la place à la note.
      // Échec, retour : la frise avec les heures, sous le titre.
      if (!flowing && !returning) ...[_Steps(order: o), const SizedBox(height: 16)],
      if (failure?.decision == 'OFFICE' && o.office != null) ...[
        _OfficeCard(office: o.office!, now: now),
        const SizedBox(height: 12),
      ],
      if (o.awaitingPayment && pay != null) ...[
        _PayCard(state: pay!, operator: o.feePaymentMethod == 'MOMO_ORANGE' ? l.payOrange : l.payMtn),
        const SizedBox(height: 16),
      ],
      if (returning) ...[
        // Code de retour (maquette) : à donner au livreur quand il rend le colis.
        if (pickupCode != null)
          _ReturnCodeCard(code: pickupCode!)
        else
          TintBox(
            tone: TintTone.accent,
            child: Text(l.returnCodeHint, style: TaraText.label.copyWith(color: c.textPrimary)),
          ),
        if (o.returnFee > 0) ...[
          const SizedBox(height: 10),
          Text(
            l.returnFeeHint('${formatAmount(o.returnFee)} F'),
            style: TaraText.small.copyWith(color: c.textSecondary),
          ),
        ],
        const SizedBox(height: 12),
      ],
      ...[
        if (o.rider case final rider? when rider.phone != null) ...[
          _RiderCard(
            rider: rider,
            photo: riderPhoto,
            unread: unread,
            onCall: () => onCall(rider.phone!),
            onMessage: onMessage,
          ),
          const SizedBox(height: 12),
        ],
        // Code d'enlèvement à donner au livreur (maquette).
        if (pickupCode != null && const ['CREATED', 'SEARCHING_RIDER', 'ASSIGNED'].contains(o.status)) ...[
          _PickupCodeCard(code: pickupCode!, reference: o.reference),
          const SizedBox(height: 12),
        ],
        _recipientRow(l, o, recipientFirst),
        if (returning && pickupCode == null)
          Align(
            alignment: Alignment.centerLeft,
            child: TaraLink(label: l.newReturnCode, onPressed: busy ? null : onNewPickupCode),
          ),
        if (const ['SEARCHING_RIDER', 'ASSIGNED'].contains(o.status) && pickupCode == null)
          Align(
            alignment: Alignment.centerLeft,
            child: TaraLink(label: l.newPickupCode, onPressed: busy ? null : onNewPickupCode),
          ),
        // Jusqu'à l'enlèvement ; livreur déjà en route : son déplacement est annoncé avant.
        if (const ['CREATED', 'SEARCHING_RIDER', 'ASSIGNED'].contains(o.status)) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: TaraLink(label: l.cancelDelivery, onPressed: busy ? null : onCancel),
          ),
          if (confirmCancel)
            Text(
              o.cancellationFee > 0 ? l.cancelConfirmFee('${formatAmount(o.cancellationFee)}\u00a0F') : l.cancelConfirm,
              style: TaraText.small.copyWith(color: c.dangerText),
            ),
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: TaraLink(label: l.reportProblem, onPressed: onReport),
        ),
      ],
      if (error != null) ...[const SizedBox(height: 8), ErrorLine(error!)],
    ];
    // Frais Mobile Money pas encore payés : relancer le paiement (aucun livreur avant).
    if (o.awaitingPayment && pay != null) {
      final state = pay!;
      return ScrollWithFooter(
        horizontal: 20,
        top: 4,
        content: content,
        footer: PrimaryButton(
          label: l.trackPayNow('${formatAmount(state.amount)} F'),
          icon: TaraIcons.phone,
          loading: busy || state.pending,
          onPressed: busy || state.pending ? null : state.onPay,
        ),
      );
    }
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 4, 20, 20 + MediaQuery.paddingOf(context).bottom),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: content),
    );
  }

  /// Destinataire : adresse, et son numéro à appeler quand la livraison bute (bouton à
  /// part : la ligne fusionne sa sémantique).
  Widget _recipientRow(AppLocalizations l, TrackedOrder o, String first) {
    // Retour décidé : c'est l'adresse d'enlèvement qui compte désormais.
    if (o.status == 'DELIVERY_FAILED' && o.failure?.decision == 'RETURN') {
      return ListRow(
        leading: const IconTile(icon: TaraIcons.returnArrow, size: 40),
        title: l.returnToPickup,
        subtitle: o.pickup.summary,
      );
    }
    final row = ListRow(
      leading: const IconTile(icon: TaraIcons.mapPin, size: 40),
      title: l.forRecipient(o.recipientName),
      subtitle: o.dropoff.summary,
    );
    if (o.status != 'DELIVERY_FAILED') return row;
    return Row(
      children: [
        Expanded(child: row),
        const SizedBox(width: 10),
        GlassIconButton(
          icon: TaraIcons.phone,
          label: l.callRecipient(first),
          onPressed: () => onCall(o.recipientPhone),
        ),
      ],
    );
  }

  /// « 4, 9 et 12 » : numéros des colis d'une tournée.
  static String _numbers(AppLocalizations l, List<int> numbers) => numbers.length == 1
      ? '${numbers.single}'
      : l.listAnd(numbers.take(numbers.length - 1).join(', '), '${numbers.last}');

  static String _reason(AppLocalizations l, String? reason) => switch (reason) {
    'RECIPIENT_ABSENT' => l.failureReasonRecipientAbsent,
    'RECIPIENT_UNREACHABLE' => l.failureReasonRecipientUnreachable,
    'REFUSED' => l.failureReasonRefused,
    'ADDRESS_NOT_FOUND' => l.failureReasonAddressNotFound,
    'PAYMENT_REFUSED' => l.failureReasonPaymentRefused,
    'DAMAGED' => l.failureReasonDamaged,
    _ => l.failureReasonOther,
  };

  /// Arrivée estimée (prudente) du livreur à l'étape visée, en minutes.
  int? _eta(TrackedOrder o) {
    final position = rider;
    if (position == null) return null;
    final target = switch (o.status) {
      'ASSIGNED' => o.pickup,
      'PICKED_UP' || 'IN_DELIVERY' => o.dropoff,
      'DELIVERY_FAILED' => switch (o.failure?.decision) {
        'RETURN' => o.pickup,
        'RETRY' => o.dropoff,
        _ => null,
      },
      _ => null,
    };
    if (target == null) return null;
    final meters = _distance(position, MapPoint(target.latitude, target.longitude));
    return math.max(1, (meters / _metersPerMinute).ceil());
  }

  static double _distance(MapPoint a, MapPoint b) {
    const earth = 6371000.0;
    double rad(double deg) => deg * math.pi / 180;
    final dLat = rad(b.latitude - a.latitude);
    final dLng = rad(b.longitude - a.longitude);
    final h =
        math.pow(math.sin(dLat / 2), 2) +
        math.cos(rad(a.latitude)) * math.cos(rad(b.latitude)) * math.pow(math.sin(dLng / 2), 2);
    return 2 * earth * math.asin(math.sqrt(h));
  }
}

/// Les quatre étapes : commande, livreur, colis récupéré, livré, avec leur heure.
class _Steps extends StatelessWidget {
  const _Steps({required this.order});

  final TrackedOrder order;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    // Échec ou retour : la dernière étape le dit, en rouge tant que rien n'est décidé.
    final failed = order.status == 'DELIVERY_FAILED' || order.status == 'UNCLAIMED';
    final last = switch (order.status) {
      'DELIVERY_FAILED' => (l.stepFailed, order.failure?.at ?? order.timeline.lastOrNull?.at),
      'RETURNED' => (l.stepReturned, order.reachedAt('RETURNED')),
      'HELD_AT_OFFICE' => (l.stepAtOffice, order.reachedAt('HELD_AT_OFFICE')),
      'UNCLAIMED' => (l.stepUnclaimed, order.reachedAt('UNCLAIMED')),
      _ => (l.stepDelivered, order.reachedAt('DELIVERED')),
    };
    final steps = [
      (l.stepOrdered, order.createdAt),
      (l.stepRiderFound, order.reachedAt('ASSIGNED')),
      (l.stepPickedUp, order.reachedAt('PICKED_UP')),
      last,
    ];
    final done = steps.lastIndexWhere((step) => step.$2 != null);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, (label, at)) in steps.indexed) ...[
          Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: i == 0
                          ? const SizedBox.shrink()
                          : Container(height: 3, color: i <= done ? TaraBrand.orange : c.track),
                    ),
                    Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: i <= done && !(failed && i == 3) ? TaraBrand.gradient : null,
                        color: failed && i == 3 ? c.dangerText : (i <= done ? null : c.track),
                        border: i == done + 1 ? Border.all(color: TaraBrand.orange, width: 2) : null,
                      ),
                    ),
                    Expanded(
                      child: i == steps.length - 1
                          ? const SizedBox.shrink()
                          : Container(height: 3, color: i < done ? TaraBrand.orange : c.track),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TaraText.small.copyWith(
                    color: failed && i == 3 ? c.dangerText : (i <= done ? c.textPrimary : c.textTertiary),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  at == null ? ' ' : formatClock(at),
                  style: TaraText.small.copyWith(color: c.textTertiary, fontFeatures: TaraText.tabular),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Avancée de la course (maquette) : barre qui coule jusqu'à l'étape, quatre libellés
/// en orange une fois atteints.
class _FlowSteps extends StatelessWidget {
  const _FlowSteps({required this.order});
  final TrackedOrder order;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final (reached, ratio) = switch (order.status) {
      'ASSIGNED' => (1, .38),
      'PICKED_UP' || 'IN_DELIVERY' => (2, .70),
      _ => (0, .10),
    };
    final labels = [l.stepOrdered, l.stepRiderFound, l.stepPickedUp, l.stepDelivered];
    return Semantics(
      label: labels.take(reached + 1).join(', '),
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: SizedBox(
              height: 6,
              child: Stack(
                children: [
                  Positioned.fill(child: ColoredBox(color: c.textPrimary.withValues(alpha: .10))),
                  TweenAnimationBuilder<double>(
                    tween: Tween(end: ratio),
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, _) => FractionallySizedBox(
                      widthFactor: value,
                      child: const FlowingGradient(
                        colors: [TaraBrand.amber, TaraBrand.orange, TaraBrand.red, TaraBrand.orange, TaraBrand.amber],
                        period: Duration(milliseconds: 2600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final (i, label) in labels.indexed)
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TaraText.small.copyWith(
                      color: i <= reached ? c.accentText : c.textPrimary.withValues(alpha: .45),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Le livreur (maquette) : photo ou initiales sur tuile orange, « Jean M. · 4,8 ★ »,
/// véhicule et plaque, message et appel.
class _RiderCard extends StatelessWidget {
  const _RiderCard({required this.rider, required this.onCall, required this.onMessage, this.photo, this.unread = 0});

  final OrderRider rider;
  final VoidCallback onCall;
  final VoidCallback onMessage;
  final Uint8List? photo;
  final int unread;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final locale = Localizations.localeOf(context);
    final vehicle = switch (rider.vehicleType) {
      'CAR' => l.vehicleCar,
      'TRICYCLE' => l.vehicleTricycle,
      _ => l.vehicleMotorbike,
    };
    final color = rider.vehicleColor;
    final model = [
      if (rider.vehicleBrand case final brand?) vehicleBrandName(brand, locale) else vehicle,
      if (color != null) vehicleColorName(color, locale).toLowerCase(),
      ?rider.plateNumber,
    ].join(' · ');
    final initials = rider.name
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();
    final rating = rider.rating;
    return Row(
      children: [
        MergeSemantics(
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(gradient: TaraBrand.gradient, borderRadius: BorderRadius.circular(14)),
            clipBehavior: Clip.antiAlias,
            alignment: Alignment.center,
            child: photo != null
                ? Image.memory(photo!, width: 42, height: 42, fit: BoxFit.cover, gaplessPlayback: true)
                : Text(
                    initials,
                    style: TaraText.titlePanel.copyWith(
                      color: TaraBrand.onBrand,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: MergeSemantics(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rating == null ? rider.name : '${rider.name} · ${rating.toStringAsFixed(1).replaceAll('.', ',')} ★',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TaraText.text.copyWith(color: c.textPrimary, fontSize: 14, fontWeight: FontWeight.w700),
                ),
                Row(
                  children: [
                    if (color != null) ...[
                      Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: vehicleColors[color],
                          shape: BoxShape.circle,
                          border: Border.all(color: c.textPrimary.withValues(alpha: .25)),
                        ),
                      ),
                      const SizedBox(width: 5),
                    ],
                    Flexible(
                      child: Text(
                        model,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TaraText.small.copyWith(color: c.textTertiary, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        GlassIconButton(
          icon: TaraIcons.message,
          label: l.chatWithRider(rider.name),
          badge: unread > 0,
          onPressed: onMessage,
        ),
        const SizedBox(width: 8),
        // Appel en vert, comme sur la maquette.
        Semantics(
          button: true,
          label: l.callRider(rider.name),
          excludeSemantics: true,
          child: Squish(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onCall,
              child: Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(shape: BoxShape.circle, color: Color.fromRGBO(74, 222, 155, .14)),
                alignment: Alignment.center,
                child: TaraIcon(TaraIcons.phone, size: 20, color: c.success),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// « CODE D'ENLÈVEMENT » : les 4 chiffres à dicter au livreur, sur une carte (maquette).
class _PickupCodeCard extends StatelessWidget {
  const _PickupCodeCard({required this.code, required this.reference});
  final String code;
  final String reference;

  /// Le QR en grand, pour que le livreur le scanne de près.
  void _enlarge(BuildContext context) {
    final l = AppLocalizations.of(context);
    unawaited(
      showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (context) => SheetPanel(
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l.pickupCodeLabel,
                    style: TaraText.cardTitle.copyWith(color: TaraColors.of(context).textPrimary),
                  ),
                  const SizedBox(height: 14),
                  PickupQr(reference: reference, code: code, size: 240),
                  const SizedBox(height: 12),
                  Text(
                    code.split('').join(' '),
                    style: TaraText.titlePanel.copyWith(
                      color: TaraColors.of(context).textPrimary,
                      fontSize: 28,
                      letterSpacing: 6,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final spaced = code.split('').join(' ');
    Widget corner(Alignment at) => Align(
      alignment: at,
      child: Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          border: Border(
            top: at.y < 0 ? const BorderSide(color: TaraBrand.orange, width: 3) : BorderSide.none,
            bottom: at.y > 0 ? const BorderSide(color: TaraBrand.orange, width: 3) : BorderSide.none,
            left: at.x < 0 ? const BorderSide(color: TaraBrand.orange, width: 3) : BorderSide.none,
            right: at.x > 0 ? const BorderSide(color: TaraBrand.orange, width: 3) : BorderSide.none,
          ),
          borderRadius: BorderRadius.only(
            topLeft: at == Alignment.topLeft ? const Radius.circular(6) : Radius.zero,
            topRight: at == Alignment.topRight ? const Radius.circular(6) : Radius.zero,
            bottomLeft: at == Alignment.bottomLeft ? const Radius.circular(6) : Radius.zero,
            bottomRight: at == Alignment.bottomRight ? const Radius.circular(6) : Radius.zero,
          ),
        ),
      ),
    );
    return Semantics(
      label: '${l.pickupCodeLabel} : $spaced',
      button: true,
      excludeSemantics: true,
      onTap: () => _enlarge(context),
      child: GestureDetector(
        onTap: () => _enlarge(context),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: boxedFieldFill(c),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: boxedFieldBorder(c)),
            boxShadow: const [
              BoxShadow(color: Color.fromRGBO(140, 70, 10, .08), blurRadius: 28, offset: Offset(0, 12)),
            ],
          ),
          child: Row(
            children: [
              // Clé dans un cadre de visée orange.
              SizedBox.square(
                dimension: 64,
                child: Stack(
                  children: [
                    Positioned.fill(
                      // QR du code dans le cadre de visée (touché : en grand pour le livreur).
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: PickupQr(reference: reference, code: code, size: 56),
                      ),
                    ),
                    corner(Alignment.topLeft),
                    corner(Alignment.topRight),
                    corner(Alignment.bottomLeft),
                    corner(Alignment.bottomRight),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.pickupCodeLabel.toUpperCase(),
                      style: TaraText.small.copyWith(
                        color: c.accentText,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: .66,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      spaced,
                      style: TaraText.titlePanel.copyWith(color: c.textPrimary, fontSize: 26, letterSpacing: 5),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l.pickupCodeDictate,
                      style: TaraText.small.copyWith(
                        color: c.textPrimary.withValues(alpha: .7),
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Récapitulatif d'une livraison réussie, partagé en image : marque, destinataire, heure,
/// durée, livreur, montant encaissé.
class _Recap extends StatelessWidget {
  const _Recap({required this.order});

  final TrackedOrder order;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final o = order;
    final delivered = o.reachedAt('DELIVERED');
    final started = o.reachedAt('PICKED_UP') ?? o.createdAt;
    final minutes = delivered == null ? null : math.max(1, delivered.difference(started).inMinutes);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: c.glassBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
            decoration: const BoxDecoration(
              gradient: TaraBrand.gradient,
              borderRadius: BorderRadius.vertical(top: Radius.circular(23)),
            ),
            child: Row(
              children: [
                const TaraIcon(TaraIcons.check, size: 24, strokeWidth: 2.6, color: TaraBrand.onBrand),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(l.trackDelivered, style: TaraText.cardTitle.copyWith(color: TaraBrand.onBrand)),
                ),
                Text('Tara', style: TaraText.cardTitle.copyWith(color: TaraBrand.onBrand)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  o.recipientName,
                  style: TaraText.text.copyWith(color: c.textPrimary, fontWeight: FontWeight.w800),
                ),
                Text(o.dropoff.summary, style: TaraText.small.copyWith(color: c.textSecondary)),
                const SizedBox(height: 10),
                Text(
                  [
                    if (delivered != null) formatClock(delivered),
                    if (minutes != null) l.deliveredIn(minutes),
                    if (o.rider != null) l.deliveredBy(o.rider!.name),
                  ].join(' · '),
                  style: TaraText.label.copyWith(color: c.textPrimary),
                ),
                if (o.codAmount > 0) ...[
                  const SizedBox(height: 6),
                  Text(
                    l.collectedAmount('${formatAmount(o.codAmount)} F'),
                    style: TaraText.label.copyWith(color: c.success, fontWeight: FontWeight.w800),
                  ),
                ],
                const SizedBox(height: 6),
                Text(o.reference, style: TaraText.small.copyWith(color: c.textTertiary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// « Comment s'est passée la livraison ? » : étoiles, mot pour l'équipe, envoi ; une fois
/// Paiement Mobile Money des frais relancé depuis le suivi.
class _PayState {
  const _PayState({
    required this.amount,
    required this.phone,
    required this.pending,
    required this.failed,
    required this.onPay,
  });

  /// Montant demandé : la course et les frais Mobile Money.
  final int amount;
  final TextEditingController phone;

  /// Demande envoyée au téléphone, en attente de validation.
  final bool pending;
  final bool failed;
  final VoidCallback onPay;
}

/// Numéro qui paie les frais (celui du compte par défaut), puis validation sur le téléphone.
class _PayCard extends StatelessWidget {
  const _PayCard({required this.state, required this.operator});

  final _PayState state;

  /// Opérateur choisi à la commande (« MTN MoMo », « Orange Money »).
  final String operator;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    return GlassCard(
      radius: 22,
      shadow: false,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.trackPayVia(operator), style: TaraText.label.copyWith(color: c.textSecondary)),
          const SizedBox(height: 10),
          TaraTextField(
            label: l.payerPhoneLabel,
            hint: l.phoneHint,
            controller: state.phone,
            keyboardType: TextInputType.phone,
            inputFormatters: [PhoneInputFormatter()],
            leading: PhonePrefixButton(prefix: '+237', semanticLabel: l.countryCodeLabel('+237')),
          ),
          if (state.pending) ...[
            const SizedBox(height: 10),
            TintBox(
              tone: TintTone.accent,
              child: Text(l.trackPayPending, style: TaraText.label.copyWith(color: c.textPrimary)),
            ),
          ],
          if (state.failed) ...[const SizedBox(height: 10), ErrorLine(l.trackPayFailed)],
        ],
      ),
    );
  }
}

/// Recharge Mobile Money demandée avant une nouvelle tentative (solde insuffisant).
class _TopUpState {
  const _TopUpState({
    required this.purpose,
    required this.amount,
    required this.operator,
    required this.phone,
    required this.pending,
    required this.failed,
    required this.onOperator,
    required this.onPay,
    required this.onCancel,
  });

  /// RETRY, RETURN ou OFFICE : ce que paie la recharge (titre et explication).
  final String purpose;
  final int amount;
  final String operator;
  final TextEditingController phone;

  /// Demande envoyée au téléphone, en attente de validation.
  final bool pending;
  final bool failed;
  final ValueChanged<String> onOperator;
  final VoidCallback onPay;
  final VoidCallback onCancel;
}

/// « Rechargez 500 F pour la nouvelle tentative » : opérateur, numéro, puis validation sur
/// le téléphone ; ou le retour à la place.
class _TopUpCard extends StatelessWidget {
  const _TopUpCard({required this.state});

  final _TopUpState state;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final amount = '${formatAmount(state.amount)} F';
    return GlassCard(
      radius: 22,
      shadow: false,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(switch (state.purpose) {
            'RETURN' => l.returnPayTitle(amount),
            'OFFICE' => l.officePayTitle(amount),
            _ => l.topUpTitle(amount),
          }, style: TaraText.cardTitle.copyWith(color: c.textPrimary)),
          const SizedBox(height: 4),
          Text(switch (state.purpose) {
            'RETURN' => l.returnPayBody,
            'OFFICE' => l.officePayBody,
            _ => l.topUpBody,
          }, style: TaraText.small.copyWith(color: c.textSecondary)),
          const SizedBox(height: 12),
          ChoiceChips<String>(
            options: [operatorChoice('MTN', l.payMtn), operatorChoice('ORANGE', l.payOrange)],
            selected: state.operator,
            onSelected: state.pending ? (_) {} : state.onOperator,
          ),
          const SizedBox(height: 10),
          TaraTextField(
            label: l.payerPhoneLabel,
            hint: l.phoneHint,
            controller: state.phone,
            keyboardType: TextInputType.phone,
            inputFormatters: [PhoneInputFormatter()],
            leading: PhonePrefixButton(prefix: '+237', semanticLabel: l.countryCodeLabel('+237')),
          ),
          if (state.pending) ...[
            const SizedBox(height: 10),
            TintBox(
              tone: TintTone.accent,
              child: Text(l.topUpPending(amount), style: TaraText.label.copyWith(color: c.textPrimary)),
            ),
          ],
          if (state.failed) ...[const SizedBox(height: 10), ErrorLine(l.topUpFailed)],
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: TaraLink(label: l.topUpCancel, onPressed: state.onCancel),
          ),
        ],
      ),
    );
  }
}

/// En-tête des pages de suivi : référence et étape (« TR-48301 · livré »), trajet.
class _Header extends StatelessWidget {
  const _Header({required this.order});

  final TrackedOrder order;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final o = order;
    // Envoi de plusieurs colis : le numéro écrit sur ce colis.
    final reference = switch (o.batchNumber) {
      final number? => '${o.reference} · ${l.parcelNumberShort(number)}',
      null => o.reference,
    };
    final from = o.pickup.neighborhood?.name ?? o.pickup.landmark;
    final to = o.dropoff.neighborhood?.name ?? o.dropoff.landmark;
    final decision = o.status == 'DELIVERY_FAILED' ? o.failure?.decision : 'none';
    final (title, subtitle) = switch (o.status) {
      'DELIVERED' => (l.trackHeaderDelivered(reference), '$from → $to'),
      'DELIVERY_FAILED' when decision == null => (l.trackHeaderDeciding(reference), l.trackFailed),
      // Retour : le colis repart vers l'enlèvement.
      'DELIVERY_FAILED' when decision == 'RETURN' => (l.trackHeaderReturning(reference), '$to → $from'),
      'DELIVERY_FAILED' when decision == 'OFFICE' => (l.trackHeaderOffice(reference), l.statusToOffice),
      'HELD_AT_OFFICE' => (l.trackHeaderOffice(reference), l.statusAtOffice),
      'UNCLAIMED' => (l.trackHeaderOffice(reference), l.statusUnclaimed),
      _ => (reference, '$from → $to'),
    };
    return MergeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TaraText.titlePanel.copyWith(color: c.textPrimary, fontSize: 18),
          ),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TaraText.small.copyWith(color: c.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

/// Vignette d'une photo de preuve ; sans photo (pas encore reçue, effacée), un fond neutre.
/// Touchée, la photo s'ouvre en grand.
class _ProofThumb extends StatelessWidget {
  const _ProofThumb({required this.photo, required this.size});

  final Uint8List? photo;
  final double size;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final bytes = photo;
    final thumb = ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox.square(
        dimension: size,
        // Fond neutre sous la photo : jamais de trou blanc pendant le décodage.
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(-.35, -1),
              end: Alignment(.35, 1),
              colors: [Color(0xFF3A4A5C), Color(0xFF1E2732)],
              stops: [0, .6],
            ),
          ),
          child: bytes == null ? null : Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true),
        ),
      ),
    );
    if (bytes == null) return ExcludeSemantics(child: thumb);
    return Semantics(
      button: true,
      label: l.proofPhotoLabel,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () => unawaited(
          showDialog<void>(
            context: context,
            builder: (context) => GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: InteractiveViewer(child: Center(child: Image.memory(bytes))),
            ),
          ),
        ),
        child: thumb,
      ),
    );
  }
}

/// Colis livré (maquette) : coche liquide verte, remise et encaissement, photo de remise et
/// reçu, puis la note du livreur (F4) dans les 7 jours, une seule fois.
class _DeliveredPage extends StatelessWidget {
  const _DeliveredPage({
    required this.order,
    required this.now,
    required this.photo,
    required this.stars,
    required this.comment,
    required this.busy,
    required this.error,
    required this.onStars,
    required this.onRate,
    required this.onReceipt,
  });

  final TrackedOrder order;
  final DateTime now;
  final Uint8List? photo;
  final int stars;
  final TextEditingController comment;
  final bool busy;
  final String? error;
  final ValueChanged<int> onStars;
  final VoidCallback onRate;
  final VoidCallback onReceipt;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final o = order;
    final deliveredAt = o.reachedAt('DELIVERED') ?? o.delivery?.at ?? now;
    final time = formatClock(o.delivery?.at ?? deliveredAt);
    final headline = [
      l.trackDeliveredBody(o.recipientName, formatClock(deliveredAt)),
      if (o.codAmount > 0) l.deliveredCollectedForYou('${formatAmount(o.codAmount)} F'),
    ].join(' · ');
    final proof = switch (o.delivery) {
      OrderDelivery(hasPhoto: true, codeVerified: true) => l.deliveredProofCode(time),
      OrderDelivery(hasPhoto: true) => l.deliveredProofPhoto(time),
      OrderDelivery(codeVerified: true) => l.deliveredCodeOnly(time),
      OrderDelivery() => l.deliveredBySupport(time),
      // Serveur d'avant : l'heure et le livreur.
      null => [time, if (o.rider != null) l.deliveredBy(o.rider!.name)].join(' · '),
    };
    final rating = o.rating;
    final canRate = rating == null && o.rider != null && now.difference(deliveredAt) < const Duration(days: 7);
    final soft = c.textPrimary.withValues(alpha: .72);
    final content = <Widget>[
      // Coche dans une goutte verte qui ondule.
      Center(
        child: Container(
          width: 84,
          height: 84,
          decoration: const BoxDecoration(shape: BoxShape.circle, color: Color.fromRGBO(74, 222, 155, .14)),
          child: const ClipOval(
            child: Stack(
              fit: StackFit.expand,
              children: [
                LiquidFill(
                  level: .62,
                  amplitude: 5,
                  front: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF7CF0B8), Color(0xFF2CC28A), Color(0xFF0E7F57)],
                    stops: [0, .55, 1],
                  ),
                  back: Color.fromRGBO(44, 194, 138, .5),
                ),
                Center(child: TaraIcon(TaraIcons.check, size: 40, strokeWidth: 3.2, color: Colors.white)),
              ],
            ),
          ),
        ),
      ),
      const SizedBox(height: 8),
      Semantics(
        header: true,
        liveRegion: true,
        child: Text(
          l.trackDelivered,
          textAlign: TextAlign.center,
          style: TaraText.titlePanel.copyWith(color: c.textPrimary, fontSize: 24),
        ),
      ),
      const SizedBox(height: 8),
      Text(
        headline,
        textAlign: TextAlign.center,
        style: TaraText.label.copyWith(color: soft, fontSize: 13),
      ),
      const SizedBox(height: 12),
      GlassCard(
        radius: 22,
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            _ProofThumb(photo: photo, size: 64),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                proof,
                style: TaraText.small.copyWith(color: c.textPrimary.withValues(alpha: .75), fontSize: 12, height: 1.45),
              ),
            ),
            const SizedBox(width: 6),
            TaraLink(
              label: l.receipt,
              onPressed: onReceipt,
              style: TaraText.small.copyWith(fontSize: 12, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      if (rating != null)
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color.fromRGBO(74, 222, 155, .12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color.fromRGBO(74, 222, 155, .4)),
          ),
          child: Column(
            children: [
              StarRating(value: rating.score, onChanged: null, labelOf: l.starsLabel, size: 22),
              const SizedBox(height: 6),
              Text(
                l.rateThanks,
                textAlign: TextAlign.center,
                style: TaraText.text.copyWith(color: c.textPrimary, fontSize: 15, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                l.rateThanksBody,
                textAlign: TextAlign.center,
                style: TaraText.label.copyWith(color: c.textPrimary.withValues(alpha: .75), fontSize: 13),
              ),
            ],
          ),
        )
      else if (canRate) ...[
        Text(
          l.rateTitle,
          textAlign: TextAlign.center,
          style: TaraText.text.copyWith(color: c.textPrimary, fontSize: 16, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        Text(
          l.rateBody(o.rider!.name),
          textAlign: TextAlign.center,
          style: TaraText.label.copyWith(color: c.textPrimary.withValues(alpha: .7), fontSize: 13),
        ),
        const SizedBox(height: 12),
        Center(
          child: StarRating(value: stars, onChanged: busy ? null : onStars, labelOf: l.starsLabel),
        ),
        const SizedBox(height: 12),
        BoxedField(
          label: l.rateCommentHint,
          controller: comment,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.done,
          inputFormatters: [LengthLimitingTextInputFormatter(300)],
        ),
      ],
      if (error != null) ...[const SizedBox(height: 8), ErrorLine(error!)],
    ];
    if (!canRate) {
      return SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 36, 20, 20 + MediaQuery.paddingOf(context).bottom),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: content),
      );
    }
    return ScrollWithFooter(
      horizontal: 20,
      top: 36,
      content: content,
      footer: PrimaryButton(label: l.rateSend, loading: busy, onPressed: stars == 0 || busy ? null : onRate),
    );
  }
}

/// Livraison impossible (maquette) : minutes restantes pour choisir, preuve du livreur
/// (photo du lieu, appels), nouvelle tentative ou retour, chaque choix avec ses frais.
class _DecidePage extends StatelessWidget {
  const _DecidePage({
    required this.order,
    required this.now,
    required this.photo,
    required this.choice,
    required this.busy,
    required this.error,
    required this.onChoose,
    required this.onDecide,
    required this.topUp,
    required this.onCallRecipient,
    this.quote,
  });

  final TrackedOrder order;
  final DateTime now;
  final Uint8List? photo;
  final String? choice;

  /// Retour sans dette : frais, part payée par le solde, reste à payer (null : pas encore lu).
  final ReturnQuote? quote;
  final bool busy;
  final String? error;
  final ValueChanged<String> onChoose;
  final VoidCallback onDecide;

  /// Recharge demandée avant la nouvelle tentative (solde insuffisant).
  final _TopUpState? topUp;

  /// Appeler le destinataire avant de choisir (convenir d'un moment pour la tentative).
  final VoidCallback onCallRecipient;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final o = order;
    final failure = o.failure;
    final riderName = o.rider?.name ?? '';
    final recipientFirst = o.recipientName.trim().split(RegExp(r'\s+')).first;
    final due = failure?.decisionDueAt;
    final left = due?.difference(now);
    final minutes = left == null ? null : math.max(0, (left.inSeconds / 60).ceil());
    final total = due == null || failure == null ? null : due.difference(failure.at);
    final level = left == null || total == null || total.inSeconds <= 0
        ? 1.0
        : (left.inSeconds / total.inSeconds).clamp(0.0, 1.0);
    final detail = failure == null
        ? ''
        : [
            if (failure.hasPhoto)
              l.failurePlacePhoto(formatClock(failure.at))
            else
              l.failureReportedAt(formatClock(failure.at)),
            if (failure.calls > 0) l.failureCalls(failure.calls),
          ].join(' · ');
    final content = <Widget>[
      Row(
        children: [
          // Compte à rebours : la goutte se vide jusqu'au retour automatique.
          Semantics(
            label: minutes == null ? null : l.failureMinutesLeft(minutes),
            excludeSemantics: true,
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color.fromRGBO(255, 138, 61, .5), width: 3),
              ),
              child: ClipOval(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    LiquidFill(
                      level: level,
                      amplitude: 5,
                      front: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [TaraBrand.amber, TaraBrand.orange, TaraBrand.red],
                        stops: [0, .18, .5],
                      ),
                      back: const Color.fromRGBO(255, 61, 0, .5),
                    ),
                    if (minutes != null)
                      Center(
                        child: Text(
                          '$minutes′',
                          style: TaraText.text.copyWith(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            shadows: const [
                              Shadow(color: Color.fromRGBO(0, 0, 0, .4), blurRadius: 4, offset: Offset(0, 1)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  liveRegion: true,
                  child: Text(l.trackFailed, style: TaraText.titlePanel.copyWith(color: c.textPrimary, fontSize: 19)),
                ),
                const SizedBox(height: 3),
                Text(
                  minutes == null ? l.failureDueBody : l.failureCountdown(minutes),
                  style: TaraText.label.copyWith(
                    color: c.textPrimary.withValues(alpha: .74),
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      if (failure != null)
        GlassCard(
          radius: 22,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              _ProofThumb(photo: photo, size: 56),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _Panel._reason(l, failure.reason),
                      style: TaraText.label.copyWith(color: c.textPrimary, fontSize: 13, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      detail,
                      style: TaraText.small.copyWith(color: c.textPrimary.withValues(alpha: .66), fontSize: 12),
                    ),
                    if (failure.note?.isNotEmpty ?? false) ...[
                      const SizedBox(height: 2),
                      Text(
                        l.riderNoteQuoted(failure.note!),
                        style: TaraText.small.copyWith(color: c.textPrimary, fontStyle: FontStyle.italic),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              GlassIconButton(
                icon: TaraIcons.phone,
                label: l.callRecipient(recipientFirst),
                onPressed: onCallRecipient,
              ),
            ],
          ),
        ),
      const SizedBox(height: 12),
      if (topUp != null)
        _TopUpCard(state: topUp!)
      else ...[
        // Une seule nouvelle tentative (E6) ; chaque choix annonce ses frais.
        if (failure?.retryAllowed ?? true)
          AddressChoice(
            icon: TaraIcons.refresh,
            title: o.retryFee > 0 ? '${l.failureRetryTitle} · ${formatAmount(o.retryFee)} F' : l.failureRetryTitle,
            subtitle: l.failureRetryBody(riderName, recipientFirst),
            selected: choice == 'RETRY',
            onTap: () => onChoose('RETRY'),
          )
        else
          TintBox(
            tone: TintTone.accent,
            child: Text(l.retryUsed, style: TaraText.label.copyWith(color: c.textPrimary)),
          ),
        const SizedBox(height: 12),
        AddressChoice(
          icon: TaraIcons.returnArrow,
          title: o.returnFee > 0 ? '${l.failureReturnTitle} · ${formatAmount(o.returnFee)} F' : l.failureReturnTitle,
          subtitle: l.failureReturnBody(riderName, o.pickup.summary),
          selected: choice == 'RETURN',
          onTap: () => onChoose('RETURN'),
        ),
        // Le prix du retour, annoncé avant de choisir : ce que le solde paie, le reste.
        if (quote case final q? when q.fee > 0) ...[
          const SizedBox(height: 8),
          TintBox(
            tone: q.toPay > 0 ? TintTone.accent : TintTone.success,
            child: Text(
              q.toPay > 0
                  ? l.returnQuoteLine(
                      '${formatAmount(q.fee)}\u00a0F',
                      '${formatAmount(q.fromBalance)}\u00a0F',
                      '${formatAmount(q.toPay)}\u00a0F',
                    )
                  : l.returnQuoteCovered('${formatAmount(q.fee)}\u00a0F'),
              style: TaraText.small.copyWith(color: c.textPrimary, height: 1.4),
            ),
          ),
        ],
        if (failure?.retryAllowed ?? true) ...[
          const SizedBox(height: 12),
          Text(
            l.failureOnceNote,
            style: TaraText.small.copyWith(color: c.textPrimary.withValues(alpha: .62), fontSize: 12, height: 1.45),
          ),
        ],
      ],
      if (error != null) ...[const SizedBox(height: 8), ErrorLine(error!)],
    ];
    final state = topUp;
    return ScrollWithFooter(
      horizontal: 20,
      top: 30,
      content: content,
      footer: state != null
          ? PrimaryButton(
              label: l.topUpPay('${formatAmount(state.amount)} F'),
              icon: TaraIcons.phone,
              loading: busy || state.pending,
              onPressed: busy || state.pending ? null : state.onPay,
            )
          : PrimaryButton(
              label: switch (choice) {
                'RETRY' => l.failureGoRetry,
                'RETURN' => l.failureGoReturn,
                _ => l.failureChoose,
              },
              loading: busy,
              onPressed: choice == null || busy ? null : onDecide,
            ),
    );
  }
}

/// Code de retour (maquette) : à donner au livreur quand il rend le colis.
class _ReturnCodeCard extends StatelessWidget {
  const _ReturnCodeCard({required this.code, this.office = false});

  final String code;

  /// Colis au bureau Tara : code de retrait, à donner au bureau.
  final bool office;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final spaced = code.split('').join(' ');
    final title = office ? l.officeCodeTitle : l.returnCodeTitle;
    final give = office ? l.officeCodeGive : l.returnCodeGive;
    return Semantics(
      label: '$title : $spaced. $give',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        decoration: BoxDecoration(
          color: boxedFieldFill(c),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: boxedFieldBorder(c)),
          boxShadow: const [BoxShadow(color: Color.fromRGBO(140, 70, 10, .08), blurRadius: 28, offset: Offset(0, 12))],
        ),
        child: Column(
          children: [
            Text(
              title.toUpperCase(),
              style: TaraText.small.copyWith(
                color: c.accentText,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: .66,
              ),
            ),
            const SizedBox(height: 6),
            Text(spaced, style: TaraText.titlePanel.copyWith(color: c.textPrimary, fontSize: 34, letterSpacing: 10)),
            const SizedBox(height: 6),
            Text(
              give,
              textAlign: TextAlign.center,
              style: TaraText.small.copyWith(color: c.textPrimary.withValues(alpha: .7), fontSize: 12, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bureau Tara : adresse, horaires et fin de la garde sans frais.
class _OfficeCard extends StatelessWidget {
  const _OfficeCard({required this.office, required this.now});

  final OrderOffice office;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final until = office.until;
    return GlassCard(
      radius: 22,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const IconTile(icon: TaraIcons.mapPin, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.officeTitle,
                  style: TaraText.label.copyWith(color: c.textPrimary, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(office.address, style: TaraText.small.copyWith(color: c.textPrimary)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    TaraIcon(TaraIcons.clock, size: 14, color: c.textSecondary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        office.hoursFor(Localizations.localeOf(context).languageCode),
                        style: TaraText.small.copyWith(color: c.textSecondary),
                      ),
                    ),
                  ],
                ),
                if (until != null) ...[
                  const SizedBox(height: 2),
                  Text(l.officeKeptUntil(_date(until)), style: TaraText.small.copyWith(color: c.textSecondary)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _date(DateTime at) =>
      '${at.day.toString().padLeft(2, '0')}/${at.month.toString().padLeft(2, '0')}/${at.year}';
}

/// Colis gardé au bureau Tara (retour non payé à temps) : où il est, ce qu'il reste à payer
/// et combien de jours ; une fois payé, le code de retrait. Non réclamé : plus rien n'est dû.
class _OfficePage extends StatelessWidget {
  const _OfficePage({
    required this.order,
    required this.now,
    required this.quote,
    required this.busy,
    required this.error,
    required this.topUp,
    required this.code,
    required this.codeSent,
    required this.onPay,
    required this.onNewCode,
    required this.onReport,
  });

  final TrackedOrder order;
  final DateTime now;
  final ReturnQuote? quote;
  final bool busy;
  final String? error;
  final _TopUpState? topUp;

  /// Nouveau code de retrait demandé dans l'app (sinon celui reçu par SMS).
  final String? code;
  final bool codeSent;
  final VoidCallback onPay;
  final VoidCallback onNewCode;
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final office = order.office;
    final unclaimed = order.status == 'UNCLAIMED';
    final paid = office?.paidAt != null;
    final due = quote?.fee ?? office?.due ?? 0;
    final toPay = quote?.toPay ?? due;
    final amount = '${formatAmount(due)}\u00a0F';
    final days = office?.daysLeft(now) ?? 0;
    final content = <Widget>[
      Row(
        children: [
          IconTile(
            icon: unclaimed ? TaraIcons.alertCircle : TaraIcons.package,
            size: 56,
            tone: unclaimed ? TintTone.danger : TintTone.accent,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  liveRegion: true,
                  child: Text(
                    unclaimed ? l.trackUnclaimed : l.trackAtOffice,
                    style: TaraText.titlePanel.copyWith(color: c.textPrimary, fontSize: 19),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  unclaimed
                      ? l.trackUnclaimedBody
                      : paid
                      ? l.trackAtOfficePaid
                      : '${l.trackAtOfficeBody(amount)} ${l.officeDaysLeft(days)}',
                  style: TaraText.label.copyWith(
                    color: c.textPrimary.withValues(alpha: .74),
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      _Steps(order: order),
      const SizedBox(height: 16),
      if (office != null && !unclaimed) ...[_OfficeCard(office: office, now: now), const SizedBox(height: 12)],
      if (!unclaimed && !paid) ...[
        if (topUp != null)
          _TopUpCard(state: topUp!)
        else if (quote case final q? when q.fee > 0)
          TintBox(
            tone: TintTone.accent,
            child: Text(
              q.toPay > 0
                  ? l.returnQuoteLine(
                      '${formatAmount(q.fee)}\u00a0F',
                      '${formatAmount(q.fromBalance)}\u00a0F',
                      '${formatAmount(q.toPay)}\u00a0F',
                    )
                  : l.returnQuoteCovered('${formatAmount(q.fee)}\u00a0F'),
              style: TaraText.small.copyWith(color: c.textPrimary, height: 1.4),
            ),
          ),
        const SizedBox(height: 12),
      ],
      if (paid && !unclaimed) ...[
        if (code != null)
          _ReturnCodeCard(code: code!, office: true)
        else
          TintBox(
            tone: TintTone.success,
            child: Text(
              codeSent ? l.officeCodeSent : l.officeCodeGive,
              style: TaraText.label.copyWith(color: c.textPrimary),
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TaraLink(label: l.newOfficeCode, onPressed: busy ? null : onNewCode),
        ),
      ],
      Align(
        alignment: Alignment.centerLeft,
        child: TaraLink(label: l.reportProblem, onPressed: onReport),
      ),
      if (error != null) ...[const SizedBox(height: 8), ErrorLine(error!)],
    ];
    final state = topUp;
    if (unclaimed || paid) {
      return SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 30, 20, 20 + MediaQuery.paddingOf(context).bottom),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: content),
      );
    }
    return ScrollWithFooter(
      horizontal: 20,
      top: 30,
      content: content,
      footer: state != null
          ? PrimaryButton(
              label: l.topUpPay('${formatAmount(state.amount)} F'),
              icon: TaraIcons.phone,
              loading: busy || state.pending,
              onPressed: busy || state.pending ? null : state.onPay,
            )
          : PrimaryButton(
              label: l.officePayNow('${formatAmount(toPay > 0 ? toPay : due)}\u00a0F'),
              icon: toPay > 0 ? TaraIcons.phone : null,
              loading: busy,
              onPressed: busy ? null : onPay,
            ),
    );
  }
}
