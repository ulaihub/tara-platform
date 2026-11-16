import 'package:flutter/widgets.dart';
import 'package:tara_ui/components/glass.dart';
import 'package:tara_ui/components/layout.dart';
import 'package:tara_ui/format.dart';
import 'package:tara_ui/tara_colors.dart';
import 'package:tara_ui/tara_icons.dart';

import '../../core/api/client_models.dart';
import '../../l10n/app_localizations.dart';

/// Livraison dans une liste : destinataire, quartier, étape (ou issue), référence.
class OrderRow extends StatelessWidget {
  const OrderRow({super.key, required this.order, required this.now, required this.onTap});
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
      // « Créée » sans créneau à venir : les frais Mobile Money ne sont pas encore payés.
      'CREATED' => (TaraIcons.timer, TintTone.danger, l.trackAwaitingPayment),
      'SEARCHING_RIDER' => (TaraIcons.timer, TintTone.accent, l.statusSearching),
      'ASSIGNED' => (TaraIcons.navigation, TintTone.accent, l.statusRiderComing),
      'PICKED_UP' || 'IN_DELIVERY' => (TaraIcons.package, TintTone.success, l.statusInDelivery),
      'DELIVERY_FAILED' => switch (order.failureDecision) {
        'RETRY' => (TaraIcons.refresh, TintTone.accent, l.statusRetrying),
        'RETURN' => (TaraIcons.returnArrow, TintTone.accent, l.statusReturning),
        _ => (TaraIcons.alertCircle, TintTone.danger, l.statusFailed),
      },
      'DELIVERED' => (TaraIcons.check, TintTone.success, l.statusDelivered(_day(l, order.createdAt.toLocal(), now))),
      'RETURNED' => (TaraIcons.returnArrow, TintTone.accent, l.statusReturned),
      'CANCELLED' => (TaraIcons.close, TintTone.danger, l.statusCancelled),
      _ => (TaraIcons.package, TintTone.accent, order.status),
    };
    final place = order.dropoffNeighborhood ?? order.dropoffLandmark;
    return ListRow(
      leading: IconTile(icon: icon, size: 40, tone: tone),
      title: '${order.recipientName} · $place',
      subtitle: [
        label,
        if (order.batchNumber case final number?) l.parcelNumberShort(number),
        order.reference,
      ].join(' · '),
      trailing: TaraIcon(TaraIcons.chevronRight, size: 20, color: c.textTertiary),
      onTap: onTap,
    );
  }

  /// Jour d'une commande terminée : aujourd'hui, hier ou la date.
  static String _day(AppLocalizations l, DateTime at, DateTime now) {
    bool same(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
    if (same(at, now)) return l.today;
    if (same(at, now.subtract(const Duration(days: 1)))) return l.yesterday;
    return '${at.day.toString().padLeft(2, '0')}/${at.month.toString().padLeft(2, '0')}';
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
