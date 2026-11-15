// Configuration Firebase de l'app expéditeur cm.tara.app (projet tara-ulaihub), reprise de
// google-services.json : l'initialisation se fait en Dart, sans plugin Gradle.
//
// La clé d'API n'est pas un secret : elle identifie le projet auprès de Firebase et
// figure dans tout APK publié. À la mise en production, la restreindre dans la console
// Google Cloud (app Android cm.tara.app + empreinte du certificat de signature).
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

abstract final class DefaultFirebaseOptions {
  /// `null` sur une plateforme pas encore enregistrée dans Firebase : l'app tourne alors
  /// sans notifications (le suivi passe aussi par le temps réel, app ouverte).
  static FirebaseOptions? get currentPlatform {
    if (kIsWeb) return null;
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => android,
      TargetPlatform.iOS => ios,
      _ => null,
    };
  }

  /// Android : valeurs `mobilesdk_app_id` et `current_key` de google-services.json.
  static const _androidAppId = '';
  static const _androidApiKey = '';

  static FirebaseOptions? get android => _androidAppId.isEmpty || _androidApiKey.isEmpty
      ? null
      : const FirebaseOptions(
          apiKey: _androidApiKey,
          appId: _androidAppId,
          messagingSenderId: '450017083015',
          projectId: 'tara-ulaihub',
          storageBucket: 'tara-ulaihub.firebasestorage.app',
        );

  /// iPhone : GOOGLE_APP_ID et API_KEY de GoogleService-Info.plist, donnés à la construction
  /// par Codemagic (`--dart-define`, voir docs/IOS.md).
  static const _iosAppId = String.fromEnvironment('FIREBASE_IOS_CLIENT_APP_ID');
  static const _iosApiKey = String.fromEnvironment('FIREBASE_IOS_CLIENT_API_KEY');

  static FirebaseOptions? get ios => _iosAppId.isEmpty || _iosApiKey.isEmpty
      ? null
      : const FirebaseOptions(
          apiKey: _iosApiKey,
          appId: _iosAppId,
          messagingSenderId: '450017083015',
          projectId: 'tara-ulaihub',
          storageBucket: 'tara-ulaihub.firebasestorage.app',
          iosBundleId: 'cm.tara.app',
        );
}
