import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tara_rider/app/app_settings.dart';
import 'package:tara_rider/design/components/brand.dart';
import 'package:tara_rider/design/tara_effects.dart';
import 'package:tara_rider/design/tara_theme.dart';
import 'package:tara_rider/l10n/app_localizations.dart';

/// Format d'écran vérifié (consigne : 390×844 et Android compact 360×640).
enum ScreenSize {
  regular(Size(390, 844), EdgeInsets.only(top: 47, bottom: 34)),
  compact(Size(360, 640), EdgeInsets.only(top: 24));

  const ScreenSize(this.size, this.padding);
  final Size size;

  /// Barre d'état et barre de navigation du système.
  final EdgeInsets padding;
}

/// Variante d'affichage d'une capture.
class Variant {
  const Variant(this.brightness, this.screen, this.textScale, {this.reducedEffects = false, this.reduceMotion = false});

  final Brightness brightness;
  final ScreenSize screen;
  final double textScale;
  final bool reducedEffects;
  final bool reduceMotion;

  String get name => [
    brightness == Brightness.dark ? 'dark' : 'light',
    '${screen.size.width.toInt()}x${screen.size.height.toInt()}',
    'text${(textScale * 100).round()}',
    if (reducedEffects) 'reduced',
    if (reduceMotion) 'nomotion',
  ].join('_');

  /// Les deux thèmes × deux formats × texte 100 % et 130 %.
  static final matrix = [
    for (final b in [Brightness.dark, Brightness.light])
      for (final s in ScreenSize.values)
        for (final t in [1.0, 1.3]) Variant(b, s, t),
  ];
}

/// Monte un écran dans les conditions d'une variante (thème, taille, texte, effets).
Future<void> pumpVariant(
  WidgetTester tester,
  Variant variant,
  Widget screen, {
  Size? surface,
  Locale locale = const Locale('fr'),
}) async {
  final size = surface ?? variant.screen.size;
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1
    ..padding = FakeViewPadding(top: variant.screen.padding.top, bottom: variant.screen.padding.bottom)
    ..viewPadding = FakeViewPadding(top: variant.screen.padding.top, bottom: variant.screen.padding.bottom);
  addTearDown(tester.view.reset);

  final effects = EffectsController()
    ..preference = variant.reducedEffects ? EffectsPreference.reduced : EffectsPreference.full;
  final settings = AppSettings(effects: effects)
    ..themeMode = variant.brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light;
  addTearDown(settings.dispose);

  await tester.pumpWidget(
    AppSettingsScope(
      settings: settings,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: TaraTheme.light,
        darkTheme: TaraTheme.dark,
        themeMode: settings.themeMode,
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(variant.textScale), disableAnimations: variant.reduceMotion),
          child: TaraEffects(controller: effects, child: child!),
        ),
        home: RepaintBoundary(key: const ValueKey('capture'), child: screen),
      ),
    ),
  );
  // Les logos sont décodés hors de l'horloge de test.
  await tester.runAsync(() async {
    final context = tester.element(find.byKey(const ValueKey('capture')));
    for (final brightness in Brightness.values) {
      await precacheImage(AssetImage(TaraLogo.assetFor(brightness)), context);
    }
  });
  await tester.pump();
}

final capture = find.byKey(const ValueKey('capture'));

/// Test de capture : `flutter test` remplace les ombres par des aplats, on veut le vrai
/// rendu. La variable est rétablie avant la vérification des invariants du test.
void goldenTest(String description, Future<void> Function(WidgetTester tester) body) {
  testWidgets(description, (tester) async {
    debugDisableShadows = false;
    try {
      await body(tester);
    } finally {
      debugDisableShadows = true;
    }
  });
}
