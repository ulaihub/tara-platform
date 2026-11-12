import 'dart:async';
import 'dart:math' as math;
import 'dart:math' show Random;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tara_core/api/api_exception.dart';
import 'package:tara_core/phone/phone_format.dart';
import 'package:tara_core/realtime/realtime_client.dart';
import 'package:tara_map/pin_picker_map.dart';
import 'package:tara_ui/components/buttons.dart';
import 'package:tara_ui/components/glass.dart';
import 'package:tara_ui/components/inputs.dart';
import 'package:tara_ui/components/layout.dart';
import 'package:tara_ui/components/star_rating.dart';
import 'package:tara_ui/components/swipe_button.dart';
import 'package:tara_ui/feedback/tara_feedback.dart';
import 'package:tara_ui/format.dart';
import 'package:tara_ui/motion/confetti.dart';
import 'package:tara_ui/motion/effects.dart';
import 'package:tara_ui/tara_colors.dart';
import 'package:tara_ui/tara_icons.dart';
import 'package:tara_ui/tara_typography.dart';

import '../../app/providers.dart';
import '../../core/api/client_models.dart';
import '../../l10n/app_localizations.dart';
import '../common/error_text.dart';
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
  String _topUpOperator = 'MTN';
  final _topUpPhone = TextEditingController();
  String? _topUpPayment;
  bool _topUpFailed = false;
  Timer? _topUpPoll;
  StreamSubscription<RealtimeEvent>? _events;
  late final RealtimeClient _realtime;
  Timer? _refresh;

  DateTime get _now => (widget.now ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    _realtime = ref.read(realtimeProvider)..connect();
    _events = _realtime.stream.listen(_onEvent);
    _realtime.subscribeOrder(widget.orderId, onAck: _onAck);
    // Temps réel coupé : l'étape est relue de temps en temps.
    _refresh = Timer.periodic(const Duration(seconds: 30), (_) => unawaited(_load()));
  }

  @override
  void dispose() {
    unawaited(_events?.cancel());
    _refresh?.cancel();
    _realtime.unsubscribeOrder(widget.orderId);
    _comment.dispose();
    _topUpPhone.dispose();
    _topUpPoll?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final order = await ref.read(clientApiProvider).order(widget.orderId);
      if (!mounted) return;
      final before = _order?.status;
      setState(() {
        _order = order;
        _error = null;
      });
      if (before != null && before != order.status) _announce(order.status);
    } catch (error) {
      if (mounted && _order == null) setState(() => _error = errorMessage(context, error));
    }
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

  Future<void> _newPickupCode() async {
    setState(() => _busy = true);
    try {
      final code = await ref.read(clientApiProvider).newPickupCode(widget.orderId);
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
        _askTopUp((error.details['amount'] as num?)?.toInt() ?? _order?.retryFee ?? 0);
        return;
      }
      final message = errorMessage(context, error);
      await _load();
      if (mounted) setState(() => _error = message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _askTopUp(int amount) {
    final me = ref.read(meProvider).value;
    if (_topUpPhone.text.isEmpty && me != null) {
      final local = digitsOf(me.phone).replaceFirst(RegExp(r'^237(?=\d{9}$)'), '');
      _topUpPhone.text = PhoneInputFormatter()
          .formatEditUpdate(TextEditingValue.empty, TextEditingValue(text: local))
          .text;
    }
    setState(() {
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

  /// Recharge validée : la nouvelle tentative est confirmée dans la foulée.
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
        setState(() {
          _topUp = null;
          _topUpPayment = null;
          _choice = 'RETRY';
        });
        await _decide();
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
      _choice = 'RETURN';
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
    final panel = height * (delivered ? .66 : (deciding ? .62 : .48));
    final top = MediaQuery.paddingOf(context).top + 72;
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
                      if (order != null)
                        GlassCard(
                          radius: 18,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          child: Text(order.reference, style: TaraText.cardTitle.copyWith(color: c.textPrimary)),
                        ),
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
                        rider: _rider,
                        pickupCode: _pickupCode,
                        choice: _choice,
                        stars: _stars,
                        comment: _comment,
                        confirmCancel: _confirmCancel,
                        busy: _busy,
                        error: _error,
                        recapKey: _recap,
                        onNewPickupCode: () => unawaited(_newPickupCode()),
                        onChoose: (choice) => setState(() => _choice = choice),
                        onDecide: () => unawaited(_decide()),
                        onStars: (stars) => setState(() => _stars = stars),
                        onRate: () => unawaited(_rate()),
                        topUp: _topUp == null
                            ? null
                            : _TopUpState(
                                amount: _topUp!,
                                operator: _topUpOperator,
                                phone: _topUpPhone,
                                pending: _topUpPayment != null,
                                failed: _topUpFailed,
                                onOperator: (value) => setState(() => _topUpOperator = value),
                                onPay: () => unawaited(_payTopUp()),
                                onCancel: _cancelTopUp,
                              ),
                        onCancel: () => unawaited(_cancel()),
                        onShare: () => unawaited(_share(order)),
                        onCall: (phone) => unawaited(ref.read(launcherProvider)(Uri(scheme: 'tel', path: phone))),
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
    required this.rider,
    required this.pickupCode,
    required this.choice,
    required this.stars,
    required this.comment,
    required this.confirmCancel,
    required this.busy,
    required this.error,
    required this.recapKey,
    required this.onNewPickupCode,
    required this.onChoose,
    required this.onDecide,
    required this.onStars,
    required this.onRate,
    required this.onCancel,
    this.topUp,
    required this.onShare,
    required this.onCall,
    required this.onReport,
  });

  final TrackedOrder order;
  final DateTime now;
  final MapPoint? rider;
  final String? pickupCode;
  final String? choice;
  final int stars;
  final TextEditingController comment;
  final bool confirmCancel;
  final bool busy;
  final String? error;
  final GlobalKey recapKey;
  final VoidCallback onNewPickupCode;
  final ValueChanged<String> onChoose;
  final VoidCallback onDecide;
  final ValueChanged<int> onStars;
  final VoidCallback onRate;
  final VoidCallback onCancel;

  /// Recharge demandée avant la nouvelle tentative (solde insuffisant).
  final _TopUpState? topUp;
  final VoidCallback onShare;
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
      'CREATED' => (l.trackAwaitingPayment, l.trackAwaitingPaymentBody),
      _ when scheduled && const ['CREATED', 'SEARCHING_RIDER'].contains(o.status) => (
        l.trackScheduled,
        l.scheduledPickup(formatClock(o.scheduledFor!)),
      ),
      'SEARCHING_RIDER' => (l.trackSearching, l.trackSearchingBody),
      'ASSIGNED' => (l.trackAssigned(riderName), l.trackAssignedBody),
      'PICKED_UP' ||
      'IN_DELIVERY' => (l.trackOnTheWay(recipientFirst), l.trackOnTheWayBody(formatClock(pickedUpAt ?? now))),
      'DELIVERY_FAILED' when failure?.decision == 'RETRY' => (
        l.trackRetrying,
        l.trackRetryingBody(riderName, recipientFirst),
      ),
      'DELIVERY_FAILED' when returning => (l.trackReturning, l.trackReturningBody(riderName)),
      'DELIVERY_FAILED' when failure != null => (
        l.trackFailed,
        l.failureReported(_reason(l, failure.reason), riderName, formatClock(failure.at)),
      ),
      'DELIVERY_FAILED' => (l.trackFailed, l.trackFailedBody),
      'DELIVERED' => (l.trackDelivered, l.trackDeliveredBody(recipientFirst, formatClock(deliveredAt ?? now))),
      'RETURNED' => (l.trackReturned, l.trackReturnedBody(formatClock(o.reachedAt('RETURNED') ?? now))),
      // Colis non conforme refusé à l'enlèvement : le motif et le déplacement facturé.
      'CANCELLED' when o.refusalReason != null => (
        l.trackRefused,
        l.trackRefusedBody(o.refusalReason!, '${formatAmount(o.retryFee)} F'),
      ),
      _ => (l.trackCancelled, ''),
    };
    final eta = _eta(o);
    final delivered = o.status == 'DELIVERED';
    final content = <Widget>[
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Semantics(
              header: true,
              liveRegion: true,
              child: Text(title, style: TaraText.titlePanel.copyWith(color: c.textPrimary)),
            ),
          ),
          if (deciding && failure?.decisionDueAt != null) ...[
            const SizedBox(width: 10),
            InfoPill(label: l.failureDue(formatClock(failure!.decisionDueAt!)), icon: TaraIcons.clock),
          ] else if (eta != null) ...[
            const SizedBox(width: 10),
            InfoPill(label: l.trackEta(eta), icon: TaraIcons.clock),
          ],
        ],
      ),
      if (body.isNotEmpty) ...[
        const SizedBox(height: 4),
        Text(body, style: TaraText.label.copyWith(color: c.textSecondary)),
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
      if (!delivered) ...[_Steps(order: o), const SizedBox(height: 16)],
      if (deciding && topUp != null) ...[
        _TopUpCard(state: topUp!),
      ] else if (deciding) ...[
        // Une seule nouvelle tentative (E6) ; chaque choix annonce ses frais.
        if (failure?.retryAllowed ?? true) ...[
          AddressChoice(
            icon: TaraIcons.refresh,
            title: o.retryFee > 0 ? '${l.failureRetryTitle} · ${formatAmount(o.retryFee)}\u00a0F' : l.failureRetryTitle,
            subtitle: l.failureRetryBody(riderName, recipientFirst),
            selected: choice == 'RETRY',
            onTap: () => onChoose('RETRY'),
          ),
          const SizedBox(height: 10),
        ] else ...[
          TintBox(
            tone: TintTone.accent,
            child: Text(l.retryUsed, style: TaraText.label.copyWith(color: c.textPrimary)),
          ),
          const SizedBox(height: 10),
        ],
        AddressChoice(
          icon: TaraIcons.returnArrow,
          title: o.returnFee > 0
              ? '${l.failureReturnTitle} · ${formatAmount(o.returnFee)}\u00a0F'
              : l.failureReturnTitle,
          subtitle: l.failureReturnBody(riderName, o.pickup.summary),
          selected: choice == 'RETURN',
          onTap: () => onChoose('RETURN'),
        ),
        const SizedBox(height: 8),
        Text(l.failureDueBody, style: TaraText.small.copyWith(color: c.textTertiary)),
        const SizedBox(height: 12),
        _recipientRow(l, o, recipientFirst),
      ] else if (delivered) ...[
        RepaintBoundary(
          key: recapKey,
          child: _Recap(order: o),
        ),
        // Notation du livreur (F4) : dans les 7 jours, une seule fois.
        if (o.rating != null ||
            (o.rider != null && deliveredAt != null && now.difference(deliveredAt) < const Duration(days: 7))) ...[
          const SizedBox(height: 12),
          _RateCard(order: o, stars: stars, comment: comment, busy: busy, onStars: onStars, onSend: onRate),
        ],
      ] else ...[
        if (o.rider case final rider? when rider.phone != null) ...[
          _RiderCard(rider: rider, onCall: () => onCall(rider.phone!)),
          const SizedBox(height: 10),
        ],
        _recipientRow(l, o, recipientFirst),
        if (returning && o.returnFee > 0) ...[
          const SizedBox(height: 8),
          Text(
            l.returnFeeHint('${formatAmount(o.returnFee)} F'),
            style: TaraText.small.copyWith(color: c.textSecondary),
          ),
        ],
        if (returning) ...[
          const SizedBox(height: 8),
          TintBox(
            tone: TintTone.accent,
            child: Text(l.returnCodeHint, style: TaraText.label.copyWith(color: c.textPrimary)),
          ),
        ],
        if (pickupCode != null) ...[
          const SizedBox(height: 8),
          TintBox(
            tone: TintTone.accent,
            child: Text(
              (returning ? l.returnCodeShown : l.pickupCodeShown)(pickupCode!.split('').join(' ')),
              style: TaraText.text.copyWith(color: c.textPrimary, fontWeight: FontWeight.w800),
            ),
          ),
        ],
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
        if (const ['CREATED', 'SEARCHING_RIDER'].contains(o.status)) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: TaraLink(label: l.cancelDelivery, onPressed: busy ? null : onCancel),
          ),
          if (confirmCancel) Text(l.cancelConfirm, style: TaraText.small.copyWith(color: c.dangerText)),
        ],
        Align(
          alignment: Alignment.centerLeft,
          child: TaraLink(label: l.reportProblem, onPressed: onReport),
        ),
      ],
      if (error != null) ...[const SizedBox(height: 8), ErrorLine(error!)],
    ];
    // Solde insuffisant pour la nouvelle tentative : on paie d'abord la recharge.
    if (deciding && topUp != null) {
      final state = topUp!;
      return ScrollWithFooter(
        horizontal: 20,
        top: 4,
        content: content,
        footer: PrimaryButton(
          label: l.topUpPay('${formatAmount(state.amount)} F'),
          icon: TaraIcons.phone,
          loading: busy || state.pending,
          onPressed: busy || state.pending ? null : state.onPay,
        ),
      );
    }
    // Échec : on choisit la suite, puis on glisse pour confirmer.
    if (deciding) {
      return ScrollWithFooter(
        horizontal: 20,
        top: 4,
        content: content,
        footer: SwipeButton(
          label: switch (choice) {
            'RETRY' => l.failureConfirmRetry,
            'RETURN' => l.failureConfirmReturn,
            _ => l.failureChoose,
          },
          semanticLabel: switch (choice) {
            'RETRY' => l.failureConfirmRetrySemantics,
            'RETURN' => l.failureConfirmReturnSemantics,
            _ => null,
          },
          icon: choice == 'RETURN' ? TaraIcons.returnArrow : TaraIcons.refresh,
          loading: busy,
          onConfirmed: choice == null ? null : onDecide,
        ),
      );
    }
    // Un bouton seulement une fois livré (« Partager ») : sinon, pas de socle vide.
    if (delivered) {
      return ScrollWithFooter(
        horizontal: 20,
        top: 4,
        content: content,
        footer: PrimaryButton(label: l.shareRecap, icon: TaraIcons.send, onPressed: onShare),
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

  static String _reason(AppLocalizations l, String? reason) => switch (reason) {
    'RECIPIENT_ABSENT' => l.failureReasonRecipientAbsent,
    'RECIPIENT_UNREACHABLE' => l.failureReasonRecipientUnreachable,
    'REFUSED' => l.failureReasonRefused,
    'ADDRESS_NOT_FOUND' => l.failureReasonAddressNotFound,
    'PAYMENT_REFUSED' => l.failureReasonPaymentRefused,
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
    final failed = order.status == 'DELIVERY_FAILED';
    final last = switch (order.status) {
      'DELIVERY_FAILED' => (l.stepFailed, order.failure?.at ?? order.timeline.lastOrNull?.at),
      'RETURNED' => (l.stepReturned, order.reachedAt('RETURNED')),
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

/// Le livreur : initiales, prénom, véhicule et plaque, bouton d'appel.
class _RiderCard extends StatelessWidget {
  const _RiderCard({required this.rider, required this.onCall});

  final OrderRider rider;
  final VoidCallback onCall;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final vehicle = switch (rider.vehicleType) {
      'CAR' => l.vehicleCar,
      'TRICYCLE' => l.vehicleTricycle,
      _ => l.vehicleMotorbike,
    };
    return GlassCard(
      radius: 20,
      shadow: false,
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      child: Row(
        children: [
          InitialsAvatar(name: rider.name, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rider.name,
                  style: TaraText.text.copyWith(color: c.textPrimary, fontWeight: FontWeight.w700),
                ),
                Text([vehicle, ?rider.plateNumber].join(' · '), style: TaraText.small.copyWith(color: c.textSecondary)),
              ],
            ),
          ),
          GlassIconButton(icon: TaraIcons.phone, label: l.callRider(rider.name), onPressed: onCall),
        ],
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
/// notée, la note et un merci.
class _RateCard extends StatelessWidget {
  const _RateCard({
    required this.order,
    required this.stars,
    required this.comment,
    required this.busy,
    required this.onStars,
    required this.onSend,
  });

  final TrackedOrder order;
  final int stars;
  final TextEditingController comment;
  final bool busy;
  final ValueChanged<int> onStars;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final rating = order.rating;
    final Widget child;
    if (rating != null) {
      child = Row(
        children: [
          StarRating(value: rating.score, onChanged: null, labelOf: l.starsLabel, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.rateThanks,
                  style: TaraText.text.copyWith(color: c.textPrimary, fontWeight: FontWeight.w700),
                ),
                Text(l.rateThanksBody, style: TaraText.small.copyWith(color: c.textSecondary)),
              ],
            ),
          ),
        ],
      );
    } else {
      final word = switch (stars) {
        1 => l.starWord1,
        2 => l.starWord2,
        3 => l.starWord3,
        4 => l.starWord4,
        _ => l.starWord5,
      };
      child = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.rateTitle, style: TaraText.cardTitle.copyWith(color: c.textPrimary)),
          const SizedBox(height: 2),
          Text(l.rateBody(order.rider?.name ?? ''), style: TaraText.small.copyWith(color: c.textSecondary)),
          const SizedBox(height: 14),
          Center(
            child: StarRating(value: stars, onChanged: busy ? null : onStars, labelOf: l.starsLabel),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: stars == 0
                ? const SizedBox(width: double.infinity)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 8),
                      Text(
                        word,
                        textAlign: TextAlign.center,
                        style: TaraText.label.copyWith(color: c.accentText, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 12),
                      TaraTextField(
                        controller: comment,
                        hint: l.rateCommentHint,
                        textCapitalization: TextCapitalization.sentences,
                        textInputAction: TextInputAction.done,
                        inputFormatters: [LengthLimitingTextInputFormatter(300)],
                      ),
                      const SizedBox(height: 10),
                      GlassButton(label: l.rateSend, icon: TaraIcons.send, onPressed: busy ? null : onSend),
                    ],
                  ),
          ),
        ],
      );
    }
    return GlassCard(radius: 22, shadow: false, padding: const EdgeInsets.fromLTRB(16, 14, 16, 16), child: child);
  }
}

/// Recharge Mobile Money demandée avant une nouvelle tentative (solde insuffisant).
class _TopUpState {
  const _TopUpState({
    required this.amount,
    required this.operator,
    required this.phone,
    required this.pending,
    required this.failed,
    required this.onOperator,
    required this.onPay,
    required this.onCancel,
  });

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
          Text(l.topUpTitle(amount), style: TaraText.cardTitle.copyWith(color: c.textPrimary)),
          const SizedBox(height: 4),
          Text(l.topUpBody, style: TaraText.small.copyWith(color: c.textSecondary)),
          const SizedBox(height: 12),
          ChoiceChips<String>(
            options: [ChoiceOption('MTN', l.payMtn), ChoiceOption('ORANGE', l.payOrange)],
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
