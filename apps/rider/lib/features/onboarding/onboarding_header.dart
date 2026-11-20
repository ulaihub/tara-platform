import 'package:flutter/widgets.dart';

import 'package:tara_ui/components/progress.dart';

import '../../l10n/app_localizations.dart';
import '../course/course_page.dart';

/// En-tête des étapes d'inscription (maquette) : retour, « ÉTAPE 1 SUR 2 · PROFIL » en
/// orange, titre et précision, puis la barre d'avancement.
class OnboardingHeader extends StatelessWidget {
  const OnboardingHeader({
    super.key,
    required this.step,
    required this.total,
    required this.name,
    required this.progress,
    required this.title,
    required this.subtitle,
    this.onBack,
  });

  final int step;
  final int total;
  final String name;
  final double progress;
  final String title;
  final String subtitle;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final label = l.stepOf(step, total, name);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CourseHeader(kicker: label, title: title, subtitle: subtitle, onBack: onBack),
        const SizedBox(height: 14),
        LiquidProgressBar(value: progress, semanticLabel: label),
      ],
    );
  }
}
