// Configuration Firebase de l'app livreur (projet tara-ulaihub), reprise de
// google-services.json : l'initialisation se fait en Dart, sans plugin Gradle.
//
// La clé d'API n'est pas un secret : elle identifie le projet auprès de Firebase et
// figure dans tout APK publié. À la mise en production, la restreindre dans la console
// Google Cloud (app Android cm.tara.rider + empreinte du certificat de signature).
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

abstract final class DefaultFirebaseOptions {
  /// `null` sur une plateforme pas encore enregistrée dans Firebase (iOS : à ajouter
  /// avec GoogleService-Info.plist et une clé APNs).
  static FirebaseOptions? get currentPlatform {
    if (kIsWeb) return null;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => android,
      _ => null,
    };
  }

  static const android = FirebaseOptions(
    apiKey: 'AIzaSyAAFXUiQJrDCai9kntF0pIbfQTXw2lxRnM',
    appId: '1:450017083015:android:e503d3d383735d085e8222',
    messagingSenderId: '450017083015',
    projectId: 'tara-ulaihub',
    storageBucket: 'tara-ulaihub.firebasestorage.app',
  );
}
