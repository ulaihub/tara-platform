import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tara_core/api/api_exception.dart';
import 'package:tara_core/realtime/realtime_client.dart';
import 'package:tara_map/pin_picker_map.dart';
import 'package:tara_ui/components/buttons.dart';
import 'package:tara_ui/components/layout.dart';
import 'package:tara_ui/components/progress.dart';
import 'package:tara_ui/components/swipe_button.dart';
import 'package:tara_ui/feedback/tara_feedback.dart';
import 'package:tara_ui/format.dart';
import 'package:tara_ui/motion/liquid_background.dart';
import 'package:tara_ui/tara_colors.dart';
import 'package:tara_ui/tara_icons.dart';
import 'package:tara_ui/tara_typography.dart';

import '../../app/providers.dart';
import '../../core/api/client_models.dart';
import '../../l10n/app_localizations.dart';
import '../common/error_text.dart';
import '../common/scoped_page.dart';
import '../home/home_screen.dart';
import 'address_editor.dart';
import 'order_draft.dart';
import 'order_placed.dart';
import 'package_step.dart';
import 'pickup_step.dart';
import 'recipient_step.dart';
import 'summary_step.dart';
import 'when_step.dart';

/// Nouvelle livraison (C1–C4), en cinq étapes : enlèvement, destinataire, colis, quand,
/// récapitulatif. « Retour » (ou le geste retour du téléphone) revient à l'étape
/// précédente ; à la première, il ferme le parcours. La commande part d'un geste
/// (glisser), puis : paiement Mobile Money s'il le faut, et « Commande envoyée ».
class NewOrderFlow extends ConsumerStatefulWidget {
  const NewOrderFlow({super.key, required this.me, required this.onClose, this.now});

  final Me me;
  final VoidCallback onClose;

  /// Horloge (tests).
  final DateTime Function()? now;

  @override
  ConsumerState<NewOrderFlow> createState() => _NewOrderFlowState();
}

class _NewOrderFlowState extends ConsumerState<NewOrderFlow> {
  static const _total = 5;
  static const _summary = 4;

  static const _blobs = [
    BlobSpec(alignment: Alignment(1.3, -1.1), size: 260, colors: BlobSpec.brand, blur: 70),
    BlobSpec(alignment: Alignment(-1.35, 0.9), size: 220, colors: BlobSpec.warm, blur: 64, delay: Duration(seconds: 4)),
  ];

  final _draft = OrderDraft();
  late final AppLifecycleListener _lifecycle;
  int _step = 0;
  bool _tried = false;
  Timer? _linkTimer;
  StreamSubscription<RealtimeEvent>? _events;

  /// Ajout ou modification d'une livraison depuis le récapitulatif : on y revient ensuite.
  bool _fromSummary = false;

  // Commande : clé d'idempotence (gardée tant que le brouillon ne change pas, pour qu'un
  // nouvel essai après une coupure ne crée pas de doublon), refus éventuel, résultat.
  String? _key;
  bool _placing = false;
  String? _placeError;
  Placement? _placed;

  // Paiement Mobile Money de la commande créée.
  Payment? _payment;
  bool _paying = false;
  String? _payError;
  Timer? _paymentPoll;

  /// Le livreur a accepté la course (temps réel).
  bool _riderFound = false;

  @override
  void initState() {
    super.initState();
    _draft.addListener(_watchLinks);
    // Le serveur annonce l'adresse placée par le destinataire : relue aussitôt.
    _events = ref.read(realtimeProvider).stream.listen(_onEvent);
    // Brouillon modifié : une nouvelle commande, donc une nouvelle clé.
    _draft.addListener(() {
      if (!_placing) _key = null;
    });
    // Retour de WhatsApp ou des SMS : le destinataire a peut-être déjà répondu.
    _lifecycle = AppLifecycleListener(onResume: () => unawaited(_checkLinks()));
  }

  @override
  void dispose() {
    _linkTimer?.cancel();
    _paymentPoll?.cancel();
    unawaited(_events?.cancel());
    _lifecycle.dispose();
    _draft.dispose();
    super.dispose();
  }

