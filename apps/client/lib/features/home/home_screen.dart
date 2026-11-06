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
import 'package:tara_ui/tara_colors.dart';
import 'package:tara_ui/tara_icons.dart';
import 'package:tara_ui/tara_typography.dart';

import '../../app/providers.dart';
import '../../core/api/client_models.dart';
import '../../l10n/app_localizations.dart';
import '../orders/order_row.dart';

/// Commandes en cours de l'expéditeur (accueil), relues à chaque retour sur l'accueil.
final activeOrdersProvider = FutureProvider<List<OrderSummary>>(
  (ref) => ref.read(clientApiProvider).orders(scope: 'active'),
);

/// Portefeuille : solde Tara, ventes de la boutique à reverser.
final walletProvider = FutureProvider<Wallet>((ref) => ref.read(clientApiProvider).wallet());

/// 04 · Accueil (non dessiné : style Tara) : salutation, « Nouvelle livraison », demande
/// d'adresse au destinataire par lien de localisation (B3), solde de la boutique pour un
/// marchand, livraisons en cours.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({
    super.key,
    required this.me,
    required this.onNewOrder,
    required this.onLocationLink,
    required this.onOpenOrder,
    required this.onWallet,
    this.now,
  });

  final Me me;
  final VoidCallback onNewOrder;
  final VoidCallback onLocationLink;
  final ValueChanged<OrderSummary> onOpenOrder;
  final VoidCallback onWallet;

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

    Future<void> refresh() async {
      ref
        ..invalidate(activeOrdersProvider)
        ..invalidate(walletProvider);
      await ref.read(activeOrdersProvider.future).catchError((_) => <OrderSummary>[]);
    }

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
            _SendCard(onNewOrder: onNewOrder, onLocationLink: onLocationLink),
            if (wallet != null) ...[const SizedBox(height: 12), _ShopBalance(wallet: wallet.value, onTap: onWallet)],
            const SizedBox(height: 22),
            SectionHeader(
              title: l.inProgress,
              action: orders.value == null || orders.value!.isEmpty
                  ? null
                  : Text(
                      '${orders.value!.length}',
                      style: TaraText.label.copyWith(color: c.accentText, fontWeight: FontWeight.w800),
                    ),
            ),
            const SizedBox(height: 8),
            switch (orders) {
              AsyncData(:final value) when value.isEmpty => _Empty(text: l.noOrdersInProgress),
              AsyncData(:final value) => GlassCard(
                radius: 22,
                shadow: false,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                child: Column(
                  children: [
                    for (var i = 0; i < value.length; i++) ...[
                      if (i > 0) Divider(height: 1, color: c.glassBorder),
                      OrderRow(order: value[i], now: clock, onTap: () => onOpenOrder(value[i])),
                    ],
                  ],
                ),
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

/// « Envoyer un colis » : nouvelle livraison, ou adresse demandée au destinataire.
class _SendCard extends StatelessWidget {
  const _SendCard({required this.onNewOrder, required this.onLocationLink});
  final VoidCallback onNewOrder;
  final VoidCallback onLocationLink;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    return GlassCard(
      radius: 28,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const IconTile(icon: TaraIcons.package, size: 48, radius: 16),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(l.sendTitle, style: TaraText.titlePanel.copyWith(color: c.textPrimary)),
                    ),
                    const SizedBox(height: 4),
                    Text(l.sendBody, style: TaraText.label.copyWith(color: c.textSecondary, height: 1.4)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          PrimaryButton(label: l.newDelivery, icon: TaraIcons.arrowRight, onPressed: onNewOrder),
          const SizedBox(height: 4),
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: TaraLink(label: l.askAddress, onPressed: onLocationLink),
            ),
          ),
        ],
      ),
    );
  }
}

/// Boutique : encaissé aujourd'hui, qui s'additionne en direct à chaque livraison (le
/// montant monte, la pièce tinte), et ce qui reste à recevoir.
class _ShopBalance extends StatefulWidget {
  const _ShopBalance({required this.wallet, required this.onTap});
  final Wallet? wallet;
  final VoidCallback onTap;

  @override
  State<_ShopBalance> createState() => _ShopBalanceState();
}

class _ShopBalanceState extends State<_ShopBalance> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 650));

  @override
  void didUpdateWidget(_ShopBalance old) {
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
            return Transform.scale(scale: 1 + .04 * (t < .5 ? t * 2 : (1 - t) * 2), child: child);
          },
          child: TintBox(
            tone: TintTone.success,
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            child: Row(
              children: [
                TaraIcon(TaraIcons.wallet, size: 24, color: c.success),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.salesToday, style: TaraText.small.copyWith(color: c.textSecondary)),
                      TweenAnimationBuilder<double>(
                        tween: Tween(end: (data?.todaySales ?? 0).toDouble()),
                        duration: const Duration(milliseconds: 900),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, _) => Text(
                          '${formatAmount(value.round())}\u00a0F',
                          style: TaraText.titlePanel.copyWith(color: c.textPrimary, fontFeatures: TaraText.tabular),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        data == null
                            ? l.shopBalance
                            : [
                                l.salesDeliveries(data.todayDeliveries),
                                if (data.payoutSchedule == 'DAILY')
                                  l.toReceiveDaily('${formatAmount(pending)}\u00a0F')
                                else
                                  l.toReceiveOnDemand('${formatAmount(pending)}\u00a0F'),
                              ].join(' · '),
                        style: TaraText.small.copyWith(color: c.textSecondary),
                      ),
                    ],
                  ),
                ),
                TaraIcon(TaraIcons.chevronRight, size: 20, color: c.textTertiary),
              ],
            ),
          ),
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
