import 'package:flutter_test/flutter_test.dart';
import 'package:dpdc_balance_check/services/turnstile_service.dart';

void main() {
  group('turnstileHtml', () {
    test('contains the sitekey', () {
      expect(turnstileHtml(), contains('0x4AAAAAAEmwuOx0sKb7pWLw'));
    });

    test('action is set to quickpay_balance', () {
      expect(turnstileHtml(), contains('quickpay_balance'));
    });

    test('script src uses render=explicit and points at turnstile api', () {
      final html = turnstileHtml();
      expect(html, contains('render=explicit'));
      expect(
        html,
        contains('https://challenges.cloudflare.com/turnstile/v0/api.js'),
      );
    });

    test('wires all six turnstile hooks', () {
      final html = turnstileHtml();
      expect(html, contains('callback'));
      expect(html, contains('error-callback'));
      expect(html, contains('timeout-callback'));
      expect(html, contains('expired-callback'));
      expect(html, contains('unsupported-callback'));
      expect(html, contains('before-interactive-callback'));
    });

    test('posts to the Dart JS channel', () {
      expect(turnstileHtml(), contains('Dart.postMessage'));
    });

    test('contains an 8s script-never-loaded guard', () {
      final html = turnstileHtml();
      expect(html, contains('setTimeout'));
      expect(html, contains('8000'));
    });

    test('error-callback body returns true to suppress cloudflare UI', () {
      final html = turnstileHtml();
      final idx = html.indexOf('error-callback');
      expect(idx, greaterThanOrEqualTo(0));
      final snippet = html.substring(idx, (idx + 200).clamp(0, html.length));
      expect(snippet, contains('return true'));
    });

    test('is pure: calling twice returns equal strings', () {
      expect(turnstileHtml(), equals(turnstileHtml()));
    });
  });
}
