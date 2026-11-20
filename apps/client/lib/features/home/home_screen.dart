import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tara_ui/components/buttons.dart';
import 'package:tara_ui/components/glass.dart';
import 'package:tara_ui/components/layout.dart';
import 'package:tara_ui/components/tab_shell.dart';
import 'package:tara_ui/feedback/tara_feedback.dart';
import 'package:tara_ui/format.dart';
import 'package:tara_ui/motion/effects.dart';
import 'package:tara_ui/motion/liquid_background.dart';
import 'package:tara_ui/motion/liquid_wave.dart';
import 'package:tara_ui/tara_colors.dart';
import 'package:tara_ui/tara_icons.dart';
import 'package:tara_ui/tara_typography.dart';

import '../../app/providers.dart';
import '../../core/api/client_models.dart';
import '../../l10n/app_localizations.dart';
import '../bulk/bulk_screen.dart';
import '../orders/order_row.dart';

/// Commandes en cours de l'expéditeur (accueil), relues à chaque retour sur l'accueil.
final activeOrdersProvider = FutureProvider<List<OrderSummary>>(
  (ref) => ref.read(clientApiProvider).orders(scope: 'active'),
);

/// Portefeuille : solde Tara, ventes de la boutique à reverser.
final walletProvider = FutureProvider<Wallet>((ref) => ref.read(clientApiProvider).wallet());

/// 04 · Accueil (maquette de la refonte) : salutation, ventes du jour de la boutique sur
/// le liquide de la marque, « Où livrer ? », raccourcis (plusieurs colis, adresse demandée
/// au destinataire, reçus), livraisons en cours avec leur avancée.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({
    super.key,
    required this.me,
    required this.onNewOrder,
    required this.onLocationLink,
    this.onBulk,
    required this.onOpenOrder,
    required this.onWallet,
    this.onReceipts,
    this.onSeeAll,
    this.now,
  });

  final Me me;
  final VoidCallback onNewOrder;
  final VoidCallback onLocationLink;

  /// Envoi en masse (liste d'envoi) ; absent, le raccourci n'est pas proposé.
  final VoidCallback? onBulk;
  final ValueChanged<OrderSummary> onOpenOrder;
  final VoidCallback onWallet;

  /// Livraisons terminées et leurs reçus ; absent, le raccourci n'est pas proposé.
  final VoidCallback? onReceipts;

  /// Toutes les livraisons en cours (onglet Commandes).
  final VoidCallback? onSeeAll;

  /// Horloge (tests).
  final DateTime Function()? now;

  static const _blobs = [
    BlobSpec(alignment: Alignment(1.25, -1.05), size: 300, colors: BlobSpec.brand, blur: 70),
    BlobSpec(alignment: Alignment(-1.3, 0.65), size: 240, colors: BlobSpec.warm, blur: 64, delay: Duration(seconds: 5)),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final orders = ref.watch(activeOrdersProvider);
    final wallet = me.merchant == null ? null : ref.watch(walletProvider);
    final clock = now?.call() ?? DateTime.now();
    final bulkCount = ref.watch(bulkDraftCountProvider(me.id)).value ?? 0;

    Future<void> refresh() async {
      ref
        ..invalidate(activeOrdersProvider)
        ..invalidate(walletProvider);
      await ref.read(activeOrdersProvider.future).catchError((_) => <OrderSummary>[]);
    }

    final count = orders.value?.length ?? 0;
    return TaraScreen(
      blobs: _blobs,
      safeBottom: false,
      // Le contenu défile jusqu'en bas de l'écran, sous la barre d'onglets en verre.
      child: RefreshIndicator(
        onRefresh: refresh,
        child: ListView(
          padding: EdgeInsets.fromLTRB(20, 12, 20, 24 + TaraTabShell.bottomInset(context)),
          children: [
            Row(
              children: [
                InitialsAvatar(name: me.fullName ?? ''),
                const SizedBox(width: 12),
                Expanded(
                  child: MergeSemantics(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          clock.hour < 18 ? l.goodMorning : l.goodEvening,
                          style: TaraText.label.copyWith(color: c.textTertiary),
                        ),
                        Text(
                          me.merchant?.shopName ?? me.fullName ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TaraText.cardTitle.copyWith(color: c.textPrimary),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (wallet != null) ...[_SalesHero(wallet: wallet.value, onTap: onWallet), const SizedBox(height: 14)],
            _WhereTo(onTap: onNewOrder),
            const SizedBox(height: 18),
            _QuickActions(
              actions: [
                if (onBulk != null) (TaraIcons.users, l.quickBulk, onBulk!, bulkCount),
                (TaraIcons.mapPin, l.quickAskAddress, onLocationLink, 0),
                if (onReceipts != null) (TaraIcons.clipboard, l.quickReceipts, onReceipts!, 0),
              ],
            ),
            const SizedBox(height: 22),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: l.inProgress),
                          if (count > 0) TextSpan(text: ' · $count', style: TextStyle(color: c.accentText)),
                        ],
                      ),
                      style: TaraText.cardTitle.copyWith(color: c.textPrimary),
                    ),
                  ),
                ),
                if (onSeeAll != null && count > 0) TaraLink(label: l.seeAll, onPressed: onSeeAll!),
              ],
            ),
            const SizedBox(height: 10),
            switch (orders) {
              AsyncData(:final value) when value.isEmpty => _Empty(text: l.noOrdersInProgress),
              AsyncData(:final value) => Column(
                children: [
                  for (var i = 0; i < value.length; i++) ...[
                    if (i > 0) const SizedBox(height: 8),
                    _ActiveOrderCard(order: value[i], now: clock, onTap: () => onOpenOrder(value[i])),
                  ],
                ],
              ),
              AsyncError() => _Failed(onRetry: () => ref.invalidate(activeOrdersProvider)),
              _ => const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(child: GooLoader(compact: true)),
              ),
            },
          ],
        ),
      ),
    );
  }
}

