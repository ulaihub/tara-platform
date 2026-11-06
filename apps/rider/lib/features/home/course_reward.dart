import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tara_ui/components/glass.dart';
import 'package:tara_ui/feedback/tara_feedback.dart';
import 'package:tara_ui/format.dart';
import 'package:tara_ui/motion/confetti.dart';
import 'package:tara_ui/tara_colors.dart';
import 'package:tara_ui/tara_effects.dart';
import 'package:tara_ui/tara_typography.dart';

import '../../l10n/app_localizations.dart';

/// Récompense d'une livraison : « +1 500 F » apparaît, s'envole vers les gains du jour
/// (en haut à droite) et la pièce tinte à l'arrivée. Aux paliers de courses du jour (5,
/// 10, puis chaque dizaine) : confettis de la marque et mot de félicitations.
class CourseReward extends StatefulWidget {
  const CourseReward({super.key, required this.earning, required this.deliveredToday, required this.onDone});

  final int earning;

  /// Courses livrées aujourd'hui, celle-ci comprise.
  final int deliveredToday;
  final VoidCallback onDone;

  static bool isMilestone(int delivered) => delivered == 5 || (delivered >= 10 && delivered % 10 == 0);

  @override
  State<CourseReward> createState() => _CourseRewardState();
}

class _CourseRewardState extends State<CourseReward> with SingleTickerProviderStateMixin {
  late final bool _milestone = CourseReward.isMilestone(widget.deliveredToday);
  late final AnimationController _time = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: _milestone ? 3600 : 1700),
  );
  bool _landed = false;

  /// Arrivée de la pièce sur les gains du jour, en millisecondes.
  static const _landAt = 1300;

  @override
  void initState() {
    super.initState();
    _time.addListener(_onTick);
    _time.addStatusListener((status) {
      if (status == AnimationStatus.completed) widget.onDone();
    });
    unawaited(_time.forward());
  }

  void _onTick() {
    if (_landed || _ms < _landAt) return;
    _landed = true;
    TaraFeedback.play(context, TaraSound.cash);
  }

  double get _ms => _time.value * _time.duration!.inMilliseconds;

  @override
  void dispose() {
    _time.dispose();
    super.dispose();
  }

  /// Avancement entre deux instants (ms), adouci.
  double _phase(double from, double to, [Curve curve = Curves.easeInOutCubic]) =>
      curve.transform(((_ms - from) / (to - from)).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final motion = TaraEffects.of(context).decorativeMotion;
    final amount = '+${formatAmount(widget.earning)} F';
    // Posée au-dessus des écrans : sans ce Material transparent, ses textes n'auraient pas
    // de style de base (soulignés en jaune par Flutter).
    return IgnorePointer(
      child: Material(
        type: MaterialType.transparency,
        child: Semantics(
          liveRegion: true,
          label: _milestone ? '$amount. ${l.milestoneTitle(widget.deliveredToday)}' : amount,
          child: Stack(
            children: [
              AnimatedBuilder(
                animation: _time,
                builder: (context, _) {
                  final appear = _phase(0, 380, Curves.easeOutBack);
                  final fly = motion ? _phase(650, _landAt.toDouble()) : 0.0;
                  final fade = motion ? 1 - _phase(_landAt - 150, _landAt + 120) : 1 - _phase(1200, 1600);
                  final alignment = Alignment.lerp(const Alignment(0, .1), const Alignment(.8, -.84), fly)!;
                  final scale = (motion ? .6 + .4 * appear : 1.0) * (1 - .45 * fly);
                  return Align(
                    alignment: alignment,
                    child: Opacity(
                      opacity: (appear * fade).clamp(0.0, 1.0),
                      child: Transform.scale(
                        scale: scale,
                        child: _Pill(amount: amount),
                      ),
                    ),
                  );
                },
              ),
              if (_milestone)
                AnimatedBuilder(
                  animation: _time,
                  builder: (context, _) {
                    final shown = _phase(900, 1250) * (1 - _phase(3200, 3600));
                    return Align(
                      alignment: const Alignment(0, -.25),
                      child: Opacity(
                        opacity: shown,
                        child: Transform.translate(
                          offset: Offset(0, 16 * (1 - shown)),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: GlassCard(
                              radius: 26,
                              padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    l.milestoneTitle(widget.deliveredToday),
                                    textAlign: TextAlign.center,
                                    style: TaraText.titlePanel.copyWith(color: c.textPrimary),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    l.milestoneBody,
                                    textAlign: TextAlign.center,
                                    style: TaraText.label.copyWith(color: c.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              // Les confettis tombent devant tout le reste.
              if (_milestone) const Positioned.fill(child: Confetti()),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pastille du gain : dégradé de la marque, montant en gras.
class _Pill extends StatelessWidget {
  const _Pill({required this.amount});

  final String amount;

  @override
  Widget build(BuildContext context) {
    final c = TaraColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
      decoration: BoxDecoration(
        gradient: TaraBrand.gradient,
        borderRadius: BorderRadius.circular(30),
        boxShadow: c.brandShadow,
      ),
      child: Text(amount, style: TaraText.amountL.copyWith(fontSize: 30, color: TaraBrand.onBrand)),
    );
  }
}
