import 'package:flutter/widgets.dart';
import 'package:tara_ui/components/glass.dart';
import 'package:tara_ui/tara_colors.dart';
import 'package:tara_ui/tara_icons.dart';
import 'package:tara_ui/tara_typography.dart';

import '../../l10n/app_localizations.dart';

/// Objets que Tara ne transporte pas, rappelés dans l'étape « Colis » de la nouvelle
/// livraison (liste validée par le porteur du projet).
List<String> prohibitedItems(AppLocalizations l) => [
  l.prohibitedWeapons,
  l.prohibitedIllegal,
  l.prohibitedDangerous,
  l.prohibitedAnimals,
  l.prohibitedCash,
];

/// Rappel discret des objets interdits : titre, liste, engagement de l'expéditeur.
class ProhibitedItemsNote extends StatelessWidget {
  const ProhibitedItemsNote({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    return TintBox(
      tone: TintTone.danger,
      child: MergeSemantics(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: TaraIcon(TaraIcons.alertCircle, size: 18, color: c.dangerText),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.prohibitedTitle,
                    style: TaraText.label.copyWith(color: c.textPrimary, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  for (final item in prohibitedItems(l))
                    Text('• $item', style: TaraText.small.copyWith(color: c.textSecondary, height: 1.45)),
                  const SizedBox(height: 6),
                  Text(l.prohibitedPledge, style: TaraText.small.copyWith(color: c.textTertiary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
