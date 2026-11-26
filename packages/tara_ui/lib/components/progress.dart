import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../motion/effects.dart';
import '../tara_colors.dart';
import '../tara_icons.dart';
import '../tara_typography.dart';

/// Barre de progression dont le remplissage dégradé « coule » (A10).
class LiquidProgressBar extends StatelessWidget {
  const LiquidProgressBar({super.key, required this.value, this.semanticLabel});

  final double value;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = TaraColors.of(context);
    return Semantics(
      label: semanticLabel,
      value: '${(value * 100).round()} %',
      child: Container(
        height: 8,
        decoration: BoxDecoration(color: c.track, borderRadius: BorderRadius.circular(8)),
        child: Align(
          alignment: Alignment.centerLeft,
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: value.clamp(0, 1)),
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOut,
            builder: (context, v, _) => FractionallySizedBox(
              widthFactor: v,
              heightFactor: 1,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: const FlowingGradient(
                  period: Duration(milliseconds: 2600),
                  colors: [TaraBrand.amber, TaraBrand.orange, TaraBrand.red, TaraBrand.orange, TaraBrand.amber],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum StepState { done, active, upcoming }

/// États d'une étape lus par le lecteur d'écran, dans la langue de l'app.
@immutable
class StepStateLabels {
  const StepStateLabels({required this.done, required this.active, required this.upcoming});
  final String done;
  final String active;
  final String upcoming;
}

/// Étapes de la course : barre de 4 px et libellé ; faite, active ou à venir.
class CourseStepper extends StatelessWidget {
  const CourseStepper({super.key, required this.labels, required this.activeIndex, required this.stateLabels});

  final List<String> labels;
  final int activeIndex;
  final StepStateLabels stateLabels;

  @override
  Widget build(BuildContext context) {
    final c = TaraColors.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: Builder(
              builder: (context) {
                final state = i < activeIndex
                    ? StepState.done
                    : (i == activeIndex ? StepState.active : StepState.upcoming);
                return Semantics(
                  label: labels[i],
                  value: switch (state) {
                    StepState.done => stateLabels.done,
                    StepState.active => stateLabels.active,
                    StepState.upcoming => stateLabels.upcoming,
                  },
                  excludeSemantics: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 4,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          gradient: state == StepState.active ? TaraBrand.gradient : null,
                          color: switch (state) {
                            StepState.done => TaraBrand.orange.withValues(alpha: c.isDark ? .5 : .6),
                            StepState.active => null,
                            StepState.upcoming => c.track,
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      // « Enlèvement ✓ » : la coche est une icône, le glyphe manque aux polices.
                      // Une seule ligne : avec le texte agrandi, le libellé rétrécit au lieu
                      // d'être coupé au milieu d'un mot.
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerStart,
                        child: Text.rich(
                          maxLines: 1,
                          softWrap: false,
                          TextSpan(
                            text: labels[i],
                            children: [
                              if (state == StepState.done)
                                WidgetSpan(
                                  alignment: PlaceholderAlignment.middle,
                                  child: Padding(
                                    padding: const EdgeInsetsDirectional.only(start: 4),
                                    child: TaraIcon(
                                      TaraIcons.check,
                                      size: 12,
                                      strokeWidth: 2.6,
                                      color: c.textSecondary,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          style: TaraText.smallStrong.copyWith(
                            color: state == StepState.active
                                ? c.accentText
                                : (state == StepState.done ? c.textSecondary : c.textTertiary),
                            fontWeight: state == StepState.active ? FontWeight.w700 : FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}

/// Sélecteur à deux ou trois segments dont le curseur dégradé glisse avec un rebond
/// élastique (A9) : léger recul puis dépassement, 500 ms.
class LiquidSegmented<T> extends StatelessWidget {
  const LiquidSegmented({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
    this.compact = false,
  });

  final List<(T, String)> segments;
  final T selected;
  final ValueChanged<T> onChanged;

  /// Variante compacte h 34 (Jour / Semaine / Mois).
  final bool compact;

  static const _elastic = Cubic(0.6, -0.35, 0.3, 1.45);

  @override
  Widget build(BuildContext context) {
    final c = TaraColors.of(context);
    final index = segments.indexWhere((s) => s.$1 == selected);
    // Maquettes : rail encre 7 %, bord encre 10 %, marge 4, coins 17, segments de 50.
    // Finesse : rail en pilule, curseur en pilule.
    final height = compact ? 34.0 : 46.0;
    final radius = height / 2;
    final pad = compact ? 3.0 : 4.0;
    return Container(
      constraints: BoxConstraints(minHeight: height),
      padding: EdgeInsets.all(pad),
      decoration: BoxDecoration(
        color: c.textPrimary.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: c.textPrimary.withValues(alpha: .10)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth / segments.length;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 500),
                curve: _elastic,
                left: width * index,
                top: 0,
                bottom: 0,
                width: width,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: TaraBrand.gradient,
                    borderRadius: BorderRadius.circular(radius - pad),
                    boxShadow: compact
                        ? null
                        : const [
                            BoxShadow(color: Color.fromRGBO(255, 90, 0, .35), blurRadius: 16, offset: Offset(0, 6)),
                          ],
                  ),
                ),
              ),
              Row(
                children: [
                  for (final (value, label) in segments)
                    Expanded(
                      child: Semantics(
                        inMutuallyExclusiveGroup: true,
                        checked: value == selected,
                        button: true,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            HapticFeedback.selectionClick();
                            onChanged(value);
                          },
                          child: ConstrainedBox(
                            constraints: BoxConstraints(minHeight: height - 2 * pad < 28 ? 28 : height - 2 * pad),
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                child: AnimatedDefaultTextStyle(
                                  duration: const Duration(milliseconds: 300),
                                  style: (compact ? TaraText.smallStrong : TaraText.text).copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: value == selected ? TaraBrand.onBrand : c.textPrimary.withValues(alpha: .78),
                                  ),
                                  child: Text(label, textAlign: TextAlign.center),
                                ),
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
