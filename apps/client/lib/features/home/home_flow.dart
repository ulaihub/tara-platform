import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tara_core/realtime/realtime_client.dart';
import 'package:tara_ui/components/glass.dart';
import 'package:tara_ui/components/tab_shell.dart';
import 'package:tara_ui/feedback/tara_feedback.dart';
import 'package:tara_ui/format.dart';
import 'package:tara_ui/tara_colors.dart';
import 'package:tara_ui/tara_icons.dart';
import 'package:tara_ui/tara_typography.dart';

import '../../app/providers.dart';
import '../../core/api/client_models.dart';
import '../../l10n/app_localizations.dart';
import '../common/scoped_page.dart';
import '../order/new_order_flow.dart';
import '../orders/orders_screen.dart';
import '../profile/profile_screen.dart';
import '../tracking/tracking_screen.dart';
import 'home_screen.dart';

/// Onglets de l'expéditeur (Accueil, Commandes, Profil) : le contenu défile sous la barre en
/// verre, transition vitrée d'un onglet à l'autre. La nouvelle livraison s'ouvre en plein
/// écran. Le temps réel garde l'accueil à jour (livraisons, ventes du jour) et annonce les
/// reversements par un bandeau et le son de pièce.
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
  StreamSubscription<RealtimeEvent>? _events;

  /// Reversement arrivé sur le Mobile Money (montant), affiché quelques secondes.
  int? _payout;
  Timer? _payoutTimer;

  @override
  void initState() {
    super.initState();
    final realtime = ref.read(realtimeProvider)..connect();
    _events = realtime.stream.listen(_onEvent);
  }

  @override
  void dispose() {
    unawaited(_events?.cancel());
    _payoutTimer?.cancel();
    super.dispose();
  }

  void _onEvent(RealtimeEvent event) {
    switch (event.name) {
      case 'order.status':
        // Livraison qui avance : listes et ventes du jour relues.
        ref
          ..invalidate(activeOrdersProvider)
          ..invalidate(ordersProvider)
          ..invalidate(walletProvider);
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

  /// Nouvelle livraison en plein écran, au-dessus des onglets ; « Suivre la livraison »
  /// remplace le parcours par le suivi.
  void _newOrder() => unawaited(
    Navigator.of(context).push(
      scopedPage<void>(
        context,
        (flowContext) => NewOrderFlow(
          me: widget.me,
          onClose: () => Navigator.of(flowContext).pop(),
          onTrack: (orderId) => unawaited(
            Navigator.of(flowContext).pushReplacement(scopedPage<void>(flowContext, (c) => _tracking(c, orderId))),
          ),
        ),
      ),
    ),
  );

  /// Suivi d'une commande (F1), en plein écran.
  void _openOrder(String orderId) =>
      unawaited(Navigator.of(context).push(scopedPage<void>(context, (c) => _tracking(c, orderId))));

  Widget _tracking(BuildContext context, String orderId) =>
      TrackingScreen(orderId: orderId, now: widget.now, onBack: () => Navigator.of(context).pop());

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final payout = _payout;
    return Stack(
      children: [
        Positioned.fill(
          child: TaraTabShell(
            items: [
              TabItem(TaraIcons.home, l.tabHome),
              TabItem(TaraIcons.package, l.tabOrders),
              TabItem(TaraIcons.user, l.tabProfile),
            ],
            current: _tab,
            onSelected: (tab) => setState(() => _tab = tab),
            child: switch (_tab) {
              1 => OrdersScreen(onOpenOrder: (order) => _openOrder(order.id), now: widget.now),
              2 => ProfileScreen(me: widget.me),
              _ => HomeScreen(
                me: widget.me,
                onNewOrder: _newOrder,
                onLocationLink: () {},
                onOpenOrder: (order) => _openOrder(order.id),
                onWallet: () {},
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
            child: payout == null ? const SizedBox.shrink() : _PayoutBanner(key: ValueKey(payout), amount: payout),
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
