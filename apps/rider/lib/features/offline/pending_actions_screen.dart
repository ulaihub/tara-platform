import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/api/models.dart';
import '../../core/offline/action_queue.dart';
import '../../design/components/buttons.dart';
import '../../design/components/glass.dart';
import '../../design/components/layout.dart';
import '../../design/format.dart';
import '../../design/motion/effects.dart';
import '../../design/tara_colors.dart';
import '../../design/tara_icons.dart';
import '../../design/tara_typography.dart';
import '../../l10n/app_localizations.dart';
import '../course/course_scaffold.dart' show callPhone;
import '../map/tara_map.dart';

/// 15 · Hors connexion : actions de course gardées sur le téléphone, envoyées seules au
/// retour du réseau. « Réessayer maintenant » relance l'envoi ; une action refusée par le
/// serveur est expliquée, à corriger depuis la course ou à retirer après appel au support.
class PendingActionsScreen extends ConsumerStatefulWidget {
  const PendingActionsScreen({super.key, required this.onContinue});

  /// Retour à la course (ou à l'accueil).
  final VoidCallback onContinue;

  @override
  ConsumerState<PendingActionsScreen> createState() => _PendingActionsScreenState();
}

class _PendingActionsScreenState extends ConsumerState<PendingActionsScreen> {
  /// Une tentative a été faite et le réseau manque toujours.
  bool _tried = false;

  /// Action dont le retrait attend confirmation.
  String? _confirming;

  Future<void> _retry() async {
    await ref.read(actionQueueProvider).flush();
    if (mounted) setState(() => _tried = true);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final queue = ref.watch(actionQueueProvider);
    final network = ref.watch(networkStatusProvider);
    final order = ref.watch(activeOrderProvider).order;
    final config = ref.watch(riderConfigProvider).value;
    final support = config?.supportPhone ?? config?.safetyHotline;

    return ListenableBuilder(
      listenable: Listenable.merge([queue, network]),
      builder: (context, _) {
        final items = queue.items;
        final pending = queue.pendingCount;
        final syncing = queue.syncing;
        final retryLabel = syncing
            ? l.retrying
            : (_tried && network.offline && pending > 0)
            ? l.stillOffline
            : l.retryNow;
        return TaraScreen(
          safeTop: false,
          background: Positioned.fill(
            // Carte gardée sur le téléphone, en gris : rien n'est à jour sans réseau.
            child: ColorFiltered(
              colorFilter: const ColorFilter.matrix(_grayscale),
              child: TaraMap(
                zoom: 14,
                stop: order == null
                    ? null
                    : MapStop(
                        latitude: order.status == 'ASSIGNED' ? order.pickup.latitude : order.dropoff.latitude,
                        longitude: order.status == 'ASSIGNED' ? order.pickup.longitude : order.dropoff.longitude,
                        dropoff: order.status != 'ASSIGNED',
                      ),
              ),
            ),
          ),
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(16, MediaQuery.paddingOf(context).top + 12, 16, 0),
                child: network.offline
                    ? OfflineBanner(
                        title: l.offlineBannerTitle,
                        detail: pending > 0 ? l.offlineBannerPending(pending) : l.offlineNoPending,
                      )
                    : const SizedBox.shrink(),
              ),
              const Spacer(),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .68),
                child: GlassCard(
                  radius: 28,
                  fill: c.glassStrong,
                  padding: EdgeInsets.fromLTRB(18, 16, 18, 12 + MediaQuery.paddingOf(context).bottom),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Semantics(
                              header: true,
                              child: Text(
                                l.pendingActionsTitle,
                                style: TaraText.titlePanel.copyWith(color: c.textPrimary),
                              ),
                            ),
                          ),
                          _Pill(l.autoSend),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Flexible(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (items.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  child: Text(l.allSent, style: TaraText.text.copyWith(color: c.success)),
                                ),
                              for (var i = 0; i < items.length; i++) ...[
                                if (i > 0) Divider(height: 1, color: c.glassBorder),
                                _ActionRow(
                                  action: items[i],
                                  order: order?.id == items[i].orderId ? order : null,
                                  syncing: syncing,
                                  confirming: _confirming == items[i].id,
                                  onSupport: support == null ? null : () => unawaited(callPhone(support)),
                                  onRemove: () async {
                                    if (_confirming != items[i].id) {
                                      setState(() => _confirming = items[i].id);
                                      return;
                                    }
                                    setState(() => _confirming = null);
                                    await queue.discard(items[i].id);
                                  },
                                ),
                              ],
                              const SizedBox(height: 10),
                              TintBox(
                                child: Text(
                                  l.offlineNote,
                                  style: TaraText.label.copyWith(color: c.textSecondary, height: 1.4),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _RetryButton(
                        label: retryLabel,
                        spinning: syncing,
                        onPressed: syncing || pending == 0 ? null : () => unawaited(_retry()),
                      ),
                      const SizedBox(height: 10),
                      PrimaryButton(label: l.continueCourse, icon: TaraIcons.arrowRight, onPressed: widget.onContinue),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static const _grayscale = <double>[
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0, 0, 0, 1, 0,
  ];
}

/// « Envoi automatique ».
class _Pill extends StatelessWidget {
  const _Pill(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = TaraColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: c.chipBg, borderRadius: BorderRadius.circular(12)),
      child: Text(label, style: TaraText.smallStrong.copyWith(color: c.textSecondary)),
    );
  }
}

/// Action en attente : type, course, détail, heure et statut ; refusée : explication.
class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.action,
    required this.order,
    required this.syncing,
    required this.confirming,
    required this.onSupport,
    required this.onRemove,
  });

