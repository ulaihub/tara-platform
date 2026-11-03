import 'dart:async';

import 'package:flutter/widgets.dart';

import 'app.dart';
import 'app/app_settings.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = AppSettings();
  // La détection du téléphone modeste ne bloque pas le démarrage.
  unawaited(settings.effects.detectDevice());
  runApp(TaraApp(settings: settings));
}
