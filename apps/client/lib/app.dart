import 'package:flutter/material.dart';
import 'package:tara_ui/app_settings.dart';
import 'package:tara_ui/tara_effects.dart';
import 'package:tara_ui/tara_theme.dart';

import 'app/root.dart';
import 'l10n/app_localizations.dart';

/// Application Tara des expéditeurs. Le thème suit le téléphone sauf choix contraire ; les
/// langues prises en charge sont le français et l'anglais.
class TaraClientApp extends StatelessWidget {
  const TaraClientApp({super.key, required this.settings});

  final AppSettings settings;

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
          home: const RootGate(),
        ),
      ),
    );
  }
}