  final QueuedAction action;
  final RiderOrder? order;
  final bool syncing;
  final bool confirming;
  final VoidCallback? onSupport;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final (title, icon) = switch (action.kind) {
      'pickup' => (l.queuedPickup, TaraIcons.package),
      'depart' => (l.queuedDepart, TaraIcons.navigation),
      'collect' => (l.queuedCollect, TaraIcons.cash),
      'deliver' => (l.queuedDeliver, TaraIcons.check),
      'fail' => (l.queuedFail, TaraIcons.alertCircle),
      'retry' => (l.queuedRetry, TaraIcons.refresh),
      _ => (l.queuedReturn, TaraIcons.returnArrow),
    };
    final details = <String>[
      order?.reference ?? action.orderId.substring(0, 8).toUpperCase(),
      ?_detail(l),
      formatClock(action.createdAt),
    ];
    final refused = action.failed;
    final status = refused ? l.statusRefused : (syncing ? l.statusSending : l.statusWaiting);
    final statusColor = refused ? c.dangerTextStrong : c.warningText;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MergeSemantics(
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: refused ? c.dangerTint : c.chipBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TaraIcon(icon, size: 18, color: refused ? c.dangerTextStrong : c.textSecondary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TaraText.text.copyWith(fontWeight: FontWeight.w700, color: c.textPrimary),
                      ),
                      Text(details.join(' · '), style: TaraText.small.copyWith(color: c.textSecondary)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(status, style: TaraText.smallStrong.copyWith(color: statusColor)),
              ],
            ),
          ),
          if (refused) ...[
            const SizedBox(height: 8),
            Text(action.failureMessage ?? l.refusedHelp, style: TaraText.label.copyWith(color: c.dangerTextStrong)),
            Text(l.refusedHelp, style: TaraText.small.copyWith(color: c.textSecondary)),
            Wrap(
              spacing: 16,
              children: [
                if (onSupport != null) TaraLink(label: l.callSupport, onPressed: onSupport),
                TaraLink(label: confirming ? l.confirmRemoveAction : l.removeAction, onPressed: onRemove),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String? _detail(AppLocalizations l) {
    final photo = action.photoPath;
    switch (action.kind) {
      case 'pickup' || 'return':
        return l.detailCodePhoto;
      case 'deliver':
        return action.body.containsKey('deliveryCode') ? l.detailCodePhoto : l.detailNoCodePhoto;
      case 'collect':
        final amount = order?.collectAtDelivery;
        return amount == null || amount == 0 ? null : '${formatAmount(amount)} F';
      case 'fail':
        if (photo == null) return null;
        try {
          final mo = File(photo).lengthSync() / (1024 * 1024);
          return l.detailPhotoSize(mo.toStringAsFixed(1).replaceAll('.', ','));
        } catch (_) {
          return null;
        }
      default:
        return null;
    }
  }
}

/// « Réessayer maintenant » : l'icône tourne pendant la tentative (A14).
class _RetryButton extends StatelessWidget {
  const _RetryButton({required this.label, required this.spinning, required this.onPressed});
  final String label;
  final bool spinning;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final c = TaraColors.of(context);
    return Semantics(
      button: true,
      enabled: onPressed != null,
      child: GestureDetector(
        onTap: onPressed,
        child: Opacity(
          opacity: onPressed == null && !spinning ? .5 : 1,
          child: SizedBox(
            height: 50,
            child: GlassCard(
              radius: 18,
              shadow: false,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox.expand(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (spinning)
                      Spin(child: TaraIcon(TaraIcons.refresh, size: 20, color: c.textPrimary))
                    else
                      TaraIcon(TaraIcons.refresh, size: 20, color: c.textPrimary),
                    const SizedBox(width: 8),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(label, maxLines: 1, style: TaraText.buttonSecondary.copyWith(color: c.textPrimary)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
