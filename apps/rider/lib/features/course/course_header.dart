import 'package:flutter/widgets.dart';

import 'package:tara_ui/components/buttons.dart';
import 'package:tara_ui/components/glass.dart';
import 'package:tara_ui/tara_colors.dart';
import 'package:tara_ui/tara_icons.dart';
import 'package:tara_ui/tara_typography.dart';

import '../../l10n/app_localizations.dart';

/// En-tête des écrans de course, sur la carte : retour, référence et étape, SOS.
class CourseHeader extends StatelessWidget {
  const CourseHeader({
    super.key,
    required this.reference,
    required this.title,
    required this.onBack,
    required this.onSos,
  });

  final String reference;
  final String title;
  final VoidCallback onBack;
  final VoidCallback onSos;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    // Une ligne chacun : avec le texte agrandi, ils rétrécissent au lieu d'être coupés.
    Widget line(String text, TextStyle style) => FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text(text, maxLines: 1, softWrap: false, style: style),
    );
    return Row(
      children: [
        GlassIconButton(icon: TaraIcons.chevronLeft, label: l.back, onPressed: onBack),
        const SizedBox(width: 10),
        Expanded(
          child: Semantics(
            header: true,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: GlassCard(
                radius: 16,
                shadow: false,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    line(reference, TaraText.small.copyWith(fontSize: 11, color: c.textSecondary)),
                    line(title, TaraText.text.copyWith(color: c.textPrimary, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SosButton(label: l.safetyAlert, onPressed: onSos, size: 48),
      ],
    );
  }
}
