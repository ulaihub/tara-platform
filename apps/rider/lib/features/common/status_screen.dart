import 'package:flutter/widgets.dart';

import '../../design/components/brand.dart';
import '../../design/components/buttons.dart';
import '../../design/components/glass.dart';
import '../../design/components/layout.dart';
import '../../design/motion/liquid_background.dart';
import '../../design/tara_colors.dart';
import '../../design/tara_typography.dart';

/// Écran d'état (non dessiné, proposé) : dossier en vérification, compte suspendu, erreur
/// de chargement. Pictogramme, message, action principale et lien secondaire.
class StatusScreen extends StatelessWidget {
  const StatusScreen({
    super.key,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
    this.linkLabel,
    this.onLink,
  });

  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? linkLabel;
  final VoidCallback? onLink;

  static const _blobs = [
    BlobSpec(alignment: Alignment(1.2, -1.0), size: 300, colors: BlobSpec.brand, blur: 70),
    BlobSpec(alignment: Alignment(-1.25, 1.0), size: 260, colors: BlobSpec.soft, blur: 70, delay: Duration(seconds: 5)),
  ];

  @override
  Widget build(BuildContext context) {
    final c = TaraColors.of(context);
    return TaraScreen(
      blobs: _blobs,
      child: ScrollWithFooter(
        content: [
          const SizedBox(height: 48),
          const Center(child: TaraMark(width: 132)),
          const SizedBox(height: 28),
          GlassCard(
            radius: 28,
            padding: const EdgeInsets.all(22),
            child: Column(
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: TaraText.titleCourse.copyWith(color: c.textPrimary),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  body,
                  textAlign: TextAlign.center,
                  style: TaraText.body.copyWith(color: c.textSecondary),
                ),
              ],
            ),
          ),
        ],
        footer: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (actionLabel != null) GlassButton(label: actionLabel!, onPressed: onAction),
            if (linkLabel != null) ...[
              const SizedBox(height: 8),
              Center(
                child: TaraLink(label: linkLabel!, onPressed: onLink),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
