import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tara_ui/components/buttons.dart';
import 'package:tara_ui/components/layout.dart';
import 'package:tara_ui/components/progress.dart';
import 'package:tara_ui/components/star_rating.dart';
import 'package:tara_ui/components/three_d.dart';
import 'package:tara_ui/feedback/tara_feedback.dart';
import 'package:tara_ui/format.dart';
import 'package:tara_ui/motion/confetti.dart';
import 'package:tara_ui/motion/liquid_background.dart';
import 'package:tara_ui/motion/motion_clock.dart';
import 'package:tara_ui/tara_colors.dart';
import 'package:tara_ui/tara_typography.dart';

import '../../l10n/app_localizations.dart';
import 'home_summary.dart';
import 'home_widgets.dart';

/// Course livrée (maquette Livreur-Gain) : colis 3D qui flotte avec le gain, rang de la
/// course dans la journée, gain en grand, objectif de la prochaine célébration (5 puis
/// toutes les 10 courses), note à l'expéditeur d'un geste, puis « Continuer ».
class CourseDoneScreen extends ConsumerStatefulWidget {
  const CourseDoneScreen({
    super.key,
    required this.reference,
    required this.deliveredAt,
    required this.earning,
    required this.deliveredToday,
    required this.senderName,
    required this.onRate,
    required this.onDone,
  });

  final String reference;
  final DateTime deliveredAt;
  final int earning;

  /// Courses livrées aujourd'hui, celle-ci comprise.
  final int deliveredToday;
  final String senderName;

  /// Envoi de la note (1 à 5) ; un échec réseau n'est pas montré, la note est facultative.
  final ValueChanged<int> onRate;
  final VoidCallback onDone;

  /// Célébration : la 5e course, puis chaque dizaine.
  static bool isMilestone(int delivered) => delivered == 5 || (delivered >= 10 && delivered % 10 == 0);

  /// Prochaine célébration : 5 courses, puis toutes les 10.
  static int nextMilestone(int delivered) => delivered < 5 ? 5 : ((delivered ~/ 10) + 1) * 10;

  @override
  ConsumerState<CourseDoneScreen> createState() => _CourseDoneScreenState();
}

class _CourseDoneScreenState extends ConsumerState<CourseDoneScreen> {
  int _stars = 0;
  late final bool _milestone = CourseDoneScreen.isMilestone(widget.deliveredToday);

  static const _blobs = [
    BlobSpec(alignment: Alignment(0, -.55), size: 340, colors: BlobSpec.warm, blur: 60, opacity: .7),
  ];

  @override
  void initState() {
    super.initState();
    // La pièce tombe sur les gains du jour.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) TaraFeedback.play(context, TaraSound.cash);
    });
  }

  void _rate(int stars) {
    setState(() => _stars = stars);
    widget.onRate(stars);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final summary = ref.watch(homeSummaryProvider).value;
    final first = (summary?.fullName ?? '').trim().split(RegExp(r'\s+')).first;
    final n = widget.deliveredToday;
    final goal = _milestone ? n : CourseDoneScreen.nextMilestone(n);
    final amount = '${formatAmount(widget.earning)} F';
    final at = widget.deliveredAt;
    final time = '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';
    final ok = c.isDark ? const Color(0xFF4ADE9B) : const Color(0xFF0E7F57);
    final muted = c.textPrimary.withValues(alpha: .72);
    Widget card(Widget child) => Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: c.textPrimary.withValues(alpha: .06),
        border: Border.all(color: c.textPrimary.withValues(alpha: .10)),
      ),
      child: child,
    );
    return Stack(
      children: [
        TaraScreen(
          blobs: _blobs,
          child: ScrollWithFooter(
            horizontal: 20,
            top: 18,
            content: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: c.textPrimary.withValues(alpha: .08),
                    ),
                    child: Text(
                      l.deliveredAtLabel(widget.reference, time),
                      style: TaraText.small.copyWith(fontSize: 12, fontWeight: FontWeight.w800, color: c.textPrimary),
                    ),
                  ),
                  if (summary != null)
                    StatusPill(online: true, label: l.todayEarningsPill('${formatAmount(summary.earnings)}\u00a0F')),
                ],
              ),
              const SizedBox(height: 10),
              // Colis qui flotte, le gain s'élève au-dessus.
              SizedBox(
                height: 210,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Parcel3D(size: 110),
                    Positioned(
                      top: 14,
                      child: MotionBuilder(
                        period: const Duration(seconds: 3),
                        stillPhase: .5,
                        builder: (context, t, child) =>
                            Transform.translate(offset: Offset(0, -10 * (1 - (t * 2 - 1).abs())), child: child),
                        child: Text(
                          '+$amount',
                          style: TextStyle(
                            fontFamily: TaraText.sora,
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: ok,
                            shadows: const [Shadow(color: Color.fromRGBO(0, 0, 0, .45), blurRadius: 10)],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _caps(first.isEmpty ? l.rideOfDay(n) : l.rideOfDayBravo(n, first)),
                textAlign: TextAlign.center,
                style: TaraText.small.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.3,
                  color: c.accentText,
                ),
              ),
              const SizedBox(height: 4),
              Center(
                child: ShaderMask(
                  shaderCallback: TaraBrand.gradient.createShader,
                  child: Text(
                    amount,
                    style: const TextStyle(
                      fontFamily: TaraText.sora,
                      fontSize: 48,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1,
                      height: 1.1,
                      color: Color(0xFFFFFFFF),
                      fontFeatures: TaraText.tabular,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                l.addedToEarnings,
                textAlign: TextAlign.center,
                style: TaraText.text.copyWith(fontSize: 13, color: muted),
              ),
              const SizedBox(height: 18),
              card(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            l.dailyGoal(goal),
                            style: TaraText.bodyStrong.copyWith(fontSize: 14, color: c.textPrimary),
                          ),
                        ),
                        Text(
                          '$n / $goal',
                          style: TaraText.label.copyWith(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: c.textPrimary,
                            fontFeatures: TaraText.tabular,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    LiquidProgressBar(value: goal == 0 ? 0 : n / goal, semanticLabel: '$n / $goal'),
                    const SizedBox(height: 8),
                    Text(
                      _milestone ? l.milestoneTitle(n) : l.ridesToNextCelebration(goal - n),
                      style: TaraText.small.copyWith(fontSize: 12, color: muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              card(
                Row(
                  children: [
                    Expanded(
                      child: Semantics(
                        liveRegion: true,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _stars > 0 ? l.rateSenderThanks : l.rateSenderTitle(widget.senderName),
                              style: TaraText.bodyStrong.copyWith(fontSize: 14, color: c.textPrimary),
                            ),
                            if (_stars == 0)
                              Text(l.rateSenderBody, style: TaraText.small.copyWith(fontSize: 12, color: muted)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    StarRating(value: _stars, onChanged: _stars > 0 ? null : _rate, labelOf: l.starsLabel, size: 24),
                  ],
                ),
              ),
            ],
            footer: PrimaryButton(label: l.continueOnline, height: 56, strong: true, onPressed: widget.onDone),
          ),
        ),
        if (_milestone) const Positioned.fill(child: IgnorePointer(child: Confetti())),
      ],
    );
  }
}

/// Petites capitales de la maquette, sans toucher au rang (« 5e », « 1re »).
String _caps(String text) {
  final space = text.indexOf(' ');
  return space < 0 ? text.toUpperCase() : text.substring(0, space) + text.substring(space).toUpperCase();
}
