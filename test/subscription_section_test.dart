import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'package:ai_mom/core/models/plan.dart';
import 'package:ai_mom/core/models/subscription_status.dart';
import 'package:ai_mom/core/providers/service_providers.dart';
import 'package:ai_mom/core/theme/app_theme.dart';
import 'package:ai_mom/features/settings/settings_screen.dart';

const _channel = MethodChannel('purchases_flutter');

Map<String, Object?> _entitlement({String store = 'PLAY_STORE', bool active = true}) => {
      'identifier': 'full_mom',
      'isActive': active,
      'willRenew': true,
      'latestPurchaseDate': '2026-10-06T12:00:00Z',
      'originalPurchaseDate': '2026-10-06T12:00:00Z',
      'productIdentifier': 'full_mom_yearly',
      'isSandbox': true,
      'ownershipType': 'PURCHASED',
      'store': store,
      'periodType': 'NORMAL',
      'expirationDate': '2027-10-06T12:00:00Z',
    };

Map<String, Object?> _customer({bool full = false, String store = 'PLAY_STORE'}) => {
      'entitlements': {
        'all': {if (full) 'full_mom': _entitlement(store: store)},
        'active': {if (full) 'full_mom': _entitlement(store: store)},
      },
      'allPurchaseDates': <String, Object?>{},
      'activeSubscriptions': <String>[],
      'allPurchasedProductIdentifiers': <String>[],
      'nonSubscriptionTransactions': <Object?>[],
      'firstSeen': '2026-10-06T12:00:00Z',
      'originalAppUserId': 'user-1',
      'allExpirationDates': <String, Object?>{},
      'requestDate': '2026-10-06T12:00:00Z',
    };

/// Pretends to be the RevenueCat plugin. [restoreResult] is what the store
/// hands back when asked to restore; [restoreGate] lets a test hold it open.
void _fakeRevenueCat({
  required bool configured,
  Map<String, Object?>? restoreResult,
  Future<void>? restoreGate,
  Object? restoreError,
}) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, (call) async {
    switch (call.method) {
      case 'isConfigured':
        return configured;
      case 'restorePurchases':
        await restoreGate;
        if (restoreError != null) throw PlatformException(code: 'x', message: '$restoreError');
        return restoreResult;
    }
    return null;
  });
  addTearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_channel, null));
}

SubscriptionStatus _statusOf(Map<String, Object?> customer) =>
    SubscriptionStatus.fromCustomerInfo(CustomerInfo.fromJson(customer), entitlementId: 'full_mom');

Future<void> _pump(WidgetTester tester, {required AppPlan plan, SubscriptionStatus status = SubscriptionStatus.none}) async {
  tester.view.physicalSize = const Size(1233, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final router = GoRouter(routes: [
    GoRoute(path: '/', builder: (_, _) => const Scaffold(body: SingleChildScrollView(child: SubscriptionGroup()))),
    GoRoute(path: '/upgrade', builder: (_, _) => const Scaffold(body: Text('UPGRADE PAGE'))),
  ]);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      planProvider.overrideWithValue(plan),
      subscriptionStatusProvider.overrideWithValue(status),
    ],
    child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
  ));
  await tester.pumpAndSettle();
}

void main() {
  group('Current plan', () {
    testWidgets('free user: shows Basic Mom and no status line', (tester) async {
      await _pump(tester, plan: AppPlan.basic);
      expect(find.text('Basic Mom'), findsOneWidget);
      expect(find.textContaining('Renews'), findsNothing);
    });

    testWidgets('paying user: shows the plan and when it renews', (tester) async {
      await _pump(tester, plan: AppPlan.full, status: _statusOf(_customer(full: true)));
      expect(find.text('Full Mom · Yearly'), findsOneWidget);
      expect(find.textContaining('Renews'), findsOneWidget);
      expect(find.textContaining('2027'), findsOneWidget);
    });

    testWidgets('free user tapping it is taken to the plans', (tester) async {
      await _pump(tester, plan: AppPlan.basic);
      await tester.tap(find.text('Current plan'));
      await tester.pumpAndSettle();
      expect(find.text('UPGRADE PAGE'), findsOneWidget);
    });
  });

  group('Manage subscription', () {
    testWidgets('free user is taken to the plans', (tester) async {
      await _pump(tester, plan: AppPlan.basic);
      await tester.tap(find.text('Manage subscription'));
      await tester.pumpAndSettle();
      expect(find.text('UPGRADE PAGE'), findsOneWidget);
    });

    testWidgets('a test-store purchase explains there is no store page', (tester) async {
      await _pump(tester, plan: AppPlan.full, status: _statusOf(_customer(full: true, store: 'TEST_STORE')));
      await tester.tap(find.text('Manage subscription'));
      await tester.pumpAndSettle();
      expect(find.text('Test purchase'), findsOneWidget);
      expect(find.textContaining('no App Store or Play Store subscription'), findsOneWidget);
    });

    testWidgets('a Full plan with no purchase behind it says so, instead of doing nothing', (tester) async {
      await _pump(tester, plan: AppPlan.full);
      await tester.tap(find.text('Manage subscription'));
      await tester.pumpAndSettle();
      expect(find.textContaining("isn't tied to a store subscription"), findsOneWidget);
    });
  });

  group('Restore purchases', () {
    testWidgets('shows a spinner while working, then says the plan is restored', (tester) async {
      final gate = Completer<void>();
      _fakeRevenueCat(configured: true, restoreResult: _customer(full: true), restoreGate: gate.future);
      await _pump(tester, plan: AppPlan.basic);

      await tester.tap(find.text('Restore purchases'));
      await tester.pump();
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // A second tap while it is working does not start another restore.
      await tester.tap(find.text('Restore purchases'), warnIfMissed: false);
      await tester.pump();

      gate.complete();
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Welcome back — your Full plan is restored.'), findsOneWidget);
    });

    testWidgets('already subscribed: says it is active, never "restored"', (tester) async {
      _fakeRevenueCat(configured: true, restoreResult: _customer(full: true));
      await _pump(tester, plan: AppPlan.full, status: _statusOf(_customer(full: true)));
      await tester.tap(find.text('Restore purchases'));
      await tester.pumpAndSettle();
      expect(find.text("You're all set — your Full plan is already active."), findsOneWidget);
      expect(find.textContaining('restored'), findsNothing);
    });

    testWidgets('nothing to restore: says so', (tester) async {
      _fakeRevenueCat(configured: true, restoreResult: _customer(full: false));
      await _pump(tester, plan: AppPlan.basic);
      await tester.tap(find.text('Restore purchases'));
      await tester.pumpAndSettle();
      expect(find.textContaining("couldn't find a Full plan purchase"), findsOneWidget);
    });

    testWidgets('store unreachable: a plain error, and the button works again', (tester) async {
      _fakeRevenueCat(configured: true, restoreError: 'SocketException: Failed host lookup');
      await _pump(tester, plan: AppPlan.basic);
      await tester.tap(find.text('Restore purchases'));
      await tester.pumpAndSettle();
      expect(find.textContaining("Couldn't connect"), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('no RevenueCat set up on this device: says purchases are unavailable', (tester) async {
      _fakeRevenueCat(configured: false);
      await _pump(tester, plan: AppPlan.basic);
      await tester.tap(find.text('Restore purchases'));
      await tester.pumpAndSettle();
      expect(find.text("Purchases aren't available on this device."), findsOneWidget);
    });
  });
}