  bool get _stepValid => switch (_step) {
    0 => _draft.pickup != null,
    1 => _draft.delivery.hasRecipient && _draft.delivery.hasAddress,
    2 => _draft.delivery.hasPackage,
    3 => _draft.hasWhen,
    _ => _draft.allQuoted && _draft.hasPayment,
  };

  void _go(int step) => setState(() {
    _step = step;
    _tried = false;
    _placeError = null;
  });

  void _next() {
    FocusScope.of(context).unfocus();
    if (!_stepValid) {
      setState(() => _tried = true);
      return;
    }
    // Livraison ajoutée ou modifiée : l'heure est déjà choisie, retour au récapitulatif.
    if (_step == 2 && (_fromSummary || _draft.deliveries.length > 1)) {
      _fromSummary = false;
      _go(_summary);
      return;
    }
    if (_step < _summary) _go(_step + 1);
  }

  void _back() {
    FocusScope.of(context).unfocus();
    if (_step == 0) {
      widget.onClose();
      return;
    }
    // Ajout abandonné depuis le récapitulatif : la livraison vide disparaît.
    if (_step == 1 && _fromSummary) {
      final d = _draft.delivery;
      if (d.recipientName.trim().isEmpty && d.recipientPhone.isEmpty && !d.hasAddress) {
        _draft.removeDelivery(_draft.currentIndex);
      }
      _fromSummary = false;
      _go(_summary);
      return;
    }
    _go(_step - 1);
  }

  void _addDelivery() {
    _draft.addDelivery();
    _fromSummary = true;
    _go(1);
  }

  void _editDelivery(int index) {
    _draft.select(index);
    _fromSummary = true;
    _go(1);
  }

  void _onEvent(RealtimeEvent event) {
    switch (event.name) {
      case 'location-link.submitted':
        unawaited(_checkLinks());
      case 'payment.status' when event.payload['paymentId'] == _payment?.id:
        unawaited(_refreshPayment());
      case 'order.status' when event.payload['status'] == 'ASSIGNED' && !_riderFound:
        final placed = _placed;
        if (placed == null || !placed.orders.any((o) => o.id == event.payload['orderId'])) return;
        TaraFeedback.play(context, TaraSound.received);
        setState(() => _riderFound = true);
    }
  }

