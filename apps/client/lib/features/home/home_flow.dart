import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tara_core/realtime/realtime_client.dart';
import 'package:tara_ui/components/glass.dart';
import 'package:tara_ui/components/layout.dart';
import 'package:tara_ui/components/tab_shell.dart';
import 'package:tara_ui/feedback/tara_feedback.dart';
import 'package:tara_ui/format.dart';
import 'package:tara_ui/tara_colors.dart';
import 'package:tara_ui/tara_icons.dart';
import 'package:tara_ui/tara_typography.dart';

import '../../app/providers.dart';
import '../../core/api/client_models.dart';
import '../../l10n/app_localizations.dart';
import '../bulk/bulk_screen.dart';
import '../common/scoped_page.dart';
import '../legal/terms_screen.dart';
import '../order/new_order_flow.dart';
import '../orders/orders_screen.dart';
import '../orders/pending_section.dart';
import '../profile/profile_screen.dart';
import '../tracking/tracking_screen.dart';
import '../wallet/wallet_screen.dart';
import 'activity_screen.dart';
import 'ask_address_screen.dart';
import 'home_screen.dart';
import 'notifications_screen.dart';

/// Onglets de l'expéditeur (Accueil, Commandes, Profil) : le contenu défile sous la barre en
/// verre, transition vitrée d'un onglet à l'autre. La nouvelle livraison s'ouvre en plein
/// écran. Le temps réel garde l'accueil à jour (livraisons, ventes du jour) et annonce les
/// reversements par un bandeau et le son de pièce ; une livraison impossible, par un bandeau
/// rouge qui ouvre son suivi (l'expéditeur n'a que quelques minutes pour choisir la suite).
class HomeFlow extends ConsumerStatefulWidget {
  const HomeFlow({super.key, required this.me, this.now});

  final Me me;

  /// Horloge des onglets (tests).
  final DateTime Function()? now;

  @override
  ConsumerState<HomeFlow> createState() => _HomeFlowState();
}

class _HomeFlowState extends ConsumerState<HomeFlow> {
  int _tab = 0;

  /// Liste ouverte dans l'onglet Commandes (« Mes reçus » ouvre les terminées).
  String _ordersScope = 'active';
  StreamSubscription<RealtimeEvent>? _events;
  ValueNotifier<bool>? _connected;
  bool _cut = false;
  StreamSubscription<Json>? _pushOpened;

  /// Reversement arrivé sur le Mobile Money (montant), affiché quelques secondes.
  int? _payout;
  Timer? _payoutTimer;

  /// Livraison impossible à décider : (commande, référence), jusqu'au choix ou au toucher.
  (String, String)? _failed;
  Timer? _failedTimer;

  @override
  void initState() {
    super.initState();
    final realtime = ref.read(realtimeProvider)..connect();
    _events = realtime.stream.listen(_onEvent);
    _connected = realtime.connected..addListener(_onConnection);
    // Notifications : jeton enregistré, et une notification touchée ouvre sa commande.
    final push = ref.read(pushServiceProvider);
    _pushOpened = push.opened.listen(_openFromPush);
    unawaited(
      push
          .start()
          .then((_) {
            final initial = push.takeInitialOpened();
            if (initial != null) _openFromPush(initial);
          })
          .catchError((Object _) {}),
    );
  }

  /// Retour du réseau après une coupure : les listes sont relues (statuts manqués pendant la
  /// coupure, message d'erreur affiché sans réseau).
  void _onConnection() {
    final connected = _connected?.value ?? false;
    if (!connected) {
      _cut = true;
      return;
    }
    if (!_cut || !mounted) return;
    _cut = false;
    ref
      ..invalidate(activeOrdersProvider)
      ..invalidate(ordersProvider)
      ..invalidate(walletProvider);
  }

  void _openFromPush(Json data) {
    final orderId = data['orderId'];
    if (orderId is String && orderId.isNotEmpty && mounted) {
      _openOrder(orderId);
    } else if (data['pendingId'] is String && mounted) {
      // Colis d'un envoi en attente (départ bloqué) : l'onglet Commandes le montre en tête.
      ref.invalidate(pendingDeliveriesProvider);
      setState(() => _tab = 1);
    }
  }

  @override
  void dispose() {
    unawaited(_events?.cancel());
    _connected?.removeListener(_onConnection);
    unawaited(_pushOpened?.cancel());
    _payoutTimer?.cancel();
    _failedTimer?.cancel();
    super.dispose();
  }

