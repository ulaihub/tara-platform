import 'package:flutter/widgets.dart';

import '../../design/components/buttons.dart';
import '../../design/components/progress.dart';
import '../../design/tara_colors.dart';
import '../../design/tara_icons.dart';
import '../../design/tara_typography.dart';
import '../../l10n/app_localizations.dart';

/// En-tête des étapes d'inscription : retour, « Étape 1 sur 2 · Profil », avancement.
class OnboardingHeader extends StatelessWidget {
  const OnboardingHeader({
    super.key,
    required this.step,
    required this.total,
    required this.name,
    required this.progress,
    required this.trailing,
    this.onBack,
  });

  final int step;
  final int total;
  final String name;
  final double progress;
  final String trailing;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final c = TaraColors.of(context);
    final l = AppLocalizations.of(context);
    final label = l.stepOf(step, total, name);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            if (onBack != null) ...[
              GlassIconButton(icon: TaraIcons.chevronLeft, label: l.back, onPressed: onBack, size: 44),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(label, style: TaraText.label.copyWith(color: c.textSecondary)),
            ),
            Text(
              trailing,
              style: TaraText.label.copyWith(color: c.accentText, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 12),
        LiquidProgressBar(value: progress, semanticLabel: label),
      ],
    );
  }
}
