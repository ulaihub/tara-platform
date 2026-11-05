import 'package:flutter/widgets.dart';

import '../tara_colors.dart';
import '../tara_icons.dart';
import '../tara_typography.dart';
import 'layout.dart';
import 'legal_markdown.dart';

/// Lecture des conditions avant de les accepter : titre, explication, textes complets les
/// uns après les autres, puis le socle d'actions (case à cocher, bouton). [footer] reçoit
/// `readToEnd` : vrai une fois le bas des textes atteint (ou s'ils tiennent dans l'écran),
/// pour n'autoriser l'acceptation qu'après la lecture.
class TermsReader extends StatefulWidget {
  const TermsReader({
    super.key,
    required this.title,
    required this.intro,
    required this.documents,
    required this.footer,
    this.leading,
    this.readHint,
  });

  final String title;
  final String intro;

  /// Textes Markdown (titre `#` compris), dans l'ordre de lecture.
  final List<String> documents;
  final Widget Function(BuildContext context, bool readToEnd) footer;

  /// Ligne du haut (retour, « Plus tard »).
  final Widget? leading;

  /// Rappel affiché en bas des textes tant qu'ils n'ont pas été lus jusqu'au bout.
  final String? readHint;

  @override
  State<TermsReader> createState() => _TermsReaderState();
}

class _TermsReaderState extends State<TermsReader> {
  bool _readToEnd = false;

  bool _onScroll(ScrollMetrics metrics) {
    if (!_readToEnd && metrics.axis == Axis.vertical && metrics.extentAfter < 48) {
      setState(() => _readToEnd = true);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final c = TaraColors.of(context);
    return NotificationListener<ScrollMetricsNotification>(
      onNotification: (notification) => _onScroll(notification.metrics),
      child: NotificationListener<ScrollUpdateNotification>(
        onNotification: (notification) => _onScroll(notification.metrics),
        child: ScrollWithFooter(
          horizontal: 20,
          top: 8,
          content: [
            ?widget.leading,
            if (widget.leading != null) const SizedBox(height: 20),
            Semantics(
              header: true,
              child: Text(widget.title, style: TaraText.titleForm.copyWith(color: c.textPrimary)),
            ),
            const SizedBox(height: 10),
            Text(widget.intro, style: TaraText.body.copyWith(color: c.textSecondary)),
            for (final markdown in widget.documents) ...[
              const SizedBox(height: 28),
              Container(height: 1, color: c.chipBorder),
              const SizedBox(height: 24),
              LegalMarkdown(markdown),
            ],
            if (widget.readHint != null) ...[
              const SizedBox(height: 28),
              Row(
                children: [
                  TaraIcon(TaraIcons.check, size: 18, color: c.success),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(widget.readHint!, style: TaraText.label.copyWith(color: c.textTertiary)),
                  ),
                ],
              ),
            ],
          ],
          footer: widget.footer(context, _readToEnd),
        ),
      ),
    );
  }
}
