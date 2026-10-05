import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ai_mom/core/theme/app_theme.dart';
import 'package:ai_mom/core/widgets/mom_avatar.dart';
import 'package:ai_mom/features/onboarding/onboarding_flow.dart';

// The first onboarding screen's row of avatars to pick from sits inside 20
// pixels of padding on each side of the screen. Each avatar is drawn inside a
// ring that adds 5 pixels all round.
const _sidePadding = 20.0;
const _ring = 5.0;

Future<void> _pumpAt(WidgetTester tester, double width) async {
  tester.view.physicalSize = Size(width * 3, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  // Tests draw text with a wide placeholder font, so unrelated text rows can
  // report overflow; this test measures the avatars directly instead.
  final original = FlutterError.onError;
  FlutterError.onError = (details) {
    if (details.exceptionAsString().contains('overflowed')) return;
    original?.call(details);
  };
  addTearDown(() => FlutterError.onError = original);

  await tester.pumpWidget(
    ProviderScope(child: MaterialApp(theme: AppTheme.light(), home: const OnboardingFlow())),
  );
  await tester.pumpAndSettle();
}

/// The picker's avatars, left to right. (The big one above the sheet is much larger.)
List<Rect> _pickerRects(WidgetTester tester) {
  final finder = find.byWidgetPredicate((w) => w is MomAvatar && w.size <= 60);
  final rects = [for (var i = 0; i < finder.evaluate().length; i++) tester.getRect(finder.at(i))];
  rects.sort((a, b) => a.left.compareTo(b.left));
  return rects;
}

void main() {
  for (final width in [320.0, 360.0, 375.0, 393.0, 411.0, 600.0]) {
    testWidgets('all 5 avatars fit on screen, without overlapping, at $width wide', (tester) async {
      await _pumpAt(tester, width);
      final rects = _pickerRects(tester);

      expect(rects.length, 5);
      expect(rects.first.left - _ring, greaterThanOrEqualTo(_sidePadding - 0.01), reason: 'first avatar inside the left edge');
      expect(rects.last.right + _ring, lessThanOrEqualTo(width - _sidePadding + 0.01), reason: 'last avatar inside the right edge');
      for (var i = 1; i < rects.length; i++) {
        expect(rects[i].left - _ring, greaterThanOrEqualTo(rects[i - 1].right + _ring - 0.01), reason: 'avatars $i and ${i - 1} overlap');
      }
    });
  }

  for (final width in [320.0, 360.0, 375.0, 393.0, 411.0, 600.0, 800.0, 1024.0]) {
    testWidgets('the avatar list is centred on the screen at $width wide', (tester) async {
      await _pumpAt(tester, width);
      final rects = _pickerRects(tester);
      final leftEdge = rects.first.left - _ring;
      final rightEdge = rects.last.right + _ring;

      // Same distance from each side of the screen, so the group sits in the middle.
      expect(leftEdge, closeTo(width - rightEdge, 0.5), reason: 'left margin $leftEdge vs right margin ${width - rightEdge}');
      expect((leftEdge + rightEdge) / 2, closeTo(width / 2, 0.5));
    });
  }

  testWidgets('on wide screens the avatars stay together instead of spreading to the edges', (tester) async {
    await _pumpAt(tester, 1024);
    final rects = _pickerRects(tester);
    expect(rects.last.right - rects.first.left, lessThanOrEqualTo(400));
  });

  for (final width in [411.0, 600.0, 1024.0]) {
    testWidgets('on a normal or wide screen ($width) the avatars keep their usual size', (tester) async {
      await _pumpAt(tester, width);
      for (final r in _pickerRects(tester)) {
        expect(r.width, 60);
      }
    });
  }

  testWidgets('on a narrow phone they shrink but stay a comfortable size to tap', (tester) async {
    await _pumpAt(tester, 360);
    for (final r in _pickerRects(tester)) {
      expect(r.width, inInclusiveRange(44, 60));
    }
  });

  testWidgets('picking an avatar still works at a narrow width', (tester) async {
    await _pumpAt(tester, 360);
    final before = find.widgetWithText(ElevatedButton, 'Continue');
    expect(tester.widget<ElevatedButton>(before).onPressed, isNull, reason: 'nothing picked yet');
    await tester.tap(find.byWidgetPredicate((w) => w is MomAvatar && w.size <= 60).at(3));
    await tester.pump();
    expect(tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Continue')).onPressed, isNotNull);
  });
}
