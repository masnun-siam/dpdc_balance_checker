import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dpdc_balance_check/services/storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('turnstile code cache', () {
    test('saveTurnstileCode then getTurnstileCode returns the code', () async {
      final storage = StorageService();
      await storage.saveTurnstileCode('abc123', ttl: 3600);
      expect(await storage.getTurnstileCode(), equals('abc123'));
    });

    test('getTurnstileCode on empty storage returns null', () async {
      final storage = StorageService();
      expect(await storage.getTurnstileCode(), isNull);
    });

    test('an expired code returns null', () async {
      SharedPreferences.setMockInitialValues({
        'turnstile_code': 'expired-code',
        'turnstile_code_expiry':
            DateTime.now().millisecondsSinceEpoch - 1000,
      });
      final storage = StorageService();
      expect(await storage.getTurnstileCode(), isNull);
    });

    test('expiry exactly now returns null (>= comparison)', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      SharedPreferences.setMockInitialValues({
        'turnstile_code': 'edge-code',
        'turnstile_code_expiry': now,
      });
      final storage = StorageService();
      expect(await storage.getTurnstileCode(), isNull);
    });

    test('clearTurnstileCode then getTurnstileCode returns null', () async {
      final storage = StorageService();
      await storage.saveTurnstileCode('abc123', ttl: 3600);
      await storage.clearTurnstileCode();
      expect(await storage.getTurnstileCode(), isNull);
    });

    test('code present but expiry key missing returns null, not throw',
        () async {
      SharedPreferences.setMockInitialValues({
        'turnstile_code': 'orphan-code',
      });
      final storage = StorageService();
      expect(await storage.getTurnstileCode(), isNull);
    });
  });
}