  void _onEvent(RealtimeEvent event) {
    // Toute nouvelle du serveur peut avoir mis une notification dans la cloche.
    ref.invalidate(inboxProvider);
    switch (event.name) {
      case 'location-link.submitted':
        // Un client de l'envoi a placé son point : son colis part (ou attend le paiement).
        ref
          ..invalidate(pendingDeliveriesProvider)
          ..invalidate(activeOrdersProvider);
      case 'order.status':
        // Livraison qui avance : listes et ventes du jour relues.
        ref
          ..invalidate(activeOrdersProvider)
          ..invalidate(ordersProvider)
          ..invalidate(walletProvider);
        _onStatus(event.payload);
      case 'payout.status' when event.payload['status'] == 'SUCCEEDED':
        ref.invalidate(walletProvider);
        final amount = (event.payload['amount'] as num?)?.toInt();
        if (amount == null || !mounted) return;
        TaraFeedback.play(context, TaraSound.cash);
        _payoutTimer?.cancel();
        setState(() => _payout = amount);
        _payoutTimer = Timer(const Duration(seconds: 5), () {
          if (mounted) setState(() => _payout = null);
        });
    }
  }

  /// Échec à décider : son d'alerte et bandeau, sauf si un autre écran (le suivi) est
  /// devant. Le choix fait, ici ou ailleurs, retire le bandeau.
  void _onStatus(Json payload) {
    final orderId = payload['orderId'];
    if (orderId is! String || !mounted) return;
    final failed = payload['status'] == 'DELIVERY_FAILED' && payload['failureDecision'] == null;
    if (!failed) {
      if (_failed?.$1 == orderId) _hideFailed();
      return;
    }
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;
    TaraFeedback.play(context, TaraSound.error);
    _failedTimer?.cancel();
    setState(() => _failed = (orderId, payload['reference'] as String? ?? ''));
    // Le bandeau s'efface ; la ligne « à décider » reste sur l'accueil.
    _failedTimer = Timer(const Duration(seconds: 30), _hideFailed);
  }

  void _hideFailed() {
    _failedTimer?.cancel();
    if (mounted && _failed != null) setState(() => _failed = null);
  }

  /// Nouvelle livraison en plein écran, au-dessus des onglets ; « Suivre la livraison »
  /// remplace le parcours par le suivi. Nouvelle version des conditions pas encore signée :
  /// elle est présentée d'abord, la livraison s'ouvre une fois signée.
  void _newOrder({LocationLink? fromLink}) {
    final terms = ref.read(termsStatusProvider).value;
    if (terms != null && !terms.upToDate) {
      unawaited(
        Navigator.of(context).push(
          scopedPage<void>(
            context,
            (route) => TermsScreen.update(
              onLater: () => Navigator.of(route).pop(),
              onSigned: () {
                Navigator.of(route).pop();
                _openNewOrder(fromLink: fromLink);
              },
            ),
          ),
        ),
      );
      return;
    }
    _openNewOrder(fromLink: fromLink);
  }

  void _openNewOrder({LocationLink? fromLink}) => unawaited(
    Navigator.of(context).push(
      scopedPage<void>(
        context,
        (flowContext) => NewOrderFlow(
          me: widget.me,
          fromLink: fromLink,
          onClose: () => Navigator.of(flowContext).pop(),
          onTrack: (orderId) => unawaited(
            Navigator.of(flowContext).pushReplacement(scopedPage<void>(flowContext, (c) => _tracking(c, orderId))),
          ),
        ),
      ),
    ),
  );

  /// Envoi en masse (C4) : la liste d'envoi en plein écran ; les conditions à jour d'abord,
  /// comme pour une livraison.
  void _bulk() {
    final terms = ref.read(termsStatusProvider).value;
    if (terms != null && !terms.upToDate) {
      unawaited(
        Navigator.of(context).push(
          scopedPage<void>(
            context,
            (route) => TermsScreen.update(
              onLater: () => Navigator.of(route).pop(),
              onSigned: () {
                Navigator.of(route).pop();
                _openBulk();
              },
            ),
          ),
        ),
      );
      return;
    }
    _openBulk();
  }

  void _openBulk() => unawaited(
    Navigator.of(context).push(
      scopedPage<void>(
        context,
        (flowContext) => BulkScreen(
          me: widget.me,
          now: widget.now,
          onClose: () {
            ref
              ..invalidate(activeOrdersProvider)
              ..invalidate(pendingDeliveriesProvider);
            Navigator.of(flowContext).pop();
          },
        ),
      ),
    ),
  );

  /// « Demander l'adresse » (B3) : lien envoyé au destinataire, puis livraison créée avec
  /// son point, l'écran du lien remplacé par la nouvelle livraison.
  void _askAddress() => unawaited(
    Navigator.of(context).push(
      scopedPage<void>(
        context,
        (route) => AskAddressScreen(
          me: widget.me,
          onBack: () => Navigator.of(route).pop(),
          onCreateOrder: (link) {
            Navigator.of(route).pop();
            _newOrder(fromLink: link);
          },
        ),
      ),
    ),
  );

  /// Cloche : notifications ; une notification ouvre la commande, le portefeuille ou les
  /// adresses demandées.
  void _openNotifications() => unawaited(
    Navigator.of(context).push(
      scopedPage<void>(
        context,
        (route) => NotificationsScreen(
          now: widget.now,
          onBack: () => Navigator.of(route).pop(),
          onOpenOrder: _openOrder,
          onWallet: () {
            Navigator.of(route).pop();
            _openWallet();
          },
          onAskAddress: () {
            Navigator.of(route).pop();
            _askAddress();
          },
        ),
      ),
    ),
  );