/// Boutique : encaissé aujourd'hui sur le liquide de la marque. Le montant s'additionne en
/// direct à chaque livraison (il monte, la pièce tinte) ; dessous, ce qui part ce soir.
class _SalesHero extends StatefulWidget {
  const _SalesHero({required this.wallet, required this.onTap});
  final Wallet? wallet;
  final VoidCallback onTap;

  @override
  State<_SalesHero> createState() => _SalesHeroState();
}

class _SalesHeroState extends State<_SalesHero> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 650));

  @override
  void didUpdateWidget(_SalesHero old) {
    super.didUpdateWidget(old);
    final before = old.wallet?.todaySales;
    final now = widget.wallet?.todaySales;
    if (before != null && now != null && now > before) {
      TaraFeedback.play(context, TaraSound.cash);
      unawaited(_pulse.forward(from: 0));
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final data = widget.wallet;
    final pending = data?.merchantBalance ?? 0;
    final pendingText = '${formatAmount(pending)} F';
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (context, child) {
            // Petit rebond quand une vente s'ajoute.
            final t = Curves.easeOut.transform(_pulse.value);
            return Transform.scale(scale: 1 + .03 * (t < .5 ? t * 2 : (1 - t) * 2), child: child);
          },
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: SizedBox(
              height: 158,
              child: Stack(
                children: [
                  const Positioned.fill(
                    child: GlassCard(radius: 28, shadow: false, padding: EdgeInsets.zero, child: SizedBox.expand()),
                  ),
                  Positioned.fill(
                    child: LiquidFill(
                      level: .27,
                      front: TaraLiquid.front,
                      back: TaraLiquid.back(dark: c.isDark),
                      frontPeriod: TaraLiquid.frontPeriod,
                      backPeriod: TaraLiquid.backPeriod,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                data == null
                                    ? l.salesToday
                                    : '${l.salesToday} · ${l.salesDeliveries(data.todayDeliveries)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TaraText.label.copyWith(color: c.textSecondary),
                              ),
                            ),
                            TaraIcon(TaraIcons.chevronRight, size: 20, color: c.textTertiary),
                          ],
                        ),
                        const SizedBox(height: 4),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(end: (data?.todaySales ?? 0).toDouble()),
                            duration: const Duration(milliseconds: 900),
                            curve: Curves.easeOutCubic,
                            builder: (context, value, _) => Text(
                              '${formatAmount(value.round())} F',
                              maxLines: 1,
                              style: TaraText.amountL.copyWith(color: c.textPrimary),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (data != null)
                          Text(
                            data.payoutSchedule == 'DAILY'
                                ? l.toReceiveDaily(pendingText)
                                : l.toReceiveOnDemand(pendingText),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TaraText.small.copyWith(color: c.textSecondary, fontWeight: FontWeight.w600),
                          ),
                      ],
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
}

/// « Où livrer ? » : la porte d'entrée d'une nouvelle livraison, comme un champ de recherche.
class _WhereTo extends StatelessWidget {
  const _WhereTo({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    return Semantics(
      button: true,
      label: '${l.whereToDeliver} ${l.whereToDeliverHint}',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: GlassCard(
          radius: 24,
          shadow: false,
          padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
          child: Row(
            children: [
              const IconTile(icon: TaraIcons.search, size: 44, radius: 15),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.whereToDeliver, style: TaraText.bodyStrong.copyWith(color: c.textPrimary)),
                    Text(
                      l.whereToDeliverHint,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TaraText.small.copyWith(color: c.textTertiary),
                    ),
                  ],
                ),
              ),
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(shape: BoxShape.circle, gradient: TaraBrand.gradient),
                child: const Center(child: TaraIcon(TaraIcons.arrowRight, size: 20, color: TaraBrand.onBrand)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Raccourcis en pastilles rondes : icône dans un disque, libellé dessous ; un compteur
/// orange quand une liste d'envoi attend d'être reprise.
class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.actions});
  final List<(TaraIconData, String, VoidCallback, int)> actions;

  @override
  Widget build(BuildContext context) {
    final c = TaraColors.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (icon, label, onTap, badge) in actions)
          Expanded(
            child: Semantics(
              button: true,
              label: badge > 0 ? '$label ($badge)' : label,
              excludeSemantics: true,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onTap,
                child: Column(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        GlassCard(
                          radius: 26,
                          padding: EdgeInsets.zero,
                          child: SizedBox(
                            width: 52,
                            height: 52,
                            child: Center(child: TaraIcon(icon, size: 22, color: c.textPrimary)),
                          ),
                        ),
                        if (badge > 0)
                          Positioned(
                            top: -4,
                            right: -4,
                            child: Container(
                              constraints: const BoxConstraints(minWidth: 20),
                              height: 20,
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              decoration: BoxDecoration(gradient: TaraBrand.gradient, borderRadius: BorderRadius.circular(10)),
                              alignment: Alignment.center,
                              child: Text(
                                '$badge',
                                style: TaraText.smallStrong.copyWith(color: TaraBrand.onBrand, fontSize: 11),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: TaraText.small.copyWith(color: c.textPrimary, fontWeight: FontWeight.w700, height: 1.25),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Livraison en cours (maquette) : destinataire et lieu précis, étape, puis une barre qui
/// avance avec la course (liquide qui coule, livreur qui roule) ; rouge si elle a échoué.
class _ActiveOrderCard extends StatelessWidget {
  const _ActiveOrderCard({required this.order, required this.now, required this.onTap});
  final OrderSummary order;
  final DateTime now;
  final VoidCallback onTap;

  /// Avancée affichée selon l'étape (le serveur ne donne pas encore la distance restante).
  static double _progress(String status) => switch (status) {
    'CREATED' => .06,
    'SEARCHING_RIDER' => .12,
    'ASSIGNED' => .25,
    'PICKED_UP' => .55,
    'IN_DELIVERY' => .76,
    _ => 1,
  };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final (_, tone, label) = OrderRow.orderStatus(l, order, now);
    final failed = order.status == 'DELIVERY_FAILED' && order.failureDecision == null;
    final unpaid = order.status == 'CREATED' && tone == TintTone.danger;
    final moving = const {'ASSIGNED', 'PICKED_UP', 'IN_DELIVERY'}.contains(order.status);
    final chip = failed ? l.chipDecide : (unpaid ? l.chipPay : null);
    final name = [
      if (order.batchNumber case final number?) l.parcelNumberShort(number),
      order.recipientName,
    ].join(' · ');
    return MergeSemantics(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: GlassCard(
          radius: 20,
          shadow: false,
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: name,
                                style: TaraText.text.copyWith(color: c.textPrimary, fontWeight: FontWeight.w800),
                              ),
                              TextSpan(
                                text: '  ${precisePlace(order.dropoffLandmark, order.dropoffNeighborhood)}',
                                style: TaraText.small.copyWith(color: c.textTertiary, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$label · ${order.reference}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TaraText.small.copyWith(
                            color: failed || unpaid ? c.dangerText : c.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (chip != null) ...[
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: c.dangerTint, borderRadius: BorderRadius.circular(999)),
                      child: Text(chip, style: TaraText.smallStrong.copyWith(color: c.dangerText)),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              _RideProgress(ratio: _progress(order.status), failed: failed, moving: moving),
            ],
          ),
        ),
      ),
    );
  }
}

/// Barre d'avancée d'une livraison : point de départ, liquide qui coule jusqu'à l'étape,
/// anneau d'arrivée ; le livreur pulse à sa place pendant la course.
class _RideProgress extends StatelessWidget {
  const _RideProgress({required this.ratio, required this.failed, required this.moving});
  final double ratio;
  final bool failed;
  final bool moving;

  @override
  Widget build(BuildContext context) {
    final c = TaraColors.of(context);
    final colors = failed
        ? const [Color(0xFFFF2D3D), Color(0xFFFF6B75), Color(0xFFFF2D3D)]
        : const [TaraBrand.amber, TaraBrand.orange, TaraBrand.red, TaraBrand.orange, TaraBrand.amber];
    return ExcludeSemantics(
      child: SizedBox(
        height: 14,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            return Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.centerLeft,
              children: [
                Container(
                  height: 4,
                  decoration: BoxDecoration(color: c.track, borderRadius: BorderRadius.circular(2)),
                ),
                SizedBox(
                  width: width * ratio,
                  height: 4,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: FlowingGradient(colors: colors, period: const Duration(milliseconds: 2600)),
                  ),
                ),
                Positioned(
                  left: -4,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(color: c.textPrimary, shape: BoxShape.circle),
                  ),
                ),
                Positioned(
                  right: -2,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: c.bg,
                      border: Border.all(color: failed ? c.dangerText : TaraBrand.orange, width: 2.5),
                    ),
                  ),
                ),
                if (moving)
                  Positioned(
                    left: width * ratio - 7,
                    child: PulseRings(
                      size: 14,
                      color: TaraBrand.orange,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: TaraBrand.gradient,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = TaraColors.of(context);
    return GlassCard(
      radius: 22,
      shadow: false,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      child: Row(
        children: [
          TaraIcon(TaraIcons.package, size: 22, color: c.textTertiary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: TaraText.label.copyWith(color: c.textSecondary, height: 1.4)),
          ),
        ],
      ),
    );
  }
}

class _Failed extends StatelessWidget {
  const _Failed({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(l.ordersError, style: TaraText.label.copyWith(color: c.textSecondary)),
          ),
          TaraLink(label: l.retry, onPressed: onRetry),
        ],
      ),
    );
  }
}
