import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tara_ui/components/buttons.dart';
import 'package:tara_ui/components/glass.dart';
import 'package:tara_ui/components/layout.dart';
import 'package:tara_ui/components/status.dart';
import 'package:tara_ui/components/swipe_button.dart';
import 'package:tara_ui/feedback/tara_feedback.dart';
import 'package:tara_ui/format.dart';
import 'package:tara_ui/motion/liquid_background.dart';
import 'package:tara_ui/tara_colors.dart';
import 'package:tara_ui/tara_icons.dart';
import 'package:tara_ui/tara_typography.dart';

import '../../app/providers.dart';
import '../../core/api/models.dart';
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
  int? _lastPulse;
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
    // Sonnerie de la nouvelle course (balafon), répétée jusqu'à la réponse ou l'expiration.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) TaraFeedback.play(context, TaraSound.offer, loop: true);
    });
    _ticker = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (!mounted) return;
      setState(() {});
      // Les 5 dernières secondes se sentent dans la main : une impulsion par seconde.
      final left = _remaining;
      if (left > 0 && left <= 5 && left != _lastPulse && !_busy) {
        _lastPulse = left;
        unawaited(HapticFeedback.mediumImpact());
      }
      if (_remaining == 0 && !_busy) {
        _ticker?.cancel();
        widget.onClosed(AppLocalizations.of(context).offerExpired);
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    TaraFeedback.stop(TaraSound.offer);
    super.dispose();
  }

  Future<void> _accept() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final order = await ref.read(riderApiProvider).acceptOffer(widget.offer.id);
      _ticker?.cancel();
      TaraFeedback.stop(TaraSound.offer);
      if (mounted) TaraFeedback.play(context, TaraSound.accepted);
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
    TaraFeedback.stop(TaraSound.offer);
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
    // Tout doit tenir sur un écran : 30 s pour décider, pas le temps de faire défiler.
    final height = MediaQuery.sizeOf(context).height;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final compact = height < 720 || textScale > 1.15;
    // Petit écran et texte agrandi : anneau et gain côte à côte, pour garder l'argent
    // à encaisser et le colis visibles au-dessus des boutons.
    final tight = height / textScale < 560;
    final package = switch (offer.packageSize) {
      'SMALL' => l.packageSmall,
      'LARGE' => l.packageLarge,
      _ => l.packageMedium,
    };
    final ring = CountdownRing(
      remaining: remaining,
      total: total,
      unitLabel: l.seconds,
      semanticLabel: l.secondsRemaining(remaining),
      size: tight ? 112 : (compact ? 136 : 200),
    );
    final earningLabel = Text(l.yourEarning, style: TaraText.label.copyWith(color: c.textSecondary));
    final earning = AmountText(offer.riderEarning, style: TaraText.amountXL.copyWith(fontSize: 40));
    return TaraScreen(
      safeBottom: false,
      blobs: _blobs,
      child: ScrollWithFooter(
        horizontal: 20,
        top: 12,
        content: [
          Center(
            child: InfoPill(label: '${l.newJob} · ${l.vehicleShort}', dot: TaraBrand.orange, blinkDot: true),
          ),
          SizedBox(height: compact ? 8 : 16),
          if (tight)
            Row(
              children: [
                ring,
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      earningLabel,
                      FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: earning),
                    ],
                  ),
                ),
              ],
            )
          else ...[
            Center(child: ring),
            const SizedBox(height: 16),
            Center(child: earningLabel),
            Center(child: earning),
          ],
          SizedBox(height: tight ? 12 : 16),
          GlassCard(
            radius: 24,
            padding: EdgeInsets.all(tight ? 14 : 16),
            child: _Trip(offer: offer, tight: tight),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              // L'argent à encaisser d'abord : c'est souvent ce qui décide.
              if (offer.cashToCollect > 0)
                InfoPill(
                  label: l.toCollect('${formatAmount(offer.cashToCollect)} F'),
                  icon: TaraIcons.cash,
                  tone: TintTone.accent,
                ),
              InfoPill(label: package, icon: TaraIcons.package),
              if (offer.isFragile) InfoPill(label: l.fragile, icon: TaraIcons.alertCircle),
              if (offer.isExpress) InfoPill(label: l.express, icon: TaraIcons.clock),
            ],
          ),
          if (_error != null) ...[const SizedBox(height: 12), ErrorLine(_error!)],
        ],
        // Accepter engage le livreur : on glisse la pastille plutôt que toucher, pour
        // éviter l'acceptation par mégarde. Refuser reste à portée de pouce.
        footer: Row(
          children: [
            GlassIconButton(
              icon: TaraIcons.close,
              label: l.decline,
              size: 58,
              radius: 20,
              onPressed: _busy ? null : _decline,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SwipeButton(
                label: l.accept,
                semanticLabel: l.slideToAccept,
                loading: _busy,
                onConfirmed: remaining == 0 ? null : _accept,
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
  const _Trip({required this.offer, this.tight = false});

  final Offer offer;

  /// Petit écran : liaison en tirets plus courte.
  final bool tight;

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
              size: Size(2, tight ? 14 : 26),
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
