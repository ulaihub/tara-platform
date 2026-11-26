import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../tara_colors.dart';
import '../tara_typography.dart';
import 'inputs.dart';
import 'intro.dart';
import 'legal_markdown.dart';

/// Textes des conditions dans une carte qui défile (maquettes « Conditions ») : la part lue
/// s'affiche sous la carte (« Lu à 40% ») ; [onProgress] reçoit la part lue (0 à 1) et
/// [onReadToEnd] est appelé une fois le bas atteint (ou si tout tient dans la carte).
class TermsReadCard extends StatefulWidget {
  const TermsReadCard({
    super.key,
    required this.documents,
    required this.endLine,
    required this.onProgress,
    this.fade = false,
  });

  /// Textes Markdown (titre `#` compris), dans l'ordre de lecture.
  final List<String> documents;

  /// « Vous êtes arrivé au bout des textes. », en vert après le dernier texte.
  final String endLine;
  final ValueChanged<double> onProgress;

  /// Fondu en bas de la carte (maquette des livreurs).
  final bool fade;

  @override
  State<TermsReadCard> createState() => _TermsReadCardState();
}

class _TermsReadCardState extends State<TermsReadCard> {
  double _read = 0;

  bool _onScroll(ScrollMetrics metrics) {
    if (metrics.axis != Axis.vertical) return false;
    final max = metrics.maxScrollExtent;
    final part = max <= 0 ? 1.0 : (metrics.pixels / max).clamp(0.0, 1.0);
    // Le bas est atteint à 24 près ; la part lue ne redescend pas.
    final read = math.max(_read, metrics.extentAfter < 24 ? 1.0 : part);
    if (read != _read) {
      _read = read;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onProgress(_read);
      });
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final c = TaraColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: boxedFieldFill(c),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: c.isDark ? const Color.fromRGBO(255, 255, 255, .10) : const Color(0xFFFFFFFF)),
        boxShadow: const [BoxShadow(color: Color.fromRGBO(140, 70, 10, .08), blurRadius: 28, offset: Offset(0, 12))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(21),
        child: Stack(
          children: [
            NotificationListener<ScrollMetricsNotification>(
              onNotification: (n) => _onScroll(n.metrics),
              child: NotificationListener<ScrollUpdateNotification>(
                onNotification: (n) => _onScroll(n.metrics),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final (i, text) in widget.documents.indexed) ...[
                        if (i > 0) const SizedBox(height: 16),
                        LegalMarkdown(text, compact: true),
                      ],
                      const SizedBox(height: 8),
                      Text(
                        widget.endLine,
                        style: TaraText.label.copyWith(fontWeight: FontWeight.w700, color: c.success),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (widget.fade)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 60,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [c.bg.withValues(alpha: 0), c.bg.withValues(alpha: .9)],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Barre « Lu à 40% » sous la carte : rail de 6, dégradé qui coule, pourcentage à droite.
class TermsReadBar extends StatelessWidget {
  const TermsReadBar({super.key, required this.read, required this.label});

  /// Part lue, de 0 à 1.
  final double read;
  final String Function(int percent) label;

  @override
  Widget build(BuildContext context) {
    final c = TaraColors.of(context);
    final percent = (read * 100).round();
    return Semantics(
      label: label(percent),
      excludeSemantics: true,
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 6,
              decoration: BoxDecoration(
                color: c.textPrimary.withValues(alpha: .10),
                borderRadius: BorderRadius.circular(3),
              ),
              alignment: Alignment.centerLeft,
              child: AnimatedFractionallySizedBox(
                duration: const Duration(milliseconds: 500),
                widthFactor: read.clamp(0.0, 1.0),
                child: const ClipRRect(
                  borderRadius: BorderRadius.all(Radius.circular(3)),
                  child: SizedBox(height: 6, child: FlowBar()),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            label(percent),
            style: TaraText.smallStrong.copyWith(fontWeight: FontWeight.w800, color: c.textPrimary),
          ),
        ],
      ),
    );
  }
}
