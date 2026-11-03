import 'package:flutter/material.dart';

import '../design/tara_effects.dart';

/// Réglages d'affichage choisis par le livreur (profil) : thème, langue, effets.
/// Par défaut le thème et la langue suivent le téléphone.
class AppSettings extends ChangeNotifier {
  AppSettings({EffectsController? effects}) : effects = effects ?? EffectsController();

  final EffectsController effects;
  ThemeMode _themeMode = ThemeMode.system;
  Locale? _locale;

  ThemeMode get themeMode => _themeMode;
  set themeMode(ThemeMode value) {
    if (value == _themeMode) return;
    _themeMode = value;
    notifyListeners();
  }

  /// `null` : langue du téléphone (français si elle n'est pas prise en charge).
  Locale? get locale => _locale;
  set locale(Locale? value) {
    if (value == _locale) return;
    _locale = value;
    notifyListeners();
  }

  @override
  void dispose() {
    effects.dispose();
    super.dispose();
  }
}

/// Met les réglages à disposition des écrans.
class AppSettingsScope extends InheritedNotifier<AppSettings> {
  const AppSettingsScope({super.key, required AppSettings settings, required super.child}) : super(notifier: settings);

  static AppSettings? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppSettingsScope>()?.notifier;

  static AppSettings of(BuildContext context) => maybeOf(context)!;
}
