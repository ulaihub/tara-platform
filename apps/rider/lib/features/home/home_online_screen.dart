import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../design/components/buttons.dart';
import '../../design/components/glass.dart';
import '../../design/components/layout.dart';
import '../../design/components/status.dart';
import '../../design/format.dart';
import '../../design/motion/effects.dart';
import '../../design/tara_colors.dart';
import '../../design/tara_icons.dart';
import '../../design/tara_typography.dart';
import '../../l10n/app_localizations.dart';
import '../map/tara_map.dart';
import 'home_summary.dart';

/// 06 · Accueil — en ligne : carte plein écran, position suivie, gains du jour, SOS,
/// recentrer, « Recherche de courses… ». Les propositions s'ouvrent par-dessus (07).
class HomeOnlineScreen extends ConsumerStatefulWidget {
  const HomeOnlineScreen({super.key, required this.onWentOffline, required this.onDetails, required this.onSos});

  final VoidCallback onWentOffline;
  final VoidCallback onDetails;
  final VoidCallback onSos;

  @override
  ConsumerState<HomeOnlineScreen> createState() => _HomeOnlineScreenState();
}

class _HomeOnlineScreenState extends ConsumerState<HomeOnlineScreen> {
  final _map = TaraMapHandle();
  bool _following = true;

  Future<void> _goOffline() async {
    try {
      await ref.read(onlineControllerProvider).goOffline();
    } catch (_) {
      // Sans réseau, le serveur le passera hors ligne de lui-même après 90 s.
    }
    widget.onWentOffline();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final online = ref.watch(onlineControllerProvider);
    final summary = ref.watch(homeSummaryProvider).value;
    return TaraScreen(
      safeTop: false,
      safeBottom: false,
      background: Positioned.fill(
        child: ListenableBuilder(
          listenable: online,
          builder: (context, _) => TaraMap(
            rider: online.lastPosition,
            handle: _map,
            onFollowChanged: (value) => setState(() => _following = value),
          ),
        ),
      ),
      child: Stack(
        children: [
          // Voiles haut et bas : textes lisibles sur la carte.
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: 180,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [c.bg.withValues(alpha: .85), c.bg.withValues(alpha: 0)],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 300,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [c.bg.withValues(alpha: .92), c.bg.withValues(alpha: 0)],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      OnlineToggle(label: l.online, semanticLabel: l.goOfflineLabel, onToggle: _goOffline),
                      const Spacer(),
                      Flexible(
                        child: GestureDetector(
                          onTap: widget.onDetails,
                          child: InfoPill(
                            label: l.todayPill('${formatAmount(summary?.earnings ?? 0)} F'),
                            tone: TintTone.accent,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Column(
                      children: [
                        SosButton(label: l.safetyAlert, onPressed: widget.onSos),
                        const SizedBox(height: 12),
                        GlassIconButton(
                          icon: TaraIcons.navigation,
                          label: l.recenterMap,
                          badge: !_following,
                          onPressed: _map.recenter,
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  GlassCard(
                    radius: 24,
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    child: Row(
                      children: [
                        const SizedBox(width: 64, child: GooLoader(compact: true)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(l.searchingTitle, style: TaraText.cardTitle.copyWith(color: c.textPrimary)),
                              const SizedBox(height: 2),
                              Text(l.searchingJobsHint, style: TaraText.small.copyWith(color: c.textTertiary)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  FloatingTabBar(
                    items: [
                      TabItem(TaraIcons.home, l.tabHome),
                      TabItem(TaraIcons.activity, l.tabActivity),
                      TabItem(TaraIcons.user, l.tabProfile),
                    ],
                    current: 0,
                    onSelected: (_) {},
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
