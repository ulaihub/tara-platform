import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:tara_ui/components/buttons.dart';
import 'package:tara_ui/components/inputs.dart';
import 'package:tara_ui/components/layout.dart';
import 'package:tara_ui/components/progress.dart';
import 'package:tara_ui/components/three_d.dart';
import 'package:tara_ui/format.dart';
import 'package:tara_ui/motion/effects.dart';
import 'package:tara_ui/motion/liquid_background.dart';
import 'package:tara_ui/tara_colors.dart';
import 'package:tara_ui/tara_icons.dart';
import 'package:tara_ui/tara_typography.dart';

import '../../app/providers.dart';
import '../../core/api/client_models.dart';
import '../../l10n/app_localizations.dart';

/// « Mon activité » par période (day, week, month).
final merchantActivityProvider = FutureProvider.autoDispose.family<MerchantActivity, String>(
  (ref, period) => ref.read(clientApiProvider).merchantActivity(period),
);

/// Heure du Cameroun (UTC+1 toute l'année), quel que soit le fuseau du téléphone.
DateTime doualaTime(DateTime at) {
  final utc = at.toUtc().add(const Duration(hours: 1));
  return DateTime(utc.year, utc.month, utc.day, utc.hour, utc.minute);
}

/// Montant court : « 386 500 F », « 1,38 M F » à partir du million.
String compactAmount(int amount) {
  if (amount < 1000000) return '${formatAmount(amount)} F';
  return '${(amount / 1000000).toStringAsFixed(2).replaceAll('.', ',')} M F';
}

/// Tableau de bord de la boutique (maquette « Mon activité ») : période en segment, trois
/// chiffres et leur évolution, courbe des ventes encaissées sur les colonnes 3D des
/// livraisons (un toucher choisit le moment), quartiers les plus livrés et délai moyen.
class ActivityScreen extends ConsumerStatefulWidget {
  const ActivityScreen({super.key, required this.shopName, required this.onBack});

  final String shopName;
  final VoidCallback onBack;

