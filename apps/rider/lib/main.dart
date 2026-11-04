import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tara_core/session/session_store.dart';
import 'package:tara_ui/app_settings.dart';

import 'app.dart';
import 'app/providers.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _initFirebase();
  // Thème, langue et effets choisis dans le profil, gardés sur le téléphone.
  final settings = await AppSettings.load(const SecureKeyValueStore());
  // La détection du téléphone modeste ne bloque pas le démarrage.
  unawaited(settings.effects.detectDevice());
  runApp(
    ProviderScope(
      overrides: [appSettingsProvider.overrideWithValue(settings)],
      child: TaraApp(settings: settings),
    ),
  );
}

/// Firebase sert aux notifications. Sans lui l'app fonctionne quand même : les
/// propositions arrivent aussi par le temps réel.
Future<void> _initFirebase() async {
  final options = DefaultFirebaseOptions.currentPlatform;
  if (options == null) return;
  try {
    await Firebase.initializeApp(options: options);
  } catch (error) {
    debugPrint('Firebase indisponible : $error');
  }
}
