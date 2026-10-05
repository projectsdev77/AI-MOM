import 'package:flutter_test/flutter_test.dart';

import 'package:ai_mom/core/utils/friendly_error.dart';

void main() {
  group('friendlyAuthError for the email sign-up code', () {
    test('a wrong or expired code reads as a code problem, not a raw error', () {
      const raw = 'AuthApiException(message: Token has expired or is invalid, statusCode: 403, code: otp_expired)';
      expect(friendlyAuthError(raw), "That code or link has expired or isn't valid — request a new one.");
    });

    test('asking for another code too soon says to wait, not "too many attempts"', () {
      const raw = 'AuthApiException(message: For security purposes, you can only request this after 52 seconds., '
          'statusCode: 429, code: over_email_send_rate_limit)';
      expect(friendlyAuthError(raw), 'Please wait a minute before asking for another email.');
    });

    test('other rate limits keep the general message', () {
      expect(friendlyAuthError('AuthApiException(message: Too many requests, statusCode: 429)'),
          'Too many attempts — please wait a moment and try again.');
    });

    test('existing messages are unchanged', () {
      expect(friendlyAuthError('Invalid login credentials'), "That email or password isn't right.");
      expect(friendlyAuthError('Email not confirmed'), 'Please confirm your email before logging in.');
      expect(friendlyAuthError('User already registered'),
          'An account with that email already exists — try logging in instead.');
    });
  });
}
