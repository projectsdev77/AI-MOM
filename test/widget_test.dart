import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:ai_mom/app.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    // A local, unreachable project is enough to construct the client —
    // the app never awaits a network call before rendering onboarding.
    await Supabase.initialize(
      url: 'http://localhost:54321',
      publishableKey: 'test-anon-key',
    );
  });

  testWidgets('App boots into onboarding', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: AiMomApp()));
    await tester.pumpAndSettle();

    expect(find.text('Meet your Mom'), findsOneWidget);
  });
}
