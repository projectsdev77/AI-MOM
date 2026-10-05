import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:ai_mom/core/providers/service_providers.dart';
import 'package:ai_mom/core/repositories/profile_repository.dart';
import 'package:ai_mom/core/services/auth_service.dart';
import 'package:ai_mom/core/theme/app_theme.dart';
import 'package:ai_mom/core/widgets/mom_avatar.dart';
import 'package:ai_mom/features/onboarding/onboarding_flow.dart';

const _user = User(
  id: 'user-1',
  appMetadata: {},
  userMetadata: {},
  aud: 'authenticated',
  createdAt: '2026-01-01T00:00:00Z',
);

/// Stands in for Supabase: when [requireConfirmation] is true, signing up
/// creates no session until the right code (123456) is entered, like a project
/// with "Confirm email" switched on.
class _FakeAuth implements AuthService {
  _FakeAuth({required this.requireConfirmation});

  final bool requireConfirmation;
  final calls = <String>[];
  User? signedInUser;

  @override
  User? get currentUser => signedInUser;

  @override
  Future<bool> signUpWithEmail({required String email, required String password, required String name}) async {
    calls.add('signUp:$email');
    if (requireConfirmation) return false;
    signedInUser = _user;
    return true;
  }

  @override
  Future<void> signInWithEmail({required String email, required String password}) async {
    calls.add('signIn:$email');
    throw const AuthException('Email not confirmed', code: 'email_not_confirmed');
  }

  @override
  Future<void> verifyEmailCode({required String email, required String code}) async {
    calls.add('verify:$code');
    if (code != '123456') {
      throw const AuthException('Token has expired or is invalid', statusCode: '403', code: 'otp_expired');
    }
    signedInUser = _user;
  }

