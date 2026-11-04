import 'package:flutter/services.dart';

/// Charge les polices embarquées pour que les captures montrent le vrai rendu
/// (sans cela, `flutter test` dessine tous les textes avec une police de test).
Future<void> loadAppFonts() async {
  const weights = [400, 500, 600, 700, 800];
  for (final family in const ['Sora', 'PlusJakartaSans']) {
    // Polices du paquet tara_ui : Flutter les nomme « packages/tara_ui/… ».
    final loader = FontLoader('packages/tara_ui/$family');
    for (final weight in weights) {
      loader.addFont(rootBundle.load('packages/tara_ui/fonts/$family-$weight.ttf'));
    }
    await loader.load();
  }
}
