import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:tara_ui/components/buttons.dart';
import 'package:tara_ui/components/glass.dart';
import 'package:tara_ui/components/layout.dart';
import 'package:tara_ui/components/pin_flow.dart';
import 'package:tara_ui/components/progress.dart';
import 'package:tara_ui/components/tab_shell.dart';
import 'package:tara_ui/format.dart';
import 'package:tara_ui/motion/effects.dart';
import 'package:tara_ui/motion/liquid_background.dart';
import 'package:tara_ui/tara_colors.dart';
import 'package:tara_ui/tara_icons.dart';
import 'package:tara_ui/tara_typography.dart';

import '../../app/providers.dart';
import '../../core/api/models.dart';
import '../../l10n/app_localizations.dart';
import '../common/pin.dart';
import 'deposit_screen.dart';
import 'withdraw_screen.dart';

/// 13 · Activité (E9) : gains du jour, de la semaine ou du mois avec leur histogramme,
/// solde prépayé et sa recharge (G5), anciennes espèces à reverser, dernières courses.
class ActivityScreen extends ConsumerStatefulWidget {
  const ActivityScreen({super.key, this.now});

  /// Horloge (tests).
  final DateTime Function()? now;

  @override
  ConsumerState<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends ConsumerState<ActivityScreen> {
  static const _blobs = [
    BlobSpec(alignment: Alignment(1.2, -1.05), size: 300, colors: BlobSpec.brand, blur: 70),
    BlobSpec(alignment: Alignment(-1.3, 0.6), size: 240, colors: BlobSpec.warm, blur: 64, delay: Duration(seconds: 5)),
  ];

  String _period = 'day';
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
                padding: EdgeInsets.fromLTRB(20, 12, 20, 24 + TaraTabShell.bottomInset(context)),
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final title = Semantics(
                        header: true,
                        child: Text(l.tabActivity, style: TaraText.titleForm.copyWith(color: c.textPrimary)),
                      );
                      final selector = LiquidSegmented<String>(
                        compact: true,
                        segments: [('day', l.periodDay), ('week', l.periodWeek), ('month', l.periodMonth)],
                        selected: _period,
                        onChanged: (period) {
                          if (period == _period) return;
                          setState(() {
                            _period = period;
                            _earnings = ref.read(riderApiProvider).earnings(period);
                          });
                        },
                      );
                      // Sélecteur à droite du titre (maquette) ; dessous si la place manque.
                      final wide = constraints.maxWidth >= 340 && MediaQuery.textScalerOf(context).scale(10) <= 11;
                      if (!wide) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [title, const SizedBox(height: 10), selector],
                        );
                      }
                      return Row(
                        children: [
                          title,
                          const SizedBox(width: 16),
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 230), child: selector),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  FutureBuilder<Earnings>(
                    future: _earnings,
                    builder: (context, snapshot) =>
                        _EarningsCard(earnings: snapshot.data, failed: snapshot.hasError, onRetry: _reload, now: now),
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

/// Total de la période, nombre de courses et histogramme (barre courante en dégradé).
class _EarningsCard extends StatelessWidget {
  const _EarningsCard({required this.earnings, required this.failed, required this.onRetry, required this.now});
  final Earnings? earnings;
  final bool failed;
  final VoidCallback onRetry;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final data = earnings;
    final caption = switch (data?.period) {
      'week' => l.earningsWeek,
      'month' => l.earningsMonth,
      _ => l.earningsToday,
    };
    return GlassCard(
      radius: 26,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      child: failed
          ? _Failed(onRetry: onRetry)
          : data == null
          ? const SizedBox(height: 210, child: Center(child: GooLoader(compact: true)))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(caption, style: TaraText.label.copyWith(color: c.textSecondary)),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: AmountText(data.earnings, style: TaraText.amountL.copyWith(fontSize: 34)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(l.coursesCount(data.delivered), style: TaraText.label.copyWith(color: c.textSecondary)),
                  ],
                ),
                const SizedBox(height: 16),
                _Histogram(earnings: data, caption: caption, now: now),
              ],
            ),
    );
  }
}

/// Barres de la période ; seule la barre en cours est en dégradé, avec sa valeur au-dessus.
class _Histogram extends StatelessWidget {
  const _Histogram({required this.earnings, required this.caption, required this.now});
  final Earnings earnings;
  final String caption;
  final DateTime now;

  static const _maxHeight = 104.0;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final series = earnings.series;
    if (series.isEmpty) return const SizedBox.shrink();
    final labels = _labels(l, series);
    final current = _current(series);
    final max = series.map((bucket) => bucket.earnings).fold<int>(0, math.max);
    final values = [for (var i = 0; i < series.length; i++) '${labels[i]} ${formatAmount(series[i].earnings)} F']
        .join(', ');

    return Semantics(
      label: l.chartSemantics(caption, values),
      excludeSemantics: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < series.length; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (i == current)
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          formatAmount(series[i].earnings),
                          style: TaraText.smallStrong.copyWith(color: c.textPrimary, fontFeatures: TaraText.tabular),
                        ),
                      ),
                    const SizedBox(height: 4),
                    Container(
                      constraints: const BoxConstraints(maxWidth: 34),
                      height: max == 0 ? 6 : math.max(6, series[i].earnings / max * _maxHeight),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        gradient: i == current
                            ? const LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [TaraBrand.amber, TaraBrand.orange, TaraBrand.red],
                                stops: [0, .55, 1],
                              )
                            : null,
                        color: i == current ? null : c.neutralBar,
                        boxShadow: i == current
                            ? const [
                                BoxShadow(color: Color.fromRGBO(255, 90, 0, .4), blurRadius: 20, offset: Offset(0, 8)),
                              ]
                            : null,
                      ),
                    ),
                    const SizedBox(height: 6),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        labels[i],
                        maxLines: 1,
                        style: TaraText.small.copyWith(
                          color: i == current ? c.textPrimary : c.textTertiary,
                          fontWeight: i == current ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<String> _labels(AppLocalizations l, List<EarningsBucket> series) {
    final weekdays = l.weekdaysShort.split(',');
    return [
      for (var i = 0; i < series.length; i++)
        switch (earnings.bucket) {
          'two_hours' => l.hourShort(series[i].start.toLocal().hour),
          'day' =>
            _sameDay(series[i].start.toLocal(), now) ? l.todayShort : weekdays[series[i].start.toLocal().weekday - 1],
          _ => l.weekShort(i + 1),
        },
    ];
  }

  /// Tranche qui contient l'heure actuelle (aucune la nuit, hors des tranches du jour).
  int _current(List<EarningsBucket> series) {
    for (var i = series.length - 1; i >= 0; i--) {
      final start = series[i].start;
      final end = i + 1 < series.length
          ? series[i + 1].start
          : start.add(earnings.bucket == 'two_hours' ? const Duration(hours: 2) : const Duration(days: 7));
      if (!now.isBefore(start) && now.isBefore(end)) return i;
    }
    return -1;
  }

  static bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;
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
    final button = GlassButton(label: action, height: 44, radius: 14, onPressed: onAction);
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
                  child: GlassButton(label: secondary, height: 44, radius: 14, onPressed: onSecondary),
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
