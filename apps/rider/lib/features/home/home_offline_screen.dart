import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tara_ui/components/buttons.dart';
import 'package:tara_ui/components/city_3d.dart';
import 'package:tara_ui/components/glass.dart';
import 'package:tara_ui/components/layout.dart';
import 'package:tara_ui/components/status.dart';
import 'package:tara_ui/components/tab_shell.dart';
import 'package:tara_ui/format.dart';
import 'package:tara_ui/motion/liquid_background.dart';
import 'package:tara_ui/tara_colors.dart';
import 'package:tara_ui/tara_effects.dart';
import 'package:tara_ui/tara_icons.dart';
import 'package:tara_ui/tara_typography.dart';

import '../../app/providers.dart';
import '../../core/location/online_controller.dart';
import '../../l10n/app_localizations.dart';
import '../activity/deposit_screen.dart';
import '../common/error_text.dart';
import '../common/pin.dart';
import '../legal/terms_screen.dart';
import 'home_summary.dart';
import 'home_widgets.dart';

/// 05 · Accueil — hors ligne : gains du jour, bouton « Passer en ligne ». Pas de cloche de
/// notifications au lancement (les messages arrivent par notification du téléphone).
class HomeOfflineScreen extends ConsumerStatefulWidget {
  const HomeOfflineScreen({
    super.key,
    required this.onWentOnline,
    required this.onDetails,
    this.courseBanner,
    this.now,
  });

  /// Course en cours mise de côté (« Retour à l'accueil ») : bandeau pour la reprendre.
  final Widget? courseBanner;

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

  /// Recharge du solde prépayé ouverte par-dessus l'accueil.
  bool _toppingUp = false;

  // Formes liquides de la maquette : orange en haut à gauche, crème à droite, orange en bas.
  static const _blobs = [
    BlobSpec(alignment: Alignment(-.69, -.55), size: 300, colors: BlobSpec.warm, blur: 46, opacity: .76),
    BlobSpec(
      alignment: Alignment(.74, .02),
      size: 260,
      colors: BlobSpec.soft,
      blur: 46,
      opacity: .58,
      delay: Duration(seconds: 4),
    ),
    BlobSpec(
      alignment: Alignment(-.59, .71),
      size: 240,
      colors: BlobSpec.warm,
      blur: 46,
      opacity: .58,
      delay: Duration(seconds: 9),
    ),
  ];

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
    final width = MediaQuery.sizeOf(context).width;
    final mapRgb = c.isDark ? const Color(0xFF0D0E13) : const Color(0xFFEFE8DE);
    final screen = TaraScreen(
      safeBottom: false,
      // Comme dans la maquette, le quartier (opaque) recouvre les formes liquides en haut.
      background: Positioned.fill(
        child: IgnorePointer(
          child: Stack(
            children: [
              const Positioned.fill(child: LiquidBackground(blobs: _blobs)),
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: 450 * width / 390,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Le quartier « en veille » : pâli tant que le livreur est hors ligne.
                    ColorFiltered(
                      colorFilter: citySleepFilter(dark: c.isDark),
                      child: const City3D(),
                    ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: const Alignment(0, -.3),
                          radius: .75,
                          colors: [mapRgb.withValues(alpha: 0), mapRgb.withValues(alpha: .85)],
                          stops: const [.5, 1],
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: SizedBox(
                        height: 140 * width / 390,
                        width: double.infinity,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [c.bg.withValues(alpha: 0), c.bg],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Espacements de la maquette (844 px), resserrés sur les petits écrans.
          final roomy = ((constraints.maxHeight - 600) / 244).clamp(.3, 1.0);
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    RiderAvatar(name: summary?.fullName ?? ''),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            hour < 18 ? l.goodMorning : l.goodEvening,
                            style: TaraText.label.copyWith(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: c.textPrimary.withValues(alpha: .70),
                            ),
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
                    const SizedBox(width: 8),
                    StatusPill(label: l.offline),
                  ],
                ),
                if (widget.courseBanner case final banner?) ...[const SizedBox(height: 16), banner],
                SizedBox(height: 112 * roomy),
                Center(
                  child: PowerButton(
                    label: l.goOnline,
                    semanticLabel: l.goOnlineLabel,
                    onPressed: _switching ? null : _goOnline,
                  ),
                ),
                const SizedBox(height: 28),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    l.offlineHint,
                    textAlign: TextAlign.center,
                    style: TaraText.text.copyWith(
                      fontSize: 14,
                      height: 1.5,
                      color: c.textPrimary.withValues(alpha: .78),
                    ),
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
                SizedBox(height: 48 * roomy),
                _Rise(
                  child: _TodayCards(
                    summary: summary,
                    onDetails: widget.onDetails,
                    onTopUp: () => setState(() => _toppingUp = true),
                  ),
                ),
                // Bas de l'écran, sous la barre d'onglets : amené à l'écran avec les blocages.
                SizedBox(key: _bottom, height: 16 + inset),
              ],
            ),
          );
        },
      ),
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        screen,
        if (_toppingUp)
          Positioned.fill(
            child: HideTabBar(
              child: DepositScreen.topUp(
                available: summary?.available ?? 0,
                withdrawalMinimum: summary?.withdrawalMinimum ?? 0,
                onBack: () => setState(() => _toppingUp = false),
                onDone: () {
                  ref.invalidate(homeSummaryProvider);
                  setState(() => _toppingUp = false);
                },
              ),
            ),
          ),
      ],
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

