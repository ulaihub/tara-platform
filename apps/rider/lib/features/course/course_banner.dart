import 'package:flutter/widgets.dart';

import 'package:tara_ui/components/buttons.dart';
import 'package:tara_ui/components/glass.dart';
import 'package:tara_ui/components/layout.dart';
import 'package:tara_ui/tara_colors.dart';
import 'package:tara_ui/tara_icons.dart';
import 'package:tara_ui/tara_typography.dart';

import '../../l10n/app_localizations.dart';

/// Course en cours, réduite à l'accueil : la référence et « Reprendre ».
class CourseBanner extends StatelessWidget {
  const CourseBanner({super.key, required this.reference, required this.stepLabel, required this.onResume});

  final String reference;
  final String stepLabel;
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    return GlassCard(
      radius: 24,
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      child: Row(
        children: [
          const IconTile(icon: TaraIcons.package, size: 46, radius: 15),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.courseInProgress(reference), style: TaraText.cardTitle.copyWith(color: c.textPrimary)),
                const SizedBox(height: 2),
                Text(stepLabel, style: TaraText.small.copyWith(color: c.textTertiary)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 120,
            child: PrimaryButton(label: l.courseResume, height: 48, onPressed: onResume),
          ),
        ],
      ),
    );
  }
}
