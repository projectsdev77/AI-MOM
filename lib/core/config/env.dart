/// Build-time configuration, supplied via --dart-define / --dart-define-from-file.
///
/// None of these are committed anywhere — see README.md for the flutter
/// run/build invocation. Every value defaults to empty so a config
/// mistake fails loudly (see [Env.isConfigured]) instead of silently
/// pointing at nothing.
class Env {
  Env._();

  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const revenueCatIosKey = String.fromEnvironment('REVENUECAT_IOS_KEY');
  static const revenueCatAndroidKey =
      String.fromEnvironment('REVENUECAT_ANDROID_KEY');
  static const googleWebClientId =
      String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');

  // Defaults to a real address so Help & contact support always has
  // somewhere to send mail, even before config/local.json sets its own.
  static const supportEmail =
      String.fromEnvironment('SUPPORT_EMAIL', defaultValue: 'projects.dev@gmail.com');

  // Firebase (push notifications) — values come from Firebase Console
  // -> Project settings -> Your apps -> the relevant app's config, not
  // from running the FlutterFire CLI. Same "paste values into
  // config/local.json" pattern as everything else in this app.
  static const firebaseApiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const firebaseAppId = String.fromEnvironment('FIREBASE_APP_ID');
  static const firebaseMessagingSenderId =
      String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
  static const firebaseProjectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const firebaseAuthDomain = String.fromEnvironment('FIREBASE_AUTH_DOMAIN');
  static const firebaseStorageBucket = String.fromEnvironment('FIREBASE_STORAGE_BUCKET');

  static bool get isSupabaseConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  static bool get isFirebaseConfigured =>
      firebaseApiKey.isNotEmpty && firebaseAppId.isNotEmpty && firebaseProjectId.isNotEmpty;
}
