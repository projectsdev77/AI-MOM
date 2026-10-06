import 'package:flutter_test/flutter_test.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'package:ai_mom/core/models/subscription_status.dart';

const _id = 'full_mom';

EntitlementInfo _entitlement({
  bool isActive = true,
  bool willRenew = true,
  String product = 'full_mom_yearly',
  String? expires = '2027-10-06T12:00:00Z',
  String? billingIssue,
  PeriodType period = PeriodType.normal,
  Store store = Store.playStore,
}) =>
    EntitlementInfo(
      _id,
      isActive,
      willRenew,
      '2026-10-06T12:00:00Z',
      '2026-10-06T12:00:00Z',
      product,
      true,
      expirationDate: expires,
      billingIssueDetectedAt: billingIssue,
      periodType: period,
      store: store,
    );

CustomerInfo _info(EntitlementInfo? e, {String? managementUrl}) => CustomerInfo(
      EntitlementInfos({_id: ?e}, {if (e != null && e.isActive) _id: e}),
      const {},
      const [],
      const [],
      const [],
      '2026-10-06T12:00:00Z',
      'user-1',
      const {},
      '2026-10-06T12:00:00Z',
      managementURL: managementUrl,
    );

SubscriptionStatus _status(EntitlementInfo? e, {String? url}) =>
    SubscriptionStatus.fromCustomerInfo(_info(e, managementUrl: url), entitlementId: _id);

void main() {
  group('reading RevenueCat customer info', () {
    test('no info yet, or no Full purchase ever: nothing to show', () {
      expect(SubscriptionStatus.fromCustomerInfo(null, entitlementId: _id).hasEntitlement, isFalse);
      final s = _status(null);
      expect(s.hasEntitlement, isFalse);
      expect(s.summary, isNull);
    });

    test('active yearly plan that renews', () {
      final s = _status(_entitlement());
      expect(s.isActive, isTrue);
      expect(s.planLabel, 'Yearly');
      expect(s.summary, startsWith('Renews '));
      expect(s.summary, contains('2027'));
      expect(s.planTitle(isFull: true), 'Full Mom · Yearly');
    });

    test('monthly is recognised', () {
      expect(_status(_entitlement(product: 'full_mom_monthly')).planLabel, 'Monthly');
      expect(_status(_entitlement(product: 'full_mom:monthly-base')).planLabel, 'Monthly');
      expect(_status(_entitlement(product: 'something_else')).planLabel, isNull);
      expect(_status(_entitlement(product: 'something_else')).planTitle(isFull: true), 'Full Mom');
    });

    test('cancelled but still paid up: says when it ends, not that it renews', () {
      final s = _status(_entitlement(willRenew: false));
      expect(s.isActive, isTrue);
      expect(s.summary, startsWith('Ends '));
      expect(s.summary, contains("won't renew"));
    });

    test('payment problem is called out', () {
      final s = _status(_entitlement(billingIssue: '2026-10-07T00:00:00Z'));
      expect(s.billingIssue, isTrue);
      expect(s.summary, contains('Payment problem'));
    });

    test('free trial wording', () {
      expect(_status(_entitlement(period: PeriodType.trial)).summary, startsWith('Free trial — first payment'));
      expect(_status(_entitlement(period: PeriodType.trial, willRenew: false)).summary, startsWith('Free trial ends'));
    });

    test('an ended plan says so and is no longer active', () {
      final s = _status(_entitlement(isActive: false, willRenew: false, expires: '2026-09-01T12:00:00Z'));
      expect(s.hasEntitlement, isTrue);
      expect(s.isActive, isFalse);
      expect(s.summary, startsWith('Your Full plan ended Sep'));
      expect(s.planTitle(isFull: false), 'Basic Mom');
    });

    test('a plan with no end date (promo / lifetime) just says Active', () {
      expect(_status(_entitlement(expires: null)).summary, 'Active');
    });

    test('test store purchases are recognised', () {
      expect(_status(_entitlement(store: Store.testStore)).isTestPurchase, isTrue);
      expect(_status(_entitlement()).isTestPurchase, isFalse);
    });
  });

  group('what Manage subscription does', () {
    ManageAction act(SubscriptionStatus s, {bool isFull = true, bool isWeb = false}) =>
        decideManageAction(s, isFull: isFull, isWeb: isWeb);

    test('free user who never subscribed goes to the plans', () {
      expect(act(SubscriptionStatus.none, isFull: false), ManageAction.upgrade);
    });

    test('ended plan goes to the plans so they can come back', () {
      expect(act(_status(_entitlement(isActive: false, willRenew: false)), isFull: false), ManageAction.upgrade);
    });

    test('a real store subscription opens the store', () {
      expect(act(_status(_entitlement())), ManageAction.openStore);
      expect(act(_status(_entitlement(store: Store.appStore))), ManageAction.openStore);
    });

    test('a cancelled-but-active plan still opens the store (to undo the cancel)', () {
      expect(act(_status(_entitlement(willRenew: false))), ManageAction.openStore);
    });

    test('test store purchase explains there is no store page', () {
      expect(act(_status(_entitlement(store: Store.testStore))), ManageAction.testPurchase);
    });

    test('Full plan set by hand or by promo has nothing to open', () {
      expect(act(SubscriptionStatus.none, isFull: true), ManageAction.notStoreBacked);
      expect(act(_status(_entitlement(store: Store.promotional))), ManageAction.notStoreBacked);
    });

    test('web has no store', () {
      expect(act(_status(_entitlement()), isWeb: true), ManageAction.unavailable);
    });
  });

  group('where the store link goes', () {
    test("uses RevenueCat's link to this exact subscription when there is one", () {
      final s = _status(_entitlement(), url: 'https://play.google.com/store/account/subscriptions?sku=x&package=y');
      expect(storeSubscriptionsUrl(s, isIOS: false), 'https://play.google.com/store/account/subscriptions?sku=x&package=y');
    });

    test('otherwise falls back to the general page for the platform', () {
      final s = _status(_entitlement());
      expect(storeSubscriptionsUrl(s, isIOS: false), 'https://play.google.com/store/account/subscriptions');
      expect(storeSubscriptionsUrl(s, isIOS: true), 'itms-apps://apps.apple.com/account/subscriptions');
    });
  });

  test('restore messages', () {
    expect(restoreResultMessage(restoredFull: true), contains('restored'));
    expect(restoreResultMessage(restoredFull: false), contains("couldn't find"));
  });
}
