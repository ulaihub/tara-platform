import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tara_ui/components/buttons.dart';
import 'package:tara_ui/components/glass.dart';
import 'package:tara_ui/components/layout.dart';
import 'package:tara_ui/components/progress.dart';
import 'package:tara_ui/components/tab_shell.dart';
import 'package:tara_ui/motion/effects.dart';
import 'package:tara_ui/motion/liquid_background.dart';
import 'package:tara_ui/tara_colors.dart';
import 'package:tara_ui/tara_icons.dart';
import 'package:tara_ui/tara_typography.dart';

import '../../app/providers.dart';
import '../../core/api/client_models.dart';
import '../../l10n/app_localizations.dart';
import 'order_row.dart';
import 'pending_section.dart';

/// Commandes de l'expéditeur par période : en cours (active) ou terminées (history).
final ordersProvider = FutureProvider.family<List<OrderSummary>, String>(
  (ref, scope) => ref.read(clientApiProvider).orders(scope: scope, limit: 50),
);

/// Onglet Commandes (non dessiné : style Tara) : livraisons en cours ou terminées, la plus
/// récente d'abord ; chacune s'ouvre sur son suivi.
class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key, required this.onOpenOrder, this.onOpenOrderId, this.now, this.initialScope = 'active'});

  /// Liste montée au départ : `active` (en cours) ou `history` (terminées, avec leurs reçus).
  final String initialScope;

  final ValueChanged<OrderSummary> onOpenOrder;

  /// Ouvre une commande par son identifiant (colis d'un envoi parti après coup).
  final ValueChanged<String>? onOpenOrderId;

  /// Horloge (tests).
  final DateTime Function()? now;

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  static const _blobs = [
    BlobSpec(alignment: Alignment(1.2, -1.05), size: 280, colors: BlobSpec.brand, blur: 70),
    BlobSpec(alignment: Alignment(-1.3, 0.9), size: 240, colors: BlobSpec.warm, blur: 64, delay: Duration(seconds: 6)),
  ];

  late String _scope = widget.initialScope;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final orders = ref.watch(ordersProvider(_scope));
    final now = widget.now?.call() ?? DateTime.now();
    return TaraScreen(
      blobs: _blobs,
      safeBottom: false,
      child: RefreshIndicator(
        onRefresh: () async {
          ref
            ..invalidate(ordersProvider(_scope))
            ..invalidate(pendingDeliveriesProvider);
          await ref.read(ordersProvider(_scope).future).catchError((_) => <OrderSummary>[]);
        },
        child: ListView(
          padding: EdgeInsets.fromLTRB(20, 12, 20, 24 + TaraTabShell.bottomInset(context)),
          children: [
            Semantics(
              header: true,
              child: Text(l.tabOrders, style: TaraText.titleForm.copyWith(color: c.textPrimary)),
            ),
            const SizedBox(height: 16),
            LiquidSegmented<String>(
              compact: true,
              segments: [('active', l.inProgress), ('history', l.finished)],
              selected: _scope,
              onChanged: (scope) => setState(() => _scope = scope),
            ),
            const SizedBox(height: 16),
            // Envoi en masse : colis qui attendent l'adresse de leur client.
            if (_scope == 'active' && widget.onOpenOrderId != null) PendingSection(onOpenOrder: widget.onOpenOrderId!),
            switch (orders) {
              AsyncData(:final value) when value.isEmpty => GlassCard(
                radius: 22,
                shadow: false,
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
                child: Row(
                  children: [
                    TaraIcon(TaraIcons.package, size: 22, color: c.textTertiary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _scope == 'active' ? l.noOrdersInProgress : l.noOrdersFinished,
                        style: TaraText.label.copyWith(color: c.textSecondary, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              AsyncData(:final value) => GlassCard(
                radius: 22,
                shadow: false,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                child: Column(
                  children: [
                    for (var i = 0; i < value.length; i++) ...[
                      if (i > 0) Divider(height: 1, color: c.glassBorder),
                      OrderRow(order: value[i], now: now, onTap: () => widget.onOpenOrder(value[i])),
                    ],
                  ],
                ),
              ),
              AsyncError() => Row(
                children: [
                  Expanded(
                    child: Text(l.ordersError, style: TaraText.label.copyWith(color: c.textSecondary)),
                  ),
                  TaraLink(label: l.retry, onPressed: () => ref.invalidate(ordersProvider(_scope))),
                ],
              ),
              _ => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: GooLoader(compact: true)),
              ),
            },
          ],
        ),
      ),
    );
  }
}
