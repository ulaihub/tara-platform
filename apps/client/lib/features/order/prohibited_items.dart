import 'package:flutter/widgets.dart';
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

/// Clé du rappel des objets interdits (tests).
const prohibitedItemsKey = ValueKey('prohibited-items');

/// Rappel des objets interdits (maquette) : bandeau rouge pâle replié ; un toucher déplie
/// la liste et l'engagement de l'expéditeur.
class ProhibitedItemsNote extends StatefulWidget {
  const ProhibitedItemsNote({super.key, this.initiallyOpen = false});

  /// Ouvert d'emblée (tests, captures).
  final bool initiallyOpen;

  @override
  State<ProhibitedItemsNote> createState() => _ProhibitedItemsNoteState();
}

class _ProhibitedItemsNoteState extends State<ProhibitedItemsNote> {
  late bool _open = widget.initiallyOpen;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    return Semantics(
      button: true,
      expanded: _open,
      child: GestureDetector(
        key: prohibitedItemsKey,
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _open = !_open),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          decoration: BoxDecoration(
            color: const Color.fromRGBO(255, 107, 117, .08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color.fromRGBO(255, 107, 117, .3)),
          ),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 24),
                  child: Row(
                    children: [
                      AnimatedRotation(
                        turns: _open ? .25 : 0,
                        duration: const Duration(milliseconds: 220),
                        child: TaraIcon(TaraIcons.chevronRight, size: 14, color: c.textPrimary),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          l.prohibitedTitle,
                          style: TaraText.label.copyWith(
                            color: c.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_open) ...[
                  const SizedBox(height: 6),
                  Text(
                    '${prohibitedItems(l).join(' · ')}. ${l.prohibitedPledge}',
                    style: TaraText.small.copyWith(
                      color: c.textPrimary.withValues(alpha: .75),
                      fontSize: 12,
                      height: 1.6,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
