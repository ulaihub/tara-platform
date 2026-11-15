// Configuration Firebase de l'app livreur (projet tara-ulaihub), reprise de
// google-services.json : l'initialisation se fait en Dart, sans plugin Gradle.
//
// La clé d'API n'est pas un secret : elle identifie le projet auprès de Firebase et
// figure dans tout APK publié. À la mise en production, la restreindre dans la console
// Google Cloud (app Android cm.tara.rider + empreinte du certificat de signature).
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

abstract final class DefaultFirebaseOptions {
  /// `null` sur une plateforme pas encore enregistrée dans Firebase : l'app tourne alors
  /// sans notifications.
  static FirebaseOptions? get currentPlatform {
    if (kIsWeb) return null;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => android,
      TargetPlatform.iOS => ios,
      _ => null,
    };
  }

  /// iPhone : identifiant et clé de l'app iOS cm.tara.rider (fichier GoogleService-Info.plist,
  /// GOOGLE_APP_ID et API_KEY), donnés à la construction par Codemagic (`--dart-define`,
  /// voir docs/IOS.md). Les notifications demandent aussi la clé APNs déposée dans Firebase.
  static const _iosAppId = String.fromEnvironment('FIREBASE_IOS_RIDER_APP_ID');
  static const _iosApiKey = String.fromEnvironment('FIREBASE_IOS_RIDER_API_KEY');

  static FirebaseOptions? get ios => _iosAppId.isEmpty || _iosApiKey.isEmpty
      ? null
      : const FirebaseOptions(
          apiKey: _iosApiKey,
          appId: _iosAppId,
          messagingSenderId: '450017083015',
          projectId: 'tara-ulaihub',
          storageBucket: 'tara-ulaihub.firebasestorage.app',
          iosBundleId: 'cm.tara.rider',
        );

  static const android = FirebaseOptions(
    apiKey: 'AIzaSyAAFXUiQJrDCai9kntF0pIbfQTXw2lxRnM',
    appId: '1:450017083015:android:e503d3d383735d085e8222',
    messagingSenderId: '450017083015',
    projectId: 'tara-ulaihub',
    storageBucket: 'tara-ulaihub.firebasestorage.app',
  );
}
