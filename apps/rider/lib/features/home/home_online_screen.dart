import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tara_ui/components/buttons.dart';
import 'package:tara_ui/components/layout.dart';
import 'package:tara_ui/components/tab_shell.dart';
import 'package:tara_ui/format.dart';
import 'package:tara_ui/motion/liquid_wave.dart';
import 'package:tara_ui/tara_colors.dart';
import 'package:tara_ui/tara_icons.dart';
import 'package:tara_ui/tara_typography.dart';

import '../../app/providers.dart';
import '../../l10n/app_localizations.dart';
import '../map/tara_map.dart';
import 'home_summary.dart';
import 'home_widgets.dart';

/// 06 · Accueil — en ligne : carte plein écran, position suivie, gains du jour, SOS,
/// recentrer, « Recherche de courses… ». Les propositions s'ouvrent par-dessus (07).
class HomeOnlineScreen extends ConsumerStatefulWidget {
  const HomeOnlineScreen({
    super.key,
    required this.onWentOffline,
    required this.onDetails,
    required this.onSos,
    this.courseBanner,
  });

  /// Course en cours réduite : remplace « Recherche de courses… ».
  final Widget? courseBanner;

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
    final legend = TaraText.small.copyWith(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      color: c.textPrimary.withValues(alpha: .86),
    );
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
            height: 160,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [c.bg.withValues(alpha: .8), c.bg.withValues(alpha: 0)],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 260,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [c.bg.withValues(alpha: .9), c.bg.withValues(alpha: 0)],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                12,
                20,
                12,
                // En bas : place de la barre d'onglets en verre, qui flotte sur la carte.
                TaraTabShell.bottomInset(context) > 0
                    ? TaraTabShell.bottomInset(context) + 4
                    : 12 + MediaQuery.paddingOf(context).bottom,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      children: [
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: StatusPill(
                              online: true,
                              label: l.onlineSince(formatOnline(summary?.onlineSeconds ?? 0)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Spacer(),
                        SosButton(label: l.safetyAlert, onPressed: widget.onSos, size: 48, round: true),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Légende de la carte : les zones interdites aux motos sont hachurées en rouge.
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: c.bg.withValues(alpha: .75),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const _ForbiddenSwatch(),
                            const SizedBox(width: 6),
                            Flexible(child: Text(l.zoneForbiddenLegend, style: legend)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Align(
                    alignment: Alignment.centerRight,
                    child: GlassIconButton(
                      icon: TaraIcons.navigation,
                      label: l.recenterMap,
                      badge: !_following,
                      size: 48,
                      radius: 18,
                      onPressed: _map.recenter,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _SearchPanel(
                    banner: widget.courseBanner,
                    earnings: summary?.earnings ?? 0,
                    delivered: summary?.delivered ?? 0,
                    onDetails: widget.onDetails,
                    onGoOffline: _goOffline,
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

/// Carré de légende « zone interdite » : hachures rouges, bord rouge.
class _ForbiddenSwatch extends StatelessWidget {
  const _ForbiddenSwatch();

  @override
  Widget build(BuildContext context) => CustomPaint(size: const Size.square(12), painter: _HatchPainter());
}

class _HatchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(3));
    canvas
      ..save()
      ..clipRRect(rect)
      ..drawRect(Offset.zero & size, Paint()..color = const Color.fromRGBO(255, 77, 77, .15));
    final stripe = Paint()
      ..color = const Color.fromRGBO(255, 77, 77, .6)
      ..strokeWidth = 2.1;
    for (var x = -size.height; x < size.width + size.height; x += 4.2) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), stripe);
    }
    canvas
      ..restore()
      ..drawRRect(
        rect.deflate(.75),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = const Color(0xFFFF5A5A),
      );
  }

  @override
  bool shouldRepaint(_HatchPainter old) => false;
}

/// Panneau du bas : « Recherche de courses… » (ou la course réduite), puis les gains du
/// jour et « Passer hors ligne ».
class _SearchPanel extends StatelessWidget {
  const _SearchPanel({
    required this.banner,
    required this.earnings,
    required this.delivered,
    required this.onDetails,
    required this.onGoOffline,
  });

  final Widget? banner;
  final int earnings;
  final int delivered;
  final VoidCallback onDetails;
  final VoidCallback onGoOffline;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            color: (c.isDark ? const Color(0xFF16161E) : const Color(0xFFFFFFFF)).withValues(alpha: .72),
            border: Border.all(color: c.textPrimary.withValues(alpha: .12)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              banner ??
                  Row(
                    children: [
                      const _LiquidDot(),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l.searchingTitle,
                              style: TaraText.bodyStrong.copyWith(fontSize: 15, color: c.textPrimary),
                            ),
                            Text(
                              l.searchingJobsHint,
                              style: TaraText.small.copyWith(fontSize: 12, color: c.textPrimary.withValues(alpha: .66)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.only(top: 10),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: c.textPrimary.withValues(alpha: .08))),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _TodayLine(amount: earnings, delivered: delivered, onTap: onDetails),
                    ),
                    const SizedBox(width: 10),
                    Semantics(
                      label: l.goOfflineLabel,
                      excludeSemantics: true,
                      button: true,
                      child: CompactButton(label: l.goOffline, brand: false, onPressed: onGoOffline),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Petit rond où ondule le liquide de marque (à mi-hauteur) : l'app cherche des courses.
class _LiquidDot extends StatelessWidget {
  const _LiquidDot();

  @override
  Widget build(BuildContext context) {
    final c = TaraColors.of(context);
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color.fromRGBO(255, 177, 92, .45), width: 2),
      ),
      child: ClipOval(
        child: LiquidFill(
          level: .5,
          amplitude: 4,
          front: TaraLiquid.front,
          back: TaraLiquid.back(dark: c.isDark),
          frontPeriod: TaraLiquid.frontPeriod,
          backPeriod: TaraLiquid.backPeriod,
        ),
      ),
    );
  }
}

/// « Aujourd'hui · 6 450 F · 7 courses » : mène au détail des gains.
class _TodayLine extends StatelessWidget {
  const _TodayLine({required this.amount, required this.delivered, required this.onTap});

  final int amount;
  final int delivered;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Le montant monte jusqu'au nouveau total quand une course vient de s'ajouter.
    return TweenAnimationBuilder<double>(
      tween: Tween(end: amount.toDouble()),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, shown, _) => _line(context, shown.round()),
    );
  }

  Widget _line(BuildContext context, int amount) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final value = l.todayTotal('${formatAmount(amount)}\u00a0F', delivered);
    return Semantics(
      button: true,
      label: '${l.today} : $value',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.today,
              style: TaraText.small.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: c.textPrimary.withValues(alpha: .66),
              ),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                maxLines: 1,
                style: TaraText.cardTitle.copyWith(fontSize: 17, color: c.textPrimary, fontFeatures: TaraText.tabular),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
