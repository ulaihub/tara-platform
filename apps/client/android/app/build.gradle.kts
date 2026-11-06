import java.util.Base64

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "cm.tara.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "cm.tara.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 26 // Android 8.0 (cahier des charges)
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Clé de signature de l'app (clé d'envoi Google Play), fournie par l'environnement :
    // en CI par les secrets du dépôt, jamais versionnée. Sans elle, clé de débogage
    // (APK de test seulement : les mises à jour entre deux machines sont refusées).
    val keystoreBase64 = System.getenv("TARA_CLIENT_KEYSTORE_BASE64")
    signingConfigs {
        if (!keystoreBase64.isNullOrBlank()) {
            create("release") {
                val file = layout.buildDirectory.file("signing/upload.jks").get().asFile
                file.parentFile.mkdirs()
                file.writeBytes(Base64.getDecoder().decode(keystoreBase64.trim()))
                storeFile = file
                storePassword = System.getenv("TARA_CLIENT_KEYSTORE_PASSWORD")
                keyAlias = System.getenv("TARA_CLIENT_KEY_ALIAS")
                keyPassword = System.getenv("TARA_CLIENT_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.findByName("release") ?: signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
