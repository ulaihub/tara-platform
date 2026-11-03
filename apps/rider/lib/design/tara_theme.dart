import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'tara_colors.dart';
import 'tara_typography.dart';

/// Thèmes Material de l'application : les composants Tara lisent [TaraColors], les rares
/// widgets Material restants (dialogues système, sélection de texte) suivent la marque.
abstract final class TaraTheme {
  static ThemeData get dark => _build(TaraColors.dark);
  static ThemeData get light => _build(TaraColors.light);

  static ThemeData _build(TaraColors c) {
    final scheme = ColorScheme.fromSeed(
      seedColor: TaraBrand.orange,
      brightness: c.brightness,
      primary: TaraBrand.orange,
      onPrimary: TaraBrand.onBrand,
      surface: c.bg,
      onSurface: c.textPrimary,
      error: c.dangerText,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: c.brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.bg,
      canvasColor: c.bg,
      fontFamily: TaraText.jakarta,
      extensions: [c],
      // Les boutons Tara ont leur propre retour visuel (reflet, enfoncement).
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: TaraBrand.orange,
        selectionColor: TaraBrand.orange.withValues(alpha: .30),
        selectionHandleColor: TaraBrand.orange,
      ),
      appBarTheme: AppBarTheme(systemOverlayStyle: c.isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}
