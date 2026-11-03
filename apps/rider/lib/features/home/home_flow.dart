import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/api/models.dart';
import '../../core/realtime/realtime_client.dart';
import '../../design/components/glass.dart';
import '../../design/tara_colors.dart';
import '../../design/tara_typography.dart';
import '../../l10n/app_localizations.dart';
import '../common/status_screen.dart';
import '../offer/offer_screen.dart';
import 'home_offline_screen.dart';
import 'home_online_screen.dart';
import 'home_summary.dart';

/// Accueil du livreur validé : hors ligne (05) ⇄ en ligne (06), propositions (07) reçues
/// par le temps réel, les notifications ou au retour dans l'app.
class HomeFlow extends ConsumerStatefulWidget {
  const HomeFlow({super.key});

  @override
  ConsumerState<HomeFlow> createState() => _HomeFlowState();
}

class _HomeFlowState extends ConsumerState<HomeFlow> {
  Offer? _offer;
  Json? _accepted;
  String? _notice;
  Timer? _noticeTimer;
  StreamSubscription<RealtimeEvent>? _realtime;
  StreamSubscription<Json>? _push;

  @override
  void initState() {
    super.initState();
    _realtime = ref.read(realtimeProvider).stream.listen(_onEvent);
    _push = ref.read(pushServiceProvider).messages.listen((data) {
      if (data['type'] == 'offer.new') unawaited(_loadPendingOffers());
    });
  }

  @override
  void dispose() {
    unawaited(_realtime?.cancel());
    unawaited(_push?.cancel());
    _noticeTimer?.cancel();
    super.dispose();
  }

  void _onEvent(RealtimeEvent event) {
    if (!ref.read(onlineControllerProvider).online) return;
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
    if (_offer != null) return;
    try {
      final offers = await ref.read(riderApiProvider).offers();
      if (mounted && offers.isNotEmpty && _offer == null) setState(() => _offer = Offer.fromJson(offers.first));
    } catch (_) {
      // Sans réseau : le temps réel ou la prochaine notification prendra le relais.
    }
  }

  void _closeOffer(String? message) {
    setState(() {
      _offer = null;
      _notice = message;
    });
    _noticeTimer?.cancel();
    if (message != null) {
      _noticeTimer = Timer(const Duration(seconds: 4), () {
        if (mounted) setState(() => _notice = null);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final online = ref.watch(onlineControllerProvider);
    final accepted = _accepted;
    if (accepted != null) {
      // Écran d'enlèvement (08) au prochain lot.
      return StatusScreen(
        title: l.jobAccepted,
        body: l.jobAcceptedBody('${accepted['reference'] ?? ''}'),
        actionLabel: l.continueLabel,
        onAction: () => setState(() => _accepted = null),
      );
    }
    final offer = _offer;
    return ListenableBuilder(
      listenable: online,
      builder: (context, _) => Stack(
        children: [
          Positioned.fill(
            child: online.online
                ? HomeOnlineScreen(onWentOffline: () => setState(() {}), onDetails: () {}, onSos: () {})
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
                onAccepted: (order) => setState(() {
                  _offer = null;
                  _accepted = order;
                }),
              ),
            ),
        ],
      ),
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
