import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tara_ui/components/buttons.dart';
import 'package:tara_ui/components/glass.dart';
import 'package:tara_ui/components/layout.dart';
import 'package:tara_ui/components/map_backdrop.dart';
import 'package:tara_ui/components/pin_flow.dart';
import 'package:tara_ui/components/status.dart';
import 'package:tara_ui/components/tab_shell.dart';
import 'package:tara_ui/format.dart';
import 'package:tara_ui/motion/liquid_background.dart';
import 'package:tara_ui/tara_colors.dart';
import 'package:tara_ui/tara_typography.dart';

import '../../app/providers.dart';
import '../../core/location/online_controller.dart';
import '../../l10n/app_localizations.dart';
import '../common/error_text.dart';
import '../common/pin.dart';
import '../legal/terms_screen.dart';
import 'home_summary.dart';

/// 05 · Accueil — hors ligne : gains du jour, bouton « Passer en ligne ». Pas de cloche de
/// notifications au lancement (les messages arrivent par notification du téléphone).
class HomeOfflineScreen extends ConsumerStatefulWidget {
  const HomeOfflineScreen({super.key, required this.onWentOnline, required this.onDetails, this.now});

  final VoidCallback onWentOnline;
  final VoidCallback onDetails;

  /// Heure affichée (bonjour / bonsoir), fixée dans les tests.
  final DateTime? now;

  @override
  ConsumerState<HomeOfflineScreen> createState() => _HomeOfflineScreenState();
}

class _HomeOfflineScreenState extends ConsumerState<HomeOfflineScreen> {
  bool _switching = false;
  String? _error;
  List<String> _blockers = const [];
  final _bottom = GlobalKey();

  static const _blobs = [BlobSpec(alignment: Alignment(0, -.05), size: 360, colors: BlobSpec.brand, blur: 80)];

  Future<void> _goOnline() async {
    if (_switching) return;
    setState(() {
      _switching = true;
      _error = null;
      _blockers = const [];
    });
    final l = AppLocalizations.of(context);
    try {
      final blockers = await ref.read(onlineControllerProvider).goOnline();
      if (!mounted) return;
      if (blockers.isEmpty) {
        widget.onWentOnline();
      } else {
        setState(() => _blockers = blockers);
        // Les blocages s'affichent sous le bouton : l'écran défile pour les montrer en entier.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final bottom = _bottom.currentContext;
          if (bottom != null && bottom.mounted) {
            unawaited(Scrollable.ensureVisible(bottom, duration: const Duration(milliseconds: 300)));
          }
        });
      }
    } on LocationAccessException {
      if (mounted) setState(() => _error = l.locationNeeded);
    } catch (error) {
      if (mounted) setState(() => _error = errorMessage(context, error));
    } finally {
      if (mounted) setState(() => _switching = false);
    }
  }

  /// Nouvelles conditions : lues et signées, puis le livreur repasse en ligne.
  Future<void> _openTerms() async {
    await openTermsUpdate(context, ref);
    if (mounted) setState(() => _blockers = _blockers.where((blocker) => blocker != 'TERMS').toList());
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final summary = ref.watch(homeSummaryProvider).value;
    final hour = (widget.now ?? DateTime.now()).hour;
    final language = Localizations.localeOf(context).languageCode;
    final requirements = ref.watch(documentLabelsProvider).value ?? const {};
    // Place de la barre d'onglets en verre : le contenu défile dessous.
    final inset = TaraTabShell.bottomInset(context);
    return TaraScreen(
      blobs: _blobs,
      safeBottom: false,
      background: Positioned.fill(
        child: Stack(
          fit: StackFit.expand,
          children: [
            MapBackdrop(opacity: c.isDark ? .55 : .8),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(colors: [c.bg.withValues(alpha: .2), c.bg.withValues(alpha: .85)], radius: .9),
              ),
            ),
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                InitialsAvatar(name: summary?.fullName ?? ''),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hour < 18 ? l.goodMorning : l.goodEvening,
                        style: TaraText.label.copyWith(color: c.textTertiary),
                      ),
                      Text(
                        summary?.fullName ?? ' ',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TaraText.cardTitle.copyWith(color: c.textPrimary, fontSize: 18),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _EarningsCard(summary: summary, onDetails: widget.onDetails),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 24),
                      PowerButton(
                        label: l.goOnline,
                        semanticLabel: l.goOnlineLabel,
                        // 210 px, réduit jusqu'à 140 sur petit écran ou avec le texte agrandi.
                        size: (constraints.maxHeight - inset - 150).clamp(140, 210).toDouble(),
                        onPressed: _switching ? null : _goOnline,
                      ),
                      const SizedBox(height: 22),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(color: c.offline, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 8),
                          Text(l.youAreOffline, style: TaraText.bodyStrong.copyWith(color: c.textPrimary)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 280),
                        child: Text(
                          l.offlineHint,
                          textAlign: TextAlign.center,
                          style: TaraText.label.copyWith(color: c.textTertiary, height: 1.5),
                        ),
                      ),
                      if (_error != null) ...[const SizedBox(height: 14), ErrorLine(_error!)],
                      if (_blockers.contains('TERMS')) ...[
                        const SizedBox(height: 14),
                        TintBox(
                          tone: TintTone.accent,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(l.blockerTerms, style: TaraText.text.copyWith(color: c.textPrimary)),
                              const SizedBox(height: 10),
                              GlassButton(
                                label: l.readAndSign,
                                height: 48,
                                radius: 14,
                                onPressed: () => unawaited(_openTerms()),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (_blockers.any((blocker) => blocker != 'TERMS')) ...[
                        const SizedBox(height: 14),
                        TintBox(
                          tone: TintTone.danger,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(l.blockersTitle, style: TaraText.text.copyWith(color: c.dangerTextStrong)),
                              const SizedBox(height: 6),
                              for (final blocker in _blockers.where((blocker) => blocker != 'TERMS'))
                                Text(
                                  '• ${switch (blocker) {
                                    'CASH_OVERDUE' => l.blockerCashOverdue,
                                    'STATUS_SUSPENDED' => l.blockerSuspended,
                                    'STATUS_PENDING' => l.blockerPending,
                                    _ => requirements[blocker]?.call(language) ?? blocker,
                                  }}',
                                  style: TaraText.label.copyWith(color: c.textSecondary),
                                ),
                            ],
                          ),
                        ),
                      ],
                      // Bas de l'écran, sous la barre d'onglets : amené à l'écran avec les blocages.
                      SizedBox(key: _bottom, height: 16 + inset),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Libellés des pièces (type → libellé selon la langue), pour les pièces bloquantes.
