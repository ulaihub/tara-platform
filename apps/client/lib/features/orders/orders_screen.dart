import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tara_ui/components/buttons.dart';
import 'package:tara_ui/components/glass.dart';
import 'package:tara_ui/components/layout.dart';
import 'package:tara_ui/components/tab_shell.dart';
import 'package:tara_ui/components/three_d.dart';
import 'package:tara_ui/format.dart';
import 'package:tara_ui/motion/effects.dart';
import 'package:tara_ui/motion/liquid_background.dart';
import 'package:tara_ui/tara_colors.dart';
import 'package:tara_ui/tara_effects.dart';
import 'package:tara_ui/tara_icons.dart';
import 'package:tara_ui/tara_typography.dart';

import '../../app/providers.dart';
import '../../core/api/client_models.dart';
import '../../l10n/app_localizations.dart';
import 'order_row.dart';
import 'pending_section.dart';

/// Commandes de l'expéditeur par période : en cours (active) ou terminées (history).
final ordersProvider = FutureProvider.family<List<OrderSummary>, String>(
  (ref, scope) => ref.read(clientApiProvider).orders(scope: scope, limit: 50),
);

/// Onglet Commandes (maquette Commandes) : titre et pile de colis 3D, recherche (client,
/// repère ou TR-…), onglets orange élastiques « En cours » / « Terminées », résumé, puis
/// livraisons groupées par jour. Chaque ligne : anneau d'avancée animé autour de l'icône
/// de l'étape, nom et lieu précis, étape en couleur, montant, référence, reçu.
class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({
    super.key,
    required this.onOpenOrder,
    this.onOpenOrderId,
    this.now,
    this.initialScope = 'active',
  });

  /// Liste montée au départ : `active` (en cours) ou `history` (terminées, avec leurs reçus).
  final String initialScope;

  final ValueChanged<OrderSummary> onOpenOrder;

  /// Ouvre une commande par son identifiant (colis d'un envoi parti après coup).
  final ValueChanged<String>? onOpenOrderId;

  /// Horloge (tests).
  final DateTime Function()? now;

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  static const _blobs = [
    BlobSpec(alignment: Alignment(1.2, -1.05), size: 280, colors: BlobSpec.brand, blur: 70),
    BlobSpec(alignment: Alignment(-1.3, 0.9), size: 240, colors: BlobSpec.warm, blur: 64, delay: Duration(seconds: 6)),
  ];

  late String _scope = widget.initialScope;
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Recherche sur le nom, le lieu et la référence, sans accents ni majuscules.
  static String _fold(String text) {
    const from = 'àâäéèêëîïôöùûüç';
    const to = 'aaaeeeeiioouuuc';
    final lower = text.toLowerCase();
    final out = StringBuffer();
    for (final rune in lower.runes) {
      final char = String.fromCharCode(rune);
      final i = from.indexOf(char);
      out.write(i < 0 ? char : to[i]);
    }
    return out.toString();
  }

  bool _matches(OrderSummary order) {
    final query = _fold(_search.text.trim());
    if (query.isEmpty) return true;
    return _fold(
      [order.recipientName, order.reference, order.dropoffLandmark, order.dropoffNeighborhood ?? ''].join(' '),
    ).contains(query);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final orders = ref.watch(ordersProvider(_scope));
    final active = ref.watch(ordersProvider('active')).value;
    final now = widget.now?.call() ?? DateTime.now();
    final activeCount = active?.length;
    return TaraScreen(
      blobs: _blobs,
      safeBottom: false,
      child: RefreshIndicator(
        onRefresh: () async {
          ref
            ..invalidate(ordersProvider(_scope))
            ..invalidate(pendingDeliveriesProvider);
          await ref.read(ordersProvider(_scope).future).catchError((_) => <OrderSummary>[]);
        },
        child: ListView(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 24 + TaraTabShell.bottomInset(context)),
          children: [
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(l.tabOrders, style: TaraText.titleAccess.copyWith(color: c.textPrimary, fontSize: 28)),
                  ),
                ),
                const _ParcelStack(),
              ],
            ),
            const SizedBox(height: 14),
            _SearchField(controller: _search, hint: l.ordersSearchHint, onChanged: () => setState(() {})),
            const SizedBox(height: 14),
            _GradientTabs(
              tabs: [
                ('active', activeCount == null ? l.inProgress : l.ordersActiveTab(activeCount)),
                ('history', l.finished),
              ],
              selected: _scope,
              onChanged: (scope) => setState(() => _scope = scope),
            ),
            if (orders.value case final list?) ...[
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Text(
                  _scope == 'active'
                      ? l.ordersSummaryActive(
                          list.length,
                          list.where((o) => o.status == 'DELIVERY_FAILED' && o.failureDecision == null).length,
                        )
                      : l.ordersSummaryHistory(list.length),
                  style: TaraText.small.copyWith(color: c.textSecondary, fontWeight: FontWeight.w700),
                ),
              ),
            ],
            const SizedBox(height: 6),
            // Envoi en masse : colis qui attendent l'adresse de leur client.
            if (_scope == 'active' && widget.onOpenOrderId != null) PendingSection(onOpenOrder: widget.onOpenOrderId!),
            switch (orders) {
              AsyncData(:final value) when value.where(_matches).isEmpty => Padding(
                padding: const EdgeInsets.only(top: 8),
                child: GlassCard(
                  radius: 22,
                  shadow: false,
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
                  child: Row(
                    children: [
                      TaraIcon(TaraIcons.package, size: 22, color: c.textTertiary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          value.isNotEmpty
                              ? l.ordersNoMatch
                              : (_scope == 'active' ? l.noOrdersInProgress : l.noOrdersFinished),
                          style: TaraText.label.copyWith(color: c.textSecondary, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              AsyncData(:final value) => _Groups(
                orders: value.where(_matches).toList(),
                now: now,
                onOpen: widget.onOpenOrder,
              ),
              AsyncError() => Row(
                children: [
                  Expanded(
                    child: Text(l.ordersError, style: TaraText.label.copyWith(color: c.textSecondary)),
                  ),
                  TaraLink(label: l.retry, onPressed: () => ref.invalidate(ordersProvider(_scope))),
                ],
              ),
              _ => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: GooLoader(compact: true)),
              ),
            },
          ],
        ),
      ),
    );
  }
}

