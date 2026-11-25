import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tara_core/realtime/realtime_client.dart';
import 'package:tara_ui/components/glass.dart';
import 'package:tara_ui/components/layout.dart';
import 'package:tara_ui/components/tab_shell.dart';
import 'package:tara_ui/format.dart';
import 'package:tara_ui/tara_colors.dart';
import 'package:tara_ui/tara_icons.dart';
import 'package:tara_ui/tara_typography.dart';

import '../../app/providers.dart';
import '../../core/api/models.dart';
import '../../core/course/active_order.dart';
import '../../core/course/course_actions.dart';
import '../../l10n/app_localizations.dart';
import '../account/account_screen.dart';
import '../activity/activity_screen.dart';
import '../common/status_screen.dart';
import '../course/collection_screen.dart';
import '../course/course_banner.dart';
import '../course/course_scaffold.dart' show parcelForWhom, parcelWhat;
import '../course/delivery_screen.dart';
import '../course/failure_screen.dart';
import '../course/pickup_screen.dart';
import '../course/refuse_parcel_screen.dart';
import '../course/return_screen.dart';
import '../offer/offer_screen.dart';
import '../offline/pending_actions_screen.dart';
import '../onboarding/documents_controller.dart';
import '../safety/sos_screen.dart';
import 'course_done_screen.dart';
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

  /// Encaissement ouvert (12), avec la livraison préparée à l'écran 09.
  ({String orderId, DeliveryDraft draft})? _collecting;

  /// Écran d'échec (10) ouvert depuis la livraison : identifiant de la course.
  String? _failing;

  /// Refus du colis (non conforme) ouvert depuis l'enlèvement : identifiant de la course.
  String? _refusing;

  /// Écran d'alerte (14) ouvert par un bouton SOS, au-dessus de tout le reste.
  bool _sos = false;

  /// Onglet affiché quand aucune course n'est à l'écran : 0 accueil, 1 activité (13),
  /// 2 profil et réglages.
  int _tab = 0;

  /// Écran des actions en attente (15), ouvert depuis le bandeau.
  bool _pending = false;

  /// Livraison qui vient d'aboutir : gain qui s'envole, palier du jour éventuel.
  ({String id, String reference, DateTime at, int earning, int deliveredToday})? _reward;

  /// Course à noter après la récompense (F4) : l'expéditeur, d'un geste.
  ({String id, String name})? _rate;

  void _selectTab(int tab) => setState(() => _tab = tab);

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
      // Pièce refusée par l'équipe : le profil la montre à renvoyer.
      if (data['type'] == 'kyc.document_rejected') ref.invalidate(documentsControllerProvider);
    });
  }

  /// Course annulée ou réattribuée : le livreur en est averti.
  void _onOrderChanged() {
    final ended = _activeOrder.takeEnded();
    if (ended == null || !mounted) return;
    final l = AppLocalizations.of(context);
    _showNotice(switch (ended) {
      OrderEnded.delivered => l.orderDeliveredNotice,
      OrderEnded.returned => l.orderReturnedNotice,
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

  void _openSos() => setState(() => _sos = true);

  /// Nouvelle tentative demandée par l'expéditeur : retour vers le destinataire (09).
  /// Tournée (2c) : départ vers le client de l'arrêt en cours.
  Future<void> _departTo(RiderOrder order) async {
    final l = AppLocalizations.of(context);
    final actions = ref.read(courseActionsProvider);
    final at = await actions.position();
    if (!mounted) return;
    if (at == null) return _showNotice(l.noPositionYet);
    await actions.departTo(order, at: at);
  }

  Future<void> _retry(RiderOrder order) async {
    final l = AppLocalizations.of(context);
    final actions = ref.read(courseActionsProvider);
    final at = await actions.position();
    if (!mounted) return;
    if (at == null) return _showNotice(l.noPositionYet);
    final result = await actions.retryDelivery(order, at: at);
    if (!mounted) return;
    if (result.outcome == ActionOutcome.refused) _showNotice(result.message ?? l.genericError);
    if (result.outcome == ActionOutcome.queued) _showNotice(l.actionSavedOffline);
  }

  void _closeOffer(String? message) {
    setState(() => _offer = null);
    if (message != null) _showNotice(message);
  }

  /// Note facultative : sans réseau, elle est simplement perdue.
  Future<void> _rateSender(String orderId, int stars) async {
    try {
      await ref.read(riderApiProvider).rateSender(orderId, stars);
    } catch (_) {}
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
    void sos() => _openSos();
    // Colis refusé sans réseau : le refus part au retour du réseau, la course s'annule alors.
    final refusalRejected = actions.refused(order.id, CourseActions.refuseParcelKind) != null;
    if (order.refusalQueued && !refusalRejected) {
      return StatusScreen(
        title: l.refusalQueuedTitle,
        body: l.refusalQueuedBody,
        actionLabel: l.backHome,
        onAction: minimize,
      );
    }
    final tour = _activeOrder.tour;
    // Une action refusée (code faux saisi hors réseau) ramène à son écran pour la corriger.
    final pickupRefused =
        actions.refused(order.id, 'pickup') != null || actions.refused(order.id, CourseActions.tourPickupKind) != null;
    if (order.status == 'ASSIGNED' || pickupRefused) {
      void onRefused(ActionOutcome outcome) {
        setState(() => _refusing = null);
        _showNotice(outcome == ActionOutcome.queued ? l.actionSavedOffline : l.parcelRefusedNotice);
      }

      // Le refus du colis se pose sur l'enlèvement, qui garde code et photo au retour.
      return Stack(
        children: [
          Positioned.fill(
            child: PickupScreen(
              key: ValueKey('pickup-${order.id}'),
              order: order,
              onBack: minimize,
              onSos: sos,
              onPickedUp: (outcome) {
                if (outcome == ActionOutcome.queued) _showNotice(l.actionSavedOffline);
              },
              onRefuse: () => setState(() => _refusing = order.id),
              onSenderAbsent: () => _showNotice(l.senderAbsentNotice),
              // Tournée : tous les colis encore à récupérer ici.
              tour: [
                for (final stop in tour)
                  if (stop.status == 'ASSIGNED' || stop.id == order.id) stop,
              ],
            ),
          ),
          if (_refusing == order.id || refusalRejected)
            Positioned.fill(
              child: RefuseParcelScreen(
                key: ValueKey('refuse-${order.id}'),
                order: order,
                onBack: () => setState(() => _refusing = null),
                onDone: onRefused,
              ),
            ),
        ],
      );
    }
    // Tournée : colis à bord, prochain client ; le livreur part quand il est prêt.
    if (order.status == 'PICKED_UP' && order.tourId != null) {
      final index = tour.indexWhere((stop) => stop.id == order.id);
      return StatusScreen(
        key: ValueKey('next-stop-${order.id}'),
        title: l.nextStopTitle(index + 1, tour.length),
        body: [
          if (order.batchNumber != null) l.parcelNumberShort(order.batchNumber!),
          parcelWhat(l, order),
          parcelForWhom(l, order),
        ].join(' · '),
        actionLabel: l.nextStopGo,
        onAction: () => unawaited(_departTo(order)),
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
    void onFailed(ActionOutcome outcome) {
      setState(() => _failing = null);
      if (outcome == ActionOutcome.queued) _showNotice(l.actionSavedOffline);
    }

    // Échec refusé par le serveur (appels insuffisants, envoyé hors réseau) : à corriger.
    if (actions.refused(order.id, 'fail') != null) {
      return FailureScreen(key: ValueKey('failure-${order.id}'), order: order, onBack: minimize, onDone: onFailed);
    }
    if (order.status == 'DELIVERY_FAILED') {
      if (order.returnQueued) {
        return StatusScreen(
          title: l.returnQueuedTitle,
          body: l.returnQueuedBody,
          actionLabel: l.backHome,
          onAction: minimize,
        );
      }
      if (order.failureDecision == 'RETURN' || actions.refused(order.id, 'return') != null) {
        return ReturnScreen(
          key: ValueKey('return-${order.id}'),
          order: order,
          onBack: minimize,
          onSos: sos,
          onReturned: (outcome) {
            if (outcome == ActionOutcome.queued) _showNotice(l.actionSavedOffline);
          },
        );
      }
      if (order.failureDecision == 'RETRY') {
        return StatusScreen(
          title: l.retryTitle,
          body: l.retryBody,
          actionLabel: l.retryAction,
          onAction: () => unawaited(_retry(order)),
        );
      }
      // En attente de l'expéditeur (au plus le délai, puis retour automatique).
      final queuedFailure = ref.read(actionQueueProvider).forOrder(order.id).any((a) => a.kind == 'fail');
      final due = order.failureDecisionDueAt;
      return StatusScreen(
        title: l.failureWaitingTitle,
        body: queuedFailure || due == null ? l.failureWaitingBodyQueued : l.failureWaitingBody(formatClock(due)),
        actionLabel: l.backHome,
        onAction: minimize,
      );
    }
    final collecting = _collecting?.orderId == order.id ? _collecting : null;
    void onDone(ActionOutcome outcome) {
      // Courses du jour avant celle-ci, relues ensuite avec les gains à jour.
      final before = ref.read(homeSummaryProvider).value?.delivered ?? 0;
      setState(() {
        _collecting = null;
        _reward = (
          id: order.id,
          reference: order.reference,
          at: DateTime.now(),
          earning: order.riderEarning,
          deliveredToday: before + 1,
        );
        _rate = (id: order.id, name: order.sender.name ?? l.senderFallback);
      });
      ref.invalidate(homeSummaryProvider);
      if (outcome == ActionOutcome.queued) _showNotice(l.actionSavedOffline);
    }

    // L'encaissement (12) se pose sur la livraison (09), qui garde code et photo au retour.
    return Stack(
      children: [
        Positioned.fill(
          child: DeliveryScreen(
            key: ValueKey('delivery-${order.id}'),
            order: order,
            onBack: minimize,
            onSos: sos,
            onCollect: (draft) => setState(() => _collecting = (orderId: order.id, draft: draft)),
            onFailure: () => setState(() => _failing = order.id),
            onDelivered: onDone,
            tourProgress: tour.length > 1
                ? (
                    stop: tour.indexWhere((stop) => stop.id == order.id) + 1,
                    total: tour.length,
                    earned: tour
                        .where((stop) => stop.status == 'DELIVERED')
                        .fold(0, (sum, stop) => sum + stop.riderEarning),
                  )
                : null,
          ),
        ),
        if (_failing == order.id)
          Positioned.fill(
            child: FailureScreen(
              key: ValueKey('failure-${order.id}'),
              order: order,
              onBack: () => setState(() => _failing = null),
              onDone: onFailed,
            ),
          ),
        if (collecting != null)
          Positioned.fill(
            child: CollectionScreen(
              key: ValueKey('collection-${order.id}'),
              order: order,
              draft: collecting.draft,
              onBack: () => setState(() => _collecting = null),
              onDone: onDone,
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final online = ref.watch(onlineControllerProvider);
    final queue = ref.watch(actionQueueProvider);
    final network = ref.watch(networkStatusProvider);
    final offer = _offer;
    return ListenableBuilder(
      listenable: Listenable.merge([online, _activeOrder, queue, network]),
      builder: (context, _) {
        final order = _activeOrder.order;
        // Course mise de côté (« Retour à l'accueil ») : l'accueil, en ligne ou hors ligne,
        // affiche un bandeau pour la reprendre ; rien ne la fait oublier.
        final showCourse = order != null && _minimized != order.id;
        final courseBanner = order == null
            ? null
            : CourseBanner(
                reference: order.reference,
                stepLabel: order.status == 'ASSIGNED' ? l.toPickup : l.toDropoff,
                onResume: () => setState(() => _minimized = null),
              );
        return Stack(
          children: [
            Positioned.fill(
              child: showCourse
                  ? _course(order)
                  // Onglets : contenu sous la barre en verre, transition vitrée entre onglets.
                  : TaraTabShell(
                      pill: true,
                      items: [
                        TabItem(TaraIcons.route, l.tabCourse),
                        TabItem(TaraIcons.earnings, l.tabEarnings),
                        TabItem(TaraIcons.user, l.tabProfile),
                      ],
                      current: _tab,
                      onSelected: _selectTab,
                      child: switch (_tab) {
                        1 => const ActivityScreen(),
                        2 => const AccountScreen(),
                        _ when online.online => HomeOnlineScreen(
                          onWentOffline: () => setState(() {}),
                          onDetails: () => _selectTab(1),
                          onSos: _openSos,
                          courseBanner: courseBanner,
                        ),
                        _ => HomeOfflineScreen(
                          onWentOnline: () {
                            ref.invalidate(homeSummaryProvider);
                            unawaited(_loadPendingOffers());
                          },
                          onDetails: () => _selectTab(1),
                          courseBanner: courseBanner,
                        ),
                      },
                    ),
            ),
            // Bandeau sous les en-têtes (retour, SOS restent accessibles) : réseau coupé, ou
            // action refusée par le serveur à vérifier.
            if (!_pending && (network.offline || queue.failures.isNotEmpty))
              Positioned(
                left: 16,
                right: 16,
                top: MediaQuery.paddingOf(context).top + 70,
                child: GestureDetector(
                  onTap: () => setState(() => _pending = true),
                  child: network.offline
                      // Course pas encore enlevée : elle sera retirée si le réseau ne revient pas.
                      ? order?.status == 'ASSIGNED' && network.offlineSince != null
                            ? _WithdrawCountdown(
                                since: network.offlineSince!,
                                limit: Duration(
                                  seconds: ref.watch(riderConfigProvider).value?.silentWithdrawSeconds ?? 180,
                                ),
                              )
                            : OfflineBanner(
                                title: l.offlineBannerTitle,
                                detail: queue.pendingCount > 0
                                    ? l.offlineBannerPending(queue.pendingCount)
                                    : l.offlineNoPending,
                              )
                      : OfflineBanner(
                          title: l.refusedBannerTitle,
                          detail: l.refusedBannerDetail(queue.failures.length),
                        ),
                ),
              ),
            if (_notice != null)
              Positioned(left: 16, right: 16, top: MediaQuery.paddingOf(context).top + 64, child: _Notice(_notice!)),
            // Course livrée (maquette Livreur-Gain) : gain, objectif du jour et note à
            // l'expéditeur sur le même écran, jusqu'à « Continuer ».
            if (_reward case final reward?)
              Positioned.fill(
                child: HideTabBar(
                  child: CourseDoneScreen(
                    key: ValueKey('reward-${reward.id}'),
                    reference: reward.reference,
                    deliveredAt: reward.at,
                    earning: reward.earning,
                    deliveredToday: reward.deliveredToday,
                    senderName: _rate?.name ?? l.senderFallback,
                    onRate: (stars) => unawaited(_rateSender(reward.id, stars)),
                    onDone: () => setState(() {
                      _reward = null;
                      _rate = null;
                    }),
                  ),
                ),
              ),
            if (_pending)
              Positioned.fill(child: PendingActionsScreen(onContinue: () => setState(() => _pending = false))),
            if (offer != null)
              Positioned.fill(
                child: OfferScreen(
                  key: ValueKey(offer.id),
                  offer: offer,
                  onClosed: _closeOffer,
                  onAccepted: (order) => unawaited(_accepted(order)),
                ),
              ),
            if (_sos)
              Positioned.fill(
                child: SosScreen(
                  orderId: order?.id,
                  orderReference: order?.reference,
                  onClose: () => setState(() => _sos = false),
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

/// Hors réseau avec une course pas encore enlevée : minutes restantes avant qu'elle soit
/// confiée à un autre livreur (le serveur la retire au bout du délai sans signe du téléphone).
class _WithdrawCountdown extends StatefulWidget {
  const _WithdrawCountdown({required this.since, required this.limit});
  final DateTime since;
  final Duration limit;

  @override
  State<_WithdrawCountdown> createState() => _WithdrawCountdownState();
}

class _WithdrawCountdownState extends State<_WithdrawCountdown> {
  late final Timer _tick = Timer.periodic(const Duration(seconds: 10), (_) => setState(() {}));

  @override
  void initState() {
    super.initState();
    _tick.isActive;
  }

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final left = widget.limit - DateTime.now().difference(widget.since);
    return OfflineBanner(
      title: l.offlineBannerTitle,
      detail: left.inSeconds <= 0 ? l.silentWithdrawNow : l.silentWithdrawIn((left.inSeconds / 60).ceil()),
    );
  }
}