/// Les cartes du jour montent à l'affichage (0,6 s), comme dans la maquette.
class _Rise extends StatelessWidget {
  const _Rise({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!TaraEffects.of(context).decorativeMotion) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOut,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, 14 * (1 - t)), child: child),
      ),
      child: child,
    );
  }
}

/// Gains d'aujourd'hui, temps en ligne et solde prépayé (avec « Recharger »).
class _TodayCards extends ConsumerWidget {
  const _TodayCards({required this.summary, required this.onDetails, required this.onTopUp});

  final HomeSummary? summary;
  final VoidCallback onDetails;
  final VoidCallback onTopUp;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final s = summary;
    final muted = TaraText.label.copyWith(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: c.textPrimary.withValues(alpha: .70),
    );
    final big = TaraText.cardTitle.copyWith(fontSize: 22, color: c.textPrimary, fontFeatures: TaraText.tabular);
    final earnings = '${formatAmount(s?.earnings ?? 0)}\u00a0F';
    final delivered = s?.delivered ?? 0;
    Widget fitted(String text, TextStyle style) => FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text(text, maxLines: 1, style: style),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Semantics(
                  button: true,
                  label: '${l.earningsToday} : $earnings, $delivered ${l.jobsWord(delivered)}',
                  excludeSemantics: true,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onDetails,
                    child: HomeCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l.earningsToday, style: muted),
                          const SizedBox(height: 4),
                          fitted(earnings, big),
                          const SizedBox(height: 4),
                          Text(
                            '$delivered ${l.jobsWord(delivered)}',
                            style: muted.copyWith(color: c.isDark ? const Color(0xFFFFC283) : const Color(0xFF9A3412)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: HomeCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.onlineTime, style: muted),
                      const SizedBox(height: 4),
                      fitted(formatOnline(s?.onlineSeconds ?? 0), big),
                      const SizedBox(height: 4),
                      Text(l.onlineTodayWord, style: muted),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        HomeCard(
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color.fromRGBO(255, 177, 92, .14),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: TaraIcon(TaraIcons.wallet, size: 22, strokeWidth: 1.9, color: c.accentText),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.prepaidTitle, style: muted),
                    const SizedBox(height: 2),
                    // Masqué par défaut, comme sur MoMo : affiché après le code secret.
                    MaskedBalance(
                      s?.available ?? 0,
                      style: TaraText.cardTitle.copyWith(fontSize: 18, fontFeatures: TaraText.tabular),
                      color: c.textPrimary,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l.prepaidCovers,
                      style: TaraText.small.copyWith(fontSize: 12, color: c.textPrimary.withValues(alpha: .70)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              CompactButton(label: l.topUpAction, onPressed: onTopUp),
            ],
          ),
        ),
      ],
    );
  }
}