  static String _newKey() {
    final random = Random.secure();
    return List.generate(16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  }

  /// Crée la commande (ou le lot), puis demande le paiement Mobile Money s'il le faut.
  Future<void> _place() async {
    FocusScope.of(context).unfocus();
    if (!_stepValid) {
      setState(() => _tried = true);
      return;
    }
    final api = ref.read(clientApiProvider);
    final draft = _draft;
    _key ??= _newKey();
    setState(() {
      _placing = true;
      _placeError = null;
    });
    try {
      final shared = draft.sharedJson();
      final placement = draft.deliveries.length == 1
          ? await api.createOrder(
              idempotencyKey: _key!,
              shared: shared,
              delivery: draft.deliveries.first.toJson(),
              promoCode: draft.promoCode,
            )
          : await api.createBatch(
              idempotencyKey: _key!,
              shared: shared,
              deliveries: [for (final d in draft.deliveries) d.toJson()],
            );
      ref
        ..invalidate(activeOrdersProvider)
        ..invalidate(walletProvider);
      if (!mounted) return;
      setState(() => _placed = placement);
      if (draft.momo) {
        await _requestPayment();
      } else {
        TaraFeedback.play(context, TaraSound.sent);
      }
    } on ApiException catch (error) {
      if (!mounted) return;
      TaraFeedback.play(context, TaraSound.error);
      if (error.code == 'SCHEDULE_INVALID') {
        // Créneau dépassé pendant la saisie : on en choisit un autre.
        draft.scheduledFor = null;
        _go(3);
        setState(() => _tried = true);
        return;
      }
      setState(() => _placeError = errorMessage(context, error));
    } finally {
      if (mounted) setState(() => _placing = false);
    }
  }

  Future<void> _requestPayment() async {
    final placed = _placed!;
    final api = ref.read(clientApiProvider);
    final phone = '+237${_draft.payerPhone}';
    final operator = _draft.paymentMethod == 'MOMO_ORANGE' ? 'ORANGE' : 'MTN';
    setState(() {
      _paying = true;
      _payError = null;
    });
    try {
      // Un lot se paie en une seule fois : une seule demande sur le téléphone.
      final payment = placed.batchId != null && placed.orders.length > 1
          ? await api.payBatch(placed.batchId!, phone: phone, operator: operator)
          : await api.payOrder(placed.orders.first.id, phone: phone, operator: operator);
      if (!mounted) return;
      setState(() => _payment = payment);
      _paymentPoll?.cancel();
      _paymentPoll = Timer.periodic(const Duration(seconds: 4), (_) => unawaited(_refreshPayment()));
    } catch (error) {
      if (mounted) setState(() => _payError = errorMessage(context, error));
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  /// Relit le paiement (temps réel coupé : toutes les 4 s) jusqu'à sa conclusion.
  Future<void> _refreshPayment() async {
    final current = _payment;
    if (current == null || current.status != 'PENDING') return;
    try {
      final fresh = await ref.read(clientApiProvider).payment(current.id);
      if (!mounted || fresh.status == 'PENDING') return;
      _paymentPoll?.cancel();
      setState(() => _payment = fresh);
      TaraFeedback.play(context, fresh.status == 'SUCCEEDED' ? TaraSound.sent : TaraSound.error);
      if (fresh.status == 'SUCCEEDED') ref.invalidate(activeOrdersProvider);
    } catch (_) {
      // Réseau absent : nouvel essai au tour suivant.
    }
  }

  Future<void> _cancelUnpaid() async {
    final l = AppLocalizations.of(context);
    final orders = _placed!.orders;
    setState(() => _paying = true);
    try {
      for (final order in orders) {
        await ref.read(clientApiProvider).cancelOrder(order.id, l.cancelReasonUnpaid);
      }
      ref.invalidate(activeOrdersProvider);
      widget.onClose();
    } catch (error) {
      if (mounted) {
        setState(() {
          _paying = false;
          _payError = errorMessage(context, error);
        });
      }
    }
  }

  void _finish() {
    ref
      ..invalidate(activeOrdersProvider)
      ..invalidate(walletProvider);
    widget.onClose();
  }

  /// Interroge les liens de localisation en attente tant que le parcours est ouvert.
  void _watchLinks() {
    final waiting = _draft.deliveries.any((d) => d.dropoff == null && d.link?.status == 'PENDING');
    if (waiting) {
      _linkTimer ??= Timer.periodic(const Duration(seconds: 5), (_) => unawaited(_checkLinks()));
    } else {
      _linkTimer?.cancel();
      _linkTimer = null;
    }
  }

  Future<void> _checkLinks() async {
    for (final delivery in List.of(_draft.deliveries)) {
      final link = delivery.link;
      if (delivery.dropoff != null || link == null || link.status != 'PENDING') continue;
      try {
        final fresh = await ref.read(clientApiProvider).locationLink(link.id);
        if (!mounted || delivery.link?.id != link.id) continue;
        delivery
          ..link = fresh
          ..dropoff = fresh.address ?? delivery.dropoff;
        if (fresh.address != null) TaraFeedback.play(context, TaraSound.received);
        _draft.touch();
      } catch (_) {
        // Réseau absent : nouvel essai au tour suivant.
      }
    }
  }

  Future<void> _placeAddress({required bool pickup}) async {
    final l = AppLocalizations.of(context);
    final delivery = _draft.delivery;
    final navigator = Navigator.of(context);
    final address = await navigator.push<Address>(
      scopedPage(
        context,
        (context) => AddressEditor(
          title: pickup ? l.pickupAddressTitle : l.deliveryAddress,
          forPickup: pickup,
          contactName: pickup ? null : delivery.recipientName.trim(),
          contactPhone: pickup || delivery.recipientPhone.isEmpty ? null : '+237${delivery.recipientPhone}',
          initial: switch (pickup ? null : delivery.dropoff) {
            final current? => MapPoint(current.latitude, current.longitude),
            null => null,
          },
          onBack: navigator.pop,
          onSaved: navigator.pop,
        ),
      ),
    );
    if (address == null || !mounted) return;
    if (pickup) {
      ref.invalidate(pickupAddressesProvider);
      _draft.pickup = address;
    } else {
      _draft.update(
        (d) => d
          ..dropoff = address
          ..link = null,
      );
    }
  }

  /// Après la commande : paiement Mobile Money en attente, puis « Commande envoyée ».
  Widget? _afterOrder(AppLocalizations l) {
    final placed = _placed;
    if (placed == null) return null;
    final payment = _payment;
    if (_draft.momo && payment?.status != 'SUCCEEDED') {
      return PaymentPending(
        amount: placed.total,
        phone: _draft.payerPhone,
        failed: payment != null && payment.status != 'PENDING' || (payment == null && _payError != null),
        busy: _paying,
        error: _payError,
        onRetry: () => unawaited(_requestPayment()),
        onCancel: () => unawaited(_cancelUnpaid()),
      );
    }
    final now = (widget.now ?? DateTime.now)();
    final scheduled = _draft.later ? _draft.scheduledFor : null;
    return OrderPlaced(
      placement: placed,
      recipients: [for (final d in _draft.deliveries) d.recipientName.trim()],
      riderFound: _riderFound,
      scheduled: scheduled == null
          ? null
          : scheduleText(l, Localizations.localeOf(context).toLanguageTag(), scheduled, now),
      onDone: _finish,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final titles = [l.stepPickup, l.stepRecipient, l.stepPackage, l.stepWhen, l.stepSummary];
    final me = widget.me;
    final after = _afterOrder(l);
    if (after != null) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _finish();
        },
        child: TaraScreen(safeBottom: false, blobs: _blobs, child: after),
      );
    }
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: TaraScreen(
        safeBottom: false,
        blobs: _blobs,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 20, 0),
              child: Row(
                children: [
                  GlassIconButton(
                    icon: _step == 0 ? TaraIcons.close : TaraIcons.chevronLeft,
                    label: _step == 0 ? l.close : l.back,
                    onPressed: _back,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.stepOf(_step + 1, _total, titles[_step]),
                          style: TaraText.label.copyWith(color: c.textSecondary),
                        ),
                        const SizedBox(height: 8),
                        LiquidProgressBar(value: (_step + 1) / _total),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListenableBuilder(
                listenable: _draft,
                builder: (context, _) => ScrollWithFooter(
                  horizontal: 20,
                  top: 22,
                  content: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 260),
                      switchInCurve: Curves.easeOutCubic,
                      layoutBuilder: (current, previous) =>
                          Stack(alignment: Alignment.topCenter, children: [...previous, ?current]),
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween(begin: const Offset(.04, 0), end: Offset.zero).animate(animation),
                          child: child,
                        ),
                      ),
                      child: KeyedSubtree(
                        key: ValueKey('$_step-${_draft.currentIndex}'),
                        child: switch (_step) {
                          0 => PickupStep(
                            draft: _draft,
                            showErrors: _tried,
                            onAddAddress: () => unawaited(_placeAddress(pickup: true)),
                          ),
                          2 => PackageStep(draft: _draft, merchant: me.merchant != null, showErrors: _tried),
                          3 => WhenStep(draft: _draft, showErrors: _tried, now: widget.now ?? DateTime.now),
                          _summary => SummaryStep(
                            draft: _draft,
                            me: me,
                            now: widget.now ?? DateTime.now,
                            showErrors: _tried,
                            error: _placeError,
                            onEdit: _editDelivery,
                            onAdd: _addDelivery,
                          ),
                          _ => RecipientStep(
                            draft: _draft,
                            senderName: me.merchant?.shopName ?? me.fullName ?? '',
                            showErrors: _tried,
                            onPlaceOnMap: () => unawaited(_placeAddress(pickup: false)),
                          ),
                        },
                      ),
                    ),
                  ],
                  footer: _step == _summary
                      // La commande engage l'expéditeur : elle part d'un geste, pas d'un toucher.
                      ? SwipeButton(
                          label: _draft.allQuoted ? l.orderFor('${formatAmount(_draft.total)}\u00a0F') : l.quoting,
                          semanticLabel: l.orderSlide,
                          icon: TaraIcons.arrowRight,
                          loading: _placing,
                          onConfirmed: _draft.allQuoted ? () => unawaited(_place()) : null,
                        )
                      : PrimaryButton(label: l.continueLabel, icon: TaraIcons.arrowRight, onPressed: _next),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