  /// « Mon activité » de la boutique.
  void _openActivity() => unawaited(
    Navigator.of(context).push(
      scopedPage<void>(
        context,
        (route) => ActivityScreen(
          shopName: widget.me.merchant?.shopName ?? widget.me.fullName ?? '',
          onBack: () => Navigator.of(route).pop(),
        ),
      ),
    ),
  );

  /// Portefeuille (G1, G2, G3, G7) : son onglet.
  void _openWallet() => setState(() => _tab = 2);

  /// Onglet Commandes, sur la liste demandée.
  void _showOrders(String scope) => setState(() {
    _ordersScope = scope;
    _tab = 1;
  });

  /// Suivi d'une commande (F1), en plein écran.
  void _openOrder(String orderId) =>
      unawaited(Navigator.of(context).push(scopedPage<void>(context, (c) => _tracking(c, orderId))));

  Widget _tracking(BuildContext context, String orderId) =>
      TrackingScreen(orderId: orderId, now: widget.now, onBack: () => Navigator.of(context).pop());

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final payout = _payout;
    final failed = _failed;
    return Stack(
      children: [
        Positioned.fill(
          child: TaraTabShell(
            items: [
              TabItem(TaraIcons.home, l.tabHome),
              TabItem(TaraIcons.package, l.tabOrders),
              TabItem(TaraIcons.wallet, l.walletTitle),
              TabItem(TaraIcons.user, l.tabProfile),
            ],
            // « + » au centre de la barre : nouvelle livraison, depuis n'importe quel onglet.
            action: TabAction(icon: TaraIcons.plus, label: l.newDelivery, onPressed: _newOrder),
            // Finesse : barre en pilule comme l'app livreur, « + » rond au milieu.
            pill: true,
            current: _tab,
            onSelected: (tab) => setState(() {
              if (tab == 1 && _tab != 1) _ordersScope = 'active';
              _tab = tab;
            }),
            child: switch (_tab) {
              1 => OrdersScreen(
                key: ValueKey(_ordersScope),
                initialScope: _ordersScope,
                onOpenOrder: (order) => _openOrder(order.id),
                onOpenOrderId: _openOrder,
                now: widget.now,
              ),
              2 => WalletScreen(me: widget.me, now: widget.now),
              3 => ProfileScreen(me: widget.me),
              _ => HomeScreen(
                me: widget.me,
                onNewOrder: _newOrder,
                onBulk: _bulk,
                onLocationLink: _askAddress,
                onOpenOrder: (order) => _openOrder(order.id),
                onWallet: _openWallet,
                onReceipts: () => _showOrders('history'),
                onSeeAll: () => _showOrders('active'),
                onNotifications: _openNotifications,
                onActivity: widget.me.merchant == null ? null : _openActivity,
                now: widget.now,
              ),
            },
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          top: MediaQuery.paddingOf(context).top + 8,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 320),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween(begin: const Offset(0, -.4), end: Offset.zero).animate(animation),
                child: child,
              ),
            ),
            child: failed != null
                ? _FailedBanner(
                    key: ValueKey(failed),
                    reference: failed.$2,
                    onTap: () {
                      _hideFailed();
                      _openOrder(failed.$1);
                    },
                  )
                : payout == null
                ? const SizedBox.shrink()
                : _PayoutBanner(key: ValueKey(payout), amount: payout),
          ),
        ),
      ],
    );
  }
}

/// « 128 500 F envoyés sur votre Mobile Money » : bandeau de verre en haut de l'écran.
class _PayoutBanner extends StatelessWidget {
  const _PayoutBanner({super.key, required this.amount});

  final int amount;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    return Semantics(
      liveRegion: true,
      child: Material(
        type: MaterialType.transparency,
        child: GlassCard(
          radius: 20,
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            children: [
              TaraIcon(TaraIcons.wallet, size: 22, color: c.success),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l.payoutSent('${formatAmount(amount)} F'),
                  style: TaraText.text.copyWith(color: c.textPrimary, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// « Livraison impossible · TR-48213 » : bandeau rouge qui ouvre le suivi pour choisir la
/// suite (nouvelle tentative ou retour).
class _FailedBanner extends StatelessWidget {
  const _FailedBanner({super.key, required this.reference, required this.onTap});

  final String reference;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    return Semantics(
      liveRegion: true,
      button: true,
      child: Material(
        type: MaterialType.transparency,
        child: GestureDetector(
          onTap: onTap,
          child: GlassCard(
            radius: 20,
            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
            child: Row(
              children: [
                const IconTile(icon: TaraIcons.alertCircle, size: 40, tone: TintTone.danger),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.failureBannerTitle(reference),
                        style: TaraText.text.copyWith(color: c.dangerText, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 2),
                      Text(l.failureBannerBody, style: TaraText.small.copyWith(color: c.textSecondary)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                TaraIcon(TaraIcons.chevronRight, size: 20, color: c.textTertiary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