final documentLabelsProvider = FutureProvider<Map<String, String Function(String)>>((ref) async {
  final requirements = await ref.read(riderApiProvider).requirements();
  return {
    for (final requirement in requirements)
      for (final option in requirement.options) option.type: option.label,
  };
});

class _EarningsCard extends ConsumerWidget {
  const _EarningsCard({required this.summary, required this.onDetails});

  final HomeSummary? summary;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final s = summary;
    // Solde masqué (comme sur MoMo) : affiché après le code secret, d'une touche sur la case.
    final visibility = ref.watch(balanceVisibilityProvider);
    Widget tile(String value, String label, {bool accent = false, VoidCallback? onTap, String? hint}) => Expanded(
      child: Semantics(
        button: onTap != null,
        hint: hint,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: accent ? c.accentTintBg : c.chipBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: accent ? c.accentTintBorder : c.chipBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    maxLines: 1,
                    style: TaraText.text.copyWith(
                      color: accent ? c.accentStrongText : c.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontFeatures: TaraText.tabular,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(label, maxLines: 2, style: TaraText.small.copyWith(color: c.textTertiary)),
              ],
            ),
          ),
        ),
      ),
    );
    return GlassCard(
      radius: 24,
      padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader(
            title: l.todayEarnings,
            action: TaraLink(label: l.details, onPressed: onDetails),
          ),
          const SizedBox(height: 2),
          AmountText(s?.earnings ?? 0, style: TaraText.amountL),
          const SizedBox(height: 12),
          Row(
            children: [
              tile('${s?.delivered ?? 0}', l.jobsWord(s?.delivered ?? 0)),
              const SizedBox(width: 8),
              tile(formatOnline(s?.onlineSeconds ?? 0), l.onlineTime),
              const SizedBox(width: 8),
              ListenableBuilder(
                listenable: visibility,
                builder: (context, _) => tile(
                  balanceText(visibility, s?.available ?? 0),
                  l.balanceShort,
                  accent: true,
                  hint: visibility.visible ? l.balanceHide : l.balanceShow,
                  onTap: visibility.visible ? visibility.hide : () => revealBalance(context, ref),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
