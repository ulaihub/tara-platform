import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tara_ui/components/buttons.dart';
import 'package:tara_ui/components/inputs.dart';
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

/// Cloche : notifications du compte, relues à chaque ouverture de l'accueil.
final inboxProvider = FutureProvider<Inbox>((ref) => ref.read(clientApiProvider).inbox());

/// Ton d'une notification : suivi (orange), réussite (vert), problème (rouge).
enum _Tone { accent, ok, bad }

(TaraIconData, _Tone) _look(String kind) => switch (kind) {
  'LOCATION_LINK_SUBMITTED' ||
  'LOCATION_LINK_SUBMITTED_ANONYMOUS' ||
  'PENDING_DELIVERY_RELEASED' ||
  'PENDING_DELIVERY_TO_PAY' => (TaraIcons.mapPin, _Tone.accent),
  'ORDER_DELIVERED' || 'ORDER_RETURNED' => (TaraIcons.check, _Tone.ok),
  'PAYOUT_SENT' => (TaraIcons.wallet, _Tone.ok),
  'ORDER_DELIVERY_FAILED' ||
  'ORDER_PARCEL_REFUSED' ||
  'ORDER_SENDER_ABSENT' ||
  'ORDER_CANCELLED' ||
  'ORDER_RIDER_NO_SIGNAL' ||
  'PENDING_DELIVERY_BLOCKED' ||
  'SENDER_WAITING_WARNING' ||
  'PAYOUT_FAILED' => (TaraIcons.alertTriangle, _Tone.bad),
  'MESSAGE_FROM_RIDER' || 'SUPPORT_REPLY' => (TaraIcons.message, _Tone.accent),
  final kind when kind.startsWith('ORDER_') || kind == 'RIDER_ARRIVED_PICKUP' => (TaraIcons.moto, _Tone.accent),
  _ => (TaraIcons.bell, _Tone.accent),
};