  @override
  Future<void> resendEmailCode(String email) async => calls.add('resend:$email');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeProfiles implements ProfileRepository {
  Map<String, Object?>? saved;

  @override
  Future<void> saveOnboardingAnswers({
    required String userId,
    required String momAvatarStyle,
    required List<String> goals,
    required List<String> procrastinationAreas,
    required String checkInFrequency,
    String? name,
    String? dailyRoutine,
    String? livingSituation,
    String? motivationStyle,
    String? currentStressor,
  }) async {
    saved = {
      'userId': userId,
      'name': name,
      'goals': goals,
      'procrastinationAreas': procrastinationAreas,
      'checkInFrequency': checkInFrequency,
      'dailyRoutine': dailyRoutine,
      'livingSituation': livingSituation,
      'motivationStyle': motivationStyle,
    };
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Tests can't download the app's real font, so every letter is drawn as a
/// wide square block and rows of text overflow by a few pixels. That's an
/// artefact of the test, not a layout problem, so those reports are skipped.
void _ignoreTestFontOverflow() {
  final original = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.exceptionAsString().contains('overflowed')) return;
    original?.call(details);
  };
  addTearDown(() => FlutterError.onError = original);
}

Future<void> _pumpOnboarding(WidgetTester tester, _FakeAuth auth, _FakeProfiles profiles) async {
  _ignoreTestFontOverflow();
  // 411 x 800 logical pixels, like the Pixel emulator.
  tester.view.physicalSize = const Size(1233, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authServiceProvider.overrideWithValue(auth),
        profileRepositoryProvider.overrideWithValue(profiles),
      ],
      child: MaterialApp(theme: AppTheme.light(), home: const OnboardingFlow()),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _continue(WidgetTester tester) async {
  await tester.tap(find.text('Continue'));
  await tester.pumpAndSettle();
}

/// Single-choice steps move on by themselves after a short pause.
Future<void> _pick(WidgetTester tester, String label, {int pauseMs = 700}) async {
  await tester.tap(find.text(label));
  await tester.pump(Duration(milliseconds: pauseMs + 100));
  await tester.pumpAndSettle();
}

/// Answers every onboarding question and ends on the account step.
Future<void> _walkToAccountStep(WidgetTester tester) async {
  await tester.tap(find.byWidgetPredicate((w) => w is MomAvatar && w.size == 60).first);
  await tester.pump();
  await _continue(tester);
  await tester.enterText(find.byType(TextField), 'Meaza');
  await tester.pump(const Duration(seconds: 2));
  await _continue(tester);
  await tester.tap(find.text('Build habits'));
  await tester.pump();
  await _continue(tester);
  await tester.tap(find.text('Exercise'));
  await tester.pump();
  await _continue(tester);
  await _pick(tester, 'Early riser');
  await _pick(tester, 'On my own');
  await _pick(tester, 'A mix of both', pauseMs: 1800);
  await _continue(tester);
  await _pick(tester, 'Once a day', pauseMs: 1800);
}

Finder _field(String hint) => find.byWidgetPredicate(
      (w) => w is TextField && (w.decoration?.hintText ?? '').startsWith(hint),
    );

Future<void> _fillAccount(WidgetTester tester) async {
  await tester.enterText(_field('Email'), 'meaza@example.com');
  await tester.enterText(_field('Password'), 'Str0ng!Pass');
  await tester.pump();
}

VoidCallback? _onPressed(WidgetTester tester, Finder button) => tester.widget<ElevatedButton>(button).onPressed;

void main() {
  testWidgets('with confirmation on: asks for a code, then saves the onboarding answers once it is right', (tester) async {
    final auth = _FakeAuth(requireConfirmation: true);
    final profiles = _FakeProfiles();
    await _pumpOnboarding(tester, auth, profiles);
    await _walkToAccountStep(tester);
    await _fillAccount(tester);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Create account'));
    await tester.pumpAndSettle();

    // No session, no saved answers, and the code box is showing.
    expect(find.text('Check your email'), findsOneWidget);
    expect(find.textContaining('meaza@example.com'), findsOneWidget);
    expect(auth.signedInUser, isNull);
    expect(profiles.saved, isNull);

    final verify = find.widgetWithText(ElevatedButton, 'Verify and continue');
    expect(_onPressed(tester, verify), isNull, reason: 'no code typed yet');
    await tester.enterText(find.byType(TextField), '12345');
    await tester.pump();
    expect(_onPressed(tester, verify), isNull, reason: 'a code needs at least 6 digits');

    // Letters are not accepted into the box at all.
    await tester.enterText(find.byType(TextField), '12ab34');
    await tester.pump();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, '1234');

    // Resend is held back for the first minute, then works, then waits again.
    final resendWait = find.widgetWithText(TextButton, 'Resend code in 60s');
    expect(tester.widget<TextButton>(resendWait).onPressed, isNull);
    await tester.pump(const Duration(seconds: 61));
    final resend = find.widgetWithText(TextButton, 'Resend code');
    expect(tester.widget<TextButton>(resend).onPressed, isNotNull);
    await tester.tap(resend);
    await tester.pump();
    expect(auth.calls, contains('resend:meaza@example.com'));
    expect(find.text('Resend code in 60s'), findsOneWidget);
    await tester.pump(const Duration(seconds: 61)); // let the wait finish, so no timer is left running

    // A wrong code shows a plain message and signs nobody in.
    await tester.enterText(find.byType(TextField), '000000');
    await tester.pump();
    await tester.tap(verify);
    await tester.pumpAndSettle();
    expect(find.text("That code or link has expired or isn't valid — request a new one."), findsOneWidget);
    expect(auth.signedInUser, isNull);
    expect(profiles.saved, isNull);

    // The right code signs in AND saves everything typed during onboarding.
    await tester.enterText(find.byType(TextField), '123456');
    await tester.pump();
    await tester.tap(verify);
    await tester.pumpAndSettle();
    expect(auth.signedInUser, isNotNull);
    expect(profiles.saved, isNotNull);
    expect(profiles.saved!['name'], 'Meaza');
    expect(profiles.saved!['goals'], ['Build habits']);
    expect(profiles.saved!['procrastinationAreas'], ['Exercise']);
    expect(profiles.saved!['dailyRoutine'], 'Early riser');
    expect(profiles.saved!['livingSituation'], 'On my own');
    expect(profiles.saved!['motivationStyle'], 'A mix of both');
    expect(profiles.saved!['checkInFrequency'], 'Once a day');
  });

  testWidgets('"Wrong email?" goes back to the form with what was typed', (tester) async {
    final auth = _FakeAuth(requireConfirmation: true);
    await _pumpOnboarding(tester, auth, _FakeProfiles());
    await _walkToAccountStep(tester);
    await _fillAccount(tester);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Create account'));
    await tester.pumpAndSettle();
    expect(find.text('Check your email'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Wrong email?'));
    await tester.pumpAndSettle();

    expect(find.text('Create your account'), findsOneWidget);
    expect(tester.widget<TextField>(_field('Email')).controller!.text, 'meaza@example.com');
    // Nothing was left counting down in the background.
    await tester.pump(const Duration(seconds: 61));
  });

  testWidgets('with confirmation off: signs in straight away and saves, no code asked for', (tester) async {
    final auth = _FakeAuth(requireConfirmation: false);
    final profiles = _FakeProfiles();
    await _pumpOnboarding(tester, auth, profiles);
    await _walkToAccountStep(tester);
    await _fillAccount(tester);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Create account'));
    await tester.pumpAndSettle();

    expect(find.text('Check your email'), findsNothing);
    expect(auth.signedInUser, isNotNull);
    expect(profiles.saved!['name'], 'Meaza');
  });

  testWidgets('logging in to an account that never confirmed sends a new code instead of a dead end', (tester) async {
    final auth = _FakeAuth(requireConfirmation: true);
    final profiles = _FakeProfiles();
    await _pumpOnboarding(tester, auth, profiles);

    await tester.tapOnText(find.textRange.ofSubstring('Log in'));
    await tester.pumpAndSettle();
    await _fillAccount(tester);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Log in'));
    await tester.pumpAndSettle();

    expect(auth.calls, contains('signIn:meaza@example.com'));
    expect(auth.calls, contains('resend:meaza@example.com'));
    expect(find.text('Check your email'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '123456');
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Verify and continue'));
    await tester.pumpAndSettle();

    expect(auth.signedInUser, isNotNull);
    // This pass's answers are blank, so nothing may be written over the account.
    expect(profiles.saved, isNull);
    await tester.pump(const Duration(seconds: 61));
  });
}
