import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/api/models.dart';
import '../../core/course/active_order.dart';
import '../../core/course/course_actions.dart';
import '../../core/realtime/realtime_client.dart';
import '../../design/components/glass.dart';
import '../../design/format.dart';
import '../../design/tara_colors.dart';
import '../../design/tara_typography.dart';
import '../../l10n/app_localizations.dart';
import '../common/status_screen.dart';
import '../course/course_banner.dart';
import '../course/delivery_screen.dart';
import '../course/pickup_screen.dart';
import '../offer/offer_screen.dart';
import 'home_offline_screen.dart';
import 'home_online_screen.dart';
import 'home_summary.dart';

/// Accueil du livreur validé : hors ligne (05) ⇄ en ligne (06), propositions (07) reçues
/// par le temps réel, les notifications ou au retour dans l'app, puis la course acceptée
/// (08 enlèvement…). Le bouton retour d'une course la réduit à l'accueil.
class HomeFlow extends ConsumerStatefulWidget {
  const HomeFlow({super.key});

  @override
  ConsumerState<HomeFlow> createState() => _HomeFlowState();
}

class _HomeFlowState extends ConsumerState<HomeFlow> {
  Offer? _offer;
  String? _notice;

  /// Course réduite à l'accueil (bouton retour) : identifiant de la course réduite.
  String? _minimized;

  /// Encaissement ouvert pour cette course (avant l'envoi de la livraison).
  String? _collecting;
  late final ActiveOrderController _activeOrder;
  Timer? _noticeTimer;
  StreamSubscription<RealtimeEvent>? _realtime;
  StreamSubscription<Json>? _push;

  @override
  void initState() {
    super.initState();
    _realtime = ref.read(realtimeProvider).stream.listen(_onEvent);
    _activeOrder = ref.read(activeOrderProvider)..addListener(_onOrderChanged);
    _push = ref.read(pushServiceProvider).messages.listen((data) {
      if (data['type'] == 'offer.new') unawaited(_loadPendingOffers());
    });
  }

  /// Course annulée ou réattribuée : le livreur en est averti.
  void _onOrderChanged() {
    final ended = _activeOrder.takeEnded();
    if (ended == null || !mounted) return;
    final l = AppLocalizations.of(context);
    _showNotice(switch (ended) {
      OrderEnded.delivered => l.orderDeliveredNotice,
      OrderEnded.cancelled => l.orderCancelledNotice,
      OrderEnded.reassigned => l.orderReassignedNotice,
    });
  }

  @override
  void dispose() {
    _activeOrder.removeListener(_onOrderChanged);
    unawaited(_realtime?.cancel());
    unawaited(_push?.cancel());
    _noticeTimer?.cancel();
    super.dispose();
  }

  void _onEvent(RealtimeEvent event) {
    // Pas de nouvelle proposition pendant une course.
    if (!ref.read(onlineControllerProvider).online || _activeOrder.order != null) return;
    switch (event.name) {
      case 'offer.new':
        if (_offer == null) setState(() => _offer = Offer.fromJson(event.payload));
      case 'offer.closed':
        final offer = _offer;
        if (offer != null && event.payload['offerId'] == offer.id && event.payload['outcome'] != 'ACCEPTED') {
          _closeOffer(AppLocalizations.of(context).offerTaken);
        }
    }
  }

  /// Propositions en attente (notification touchée, retour en ligne, temps réel coupé).
  Future<void> _loadPendingOffers() async {
    if (_offer != null || _activeOrder.order != null) return;
    try {
      final offers = await ref.read(riderApiProvider).offers();
      if (mounted && offers.isNotEmpty && _offer == null) setState(() => _offer = Offer.fromJson(offers.first));
    } catch (_) {
      // Sans réseau : le temps réel ou la prochaine notification prendra le relais.
    }
  }

  void _closeOffer(String? message) {
    setState(() => _offer = null);
    if (message != null) _showNotice(message);
  }

