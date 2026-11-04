import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tara_ui/components/buttons.dart';
import 'package:tara_ui/components/glass.dart';
import 'package:tara_ui/components/layout.dart';
import 'package:tara_ui/format.dart';
import 'package:tara_ui/motion/effects.dart';
import 'package:tara_ui/motion/liquid_background.dart';
import 'package:tara_ui/tara_colors.dart';
import 'package:tara_ui/tara_icons.dart';
import 'package:tara_ui/tara_typography.dart';

import '../../app/providers.dart';
import '../../core/api/client_models.dart';
import '../../l10n/app_localizations.dart';

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
    required this.onTab,
    this.now,
  });

  final Me me;
  final VoidCallback onNewOrder;
  final VoidCallback onLocationLink;
  final ValueChanged<OrderSummary> onOpenOrder;
  final VoidCallback onWallet;

  /// Barre d'onglets : 0 accueil, 1 commandes, 2 profil.
  final ValueChanged<int> onTab;

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
      child: Column(
        children: [
          Expanded(
            child: RefreshIndicator(
              onRefresh: refresh,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
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
                  if (wallet != null) ...[
                    const SizedBox(height: 12),
                    _ShopBalance(wallet: wallet.value, onTap: onWallet),
                  ],
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
                            _OrderRow(order: value[i], now: clock, onTap: () => onOpenOrder(value[i])),
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
          ),
          SafeArea(
            top: false,
            child: FloatingTabBar(
              items: [
                TabItem(TaraIcons.home, l.tabHome),
                TabItem(TaraIcons.package, l.tabOrders),
                TabItem(TaraIcons.user, l.tabProfile),
              ],
              current: 0,
              onSelected: onTab,
            ),
          ),
        ],
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

/// Ventes encaissées de la boutique, pas encore reversées.
class _ShopBalance extends StatelessWidget {
  const _ShopBalance({required this.wallet, required this.onTap});
  final Wallet? wallet;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final data = wallet;
    return TintBox(
      tone: TintTone.success,
      padding: const EdgeInsets.fromLTRB(14, 6, 10, 6),
      child: ListRow(
        leading: TaraIcon(TaraIcons.wallet, size: 22, color: c.success),
        title: data == null ? l.shopBalance : '${formatAmount(data.merchantBalance ?? 0)} F',
        subtitle: data == null
            ? null
            : data.payoutSchedule == 'DAILY'
            ? l.shopBalanceDaily
            : l.shopBalanceOnDemand,
        trailing: TaraIcon(TaraIcons.chevronRight, size: 20, color: c.textTertiary),
        onTap: onTap,
      ),
    );
  }
}

/// Livraison en cours : destinataire, quartier, étape.
class _OrderRow extends StatelessWidget {
  const _OrderRow({required this.order, required this.now, required this.onTap});
  final OrderSummary order;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final scheduled = order.scheduledFor?.toLocal();
    final (icon, tone, label) = switch (order.status) {
      'CREATED' when scheduled != null && scheduled.isAfter(now) => (
        TaraIcons.clock,
        TintTone.accent,
        l.statusScheduled(_when(l, scheduled, now)),
      ),
      'CREATED' || 'SEARCHING_RIDER' => (TaraIcons.timer, TintTone.accent, l.statusSearching),
      'ASSIGNED' => (TaraIcons.navigation, TintTone.accent, l.statusRiderComing),
      'PICKED_UP' || 'IN_DELIVERY' => (TaraIcons.package, TintTone.success, l.statusInDelivery),
      'DELIVERY_FAILED' => (TaraIcons.alertCircle, TintTone.danger, l.statusFailed),
      _ => (TaraIcons.package, TintTone.accent, order.status),
    };
    final place = order.dropoffNeighborhood ?? order.dropoffLandmark;
    return ListRow(
      leading: IconTile(icon: icon, size: 40, tone: tone),
      title: '${order.recipientName} · $place',
      subtitle: '$label · ${order.reference}',
      trailing: TaraIcon(TaraIcons.chevronRight, size: 20, color: c.textTertiary),
      onTap: onTap,
    );
  }

  static String _when(AppLocalizations l, DateTime at, DateTime now) {
    final sameDay = at.year == now.year && at.month == now.month && at.day == now.day;
    final tomorrow = now.add(const Duration(days: 1));
    final nextDay = at.year == tomorrow.year && at.month == tomorrow.month && at.day == tomorrow.day;
    final time = formatClock(at);
    if (sameDay) return l.todayAt(time);
    if (nextDay) return l.tomorrowAt(time);
    return '${at.day.toString().padLeft(2, '0')}/${at.month.toString().padLeft(2, '0')} · $time';
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
