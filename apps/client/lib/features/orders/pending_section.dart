import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tara_ui/components/buttons.dart';
import 'package:tara_ui/components/glass.dart';
import 'package:tara_ui/components/layout.dart';
import 'package:tara_ui/tara_colors.dart';
import 'package:tara_ui/tara_icons.dart';
import 'package:tara_ui/tara_typography.dart';

import '../../app/providers.dart';
import '../../core/api/client_models.dart';
import '../../l10n/app_localizations.dart';
import '../common/error_text.dart';
import '../home/home_screen.dart';

/// Colis d'un envoi en masse qui attendent l'adresse de leur client (ou dont le départ est
/// bloqué), relus à chaque retour sur l'onglet Commandes.
final pendingDeliveriesProvider = FutureProvider<List<PendingDelivery>>(
  (ref) => ref.read(clientApiProvider).pendingDeliveries(),
);

/// « En attente de l'adresse » : en tête de l'onglet Commandes, chaque colis qui attend son
/// client, avec ce qu'on peut faire (renvoyer le lien, l'envoyer soi-même, retirer, payer).
class PendingSection extends ConsumerWidget {
  const PendingSection({super.key, required this.onOpenOrder});

  /// Ouvre la commande créée (paiement Mobile Money à valider).
  final ValueChanged<String> onOpenOrder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final pending = ref.watch(pendingDeliveriesProvider).value ?? const <PendingDelivery>[];
    if (pending.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            title: l.pendingTitle,
            action: Text(
              '${pending.length}',
              style: TaraText.label.copyWith(color: c.accentText, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 8),
          GlassCard(
            radius: 22,
            shadow: false,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Column(
              children: [
                for (final (i, item) in pending.indexed) ...[
                  if (i > 0) Divider(height: 1, color: c.glassBorder),
                  _PendingRow(
                    item: item,
                    onTap: () => unawaited(
                      showModalBottomSheet<void>(
                        context: context,
                        backgroundColor: Colors.transparent,
                        isScrollControlled: true,
                        // La feuille s'ouvre au-dessus de l'écran : même accès à l'API que lui.
                        builder: (_) => UncontrolledProviderScope(
                          container: ProviderScope.containerOf(context, listen: false),
                          child: PendingActions(item: item, onOpenOrder: onOpenOrder),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingRow extends StatelessWidget {
  const _PendingRow({required this.item, required this.onTap});

  final PendingDelivery item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final (text, danger) = switch (item.status) {
      'EXPIRED' => (l.pendingExpired, true),
      'BLOCKED' when item.blockedReason == 'INSUFFICIENT_BALANCE' => (l.pendingBlockedBalance, true),
      'BLOCKED' => (l.pendingBlocked, true),
      _ => (l.pendingWaiting, false),
    };
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: danger ? c.dangerTint : c.glass,
                border: danger ? null : Border.all(color: TaraBrand.focusBorder, width: 1.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${item.batchNumber}',
                style: TaraText.cardTitle.copyWith(
                  color: danger ? c.dangerText : c.accentText,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.recipientName,
                    style: TaraText.text.copyWith(color: c.textPrimary, fontWeight: FontWeight.w700),
                  ),
                  Text(text, style: TaraText.small.copyWith(color: danger ? c.dangerText : c.textSecondary)),
                ],
              ),
            ),
            TaraIcon(TaraIcons.chevronRight, size: 18, color: c.textTertiary),
          ],
        ),
      ),
    );
  }
}

/// Ce qu'on peut faire d'un colis en attente : selon qu'il attend le client ou qu'il est
/// bloqué au départ.
class PendingActions extends ConsumerStatefulWidget {
  const PendingActions({super.key, required this.item, required this.onOpenOrder});

  final PendingDelivery item;
  final ValueChanged<String> onOpenOrder;

  @override
  ConsumerState<PendingActions> createState() => _PendingActionsState();
}

class _PendingActionsState extends ConsumerState<PendingActions> {
  bool _busy = false;
  String? _error;

  PendingDelivery get _item => widget.item;

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) setState(() => _error = errorMessage(context, error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _done([String? message]) {
    ref.invalidate(pendingDeliveriesProvider);
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    Navigator.of(context).pop();
    if (message != null) messenger?.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _resend() {
    final sent = AppLocalizations.of(context).pendingResent(_item.firstName);
    return _run(() async {
      await ref.read(clientApiProvider).resendPending(_item.id);
      _done(sent);
    });
  }

  Future<void> _share() => _run(() async {
    final l = AppLocalizations.of(context);
    await ref.read(shareProvider)(l.pendingShareText(_item.firstName, _item.linkUrl), null);
  });

  Future<void> _remove() async {
    final l = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(l.pendingRemoveConfirm(_item.batchNumber, _item.firstName)),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l.cancel)),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text(l.pendingRemove)),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _run(() async {
      await ref.read(clientApiProvider).cancelPending(_item.id);
      _done();
    });
  }

  /// Départ bloqué : nouvel essai (ventes rechargées), ou Mobile Money — la commande est
  /// créée et s'ouvre sur son paiement.
  Future<void> _release(String? method) => _run(() async {
    final result = await ref.read(clientApiProvider).releasePending(_item.id, feePaymentMethod: method);
    final orderId = result.orderId;
    ref
      ..invalidate(pendingDeliveriesProvider)
      ..invalidate(activeOrdersProvider);
    if (!mounted) return;
    if (orderId != null) {
      Navigator.of(context).pop();
      widget.onOpenOrder(orderId);
    } else if (result.status == 'BLOCKED') {
      setState(() => _error = AppLocalizations.of(context).pendingBlockedBalance);
    }
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final blocked = _item.status == 'BLOCKED';
    return SafeArea(
      child: GlassPanel(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l.pendingParcel(_item.batchNumber, _item.recipientName),
              style: TaraText.cardTitle.copyWith(color: c.textPrimary),
            ),
            const SizedBox(height: 14),
            if (blocked) ...[
              GlassButton(
                label: l.pendingRetry,
                icon: TaraIcons.refresh,
                color: c.accentText,
                onPressed: _busy ? null : () => unawaited(_release(null)),
              ),
              const SizedBox(height: 8),
              GlassButton(
                label: '${l.pendingPayMomo} · ${l.payMtn}',
                icon: TaraIcons.phone,
                color: c.accentText,
                onPressed: _busy ? null : () => unawaited(_release('MOMO_MTN')),
              ),
              const SizedBox(height: 8),
              GlassButton(
                label: '${l.pendingPayMomo} · ${l.payOrange}',
                icon: TaraIcons.phone,
                color: c.accentText,
                onPressed: _busy ? null : () => unawaited(_release('MOMO_ORANGE')),
              ),
            ] else ...[
              GlassButton(
                label: l.pendingResend,
                icon: TaraIcons.send,
                color: c.accentText,
                onPressed: _busy ? null : () => unawaited(_resend()),
              ),
              const SizedBox(height: 8),
              GlassButton(
                label: l.pendingShare,
                icon: TaraIcons.message,
                color: c.accentText,
                onPressed: _busy ? null : () => unawaited(_share()),
              ),
            ],
            if (_error != null) ...[const SizedBox(height: 10), ErrorLine(_error!)],
            const SizedBox(height: 6),
            Center(
              child: TaraLink(label: l.pendingRemove, onPressed: _busy ? null : () => unawaited(_remove())),
            ),
          ],
        ),
      ),
    );
  }
}
