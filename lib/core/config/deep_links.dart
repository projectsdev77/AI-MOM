/// Custom URL scheme this app registers on both platforms — see the
/// intent-filter in android/app/src/main/AndroidManifest.xml and the
/// CFBundleURLTypes entry in ios/Runner/Info.plist. Used only so a
/// password-reset email's link opens directly into the app (see
/// AuthService.sendPasswordReset and main.dart's deep-link listener)
/// instead of a browser with nowhere useful to go.
///
/// This exact value must also be added to the Supabase project's
/// Authentication -> URL Configuration -> Redirect URLs allow-list, or
/// Supabase will reject it and fall back to the default Site URL.
const passwordResetRedirectUrl = 'aimom://reset-password';
