import 'package:flutter/material.dart';

import 'app/app_settings.dart';
import 'app/root.dart';
import 'design/tara_effects.dart';
import 'design/tara_theme.dart';
import 'features/catalog/catalog_screen.dart';
import 'l10n/app_localizations.dart';

/// Application Tara Livreur. Le thème suit le téléphone (ThemeMode.system) sauf choix
/// contraire dans le profil ; les langues prises en charge sont le français et l'anglais.
class TaraApp extends StatelessWidget {
  const TaraApp({super.key, required this.settings, this.home});

  final AppSettings settings;

  /// Écran d'accueil (remplacé par le routeur à l'étape 2).
  final Widget? home;

  @override
  Widget build(BuildContext context) {
    return AppSettingsScope(
      settings: settings,
      child: ListenableBuilder(
        listenable: settings,
        builder: (context, _) => MaterialApp(
          onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
          debugShowCheckedModeBanner: false,
          theme: TaraTheme.light,
          darkTheme: TaraTheme.dark,
          themeMode: settings.themeMode,
          locale: settings.locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => TaraEffects(controller: settings.effects, child: child!),
          // Catalogue des composants : --dart-define=TARA_CATALOG=true (développement).
          home: home ?? (const bool.fromEnvironment('TARA_CATALOG') ? const CatalogScreen() : const RootGate()),
        ),
      ),
    );
  }
}