/// Deux colis posés et un troisième qui flotte en tournant au-dessus (en-tête).
class _ParcelStack extends StatelessWidget {
  const _ParcelStack();

  @override
  Widget build(BuildContext context) {
    return const ExcludeSemantics(
      child: SizedBox(
        width: 64,
        height: 44,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(left: 0, bottom: -4, child: Parcel3D(size: 18, spin: false, floating: false)),
            Positioned(left: 27, bottom: -4, child: Parcel3D(size: 18, spin: false, floating: false)),
            Positioned(left: 13, bottom: 12, child: Parcel3D(size: 16, floating: false, period: Duration(seconds: 8))),
          ],
        ),
      ),
    );
  }
}

/// Champ de recherche plein (maquette) : loupe, saisie libre.
class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.hint, required this.onChanged});
  final TextEditingController controller;
  final String hint;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final c = TaraColors.of(context);
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: c.glassFallback,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          if (!c.isDark)
            const BoxShadow(color: Color.fromRGBO(140, 70, 10, .08), blurRadius: 24, offset: Offset(0, 10)),
        ],
      ),
      child: Row(
        children: [
          TaraIcon(TaraIcons.search, size: 20, color: c.textTertiary),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: (_) => onChanged(),
              textInputAction: TextInputAction.search,
              style: TaraText.text.copyWith(color: c.textPrimary),
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: hint,
                hintStyle: TaraText.text.copyWith(color: c.placeholder, fontWeight: FontWeight.w500),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Onglets de la maquette : pastille au dégradé de la marque qui glisse avec un rebond.
class _GradientTabs extends StatelessWidget {
  const _GradientTabs({required this.tabs, required this.selected, required this.onChanged});
  final List<(String, String)> tabs;
  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = TaraColors.of(context);
    final effects = TaraEffects.of(context);
    final index = tabs.indexWhere((tab) => tab.$1 == selected);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: c.textPrimary.withValues(alpha: .06), borderRadius: BorderRadius.circular(17)),
      child: LayoutBuilder(
        builder: (context, box) {
          final width = box.maxWidth / tabs.length;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: effects.decorativeMotion ? const Duration(milliseconds: 500) : Duration.zero,
                curve: const Cubic(.6, -.35, .3, 1.45),
                left: width * index,
                top: 0,
                bottom: 0,
                width: width,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: TaraBrand.gradient,
                    borderRadius: BorderRadius.circular(13),
                    boxShadow: const [
                      BoxShadow(color: Color.fromRGBO(255, 90, 0, .35), blurRadius: 16, offset: Offset(0, 6)),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  for (final (key, label) in tabs)
                    Expanded(
                      child: Semantics(
                        button: true,
                        selected: key == selected,
                        label: label,
                        excludeSemantics: true,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            if (key == selected) return;
                            HapticFeedback.selectionClick();
                            onChanged(key);
                          },
                          child: SizedBox(
                            height: 42,
                            child: Center(
                              child: AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 300),
                                style: TaraText.text.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: key == selected ? TaraBrand.onBrand : c.textSecondary,
                                ),
                                child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Livraisons groupées par jour (prévu pour une livraison programmée, sinon créée).
class _Groups extends StatelessWidget {
  const _Groups({required this.orders, required this.now, required this.onOpen});
  final List<OrderSummary> orders;
  final DateTime now;
  final ValueChanged<OrderSummary> onOpen;

  static DateTime _day(DateTime at) => DateTime(at.year, at.month, at.day);

  String _label(AppLocalizations l, DateTime day) {
    final today = _day(now);
    final diff = day.difference(today).inDays;
    return switch (diff) {
      0 => l.today,
      1 => l.ordersTomorrow,
      -1 => l.yesterday,
      _ => '${day.day.toString().padLeft(2, '0')}/${day.month.toString().padLeft(2, '0')}',
    }.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final groups = <DateTime, List<OrderSummary>>{};
    for (final order in orders) {
      final at = (order.scheduledFor ?? order.createdAt).toLocal();
      groups.putIfAbsent(_day(at), () => []).add(order);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final MapEntry(key: day, value: rows) in groups.entries) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
            child: Text(
              _label(l, day),
              style: TaraText.small.copyWith(color: c.textTertiary, fontWeight: FontWeight.w800, letterSpacing: .7),
            ),
          ),
          GlassCard(
            radius: 22,
            shadow: false,
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < rows.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: c.glassBorder),
                  _OrderLine(order: rows[i], now: now, onOpen: () => onOpen(rows[i])),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Une livraison (maquette) : anneau d'avancée, nom et lieu, étape, montant et référence,
/// accès au reçu.
class _OrderLine extends StatelessWidget {
  const _OrderLine({required this.order, required this.now, required this.onOpen});
  final OrderSummary order;
  final DateTime now;
  final VoidCallback onOpen;

  static double _progress(String status) => switch (status) {
    'CREATED' => .05,
    'SEARCHING_RIDER' => .12,
    'ASSIGNED' => .25,
    'PICKED_UP' => .55,
    'IN_DELIVERY' => .76,
    _ => 1,
  };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final (icon, tone, label) = OrderRow.orderStatus(l, order, now);
    final waiting = order.status == 'CANCELLED' || (order.status == 'CREATED' && tone == TintTone.accent);
    final (Color? ring, Color ink, Color status) = switch (tone) {
      // Vert : seulement une livraison faite ; en route, l'anneau reste orange.
      TintTone.success when order.status == 'DELIVERED' => (const Color(0xFF10A06E), c.success, c.success),
      TintTone.danger => (const Color(0xFFFF2D3D), c.dangerText, c.dangerText),
      _ when waiting => (c.textPrimary.withValues(alpha: .30), c.textTertiary, c.textSecondary),
      _ => (null, c.accentText, c.textSecondary),
    };
    final amount = order.codAmount > 0 ? order.codAmount : order.totalPrice;
    final name = [
      if (order.batchNumber case final number?) l.parcelNumberShort(number),
      order.recipientName,
    ].join(' · ');
    return MergeSemantics(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 2, 10),
          child: Row(
            children: [
              _ProgressRing(ratio: _progress(order.status), color: ring, icon: icon, ink: ink),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: name,
                            style: TaraText.text.copyWith(color: c.textPrimary, fontWeight: FontWeight.w800),
                          ),
                          TextSpan(
                            text: '  ${precisePlace(order.dropoffLandmark, order.dropoffNeighborhood)}',
                            style: TaraText.small.copyWith(color: c.textTertiary, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TaraText.small.copyWith(color: status, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${formatAmount(amount)} F',
                    style: TaraText.label.copyWith(
                      color: c.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontFeatures: TaraText.tabular,
                    ),
                  ),
                  Text(order.reference, style: TaraText.small.copyWith(color: c.textTertiary, fontSize: 11)),
                ],
              ),
              Semantics(
                button: true,
                label: l.ordersReceiptOf(order.reference),
                excludeSemantics: true,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onOpen,
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: Center(child: TaraIcon(TaraIcons.receipt, size: 22, strokeWidth: 1.8, color: c.accentText)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Anneau d'avancée autour de l'icône de l'étape, qui se remplit à l'affichage.
class _ProgressRing extends StatelessWidget {
  const _ProgressRing({required this.ratio, required this.color, required this.icon, required this.ink});
  final double ratio;

  /// Couleur de l'anneau ; absente : dégradé de la marque.
  final Color? color;
  final TaraIconData icon;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    final c = TaraColors.of(context);
    final effects = TaraEffects.of(context);
    return SizedBox(
      width: 42,
      height: 42,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: effects.decorativeMotion ? 0 : ratio, end: ratio),
        duration: const Duration(milliseconds: 1000),
        curve: const Cubic(.2, .8, .2, 1),
        builder: (context, value, child) => CustomPaint(
          painter: _RingPainter(value: value, color: color, track: c.textPrimary.withValues(alpha: .08)),
          child: child,
        ),
        child: Center(child: TaraIcon(icon, size: 18, color: ink)),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.value, required this.color, required this.track});
  final double value;
  final Color? color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCircle(center: size.center(Offset.zero), radius: 18);
    canvas.drawArc(
      rect,
      0,
      2 * math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = track,
    );
    if (value <= 0) return;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final tint = color;
    if (tint == null) {
      paint.shader = const SweepGradient(
        colors: [TaraBrand.amber, TaraBrand.orange, TaraBrand.red, TaraBrand.amber],
        transform: GradientRotation(-math.pi / 2),
      ).createShader(rect);
    } else {
      paint.color = tint;
    }
    canvas.drawArc(rect, -math.pi / 2, 2 * math.pi * value.clamp(0, 1), false, paint);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.value != value || old.color != color || old.track != track;
}
