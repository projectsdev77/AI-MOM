import 'package:flutter_test/flutter_test.dart';

import 'package:ai_mom/core/services/purchases_service.dart';

void main() {
  group('which RevenueCat keys a build may use', () {
    test('a test key in a release build is ignored (it would close the app)', () {
      expect(isUsableRevenueCatKey('test_CGabcdwQoA', isRelease: true), isFalse);
    });

    test('a test key in a debug build is fine (that is how you try purchases)', () {
      expect(isUsableRevenueCatKey('test_CGabcdwQoA', isRelease: false), isTrue);
    });

    test('real store keys work in release', () {
      expect(isUsableRevenueCatKey('goog_abc123', isRelease: true), isTrue);
      expect(isUsableRevenueCatKey('appl_abc123', isRelease: true), isTrue);
    });

    test('no key means no purchases, in any build', () {
      expect(isUsableRevenueCatKey('', isRelease: true), isFalse);
      expect(isUsableRevenueCatKey('', isRelease: false), isFalse);
    });
  });
}
