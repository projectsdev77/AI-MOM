import 'package:intl/intl.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// What the Settings > Subscription section needs to know about the user's
/// Full plan, read from RevenueCat's customer info. Kept apart from the
/// widgets so the wording and the "what does Manage do" decision can be
/// tested without a screen or a store.
class SubscriptionStatus {
  const SubscriptionStatus({
    this.hasEntitlement = false,
    this.isActive = false,
    this.planLabel,
    this.expiresAt,
    this.willRenew = false,
    this.billingIssue = false,
    this.inTrial = false,
    this.store,
    this.managementUrl,
  });

  /// No Full-plan purchase on record at all.
  static const none = SubscriptionStatus();

  /// RevenueCat has (or once had) the Full entitlement for this user.
  final bool hasEntitlement;

  /// The entitlement is switched on right now.
  final bool isActive;

  /// "Monthly" / "Yearly" and so on, worked out from the product id.
  final String? planLabel;
  final DateTime? expiresAt;
  final bool willRenew;

  /// The store could not take payment (the plan can still be active for a
  /// grace period).
  final bool billingIssue;
  final bool inTrial;
  final Store? store;

  /// The store's own page for this exact subscription, when RevenueCat has one.
  final String? managementUrl;

  bool get isTestPurchase => store == Store.testStore;

  factory SubscriptionStatus.fromCustomerInfo(CustomerInfo? info, {required String entitlementId}) {
    final entitlement = info?.entitlements.all[entitlementId];
    if (info == null || entitlement == null) return none;
    return SubscriptionStatus(
      hasEntitlement: true,
      isActive: entitlement.isActive,
      planLabel: _labelFor(entitlement.productIdentifier, entitlement.productPlanIdentifier),
      expiresAt: DateTime.tryParse(entitlement.expirationDate ?? '')?.toLocal(),
      willRenew: entitlement.willRenew,
      billingIssue: entitlement.billingIssueDetectedAt != null,
      inTrial: entitlement.periodType == PeriodType.trial,
      store: entitlement.store,
      managementUrl: info.managementURL,
    );
  }

  static String? _labelFor(String productId, String? planId) {
    final id = '$productId ${planId ?? ''}'.toLowerCase();
    if (id.contains('life')) return 'Lifetime';
    if (id.contains('year') || id.contains('annual')) return 'Yearly';
    if (id.contains('month')) return 'Monthly';
    if (id.contains('week')) return 'Weekly';
    return null;
  }

  static String _date(DateTime d) => DateFormat('MMM d, yyyy').format(d);

  /// One line under "Current plan". `null` when there is nothing to say
  /// (a free user who never subscribed).
  String? get summary {
    if (!hasEntitlement) return null;
    final date = expiresAt == null ? null : _date(expiresAt!);
    if (!isActive) return date == null ? 'Your Full plan has ended' : 'Your Full plan ended $date';
    if (billingIssue) return 'Payment problem — please update your payment method';
    if (date == null) return 'Active';
    if (inTrial) return willRenew ? 'Free trial — first payment $date' : 'Free trial ends $date';
    return willRenew ? 'Renews $date' : "Ends $date — won't renew";
  }

  /// "Full Mom · Yearly" / "Basic Mom".
  String planTitle({required bool isFull}) {
    if (!isFull) return 'Basic Mom';
    return planLabel == null || !isActive ? 'Full Mom' : 'Full Mom · $planLabel';
  }
}

/// What tapping "Manage subscription" (or "Current plan") should do.
enum ManageAction {
  /// Nothing to manage yet — show the plans instead.
  upgrade,

  /// Open the store's subscription page.
  openStore,

  /// A RevenueCat Test Store purchase: there is no store page to open.
  testPurchase,

  /// Full plan, but not from a store purchase (given by hand or a promo).
  notStoreBacked,

  /// This device has no store (web).
  unavailable,
}

ManageAction decideManageAction(SubscriptionStatus status, {required bool isFull, required bool isWeb}) {
  if (isWeb) return ManageAction.unavailable;
  if (!status.hasEntitlement || !status.isActive) {
    // Never subscribed, or it ended: the useful next step is to pick a plan.
    // A Full plan with no purchase behind it was set by hand.
    return isFull ? ManageAction.notStoreBacked : ManageAction.upgrade;
  }
  if (status.isTestPurchase) return ManageAction.testPurchase;
  if (status.store == Store.promotional) return ManageAction.notStoreBacked;
  return ManageAction.openStore;
}

/// Where to send the user: the exact subscription page when RevenueCat knows
/// it, otherwise the store's general subscriptions page.
String storeSubscriptionsUrl(SubscriptionStatus status, {required bool isIOS}) {
  final own = status.managementUrl;
  if (own != null && own.isNotEmpty) return own;
  return isIOS ? 'itms-apps://apps.apple.com/account/subscriptions' : 'https://play.google.com/store/account/subscriptions';
}

/// The message after "Restore purchases". [wasAlreadyFull] is whether the Full
/// plan was already active before the tap — then nothing was lost, so it must
/// not say "restored".
String restoreResultMessage({required bool restoredFull, bool wasAlreadyFull = false}) {
  if (!restoredFull) return "We couldn't find a Full plan purchase to restore on this account.";
  if (wasAlreadyFull) return "You're all set — your Full plan is already active.";
  return 'Welcome back — your Full plan is restored.';
}
