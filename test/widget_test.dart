import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ai_mom/app.dart';

void main() {
  testWidgets('App boots into onboarding', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: AiMomApp()));
    await tester.pumpAndSettle();

    expect(find.text('Meet your Mom'), findsOneWidget);
  });
}
