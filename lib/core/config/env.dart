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

  static bool get isSupabaseConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