/// Notifications (maquette) : en-tête avec le nombre de non lues et « Tout lire », puis
/// les cartes, les non lues teintées avec un point orange ; un toucher ouvre la commande
/// (ou le portefeuille, ou les adresses demandées) et marque la notification lue.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({
    super.key,
    required this.onBack,
    required this.onOpenOrder,
    required this.onWallet,
    required this.onAskAddress,
    this.now,
  });

  final VoidCallback onBack;
  final ValueChanged<String> onOpenOrder;
  final VoidCallback onWallet;
  final VoidCallback onAskAddress;

  /// Horloge (tests).
  final DateTime Function()? now;

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  static const _blobs = [
    BlobSpec(alignment: Alignment(-1.3, -1.1), size: 300, colors: BlobSpec.soft, blur: 46, opacity: .9),
    BlobSpec(
      alignment: Alignment(1.4, -.1),
      size: 260,
      colors: BlobSpec.warm,
      blur: 46,
      opacity: .5,
      delay: Duration(seconds: 5),
    ),
    BlobSpec(
      alignment: Alignment(-1.2, 1.2),
      size: 240,
      colors: BlobSpec.soft,
      blur: 46,
      opacity: .6,
      delay: Duration(seconds: 10),
    ),
  ];

  Future<void> _read({List<String>? ids}) async {
    try {
      await ref.read(clientApiProvider).readInbox(ids: ids);
    } catch (_) {
      // Pas de réseau : la pastille reviendra, rien de grave.
    }
    ref.invalidate(inboxProvider);
  }

  void _open(InboxItem item) {
    if (!item.read) unawaited(_read(ids: [item.id]));
    if (item.orderId case final orderId?) {
      widget.onOpenOrder(orderId);
    } else if (item.kind.startsWith('PAYOUT_')) {
      widget.onWallet();
    } else if (item.kind.startsWith('LOCATION_LINK_')) {
      widget.onAskAddress();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final inbox = ref.watch(inboxProvider);
    final unread = inbox.value?.unread ?? 0;
    final now = widget.now?.call() ?? DateTime.now();
    return TaraScreen(
      blobs: _blobs,
      safeBottom: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 12, 0),
            child: Row(
              children: [
                GlassIconButton(icon: TaraIcons.chevronLeft, label: l.back, onPressed: widget.onBack),
                const SizedBox(width: 10),
                Expanded(
                  child: MergeSemantics(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(
                          header: true,
                          child: Text(
                            l.notificationsTitle,
                            style: TaraText.titlePanel.copyWith(color: c.textPrimary, fontSize: 18),
                          ),
                        ),
                        Text(
                          unread > 0 ? l.unreadCount(unread) : l.allRead,
                          style: TaraText.small.copyWith(color: c.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
                if (unread > 0)
                  TaraLink(
                    label: l.readAll,
                    onPressed: () => unawaited(_read()),
                    style: TaraText.small.copyWith(fontSize: 12, fontWeight: FontWeight.w800),
                  ),
              ],
            ),
          ),
          Expanded(
            child: switch (inbox) {
              AsyncData(:final value) when value.items.isEmpty => Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TaraIcon(TaraIcons.bell, size: 32, color: c.textTertiary),
                      const SizedBox(height: 10),
                      Text(
                        l.noNotifications,
                        textAlign: TextAlign.center,
                        style: TaraText.label.copyWith(color: c.textSecondary, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ),
              AsyncData(:final value) => RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(inboxProvider);
                  await ref.read(inboxProvider.future).catchError((_) => Inbox.empty);
                },
                child: ListView.separated(
                  padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + MediaQuery.paddingOf(context).bottom),
                  itemCount: value.items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, i) => _NotificationCard(
                    item: value.items[i],
                    when: _when(l, value.items[i].createdAt.toLocal(), now),
                    onTap: () => _open(value.items[i]),
                  ),
                ),
              ),
              AsyncError() => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(l.notificationsError, style: TaraText.label.copyWith(color: c.textSecondary)),
                      TaraLink(label: l.retry, onPressed: () => ref.invalidate(inboxProvider)),
                    ],
                  ),
                ),
              ),
              _ => const Center(child: GooLoader(compact: true)),
            },
          ),
        ],
      ),
    );
  }

  /// « à l'instant », « il y a 4 min », « 15:24 », « hier 18:02 », « 12/11 · 09:30 ».
  static String _when(AppLocalizations l, DateTime at, DateTime now) {
    final minutes = now.difference(at).inMinutes;
    if (minutes < 1) return l.justNow;
    if (minutes < 60) return l.minutesAgo(minutes);
    bool same(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
    if (same(at, now)) return formatClock(at);
    if (same(at, now.subtract(const Duration(days: 1)))) return l.yesterdayAt(formatClock(at));
    return '${at.day.toString().padLeft(2, '0')}/${at.month.toString().padLeft(2, '0')} · ${formatClock(at)}';
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.item, required this.when, required this.onTap});

  final InboxItem item;
  final String when;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final (icon, tone) = _look(item.kind);
    final unread = !item.read;
    final (tint, ink) = switch (tone) {
      _Tone.ok => (const Color.fromRGBO(74, 222, 155, .14), c.success),
      _Tone.bad => (const Color.fromRGBO(255, 107, 117, .14), const Color(0xFFFF6B75)),
      _Tone.accent => (const Color.fromRGBO(255, 177, 92, .14), c.accentText),
    };
    return Semantics(
      button: true,
      label: [if (unread) l.unreadLabel, item.title, item.body, when].join('. '),
      excludeSemantics: true,
      child: Squish(
        depth: .98,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: unread ? const Color.fromRGBO(255, 138, 0, .08) : boxedFieldFill(c),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: unread ? const Color.fromRGBO(255, 138, 0, .35) : boxedFieldBorder(c)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(12)),
                  alignment: Alignment.center,
                  child: TaraIcon(icon, size: 20, color: ink),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: TaraText.text.copyWith(color: c.textPrimary, fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.body,
                        style: TaraText.small.copyWith(
                          color: c.textPrimary.withValues(alpha: .7),
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        when,
                        style: TaraText.small.copyWith(color: c.textPrimary.withValues(alpha: .5), fontSize: 11),
                      ),
                    ],
                  ),
                ),
                if (unread) ...[
                  const SizedBox(width: 8),
                  Container(
                    width: 10,
                    height: 10,
                    margin: const EdgeInsets.only(top: 6),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: TaraBrand.orange,
                      boxShadow: [BoxShadow(color: Color.fromRGBO(255, 106, 0, .7), blurRadius: 10)],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Cloche de l'accueil (maquette) : 44 de côté, point rouge cerclé tant qu'il reste des
/// notifications non lues.
class NotificationBell extends ConsumerWidget {
  const NotificationBell({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final unread = ref.watch(inboxProvider).value?.unread ?? 0;
    return Semantics(
      button: true,
      label: unread > 0 ? l.notificationsUnread(unread) : l.notificationsTitle,
      excludeSemantics: true,
      child: Squish(
        child: GestureDetector(
          key: notificationBellKey,
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Stack(
              children: [
                Center(child: TaraIcon(TaraIcons.bell, size: 24, color: c.textPrimary)),
                if (unread > 0)
                  Positioned(
                    right: 10,
                    top: 9,
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: TaraBrand.red,
                        border: Border.all(color: c.bg, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Cloche de l'accueil (tests).
const notificationBellKey = ValueKey('notification-bell');
