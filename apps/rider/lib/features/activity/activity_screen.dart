import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:tara_ui/components/buttons.dart';
import 'package:tara_ui/components/glass.dart';
import 'package:tara_ui/components/layout.dart';
import 'package:tara_ui/components/pin_flow.dart';
import 'package:tara_ui/components/tab_shell.dart';
import 'package:tara_ui/components/three_d.dart';
import 'package:tara_ui/format.dart';
import 'package:tara_ui/motion/effects.dart';
import 'package:tara_ui/motion/liquid_background.dart';
import 'package:tara_ui/tara_colors.dart';
import 'package:tara_ui/tara_icons.dart';
import 'package:tara_ui/tara_typography.dart';

import '../../app/providers.dart';
import '../../app/root.dart' show riderProfileProvider;
import '../../core/api/models.dart';
import '../../l10n/app_localizations.dart';
import '../common/pin.dart';
import '../home/home_summary.dart';
import '../home/home_widgets.dart';
import 'deposit_screen.dart';
import 'withdraw_screen.dart';

/// 13 · Mes gains (E9) : semaine en cours en colonnes 3D, jour par jour,
/// solde prépayé et sa recharge (G5), anciennes espèces à reverser, dernières courses.
class ActivityScreen extends ConsumerStatefulWidget {
  const ActivityScreen({super.key, this.now});

  /// Horloge (tests).
  final DateTime Function()? now;