  @override
  ConsumerState<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends ConsumerState<ActivityScreen> {
  static const _blobs = [
    BlobSpec(alignment: Alignment(-1.4, -1.15), size: 360, colors: BlobSpec.soft, blur: 60, opacity: .6),
  ];

  String _period = 'week';
  int? _picked;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final activity = ref.watch(merchantActivityProvider(_period));
    final data = activity.value;
    final periodLabel = switch (_period) {
      'day' => l.activityToday,
      'week' => l.activityThisWeek,
      _ => data == null ? l.activityThisMonth : DateFormat.MMMM(locale).format(doualaTime(data.from)),
    };
    return TaraScreen(
      blobs: _blobs,
      safeBottom: false,
      child: ListView(
        padding: EdgeInsets.fromLTRB(20, 10, 20, 24 + MediaQuery.paddingOf(context).bottom),
        children: [
          Row(
            children: [
              GlassIconButton(icon: TaraIcons.chevronLeft, label: l.back, onPressed: widget.onBack),
              const SizedBox(width: 12),
              Expanded(
                child: MergeSemantics(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          l.activityTitle,
                          style: TaraText.titleForm.copyWith(color: c.textPrimary, fontSize: 22),
                        ),
                      ),
                      Text(
                        '${widget.shopName} · $periodLabel',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TaraText.label.copyWith(
                          color: c.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const ExcludeSemantics(
                child: SizedBox.square(
                  dimension: 48,
                  child: FittedBox(
                    child: Parcel3D(size: 28, floating: false, shadow: false, period: Duration(seconds: 8)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Semantics(
            label: l.activityPeriod,
            child: LiquidSegmented<String>(
              segments: [('day', l.periodDay), ('week', l.periodWeek), ('month', l.periodMonth)],
              selected: _period,
              onChanged: (period) => setState(() {
                _period = period;
                _picked = null;
              }),
            ),
          ),
          const SizedBox(height: 14),
          switch (activity) {
            AsyncData(:final value) => _Body(
              activity: value,
              locale: locale,
              picked: _picked ?? _defaultPick(value),
              onPick: (i) => setState(() => _picked = i),
            ),
            AsyncError() => Padding(
              padding: const EdgeInsets.symmetric(vertical: 30),
              child: Column(
                children: [
                  Text(l.activityError, style: TaraText.label.copyWith(color: c.textSecondary)),
                  TaraLink(label: l.retry, onPressed: () => ref.invalidate(merchantActivityProvider(_period))),
                ],
              ),
            ),
            _ => const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: GooLoader(compact: true)),
            ),
          },
        ],
      ),
    );
  }

  /// Moment montré d'abord : le dernier qui a des ventes, sinon le dernier.
  static int _defaultPick(MerchantActivity a) {
    for (var i = a.buckets.length - 1; i >= 0; i--) {
      if (a.buckets[i].deliveries > 0) return i;
    }
    return a.buckets.length - 1;
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.activity, required this.locale, required this.picked, required this.onPick});

  final MerchantActivity activity;
  final String locale;
  final int picked;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final a = activity;
    String? percent(int? change) => change == null ? null : '${change >= 0 ? '+' : '−'}${change.abs()} %';
    final points = a.successRateChange == null
        ? null
        : '${a.successRateChange! >= 0 ? '+' : '−'}${l.pointsShort(a.successRateChange!.abs())}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _Kpi(
                  label: l.kpiDeliveries,
                  value: '${a.deliveries}',
                  delta: percent(a.deliveriesChange),
                  down: (a.deliveriesChange ?? 0) < 0,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Kpi(
                  label: l.kpiCollected,
                  value: compactAmount(a.collected),
                  delta: percent(a.collectedChange),
                  down: (a.collectedChange ?? 0) < 0,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Kpi(
                  label: l.kpiSuccess,
                  value: a.successRate == null ? '—' : '${a.successRate} %',
                  delta: points,
                  down: (a.successRateChange ?? 0) < 0,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _SalesChart(activity: a, locale: locale, picked: picked, onPick: onPick),
        const SizedBox(height: 12),
        _Card(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l.topZones,
                      style: TaraText.text.copyWith(color: c.textPrimary, fontSize: 14, fontWeight: FontWeight.w800),
                    ),
                  ),
                  if (a.averageMinutes case final minutes?)
                    Text(
                      l.averageDelay(_duration(l, minutes)),
                      style: TaraText.small.copyWith(color: c.textSecondary, fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              if (a.zones.isEmpty)
                Text(l.noZonesYet, style: TaraText.small.copyWith(color: c.textTertiary, fontSize: 12))
              else
                for (final (i, zone) in a.zones.indexed) ...[
                  if (i > 0) const SizedBox(height: 10),
                  MergeSemantics(
                    child: Row(
                      children: [
                        SizedBox(
                          width: 96,
                          child: Text(
                            zone.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TaraText.label.copyWith(
                              color: c.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: _ZoneBar(share: zone.share)),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 40,
                          child: Text(
                            '${zone.share} %',
                            textAlign: TextAlign.right,
                            style: TaraText.small.copyWith(
                              color: c.textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
            ],
          ),
        ),
      ],
    );
  }

  static String _duration(AppLocalizations l, int minutes) =>
      minutes < 60 ? l.minutesShort(minutes) : l.hoursMinutes(minutes ~/ 60, (minutes % 60).toString().padLeft(2, '0'));
}

class _Card extends StatelessWidget {
  const _Card({required this.child, required this.padding});
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final c = TaraColors.of(context);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: boxedFieldFill(c),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: boxedFieldBorder(c)),
        boxShadow: [
          if (!c.isDark)
            const BoxShadow(color: Color.fromRGBO(140, 70, 10, .10), blurRadius: 36, offset: Offset(0, 16)),
        ],
      ),
      child: child,
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi({required this.label, required this.value, required this.delta, required this.down});
  final String label;
  final String value;
  final String? delta;
  final bool down;

  @override
  Widget build(BuildContext context) {
    final c = TaraColors.of(context);
    return MergeSemantics(
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 12, 10, 12),
        decoration: BoxDecoration(
          color: boxedFieldFill(c),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: boxedFieldBorder(c)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TaraText.small.copyWith(color: c.textSecondary, fontSize: 11, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                maxLines: 1,
                style: TaraText.titlePanel.copyWith(
                  color: c.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  fontFeatures: TaraText.tabular,
                ),
              ),
            ),
            if (delta != null) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: down ? c.dangerTint : const Color.fromRGBO(14, 127, 87, .12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  delta!,
                  style: TaraText.small.copyWith(
                    color: down ? c.dangerText : c.success,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ZoneBar extends StatelessWidget {
  const _ZoneBar({required this.share});
  final int share;

  @override
  Widget build(BuildContext context) {
    final c = TaraColors.of(context);
    return ExcludeSemantics(
      child: Container(
        height: 10,
        decoration: BoxDecoration(color: c.textPrimary.withValues(alpha: .06), borderRadius: BorderRadius.circular(5)),
        alignment: Alignment.centerLeft,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: (math.max(share, 2) * 2.4 / 100).clamp(0, 1).toDouble()),
          duration: const Duration(milliseconds: 900),
          curve: const Cubic(.2, .8, .2, 1),
          builder: (context, value, _) => FractionallySizedBox(
            widthFactor: value,
            child: Container(
              decoration: BoxDecoration(gradient: TaraBrand.gradient, borderRadius: BorderRadius.circular(5)),
            ),
          ),
        ),
      ),
    );
  }
}

/// Ventes encaissées (courbe et aire) sur les livraisons (colonnes 3D) ; un toucher sur
/// une colonne affiche son détail dans la bulle sombre.
class _SalesChart extends StatelessWidget {
  const _SalesChart({required this.activity, required this.locale, required this.picked, required this.onPick});

  final MerchantActivity activity;
  final String locale;
  final int picked;
  final ValueChanged<int> onPick;

  String _tick(AppLocalizations l, int i) {
    final from = doualaTime(activity.buckets[i].from);
    return switch (activity.period) {
      'day' => l.hourShort(from.hour),
      'week' => _cap(DateFormat.E(locale).format(from)),
      _ => l.weekShort(i + 1),
    };
  }

  String _full(AppLocalizations l, int i) {
    final b = activity.buckets[i];
    final from = doualaTime(b.from);
    return switch (activity.period) {
      'day' => l.hourLong(from.hour),
      'week' => _cap(DateFormat.MMMEd(locale).format(from)),
      _ => l.daysRange(
        from.day,
        doualaTime(b.to).subtract(const Duration(hours: 12)).day,
        DateFormat.MMM(locale).format(from),
      ),
    };
  }

  static String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final buckets = activity.buckets;
    final n = buckets.length;
    final sel = buckets[picked];
    return _Card(
      padding: const EdgeInsets.fromLTRB(0, 14, 0, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l.chartSales,
                    style: TaraText.text.copyWith(color: c.textPrimary, fontSize: 14, fontWeight: FontWeight.w800),
                  ),
                ),
                ExcludeSemantics(
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 3,
                        decoration: BoxDecoration(color: TaraBrand.orange, borderRadius: BorderRadius.circular(2)),
                      ),
                      const SizedBox(width: 4),
                      Text(l.legendSales, style: _legend(c)),
                      const SizedBox(width: 10),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: c.textPrimary.withValues(alpha: .16),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(l.legendDeliveries, style: _legend(c)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 196,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final scale = constraints.maxWidth / 350;
                final xs = [for (var i = 0; i < n; i++) (n == 1 ? 175.0 : 26 + (324 - 26) * i / (n - 1)) * scale];
                final tipX = (xs[picked] - 66).clamp(4.0, constraints.maxWidth - 132 - 4);
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: TweenAnimationBuilder<double>(
                        key: ValueKey('${activity.period}-${activity.from}'),
                        tween: Tween(begin: 0, end: 1),
                        duration: const Duration(milliseconds: 1200),
                        curve: const Cubic(.4, 0, .2, 1),
                        builder: (context, t, _) => CustomPaint(
                          painter: _ChartPainter(
                            sales: [for (final b in buckets) b.sales],
                            deliveries: [for (final b in buckets) b.deliveries],
                            xs: xs,
                            scale: scale,
                            picked: picked,
                            progress: t,
                            ink: c.textPrimary,
                            accentTick: c.accentText,
                            ticks: [for (var i = 0; i < n; i++) _tick(l, i)],
                          ),
                        ),
                      ),
                    ),
                    // Détail du moment choisi.
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      left: tipX,
                      top: 2,
                      width: 132,
                      child: IgnorePointer(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF16120E),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _full(l, picked),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TaraText.small.copyWith(
                                  color: const Color.fromRGBO(255, 255, 255, .72),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                '${formatAmount(sel.sales)} F',
                                style: TaraText.text.copyWith(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                l.deliveriesCount(sel.deliveries),
                                style: TaraText.small.copyWith(
                                  color: const Color(0xFFFFC283),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Colonnes à toucher.
                    Positioned(
                      left: 10 * scale,
                      right: 10 * scale,
                      top: 0,
                      height: 190,
                      child: Row(
                        children: [
                          for (var i = 0; i < n; i++)
                            Expanded(
                              child: Semantics(
                                button: true,
                                selected: i == picked,
                                label:
                                    '${_full(l, i)} : ${formatAmount(buckets[i].sales)} F, ${l.deliveriesCount(buckets[i].deliveries)}',
                                excludeSemantics: true,
                                child: GestureDetector(
                                  key: ValueKey('activity-bucket-$i'),
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () => onPick(i),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  static TextStyle _legend(TaraColors c) =>
      TaraText.small.copyWith(color: c.textSecondary, fontSize: 11, fontWeight: FontWeight.w700);
}

class _ChartPainter extends CustomPainter {
  _ChartPainter({
    required this.sales,
    required this.deliveries,
    required this.xs,
    required this.scale,
    required this.picked,
    required this.progress,
    required this.ink,
    required this.accentTick,
    required this.ticks,
  });

  final List<int> sales;
  final List<int> deliveries;
  final List<double> xs;
  final double scale;
  final int picked;
  final double progress;
  final Color ink;
  final Color accentTick;
  final List<String> ticks;

  static const _base = 150.0;

  @override
  void paint(Canvas canvas, Size size) {
    final left = 16 * scale;
    final right = 334 * scale;
    // Repères pointillés et sol.
    final guide = Paint()
      ..color = ink.withValues(alpha: .07)
      ..strokeWidth = 1;
    for (final y in [40.0, 95.0]) {
      for (var x = left; x < right; x += 8) {
        canvas.drawLine(Offset(x, y), Offset(math.min(x + 3, right), y), guide);
      }
    }
    canvas.drawPath(
      Path()
        ..moveTo(left, _base)
        ..lineTo(right, _base)
        ..lineTo(right + 6, _base - 5)
        ..lineTo(left + 6, _base - 5)
        ..close(),
      Paint()..color = ink.withValues(alpha: .05),
    );
    canvas.drawLine(Offset(left, _base), Offset(right, _base), Paint()..color = ink.withValues(alpha: .10));

    // Colonnes 3D des livraisons, qui poussent.
    final grow = Curves.easeOutCubic.transform((progress / .6).clamp(0, 1));
    final maxCount = math.max(1, deliveries.fold<int>(0, math.max));
    for (var i = 0; i < xs.length; i++) {
      final h = math.max(2.0, deliveries[i] / maxCount * 46) * grow;
      final x = xs[i] - 7;
      final y = _base - h;
      final on = i == picked;
      canvas
        ..drawPath(
          Path()
            ..moveTo(x + 14, y)
            ..lineTo(x + 20, y - 5)
            ..lineTo(x + 20, _base - 5)
            ..lineTo(x + 14, _base)
            ..close(),
          Paint()..color = on ? const Color(0xFFD9530A) : ink.withValues(alpha: .17),
        )
        ..drawPath(
          Path()
            ..moveTo(x, y)
            ..lineTo(x + 6, y - 5)
            ..lineTo(x + 20, y - 5)
            ..lineTo(x + 14, y)
            ..close(),
          Paint()..color = on ? const Color(0xFFFFC283) : ink.withValues(alpha: .05),
        )
        ..drawRect(
          Rect.fromLTWH(x, y, 14, h),
          Paint()..color = on ? const Color(0xFFFF8A3D) : ink.withValues(alpha: .10),
        );
    }

    // Courbe lissée des ventes et son aire.
    final maxSale = math.max(1, sales.fold<int>(0, math.max));
    final pts = [for (var i = 0; i < xs.length; i++) Offset(xs[i], _base - sales[i] / maxSale * 112)];
    final line = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 0; i < pts.length - 1; i++) {
      final p0 = pts[math.max(0, i - 1)];
      final p1 = pts[i];
      final p2 = pts[i + 1];
      final p3 = pts[math.min(pts.length - 1, i + 2)];
      final c1 = Offset(p1.dx + (p2.dx - p0.dx) / 6, math.min(_base, p1.dy + (p2.dy - p0.dy) / 6));
      final c2 = Offset(p2.dx - (p3.dx - p1.dx) / 6, math.min(_base, p2.dy - (p3.dy - p1.dy) / 6));
      line.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
    }
    final fade = ((progress - .25) / .75).clamp(0.0, 1.0);
    final area = Path.from(line)
      ..lineTo(pts.last.dx, _base)
      ..lineTo(pts.first.dx, _base)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = ui.Gradient.linear(const Offset(0, 0), const Offset(0, _base), [
          Color.fromRGBO(255, 138, 0, .34 * fade),
          const Color.fromRGBO(255, 138, 0, 0),
        ]),
    );
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..shader = ui.Gradient.linear(
        Offset(left, 0),
        Offset(right, 0),
        const [TaraBrand.amber, TaraBrand.orange, TaraBrand.red],
        const [0, .55, 1],
      );
    for (final metric in line.computeMetrics()) {
      canvas.drawPath(metric.extractPath(0, metric.length * progress), stroke);
    }

    // Moment choisi : trait pointillé et point blanc cerclé.
    final sel = pts[picked];
    final dash = Paint()
      ..color = ink.withValues(alpha: .28)
      ..strokeWidth = 1;
    for (var y = 18.0; y < _base; y += 7) {
      canvas.drawLine(Offset(sel.dx, y), Offset(sel.dx, math.min(y + 3, _base)), dash);
    }
    if (progress > .9) {
      canvas
        ..drawCircle(sel, 7, Paint()..color = Colors.white)
        ..drawCircle(
          sel,
          5.5,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..color = TaraBrand.orange,
        );
    }

    // Repères du bas.
    for (var i = 0; i < ticks.length; i++) {
      final painter = TextPainter(
        text: TextSpan(
          text: ticks[i],
          style: TaraText.small.copyWith(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: i == picked ? accentTick : ink.withValues(alpha: .62),
          ),
        ),
        textDirection: TextDirection.ltr,
        textScaler: TextScaler.noScaling,
      )..layout();
      painter.paint(canvas, Offset(xs[i] - painter.width / 2, 176 - painter.height + 3));
    }
  }

  @override
  bool shouldRepaint(_ChartPainter old) =>
      old.progress != progress || old.picked != picked || old.ink != ink || old.sales != sales || old.xs != xs;
}
