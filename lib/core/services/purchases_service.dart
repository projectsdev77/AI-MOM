import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb, kReleaseMode;
import 'package:purchases_flutter/purchases_flutter.dart';

import '../config/env.dart';

/// Whether a RevenueCat key can be used in this kind of build. RevenueCat's
/// Test Store keys (`test_...`) deliberately close the app with a "Wrong API
/// Key" popup when used in a release build, so a release build ignores one and
/// runs without purchases instead of dying on launch. A real `goog_...` /
/// `appl_...` key, or any key in a debug build, is fine.
bool isUsableRevenueCatKey(String key, {required bool isRelease}) =>
    key.isNotEmpty && !(isRelease && key.startsWith('test_'));

/// RevenueCat wraps Apple/Google IAP behind one API — see the "why not
/// Stripe" note in the planning doc: subscriptions consumed inside the
/// app must go through StoreKit/Play Billing, not a card processor.
class PurchasesService {
  PurchasesService._();

  /// Entitlement identifier configured in the RevenueCat dashboard for
  /// the Full Mom Experience tier.
  static const fullEntitlementId = 'full_mom';

  /// RevenueCat wraps Apple/Google in-app purchases — there is no such
  /// thing on the web (no App Store or Play Store to buy through), and
  /// `dart:io`'s `Platform.isIOS`/`isAndroid` throw on web rather than
  /// just returning false, so every method here has to check [kIsWeb]
  /// before touching `Platform` or the plugin at all.

  static String get _platformKey => Platform.isIOS ? Env.revenueCatIosKey : Env.revenueCatAndroidKey;

  /// True when this build has a RevenueCat key it is allowed to use.
  static bool get hasUsableKey {
    if (kIsWeb) return false;
    return isUsableRevenueCatKey(_platformKey, isRelease: kReleaseMode);
  }

  static Future<void> init() async {
    if (kIsWeb) return;
    final apiKey = _platformKey;
    if (!isUsableRevenueCatKey(apiKey, isRelease: kReleaseMode)) {
      // No key yet (local dev), or a test key in a release build: run without
      // purchases rather than configure RevenueCat.
      if (apiKey.isNotEmpty) debugPrint('RevenueCat: ignoring a test key in a release build; purchases are off.');
      return;
    }

    await Purchases.setLogLevel(LogLevel.info);
    await Purchases.configure(PurchasesConfiguration(apiKey));
  }

  static Future<void> logIn(String supabaseUserId) async {
    if (kIsWeb) return;
    if (await Purchases.isConfigured) {
      await Purchases.logIn(supabaseUserId);
    }
  }

  static Future<void> logOut() async {
    if (kIsWeb) return;
    if (await Purchases.isConfigured) {
      await Purchases.logOut();
    }
  }

  static bool hasFullEntitlement(CustomerInfo info) =>
      info.entitlements.active.containsKey(fullEntitlementId);

  /// Whether there is a store to talk to on this device (not web, and a
  /// RevenueCat key is set).
  static Future<bool> get isAvailable async => !kIsWeb && await Purchases.isConfigured;

  /// Fetches the latest purchase state from RevenueCat, skipping its cache.
  /// Changes (a purchase, a cancel or a refund made outside the app) reach the
  /// app through the customer-info listener, so nothing is returned here.
  static Future<void> refreshCustomerInfo() async {
    if (!await isAvailable) return;
    await Purchases.invalidateCustomerInfoCache();
    await Purchases.getCustomerInfo();
  }

  /// Asks the store for this account's past purchases. Returns whether the
  /// Full plan is now active. Throws if the store can't be reached.
  static Future<bool> restorePurchases() async {
    final info = await Purchases.restorePurchases();
    return hasFullEntitlement(info);
  }

  /// The current offering's packages (e.g. monthly/annual Full Mom
  /// plans) to show on the plan-selection page — `null` when there's
  /// nothing real to sell yet: web, no RevenueCat project configured,
  /// or no offering set up in the RevenueCat dashboard.
  static Future<Offering?> fetchCurrentOffering() async {
    if (kIsWeb) return null;
    if (!await Purchases.isConfigured) return null;
    try {
      final offerings = await Purchases.getOfferings();
      return offerings.current;
    } catch (_) {
      return null;
    }
  }

  static Future<void> purchasePackage(Package package) async {
    await Purchases.purchase(PurchaseParams.package(package));
  }
}