  @override
  ConsumerState<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends ConsumerState<ActivityScreen> {
  // Une seule forme orange en haut à droite, comme dans la maquette.
  static const _blobs = [
    BlobSpec(
      alignment: Alignment(.69, -.81),
      size: 360,
      colors: [TaraBrand.orange, Color(0x00FF6A00)],
      opacity: .4,
      center: Alignment.center,
    ),
  ];

  /// Semaine en cours, jour par jour (maquette Tableau-Livreur).
  static const _period = 'week';
  late Future<Earnings> _earnings;
  late Future<List<RiderOrder>> _history;
  late Future<RiderWallet> _wallet;
  bool _all = false;

  /// Écran de paiement à Tara ouvert : recharge du solde ou dépôt des espèces.
  _Payment? _paying;

  /// Code secret donné pour afficher le solde avant le retrait : il confirme aussi le retrait.
  PinProof? _withdrawProof;

  /// Retrait : le solde masqué s'affiche d'abord avec le code secret (ou l'empreinte), qui
  /// sert ensuite à confirmer le retrait sans le redemander.
  Future<void> _openWithdraw() async {
    final visibility = ref.read(balanceVisibilityProvider);
    PinProof? proof;
    if (!visibility.visible) {
      final pin = ref.read(pinApiProvider);
      try {
        proof = await withPin<PinProof>(
          context,
          pinServices(context, ref),
          reason: AppLocalizations.of(context).pinReasonBalance,
          action: (given) async {
            await pin.verify(given);
            return given;
          },
        );
      } on Exception {
        return;
      }
      if (proof == null || !mounted) return;
      visibility.show();
    }
    setState(() {
      _withdrawProof = proof;
      _paying = _Payment.withdraw;
    });
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final api = ref.read(riderApiProvider);
    _earnings = api.earnings(_period);
    _history = api.history();
    _wallet = api.riderWallet();
  }

  void _reload() => setState(_load);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final now = widget.now?.call() ?? DateTime.now();

    return Stack(
      children: [
        Positioned.fill(
          child: TaraScreen(
            blobs: _blobs,
            safeBottom: false,
            // Le contenu défile jusqu'en bas de l'écran, sous la barre d'onglets en verre.
            child: RefreshIndicator(
              onRefresh: () async {
                _reload();
                await Future.wait<Object?>([_earnings, _history, _wallet]).catchError((_) => <Object?>[]);
              },
              child: ListView(
                padding: EdgeInsets.fromLTRB(20, 22, 20, 24 + TaraTabShell.bottomInset(context)),
                children: [
                  const _GainsHeader(),
                  const SizedBox(height: 18),
                  FutureBuilder<Earnings>(
                    future: _earnings,
                    builder: (context, snapshot) => snapshot.hasError
                        ? _Failed(onRetry: _reload)
                        : snapshot.data == null
                        ? const SizedBox(height: 300, child: Center(child: GooLoader(compact: true)))
                        : _WeekBlock(earnings: snapshot.data!, now: now),
                  ),
                  FutureBuilder<RiderWallet>(
                    future: _wallet,
                    builder: (context, snapshot) {
                      final wallet = snapshot.data;
                      if (wallet == null) return const SizedBox.shrink();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 12),
                          _BalanceBox(
                            wallet: wallet,
                            onTopUp: () => setState(() => _paying = _Payment.topUp),
                            onWithdraw: () => unawaited(_openWithdraw()),
                          ),
                          if (wallet.cashHeld > 0) ...[
                            const SizedBox(height: 12),
                            _CashBox(
                              amount: wallet.cashHeld,
                              dueBy: wallet.cashDueBy,
                              overdue: wallet.cashOverdue,
                              now: now,
                              onDeposit: () => setState(() => _paying = _Payment.deposit),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  FutureBuilder<List<RiderOrder>>(
                    future: _history,
                    builder: (context, snapshot) {
                      final orders = snapshot.data;
                      final shown = orders == null ? const <RiderOrder>[] : (_all ? orders : orders.take(3).toList());
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SectionHeader(
                            title: l.lastCourses,
                            action: orders != null && orders.length > 3
                                ? TaraLink(
                                    label: _all ? l.seeLess : l.seeAll,
                                    onPressed: () => setState(() => _all = !_all),
                                  )
                                : null,
                          ),
                          const SizedBox(height: 8),
                          if (snapshot.hasError)
                            _Failed(onRetry: _reload)
                          else if (orders == null)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 20),
                              child: Center(child: GooLoader(compact: true)),
                            )
                          else if (orders.isEmpty)
                            Text(l.noCoursesYet, style: TaraText.label.copyWith(color: c.textSecondary))
                          else
                            GlassCard(
                              radius: 22,
                              shadow: false,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              child: Column(
                                children: [
                                  for (var i = 0; i < shown.length; i++) ...[
                                    if (i > 0) Divider(height: 1, color: c.glassBorder),
                                    _CourseRow(order: shown[i], now: now),
                                  ],
                                ],
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_paying case final paying?)
          Positioned.fill(
            child: HideTabBar(
              child: FutureBuilder<RiderWallet>(
                future: _wallet,
                builder: (context, snapshot) {
                  void back() => setState(() => _paying = null);
                  void done() => setState(() {
                    _paying = null;
                    _load();
                  });
                  return switch (paying) {
                    _Payment.topUp => DepositScreen.topUp(
                      available: snapshot.data?.available ?? 0,
                      withdrawalMinimum: snapshot.data?.withdrawalMinimum ?? 0,
                      onBack: back,
                      onDone: done,
                    ),
                    _Payment.deposit => DepositScreen(amount: snapshot.data?.cashHeld ?? 0, onBack: back, onDone: done),
                    _Payment.withdraw => switch (snapshot.data) {
                      final wallet? => WithdrawScreen(
                        wallet: wallet,
                        proof: _withdrawProof,
                        onBack: back,
                        onDone: done,
                      ),
                      null => const SizedBox.shrink(),
                    },
                  };
                },
              ),
            ),
          ),
      ],
    );
  }
}

/// En-tête de la maquette : « Mes gains », nom et véhicule, état en ligne ou hors ligne.
class _GainsHeader extends ConsumerWidget {
  const _GainsHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final name = ref.watch(riderNameProvider).value ?? '';
    final vehicle = switch (ref.watch(riderProfileProvider).value?.vehicleType) {
      'MOTORBIKE' => l.vehicleMotorbike,
      'CAR' => l.vehicleCar,
      'TRICYCLE' => l.vehicleTricycle,
      _ => null,
    };
    final online = ref.watch(onlineControllerProvider);
    final seconds = ref.watch(homeSummaryProvider).value?.onlineSeconds ?? 0;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(
                  l.myEarnings,
                  style: TextStyle(
                    fontFamily: TaraText.sora,
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -.52,
                    color: c.textPrimary,
                  ),
                ),
              ),
              if (name.isNotEmpty)
                Text(
                  [name, ?vehicle?.toLowerCase()].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TaraText.label.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: c.textPrimary.withValues(alpha: .72),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        ListenableBuilder(
          listenable: online,
          builder: (context, _) => online.online
              ? StatusPill(online: true, label: l.onlineSince(formatOnline(seconds)))
              : StatusPill(label: l.offline),
        ),
      ],
    );
  }
}

/// Semaine en cours : total, colonnes en relief jour par jour (aujourd'hui allumé, jours à
/// venir en pointillés), détail du jour touché, puis courses et temps en ligne.
class _WeekBlock extends StatefulWidget {
  const _WeekBlock({required this.earnings, required this.now});
  final Earnings earnings;
  final DateTime now;

  @override
  State<_WeekBlock> createState() => _WeekBlockState();
}

class _WeekBlockState extends State<_WeekBlock> {
  int? _picked;

  static bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final data = widget.earnings;
    final now = widget.now;
    final series = data.series;
    final days = [for (final bucket in series) bucket.start.toLocal()];
    final today = days.indexWhere((day) => _sameDay(day, now));
    final picked = _picked ?? (today >= 0 ? today : series.length - 1);
    final short = DateFormat.E(l.localeName);
    final full = DateFormat('EEEE d MMM', l.localeName);
    bool future(int i) => days[i].isAfter(now) && !_sameDay(days[i], now);
    String amount(int value) => '${formatAmount(value)} F';
    String capitalized(String text) => text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);
    String label(int i) => capitalized(short.format(days[i]).replaceAll('.', ''));
    String fullLabel(int i) => capitalized(full.format(days[i])) + (i == today ? ' · ${l.todaySuffix}' : '');
    final best = series.fold<int>(0, (m, b) => math.max(m, b.earnings));
    final muted = c.textPrimary.withValues(alpha: .72);
    final picked2 = c.isDark ? const Color(0xFFFFC283) : const Color(0xFF9A3412);
    final ok = c.isDark ? const Color(0xFF4ADE9B) : const Color(0xFF0E7F57);
    Widget card({required Widget child, EdgeInsets padding = const EdgeInsets.all(10), double radius = 18}) =>
        Container(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            color: c.textPrimary.withValues(alpha: .06),
            border: Border.all(color: c.textPrimary.withValues(alpha: .10)),
          ),
          child: child,
        );
    Widget tile(String caption, String value) => Expanded(
      child: card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              caption,
              style: TaraText.small.copyWith(fontSize: 11, fontWeight: FontWeight.w700, color: muted),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                maxLines: 1,
                style: TextStyle(
                  fontFamily: TaraText.sora,
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: c.textPrimary,
                  fontFeatures: TaraText.tabular,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    final pickedBucket = series.isEmpty ? null : series[picked];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l.thisWeek,
          style: TaraText.label.copyWith(fontSize: 13, fontWeight: FontWeight.w700, color: muted),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            amount(data.earnings),
            style: TextStyle(
              fontFamily: TaraText.sora,
              fontSize: 40,
              fontWeight: FontWeight.w800,
              letterSpacing: -.8,
              color: c.textPrimary,
              fontFeatures: TaraText.tabular,
            ),
          ),
        ),
        Text(
          l.jobsCount(data.delivered),
          style: TaraText.label.copyWith(fontSize: 13, fontWeight: FontWeight.w700, color: ok),
        ),
        const SizedBox(height: 14),
        card(
          radius: 24,
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Column3DChart(
                showDetail: false,
                height: 112,
                // Les plus hautes colonnes gardent de l'air au-dessus (échelle de la maquette).
                maxValue: best <= 0 ? 1 : best * 1.25,
                selected: picked,
                onSelected: (i) => setState(() => _picked = i),
                columns: [
                  for (var i = 0; i < series.length; i++)
                    Column3D(
                      label: label(i),
                      value: series[i].earnings.toDouble(),
                      future: future(i),
                      detail: future(i)
                          ? '${fullLabel(i)} : ${l.dayNotYetLabel}'
                          : '${fullLabel(i)} : ${amount(series[i].earnings)} · ${l.jobsCount(series[i].delivered)}',
                    ),
                ],
              ),
              const SizedBox(height: 10),
              if (pickedBucket != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: c.textPrimary.withValues(alpha: .06),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          fullLabel(picked),
                          style: TaraText.label.copyWith(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: c.textPrimary.withValues(alpha: .80),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text.rich(
                        TextSpan(
                          children: future(picked)
                              ? [TextSpan(text: l.dayNotYet)]
                              : [
                                  TextSpan(text: amount(pickedBucket.earnings)),
                                  TextSpan(
                                    text: ' · ${l.jobsCount(pickedBucket.delivered)}',
                                    style: TextStyle(color: picked2),
                                  ),
                                ],
                        ),
                        style: TaraText.label.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: c.textPrimary,
                          fontFeatures: TaraText.tabular,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            tile(l.weekRides, '${data.delivered}'),
            const SizedBox(width: 8),
            tile(l.weekOnline, formatOnline(data.onlineSeconds)),
          ],
        ),
      ],
    );
  }
}

/// Écran ouvert par-dessus l'activité : recharge, dépôt des espèces ou retrait des gains.
enum _Payment { topUp, deposit, withdraw }

/// Solde prépayé (G5) : disponible, montant mis de côté pour les courses en cours, boutons
/// « Recharger » et « Retirer » (vers son Mobile Money). Une course avec encaissement n'est
/// proposée que si le disponible la couvre.
class _BalanceBox extends StatelessWidget {
  const _BalanceBox({required this.wallet, required this.onTopUp, required this.onWithdraw});
  final RiderWallet wallet;
  final VoidCallback onTopUp;
  final VoidCallback onWithdraw;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final free = '${formatAmount(wallet.withdrawalFreeFrom)}\u00a0F';
    // Seule la part du livreur est annoncée (taux effectif).
    final rate =
        '${NumberFormat('#0.##', 'fr').format(wallet.withdrawalFeeBps * wallet.withdrawalFeeSharePercent / 10000)}\u00a0%';
    final open = wallet.openPayout;
    return _ActionBox(
      tone: TintTone.accent,
      icon: TaraIcons.wallet,
      lines: [
        Text(l.balanceAvailable, style: TaraText.label.copyWith(color: c.textSecondary)),
        // Masqué par défaut, comme sur MoMo : affiché après le code secret.
        MaskedBalance(
          wallet.available,
          style: TaraText.bodyStrong.copyWith(fontFeatures: TaraText.tabular),
          color: c.accentStrongText,
        ),
        Text(
          wallet.reserved > 0 ? l.balanceReserved('${formatAmount(wallet.reserved)}\u00a0F') : l.balanceExplain,
          style: TaraText.small.copyWith(color: c.textSecondary),
        ),
        if (wallet.withdrawalFeeBps > 0 && wallet.withdrawalFeeSharePercent > 0)
          Text(l.withdrawalRule(free, rate), style: TaraText.small.copyWith(color: c.textSecondary)),
        if (open != null) ...[
          const SizedBox(height: 6),
          InfoPill(
            label: l.withdrawOpen('${formatAmount(open.amount)}\u00a0F'),
            tone: TintTone.accent,
            icon: TaraIcons.clock,
          ),
        ],
      ],
      action: l.topUpAction,
      onAction: onTopUp,
      // Un seul retrait à la fois ; rien à retirer sans disponible.
      secondaryAction: open == null && wallet.available > 0 ? l.withdrawAction : null,
      onSecondary: onWithdraw,
    );
  }
}

/// Encadré teinté : icône, lignes de texte lues ensemble, bouton à droite ; bouton dessous
/// quand la place manque (petit écran, grand texte).
class _ActionBox extends StatelessWidget {
  const _ActionBox({
    required this.tone,
    required this.icon,
    required this.lines,
    required this.action,
    required this.onAction,
    this.secondaryAction,
    this.onSecondary,
  });
  final TintTone tone;
  final TaraIconData icon;
  final List<Widget> lines;
  final String action;
  final VoidCallback onAction;

  /// Second bouton (« Retirer ») : les deux boutons passent alors sous le texte.
  final String? secondaryAction;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    final c = TaraColors.of(context);
    final text = Row(
      children: [
        TaraIcon(icon, size: 22, color: c.accentText),
        const SizedBox(width: 12),
        Expanded(
          child: MergeSemantics(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: lines),
          ),
        ),
      ],
    );
    final button = GlassButton(label: action, height: 44, onPressed: onAction);
    if (secondaryAction case final secondary?) {
      return TintBox(
        tone: tone,
        padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            text,
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: button),
                const SizedBox(width: 8),
                Expanded(
                  child: GlassButton(label: secondary, height: 44, onPressed: onSecondary),
                ),
              ],
            ),
          ],
        ),
      );
    }
    return TintBox(
      tone: tone,
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 300 && MediaQuery.textScalerOf(context).scale(10) <= 11;
          if (wide) {
            return Row(
              children: [
                Expanded(child: text),
                const SizedBox(width: 8),
                button,
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [text, const SizedBox(height: 10), button],
          );
        },
      ),
    );
  }
}

