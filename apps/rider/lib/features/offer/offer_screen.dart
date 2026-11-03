import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/api/models.dart';
import '../../design/components/buttons.dart';
import '../../design/components/glass.dart';
import '../../design/components/layout.dart';
import '../../design/components/status.dart';
import '../../design/format.dart';
import '../../design/motion/liquid_background.dart';
import '../../design/tara_colors.dart';
import '../../design/tara_icons.dart';
import '../../design/tara_typography.dart';
import '../../l10n/app_localizations.dart';
import '../common/error_text.dart';

/// 07 · Proposition de course (30 s) : plein écran, par-dessus tout. Le compte à rebours
/// vient de l'heure d'expiration fixée par le serveur.
class OfferScreen extends ConsumerStatefulWidget {
  const OfferScreen({super.key, required this.offer, required this.onAccepted, required this.onClosed, this.now});

  final Offer offer;

  /// Course acceptée : réponse de l'API (course attribuée).
  final void Function(Json order) onAccepted;

  /// Refusée, expirée ou prise par un autre livreur (message à afficher, ou null).
  final void Function(String? message) onClosed;

  /// Horloge (tests).
  final DateTime Function()? now;

  @override
  ConsumerState<OfferScreen> createState() => _OfferScreenState();
}

class _OfferScreenState extends ConsumerState<OfferScreen> {
  Timer? _ticker;
  bool _busy = false;
  String? _error;

  static const _blobs = [
    BlobSpec(alignment: Alignment(1.25, -1.0), size: 320, colors: BlobSpec.brand, blur: 70),
    BlobSpec(alignment: Alignment(-1.3, 0.2), size: 260, colors: BlobSpec.warm, blur: 70, delay: Duration(seconds: 4)),
  ];

  DateTime get _now => widget.now?.call() ?? DateTime.now();
  int get _remaining {
    final left = widget.offer.expiresAt.difference(_now).inMilliseconds;
    return left <= 0 ? 0 : (left / 1000).ceil();
  }

  @override
  void initState() {
    super.initState();
    HapticFeedback.heavyImpact();
    _ticker = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (!mounted) return;
      setState(() {});
      if (_remaining == 0 && !_busy) {
        _ticker?.cancel();
        widget.onClosed(AppLocalizations.of(context).offerExpired);
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _accept() async {
    setState(() => _busy = true);
    try {
      final order = await ref.read(riderApiProvider).acceptOffer(widget.offer.id);
      _ticker?.cancel();
      unawaited(HapticFeedback.mediumImpact());
      widget.onAccepted(order);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = errorMessage(context, error);
      });
    }
  }

  Future<void> _decline() async {
    setState(() => _busy = true);
    _ticker?.cancel();
    try {
      await ref.read(riderApiProvider).declineOffer(widget.offer.id);
    } catch (_) {
      // Refus perdu (réseau) : la proposition expirera d'elle-même côté serveur.
    }
    widget.onClosed(null);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final offer = widget.offer;
    final total = ref.watch(riderConfigProvider).value?.offerTimeoutSeconds ?? 30;
    final remaining = _remaining;
    final package = switch (offer.packageSize) {
      'SMALL' => l.packageSmall,
      'LARGE' => l.packageLarge,
      _ => l.packageMedium,
    };
    return TaraScreen(
      blobs: _blobs,
      child: ScrollWithFooter(
        horizontal: 20,
        top: 12,
        content: [
          Center(
            child: InfoPill(label: '${l.newJob} · ${l.vehicleShort}', dot: TaraBrand.orange, blinkDot: true),
          ),
          const SizedBox(height: 16),
          Center(
            child: CountdownRing(
              remaining: remaining,
              total: total,
              unitLabel: l.seconds,
              semanticLabel: l.secondsRemaining(remaining),
              size: 200,
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(l.yourEarning, style: TaraText.label.copyWith(color: c.textSecondary)),
          ),
          Center(child: AmountText(offer.riderEarning, style: TaraText.amountXL.copyWith(fontSize: 40))),
          const SizedBox(height: 16),
          GlassCard(
            radius: 24,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: _Trip(offer: offer),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              InfoPill(label: package, icon: TaraIcons.package),
              if (offer.isFragile) InfoPill(label: l.fragile, icon: TaraIcons.alertCircle),
              if (offer.isExpress) InfoPill(label: l.express, icon: TaraIcons.clock),
              if (offer.cashToCollect > 0)
                InfoPill(
                  label: l.toCollect('${formatAmount(offer.cashToCollect)} F'),
                  icon: TaraIcons.cash,
                  tone: TintTone.accent,
                ),
            ],
          ),
          if (_error != null) ...[const SizedBox(height: 12), ErrorLine(_error!)],
        ],
        footer: Row(
          children: [
            Expanded(
              child: GlassButton(label: l.decline, height: 58, radius: 20, onPressed: _busy ? null : _decline),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: PrimaryButton(
                label: l.accept,
                icon: TaraIcons.check,
                strong: true,
                loading: _busy,
                onPressed: remaining == 0 ? null : _accept,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Trajet : point dégradé (enlèvement) → tirets → anneau (livraison).
class _Trip extends StatelessWidget {
  const _Trip({required this.offer});

  final Offer offer;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final approach = offer.approachMeters == null ? '—' : formatDistance(offer.approachMeters!);
    Widget stop({required Widget marker, required String overline, required String title, String? subtitle}) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 22, child: Center(child: marker)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(overline, style: TaraText.overline.copyWith(color: c.accentText)),
              const SizedBox(height: 3),
              Text(title, style: TaraText.cardTitle.copyWith(color: c.textPrimary, fontSize: 16)),
              if (subtitle != null) Text(subtitle, style: TaraText.label.copyWith(color: c.textTertiary)),
            ],
          ),
        ),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        stop(
          marker: Container(
            width: 16,
            height: 16,
            decoration: const BoxDecoration(gradient: TaraBrand.gradient, shape: BoxShape.circle),
          ),
          overline: l.pickupLabel(approach),
          title: offer.pickupName,
          subtitle: offer.pickupNeighborhood,
        ),
        Padding(
          padding: const EdgeInsets.only(left: 10, top: 4, bottom: 4),
          child: Align(
            alignment: Alignment.centerLeft,
            child: CustomPaint(
              size: const Size(2, 26),
              painter: _Dashes(color: c.textTertiary),
            ),
          ),
        ),
        stop(
          marker: Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: TaraBrand.orange, width: 3),
            ),
          ),
          overline: l.dropoffLabel(formatDistance(offer.distanceMeters), offer.estimatedMinutes),
          title: offer.dropoffNeighborhood ?? offer.dropoffCity,
        ),
      ],
    );
  }
}

class _Dashes extends CustomPainter {
  _Dashes({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (var y = 0.0; y < size.height; y += 7) {
      canvas.drawLine(Offset(1, y), Offset(1, y + 3), paint);
    }
  }

  @override
  bool shouldRepaint(_Dashes old) => old.color != color;
}
