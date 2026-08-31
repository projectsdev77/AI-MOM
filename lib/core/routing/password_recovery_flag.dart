import 'package:supabase_flutter/supabase_flutter.dart';

/// Set true the moment a password-reset deep link exchanges its token
/// for a session (main.dart's deep-link listener calling
/// getSessionFromUrl fires AuthChangeEvent.passwordRecovery for this),
/// and false again once the user actually sets a new password or signs
/// out. A recovery session is a real signed-in session as far as
/// Supabase is concerned, but the router (see router.dart's redirect)
/// checks this flag to send it to /reset-password instead of
/// /dashboard until the password is actually replaced.
bool isPasswordRecoverySession = false;

void listenForPasswordRecovery() {
  Supabase.instance.client.auth.onAuthStateChange.listen((data) {
    if (data.event == AuthChangeEvent.passwordRecovery) {
      isPasswordRecoverySession = true;
    } else if (data.event == AuthChangeEvent.signedOut) {
      isPasswordRecoverySession = false;
    }
  });
}
