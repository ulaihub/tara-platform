import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tara_rider/l10n/app_localizations.dart';
import 'package:tara_test/harness.dart' as shared;
import 'package:tara_ui/components/tab_shell.dart';
import 'package:tara_ui/tara_icons.dart';

export 'package:tara_test/harness.dart' show ScreenSize, Variant, capture, goldenTest, loadBrandImages, sounds;

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

/// Écran d'onglet dans son cadre : contenu sous la barre d'onglets en verre.
Widget tabs(int current, Widget child) => TaraTabShell(
  items: const [
    TabItem(TaraIcons.home, 'Accueil'),
    TabItem(TaraIcons.activity, 'Activité'),
    TabItem(TaraIcons.user, 'Profil'),
  ],
  current: current,
  onSelected: (_) {},
  child: child,
);
