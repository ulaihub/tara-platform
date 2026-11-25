import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tara_ui/components/swipe_button.dart';
import 'package:tara_ui/feedback/tara_feedback.dart';
import 'package:tara_ui/format.dart';
import 'package:tara_ui/motion/liquid_wave.dart';
import 'package:tara_ui/tara_colors.dart';
import 'package:tara_ui/tara_effects.dart';
import 'package:tara_ui/tara_icons.dart';
import 'package:tara_ui/tara_typography.dart';

import '../../app/providers.dart';
import '../../core/api/models.dart';
import '../../l10n/app_localizations.dart';
import '../common/error_text.dart';
import '../map/tara_map.dart';

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
    final height = MediaQuery.sizeOf(context).height;
    final online = ref.watch(onlineControllerProvider);
    final pickupStop = offer.pickupLatitude == null || offer.pickupLongitude == null
        ? null
        : MapStop(
            latitude: offer.pickupLatitude!,
            longitude: offer.pickupLongitude!,
            label: l.pinPickup(offer.pickupName),
          );
    final dropoffStop = offer.isTour || offer.dropoffLatitude == null || offer.dropoffLongitude == null
        ? null
        : MapStop(
            latitude: offer.dropoffLatitude!,
            longitude: offer.dropoffLongitude!,
            dropoff: true,
            label: l.pinDropoff(offer.dropoffNeighborhood ?? offer.dropoffCity),
          );
    return Material(
      color: c.bg,
      child: Stack(
        children: [
          // Vraie carte : le livreur en direct, le vendeur exact et la zone de livraison (à
          // environ 1 km près : le point exact n'est donné qu'après l'acceptation).
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: height * .5,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ListenableBuilder(
                  listenable: online,
                  builder: (context, _) => TaraMap(
                    rider: online.lastPosition,
                    stop: pickupStop,
                    alsoStop: dropoffStop,
                    zoom: 14,
                    framePadding: EdgeInsets.fromLTRB(48, 90 + MediaQuery.paddingOf(context).top, 48, 70),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: IgnorePointer(
                    child: SizedBox(
                      height: 60,
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
                ),
              ],
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 20, 20, 0),
                child: _OfferTimer(remaining: remaining, total: total),
              ),
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 16 + MediaQuery.paddingOf(context).bottom,
            child: ConstrainedBox(
              // Tout tient sans défiler sur un grand écran ; sinon le panneau défile.
              constraints: BoxConstraints(maxHeight: height * .74),
              child: _Rise(
                child: _OfferSheet(
                  offer: offer,
                  busy: _busy,
                  error: _error,
                  expired: remaining == 0,
                  onAccept: _accept,
                  onDecline: _decline,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Le panneau monte à l'affichage (0,5 s), comme dans la maquette.
class _Rise extends StatelessWidget {
  const _Rise({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!TaraEffects.of(context).decorativeMotion) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOut,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, 14 * (1 - t)), child: child),
      ),
      child: child,
    );
  }
}

/// Chrono en haut à droite : rond où le liquide baisse avec le temps restant, horloge
/// au centre, « 18 s pour accepter » dessous.
class _OfferTimer extends StatelessWidget {
  const _OfferTimer({required this.remaining, required this.total});
  final int remaining;
  final int total;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final ratio = total == 0 ? 0.0 : (remaining / total).clamp(0.0, 1.0);
    return Semantics(
      liveRegion: true,
      label: l.secondsRemaining(remaining),
      excludeSemantics: true,
      child: SizedBox(
        width: 84,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: c.bg.withValues(alpha: .6),
                boxShadow: const [BoxShadow(color: Color.fromRGBO(255, 90, 0, .35), blurRadius: 18)],
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipOval(
                    child: LiquidFill(
                      level: ratio,
                      amplitude: 4,
                      front: TaraLiquid.front,
                      back: TaraLiquid.back(dark: c.isDark),
                      frontPeriod: TaraLiquid.frontPeriod,
                      backPeriod: TaraLiquid.backPeriod,
                    ),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color.fromRGBO(255, 177, 92, .5), width: 2),
                    ),
                  ),
                  Center(child: TaraIcon(TaraIcons.clock, size: 24, strokeWidth: 2.2, color: c.textPrimary)),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l.secondsToAccept(remaining),
              textAlign: TextAlign.center,
              style: TaraText.small.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: c.textPrimary.withValues(alpha: .86),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Panneau du bas : gain, distance, arrêts, étiquettes, glisser pour accepter, refuser.
class _OfferSheet extends StatelessWidget {
  const _OfferSheet({
    required this.offer,
    required this.busy,
    required this.error,
    required this.expired,
    required this.onAccept,
    required this.onDecline,
  });

  final Offer offer;
  final bool busy;
  final String? error;
  final bool expired;
  final Future<void> Function() onAccept;
  final Future<void> Function() onDecline;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final muted = c.textPrimary.withValues(alpha: .68);
    final accent2 = c.isDark ? const Color(0xFFFFC283) : const Color(0xFF9A3412);
    final approach = offer.approachMeters == null ? null : formatDistance(offer.approachMeters!);
    String amount(int value) => '${formatAmount(value)} F';
    final package = switch (offer.packageSize) {
      'S' => l.packageSmall,
      'L' || 'XL' => l.packageLarge,
      'BULKY' => l.packageBulky,
      _ => l.packageMedium,
    };
    // Primes payées par Tara, comprises dans le gain : annoncées pour décider en connaissance.
    final bonuses = [
      if (offer.approachBonus > 0) l.approachBonus(amount(offer.approachBonus)),
      if (offer.boostBonus > 0) l.boostBonus(amount(offer.boostBonus)),
    ];
    final stops = <(String, String, String?, bool)>[
      (
        'A',
        l.stopPickup(offer.pickupName),
        [?offer.pickupNeighborhood, if (approach != null) l.approachFromYou(approach)].join(' · '),
        true,
      ),
      if (offer.isTour)
        for (final (index, parcel) in offer.tourParcels.indexed)
          (
            '${index + 1}',
            [
              if (parcel.batchNumber != null) l.parcelNumberShort(parcel.batchNumber!),
              parcel.neighborhood ?? offer.dropoffCity,
            ].join(' · '),
            parcel.codAmount > 0 ? l.toCollectLower(amount(parcel.codAmount)) : l.alreadyPaid,
            false,
          )
      else
        (
          'B',
          l.stopDropoff(offer.dropoffNeighborhood ?? offer.dropoffCity),
          [offer.dropoffCity, formatDistance(offer.distanceMeters)].join(' · '),
          false,
        ),
    ];
    Widget chip(String label, {bool accent = false, TaraIconData? icon}) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: accent ? const Color.fromRGBO(255, 177, 92, .14) : c.textPrimary.withValues(alpha: .08),
        border: Border.all(
          color: accent ? const Color.fromRGBO(255, 177, 92, .35) : c.textPrimary.withValues(alpha: .12),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            TaraIcon(icon, size: 14, strokeWidth: 2, color: accent ? accent2 : c.textPrimary),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              label,
              style: TaraText.small.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: accent ? accent2 : c.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: c.isDark ? const Color(0xFF16161E) : const Color(0xFFFFFFFF),
        border: Border.all(color: c.textPrimary.withValues(alpha: .10)),
        boxShadow: const [BoxShadow(color: Color.fromRGBO(0, 0, 0, .4), blurRadius: 40, offset: Offset(0, -20))],
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (offer.isTour ? l.newTour(offer.tourParcels.length) : l.newJob).toUpperCase(),
                        style: TaraText.small.copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: c.accentText,
                        ),
                      ),
                      const SizedBox(height: 4),
                      ShaderMask(
                        shaderCallback: TaraBrand.gradient.createShader,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            amount(offer.riderEarning),
                            semanticsLabel: '${l.yourEarning} : ${amount(offer.riderEarning)}',
                            style: const TextStyle(
                              fontFamily: TaraText.sora,
                              fontSize: 38,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -.76,
                              height: 1,
                              color: Color(0xFFFFFFFF),
                              fontFeatures: TaraText.tabular,
                            ),
                          ),
                        ),
                      ),
                      if (bonuses.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          l.bonusIncluded(bonuses.join(' · ')),
                          key: const ValueKey('offer-bonus'),
                          style: TaraText.small.copyWith(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: c.textPrimary.withValues(alpha: .72),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: c.textPrimary.withValues(alpha: .08),
                  ),
                  child: Text(
                    offer.isTour
                        ? l.tourSummary(formatDistance(offer.distanceMeters), offer.tourParcels.length)
                        : l.tripSummary(formatDistance(offer.distanceMeters), offer.estimatedMinutes),
                    style: TaraText.small.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: c.textPrimary.withValues(alpha: .86),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            for (final (index, (mark, title, sub, first)) in stops.indexed)
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: 26,
                      child: Column(
                        children: [
                          Container(
                            width: 26,
                            height: 26,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(9),
                              color: first ? const Color(0xFFFFFFFF) : null,
                              gradient: first ? null : TaraBrand.gradient,
                              border: first ? Border.all(color: c.textPrimary.withValues(alpha: .12)) : null,
                            ),
                            child: Text(
                              mark,
                              style: TaraText.small.copyWith(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: first ? const Color(0xFF16120E) : const Color(0xFF140800),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Container(
                              width: 2,
                              color: index == stops.length - 1
                                  ? Colors.transparent
                                  : c.textPrimary.withValues(alpha: .16),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 10, top: 2),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title, style: TaraText.bodyStrong.copyWith(fontSize: 14, color: c.textPrimary)),
                            if (sub != null && sub.isNotEmpty)
                              Text(sub, style: TaraText.small.copyWith(fontSize: 12, color: muted)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                chip(
                  offer.isTour ? l.tourOnePickup(offer.tourParcels.length) : package,
                  icon: offer.bulky ? TaraIcons.package : null,
                ),
                // L'argent à encaisser : c'est souvent ce qui décide.
                if (offer.cashToCollect > 0) chip(l.toCollectChip(amount(offer.cashToCollect)), accent: true),
                // Aide au chargement payée par l'expéditeur : à savoir avant d'accepter.
                if (offer.loadingHelp) chip(l.comeWithHelper, accent: true, icon: TaraIcons.user),
                if (offer.isFragile) chip(l.fragile, icon: TaraIcons.alertCircle),
                if (offer.isExpress) chip(l.express, icon: TaraIcons.clock),
              ],
            ),
            if (error != null) ...[const SizedBox(height: 12), ErrorLine(error!)],
            const SizedBox(height: 14),
            // Accepter engage le livreur : on glisse la pastille plutôt que toucher.
            SwipeButton(
              plain: true,
              height: 62,
              label: l.slideToAccept,
              semanticLabel: l.slideToAccept,
              loading: busy,
              onConfirmed: expired ? null : () => unawaited(onAccept()),
            ),
            const SizedBox(height: 4),
            Semantics(
              button: true,
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: busy ? null : () => unawaited(onDecline()),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 44),
                  alignment: Alignment.center,
                  child: Text(
                    l.decline,
                    style: TaraText.bodyStrong.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: c.textPrimary.withValues(alpha: .72),
                    ),
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