/// Espèces encaissées avant le solde prépayé et pas encore reversées, bouton « Reverser ».
class _CashBox extends StatelessWidget {
  const _CashBox({
    required this.amount,
    required this.dueBy,
    required this.overdue,
    required this.now,
    required this.onDeposit,
  });
  final int amount;
  final DateTime? dueBy;
  final bool overdue;
  final DateTime now;
  final VoidCallback onDeposit;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final due = dueBy?.toLocal();
    final deadline = overdue
        ? l.cashOverdueNotice
        : due == null
        ? null
        : (due.year == now.year && due.month == now.month && due.day == now.day)
        ? l.cashDueAt(formatClock(due))
        : l.cashDueTomorrow(formatClock(due));
    return _ActionBox(
      tone: overdue ? TintTone.danger : TintTone.accent,
      icon: TaraIcons.cash,
      lines: [
        Text(l.cashToDeposit, style: TaraText.label.copyWith(color: c.textSecondary)),
        Text(
          '${formatAmount(amount)}\u00a0F',
          style: TaraText.bodyStrong.copyWith(color: c.accentStrongText, fontFeatures: TaraText.tabular),
        ),
        if (deadline != null)
          Text(
            deadline,
            style: TaraText.small.copyWith(
              color: overdue ? c.dangerTextStrong : c.textSecondary,
              fontWeight: overdue ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
      ],
      action: l.depositAction,
      onAction: onDeposit,
    );
  }
}

/// Course terminée : statut, trajet, heure · statut · encaissement, gain.
class _CourseRow extends StatelessWidget {
  const _CourseRow({required this.order, required this.now});
  final RiderOrder order;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final (icon, color, background, status) = switch (order.status) {
      'DELIVERED' => (TaraIcons.check, c.success, c.successTintBg, l.statusDelivered),
      'RETURNED' => (TaraIcons.returnArrow, c.accentText, c.accentTintBg, l.statusReturned),
      _ => (TaraIcons.close, c.textTertiary, c.chipBg, l.statusCancelled),
    };
    final from = order.pickup.neighborhood ?? order.pickup.city;
    final to = order.dropoff.neighborhood ?? order.dropoff.city;
    final at = order.completedAt?.toLocal();
    final time = at == null
        ? null
        : (at.year == now.year && at.month == now.month && at.day == now.day)
        ? formatClock(at)
        : '${at.day.toString().padLeft(2, '0')}/${at.month.toString().padLeft(2, '0')} · ${formatClock(at)}';
    final money = switch (order.collectedMethod) {
      'CASH' => l.cashCollectedAmount('${formatAmount(order.collectedAmount ?? 0)} F'),
      'MOBILE_MONEY' => l.methodMomo,
      _ => null,
    };
    final meta = [?time, status, ?money].join(' · ');
    final earned = order.status == 'CANCELLED' ? null : order.riderEarning;

    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(12)),
              child: TaraIcon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$from → $to',
                    style: TaraText.text.copyWith(fontWeight: FontWeight.w700, color: c.textPrimary),
                  ),
                  Text(meta, style: TaraText.small.copyWith(color: c.textSecondary)),
                ],
              ),
            ),
            if (earned != null) ...[
              const SizedBox(width: 8),
              Text(
                '+${formatAmount(earned)}',
                style: TaraText.bodyStrong.copyWith(color: c.success, fontFeatures: TaraText.tabular),
              ),
            ],
          ],
        ),
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
            child: Text(l.activityError, style: TaraText.label.copyWith(color: c.textSecondary)),
          ),
          TaraLink(label: l.retry, onPressed: onRetry),
        ],
      ),
    );
  }
}
