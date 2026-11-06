import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tara_core/session/session_store.dart';
import 'package:tara_ui/app_settings.dart';

import 'app.dart';
import 'app/providers.dart';

// Notifications Firebase : à brancher quand l'app cm.tara.app sera enregistrée dans le
// projet Firebase (fichier de configuration à fournir) ; le suivi passe aussi par le temps
// réel quand l'app est ouverte.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Thème, langue et effets choisis dans l'app, gardés sur le téléphone.
  final settings = await AppSettings.load(const SecureKeyValueStore());
  // La détection du téléphone modeste ne bloque pas le démarrage.
  unawaited(settings.effects.detectDevice());
  runApp(
    ProviderScope(
      overrides: [appSettingsProvider.overrideWithValue(settings)],
      child: TaraClientApp(settings: settings),
    ),
  );
}
