import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Display symbol only — this doesn't convert amounts, it just changes
/// how they're shown (the same way most budgeting apps treat currency
/// unless they've integrated live FX rates, which is out of scope
/// here). Persisted locally per device via SharedPreferences.
const currencySymbols = {
  'USD': '\$',
  'EUR': '€',
  'GBP': '£',
  'CAD': 'CA\$',
  'AUD': 'A\$',
  'INR': '₹',
};

const _prefsKey = 'currency_code';

/// Overridden at app startup (see main.dart) with whatever was saved
/// last time — defaults to USD before that override lands.
final currencyProvider = StateProvider<String>((ref) => 'USD');

Future<String> loadSavedCurrency() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString(_prefsKey) ?? 'USD';
}

Future<void> saveCurrency(String code) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_prefsKey, code);
}

String currencySymbolFor(String code) => currencySymbols[code] ?? '\$';

String formatMoney(int cents, String currencyCode) {
  return '${currencySymbolFor(currencyCode)}${(cents / 100).toStringAsFixed(0)}';
}
