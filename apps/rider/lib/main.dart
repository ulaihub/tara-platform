import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';

import 'app.dart';
import 'app/app_settings.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _initFirebase();
  final settings = AppSettings();
  // La détection du téléphone modeste ne bloque pas le démarrage.
  unawaited(settings.effects.detectDevice());
  runApp(TaraApp(settings: settings));
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
