import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/env.dart';
import 'purchases_service.dart';
import 'push_service.dart';

/// Email/password + Google + Apple, per the planning decision — no other
/// social providers, no phone auth.
class AuthService {
  AuthService(this._client);

  final SupabaseClient _client;

  User? get currentUser => _client.auth.currentUser;
  bool get isSignedIn => currentUser != null;

  Future<void> signUpWithEmail({
    required String email,
    required String password,
    required String name,
  }) async {
    await _client.auth.signUp(
      email: email,
      password: password,
      data: {'name': name},
    );
    await _afterSignIn();
  }

  Future<void> signInWithEmail({required String email, required String password}) async {
    await _client.auth.signInWithPassword(email: email, password: password);
    await _afterSignIn();
  }

  Future<void> sendPasswordReset(String email) {
    return _client.auth.resetPasswordForEmail(email);
  }

  /// Supabase emails a confirmation link to the new address before the
  /// change actually takes effect — `currentUser.email` stays the old
  /// one until that's clicked.
  Future<void> updateEmail(String newEmail) async {
    await _client.auth.updateUser(UserAttributes(email: newEmail));
  }

  /// Supabase's own updateUser(password:) will happily change the
  /// password for whoever holds the current session, with no old
  /// password required — so this re-authenticates with [currentPassword]
  /// first (throwing if it's wrong) before applying [newPassword].
  Future<void> changePassword({required String currentPassword, required String newPassword}) async {
    final email = currentUser?.email;
    if (email == null) {
      throw const AuthException('No signed-in account to change the password for.');
    }
    await _client.auth.signInWithPassword(email: email, password: currentPassword);
    await _client.auth.updateUser(UserAttributes(password: newPassword));
  }

  /// The `google_sign_in` plugin only ships real implementations for
  /// Android, iOS/macOS, and web — there is no Windows or Linux desktop
  /// implementation, so calling it there throws a plugin exception
  /// rather than doing anything. Checked up front so that failure reads
  /// as "wrong platform," not a cryptic generic error.
  Future<void> signInWithGoogle() async {
    if (Env.googleWebClientId.isEmpty) {
      throw const AuthException(
        "Google sign-in isn't set up yet — add GOOGLE_WEB_CLIENT_ID to config/local.json (see README's Setup step 5).",
      );
    }
    if (!kIsWeb && !(Platform.isAndroid || Platform.isIOS || Platform.isMacOS)) {
      throw const AuthException(
        "Google sign-in only works on Android, iPhone/Mac, or in a browser — not on this desktop build. "
        'Use email sign-in here, or test Google sign-in on a phone, emulator, or in Chrome.',
      );
    }
    final googleSignIn = GoogleSignIn.instance;
    await googleSignIn.initialize(serverClientId: Env.googleWebClientId);
    final account = await googleSignIn.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw const AuthException('Google sign-in did not return an ID token.');
    }
    await _client.auth.signInWithIdToken(provider: OAuthProvider.google, idToken: idToken);
    await _afterSignIn();
  }

  /// The `sign_in_with_apple` plugin only talks to Apple's native ID
  /// service on iOS/macOS. On Android and web it needs a Service ID and
  /// return URL registered in an Apple Developer account (a paid
  /// membership — see README) that this project doesn't have configured,
  /// so this fails fast with a clear reason instead of a cryptic SDK error.
  Future<void> signInWithApple() async {
    if (kIsWeb || !(Platform.isIOS || Platform.isMacOS)) {
      throw const AuthException(
        'Apple sign-in only works on iPhone/Mac right now and needs an Apple Developer account — use email or Google instead.',
      );
    }
    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName],
    );
    final idToken = credential.identityToken;
    if (idToken == null) {
      throw const AuthException('Apple sign-in did not return an identity token.');
    }
    await _client.auth.signInWithIdToken(provider: OAuthProvider.apple, idToken: idToken);
    await _afterSignIn();
  }

  Future<void> _afterSignIn() async {
    final userId = currentUser?.id;
    if (userId != null) {
      await PurchasesService.logIn(userId);
      await PushService.registerToken((token) async {
        await _client.from('profiles').update({'fcm_token': token}).eq('id', userId);
      });
    }
  }

  Future<void> signOut() async {
    await PurchasesService.logOut();
    await _client.auth.signOut();
  }

  /// Deletes all of the user's rows via `on delete cascade` from
  /// `auth.users`, then the auth user itself. The client can't drop its
  /// own `auth.users` row directly (no client-side privilege for that) —
  /// this calls a `delete-account` edge function running with the
  /// service role, invoked with the user's own access token.
  Future<void> deleteAccount() async {
    await _client.functions.invoke('delete-account');
    await signOut();
  }
}
