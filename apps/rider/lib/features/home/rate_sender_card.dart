import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tara_ui/components/buttons.dart';
import 'package:tara_ui/components/glass.dart';
import 'package:tara_ui/components/star_rating.dart';
import 'package:tara_ui/tara_colors.dart';
import 'package:tara_ui/tara_icons.dart';
import 'package:tara_ui/tara_typography.dart';

import '../../l10n/app_localizations.dart';

/// « Notez Awa Fashion » : après la course, le livreur note l'expéditeur d'un seul geste
/// (F4). Une étoile touchée envoie la note ; un merci s'affiche puis la carte s'efface.
class RateSenderCard extends StatefulWidget {
  const RateSenderCard({super.key, required this.name, required this.onRate, required this.onClose});

  final String name;

  /// Envoi de la note (1 à 5) ; un échec réseau n'est pas montré, la note est facultative.
  final ValueChanged<int> onRate;
  final VoidCallback onClose;

  @override
  State<RateSenderCard> createState() => _RateSenderCardState();
}

class _RateSenderCardState extends State<RateSenderCard> {
  int _stars = 0;
  Timer? _close;

  @override
  void dispose() {
    _close?.cancel();
    super.dispose();
  }

  void _rate(int stars) {
    setState(() => _stars = stars);
    widget.onRate(stars);
    _close = Timer(const Duration(milliseconds: 1600), widget.onClose);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = TaraColors.of(context);
    final thanked = _stars > 0;
    return Material(
      type: MaterialType.transparency,
      child: GlassCard(
        radius: 22,
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      thanked ? l.rateSenderThanks : l.rateSenderTitle(widget.name),
                      style: TaraText.text.copyWith(color: c.textPrimary, fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (!thanked) Text(l.rateSenderBody, style: TaraText.small.copyWith(color: c.textSecondary)),
                  const SizedBox(height: 10),
                  StarRating(value: _stars, onChanged: thanked ? null : _rate, labelOf: l.starsLabel, size: 32),
                ],
              ),
            ),
            GlassIconButton(icon: TaraIcons.close, label: l.close, onPressed: widget.onClose),
          ],
        ),
      ),
    );
  }
}
