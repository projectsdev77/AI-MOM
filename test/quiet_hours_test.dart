import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ai_mom/core/theme/app_theme.dart';
import 'package:ai_mom/core/utils/quiet_hours.dart';
import 'package:ai_mom/features/settings/quiet_hours_dialog.dart';

void main() {
  group('hours and labels', () {
    test('12-hour clock text', () {
      expect(formatHour(0), '12 AM');
      expect(formatHour(7), '7 AM');
      expect(formatHour(11), '11 AM');
      expect(formatHour(12), '12 PM');
      expect(formatHour(13), '1 PM');
      expect(formatHour(22), '10 PM');
      expect(formatHour(23), '11 PM');
    });

    test('the Settings label', () {
      expect(quietHoursLabel(enabled: true, from: 22, until: 7), '10 PM – 7 AM');
      expect(quietHoursLabel(enabled: true, from: 0, until: 5), '12 AM – 5 AM');
      expect(quietHoursLabel(enabled: false, from: 22, until: 7), 'Off');
      expect(quietHoursLabel(enabled: true, from: 9, until: 9), 'Off');
    });

    test('equal hours are only a problem while quiet hours are on', () {
      expect(isValidQuietWindow(enabled: true, from: 9, until: 9), isFalse);
      expect(isValidQuietWindow(enabled: false, from: 9, until: 9), isTrue);
      expect(isValidQuietWindow(enabled: true, from: 22, until: 7), isTrue);
    });

    test('the defaults match the server (22:00 to 07:00)', () {
      expect(defaultQuietFromHour, 22);
      expect(defaultQuietUntilHour, 7);
    });
  });

  group('the dialog', () {
    QuietHoursChoice? result;
    bool closed = false;

    Future<void> open(WidgetTester tester, {bool enabled = true, int from = 22, int until = 7}) async {
      result = null;
      closed = false;
      tester.view.physicalSize = const Size(1233, 2400);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showDialog<QuietHoursChoice>(
                  context: context,
                  builder: (_) => QuietHoursDialog(enabled: enabled, from: from, until: until),
                );
                closed = true;
              },
              child: const Text('open'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    Future<void> pickHour(WidgetTester tester, int dropdownIndex, String label) async {
      await tester.tap(find.byType(DropdownButton<int>).at(dropdownIndex));
      await tester.pumpAndSettle();
      // The list of hours is long, so scroll to the one wanted like a person would.
      final menu = find.byType(Scrollable).last;
      final item = find.descendant(of: menu, matching: find.text(label));
      // The menu opens at the current hour, so the one wanted may be above or below.
      try {
        await tester.scrollUntilVisible(item, 60, scrollable: menu, maxScrolls: 30);
      } on StateError {
        await tester.scrollUntilVisible(item, -60, scrollable: menu, maxScrolls: 60);
      }
      await tester.tap(item);
      await tester.pumpAndSettle();
    }

    testWidgets('shows what is saved now', (tester) async {
      await open(tester, from: 23, until: 6);
      expect(find.text('Quiet hours'), findsWidgets);
      expect(find.text('11 PM'), findsOneWidget);
      expect(find.text('6 AM'), findsOneWidget);
    });

    testWidgets('changing the times and saving returns them', (tester) async {
      await open(tester);
      await pickHour(tester, 0, '11 PM');
      await pickHour(tester, 1, '6 AM');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(closed, isTrue);
      expect(result!.enabled, isTrue);
      expect(result!.from, 23);
      expect(result!.until, 6);
    });

    testWidgets('midnight can be chosen', (tester) async {
      await open(tester);
      await pickHour(tester, 0, '12 AM');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(result!.from, 0, reason: 'hour 0 must survive, not be treated as "not set"');
    });

    testWidgets('two equal times cannot be saved', (tester) async {
      await open(tester);
      await pickHour(tester, 1, '10 PM'); // until = from
      expect(find.text('Pick two different times.'), findsOneWidget);
      final save = tester.widget<TextButton>(find.widgetWithText(TextButton, 'Save'));
      expect(save.onPressed, isNull);
    });

    testWidgets('switching it off allows saving and returns off', (tester) async {
      await open(tester);
      await tester.tap(find.byType(AnimatedContainer).first); // the toggle
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(result!.enabled, isFalse);
    });

    testWidgets('while off the hour pickers are disabled', (tester) async {
      await open(tester, enabled: false);
      final dropdown = tester.widget<DropdownButton<int>>(find.byType(DropdownButton<int>).first);
      expect(dropdown.onChanged, isNull);
    });

    testWidgets('cancel returns nothing', (tester) async {
      await open(tester);
      await pickHour(tester, 0, '1 AM');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(closed, isTrue);
      expect(result, isNull);
    });
  });
}
