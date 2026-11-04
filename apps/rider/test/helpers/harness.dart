import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tara_rider/l10n/app_localizations.dart';
import 'package:tara_test/harness.dart' as shared;

export 'package:tara_test/harness.dart' show ScreenSize, Variant, capture, goldenTest;

/// Monte un écran de l'app livreur dans les conditions d'une variante.
Future<void> pumpVariant(
  WidgetTester tester,
  shared.Variant variant,
  Widget screen, {
  Size? surface,
  Locale locale = const Locale('fr'),
}) => shared.pumpVariant(
  tester,
  variant,
  screen,
  surface: surface,
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
);
