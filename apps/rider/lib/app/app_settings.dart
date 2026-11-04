import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:tara_core/session/session_store.dart';
import 'package:tara_ui/tara_effects.dart';

/// Réglages d'affichage choisis par le livreur (profil) : thème, langue, effets. Par
/// défaut le thème et la langue suivent le téléphone. Gardés sur le téléphone ([store]).
class AppSettings extends ChangeNotifier {
  AppSettings({EffectsController? effects, this.store}) : effects = effects ?? EffectsController() {
    this.effects.addListener(_onEffects);
  }

  /// Réglages gardés sur le téléphone ; valeurs par défaut s'ils sont absents ou illisibles.
  static Future<AppSettings> load(KeyValueStore store, {EffectsController? effects}) async {
    final settings = AppSettings(effects: effects, store: store);
    try {
      final raw = await store.read(_key);
      if (raw != null) settings._restore(jsonDecode(raw) as Map<String, Object?>);
    } catch (_) {
      // Réglages illisibles : ceux du téléphone s'appliquent.
    }
    return settings;
  }

  static const _key = 'settings.display';

  final EffectsController effects;
  final KeyValueStore? store;
  ThemeMode _themeMode = ThemeMode.system;
  Locale? _locale;
  EffectsPreference _effectsPreference = EffectsPreference.automatic;

  ThemeMode get themeMode => _themeMode;
  set themeMode(ThemeMode value) {
    if (value == _themeMode) return;
    _themeMode = value;
    _changed();
  }

  /// `null` : langue du téléphone (français si elle n'est pas prise en charge).
  Locale? get locale => _locale;
  set locale(Locale? value) {
    if (value == _locale) return;
    _locale = value;
    _changed();
  }

  /// Code de langue pour le serveur : le choix du livreur, sinon celui du téléphone.
  String languageCode(Locale device) => (_locale ?? device).languageCode == 'en' ? 'en' : 'fr';

  void _restore(Map<String, Object?> json) {
    _themeMode = ThemeMode.values.where((mode) => mode.name == json['theme']).firstOrNull ?? ThemeMode.system;
    final language = json['locale'];
    _locale = language is String && (language == 'fr' || language == 'en') ? Locale(language) : null;
    final preference = EffectsPreference.values.where((value) => value.name == json['effects']).firstOrNull;
    if (preference != null) {
      _effectsPreference = preference;
      effects.preference = preference;
    }
  }

  /// Préférence d'effets changée (profil) : gardée avec le reste. La détection d'un
  /// téléphone modeste notifie aussi, sans rien à garder.
  void _onEffects() {
    if (effects.preference == _effectsPreference) return;
    _effectsPreference = effects.preference;
    _changed();
  }

  void _changed() {
    notifyListeners();
    final target = store;
    if (target == null) return;
    final json = jsonEncode({
      'theme': _themeMode.name,
      'locale': _locale?.languageCode,
      'effects': _effectsPreference.name,
    });
    unawaited(target.write(_key, json).catchError((Object _) {}));
  }

  @override
  void dispose() {
    effects
      ..removeListener(_onEffects)
      ..dispose();
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
