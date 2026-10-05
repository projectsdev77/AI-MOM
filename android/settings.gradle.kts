pluginManagement {
    val flutterSdkPath =
        run {
            val properties = java.util.Properties()
            file("local.properties").inputStream().use { properties.load(it) }
            val flutterSdkPath = properties.getProperty("flutter.sdk")
            require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
            flutterSdkPath
        }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "9.1.0" apply false
    id("org.jetbrains.kotlin.android") version "2.4.0" apply false
    // Required for FCM push token generation (PushService) — explicit
    // FirebaseOptions from --dart-define is enough for Firebase's own
    // Dart-side init, but firebase_messaging's native getToken() call
    // goes through Firebase Installations, which looks for this plugin's
    // generated resources and throws "valid API key required" without
    // it even though initializeApp() itself succeeds.
    id("com.google.gms.google-services") version "4.4.2" apply false
}

include(":app")
