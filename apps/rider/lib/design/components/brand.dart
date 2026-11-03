import 'package:flutter/widgets.dart';

import '../tara_colors.dart';

/// Logo complet Tara, version adaptée au thème (texte blanc en sombre, foncé en clair).
/// PNG détourés en attendant la version vectorielle demandée (passation §8).
class TaraLogo extends StatelessWidget {
  const TaraLogo({super.key, this.width = 214, this.semanticLabel = 'Tara'});

  final double width;
  final String semanticLabel;

  /// Rapport largeur / hauteur des fichiers livrés (1469 × 551).
  static const aspectRatio = 1469 / 551;

  static String assetFor(Brightness brightness) =>
      brightness == Brightness.dark ? 'assets/brand/tara-logo-dark.png' : 'assets/brand/tara-logo-light.png';

  @override
  Widget build(BuildContext context) {
    final c = TaraColors.of(context);
    return Image.asset(
      assetFor(c.brightness),
      width: width,
      height: width / aspectRatio,
      semanticLabel: semanticLabel,
      filterQuality: FilterQuality.medium,
    );
  }
}