  void _showNotice(String message) {
    setState(() => _notice = message);
    _noticeTimer?.cancel();
    _noticeTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _notice = null);
    });
  }

  Future<void> _accepted(Json order) async {
    setState(() {
      _offer = null;
      _minimized = null;
    });
    await _activeOrder.start(RiderOrder.fromJson(order));
  }

  /// Écran de la course selon son étape.
  Widget _course(RiderOrder order) {
    final l = AppLocalizations.of(context);
    final actions = ref.read(courseActionsProvider);
    void minimize() => setState(() => _minimized = order.id);
    void sos() {}
    // Une action refusée (code faux saisi hors réseau) ramène à son écran pour la corriger.
    if (order.status == 'ASSIGNED' || actions.refused(order.id, 'pickup') != null) {
      return PickupScreen(
        key: ValueKey('pickup-${order.id}'),
        order: order,
        onBack: minimize,
        onSos: sos,
        onPickedUp: (outcome) {
          if (outcome == ActionOutcome.queued) _showNotice(l.actionSavedOffline);
        },
      );
    }
    final refusedDelivery = actions.refused(order.id, 'deliver') != null;
    if (order.deliveryQueued && !refusedDelivery) {
      return StatusScreen(
        title: l.deliveryQueuedTitle,
        body: l.deliveryQueuedBody,
        actionLabel: l.backHome,
        onAction: minimize,
      );
    }
    if (order.awaitingSupportValidation && !refusedDelivery) {
      return StatusScreen(
        title: l.awaitingSupportTitle,
        body: l.awaitingSupportBody,
        actionLabel: l.backHome,
        onAction: minimize,
      );
    }
    if (order.status == 'DELIVERY_FAILED') {
      // Écrans d'échec et de retour (10, 11) dans un prochain lot.
      return StatusScreen(
        title: l.deliveryFailedTitle,
        body: l.deliveryFailedBody,
        actionLabel: l.backHome,
        onAction: minimize,
      );
    }
    if (_collecting == order.id) {
      // Écran d'encaissement (12) au prochain lot.
      return StatusScreen(
        title: l.collectionPendingTitle('${formatAmount(order.collectAtDelivery)}\u00A0F'),
        body: l.collectionPendingBody,
        actionLabel: l.back,
        onAction: () => setState(() => _collecting = null),
      );
    }
    return DeliveryScreen(
      key: ValueKey('delivery-${order.id}'),
      order: order,
      onBack: minimize,
      onSos: sos,
      onCollect: () => setState(() => _collecting = order.id),
      onDelivered: (outcome) {
        if (outcome == ActionOutcome.queued) _showNotice(l.actionSavedOffline);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final online = ref.watch(onlineControllerProvider);
    final queue = ref.watch(actionQueueProvider);
    final offer = _offer;
    return ListenableBuilder(
      listenable: Listenable.merge([online, _activeOrder, queue]),
      builder: (context, _) {
        final order = _activeOrder.order;
        // Hors ligne, une course en cours reste à l'écran : rien ne doit la faire oublier.
        final showCourse = order != null && (_minimized != order.id || !online.online);
        return Stack(
          children: [
            Positioned.fill(
              child: showCourse
                  ? _course(order)
                  : online.online
                  ? HomeOnlineScreen(
                      onWentOffline: () => setState(() {}),
                      onDetails: () {},
                      onSos: () {},
                      courseBanner: order == null
                          ? null
                          : CourseBanner(
                              reference: order.reference,
                              stepLabel: order.status == 'ASSIGNED' ? l.toPickup : l.toDropoff,
                              onResume: () => setState(() => _minimized = null),
                            ),
                    )
                  : HomeOfflineScreen(
                      onWentOnline: () {
                        ref.invalidate(homeSummaryProvider);
                        unawaited(_loadPendingOffers());
                      },
                      onDetails: () {},
                    ),
            ),
            if (_notice != null)
              Positioned(left: 16, right: 16, top: MediaQuery.paddingOf(context).top + 64, child: _Notice(_notice!)),
            if (offer != null)
              Positioned.fill(
                child: OfferScreen(
                  key: ValueKey(offer.id),
                  offer: offer,
                  onClosed: _closeOffer,
                  onAccepted: (order) => unawaited(_accepted(order)),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = TaraColors.of(context);
    return Semantics(
      liveRegion: true,
      child: TintBox(
        child: Text(text, style: TaraText.text.copyWith(color: c.textPrimary)),
      ),
    );
  }
}
