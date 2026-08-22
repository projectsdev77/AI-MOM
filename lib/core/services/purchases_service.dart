import 'dart:io';

import 'package:purchases_flutter/purchases_flutter.dart';

import '../config/env.dart';

/// RevenueCat wraps Apple/Google IAP behind one API — see the "why not
/// Stripe" note in the planning doc: subscriptions consumed inside the
/// app must go through StoreKit/Play Billing, not a card processor.
class PurchasesService {
  PurchasesService._();

  /// Entitlement identifier configured in the RevenueCat dashboard for
  /// the Full Mom Experience tier.
  static const fullEntitlementId = 'full_mom';

  static Future<void> init() async {
    final apiKey = Platform.isIOS ? Env.revenueCatIosKey : Env.revenueCatAndroidKey;
    if (apiKey.isEmpty) return; // allows local dev without a RevenueCat project yet

    await Purchases.setLogLevel(LogLevel.info);
    await Purchases.configure(PurchasesConfiguration(apiKey));
  }

  static Future<void> logIn(String supabaseUserId) async {
    if (await Purchases.isConfigured) {
      await Purchases.logIn(supabaseUserId);
    }
  }

  static Future<void> logOut() async {
    if (await Purchases.isConfigured) {
      await Purchases.logOut();
    }
  }

  static bool hasFullEntitlement(CustomerInfo info) =>
      info.entitlements.active.containsKey(fullEntitlementId);

  static Future<void> restorePurchases() => Purchases.restorePurchases();
}
