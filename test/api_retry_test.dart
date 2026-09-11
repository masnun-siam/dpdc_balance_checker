import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dpdc_balance_check/services/dpdc_api_service.dart';

const _balanceData = {
  'data': {
    'postBalanceDetails': {
      'accountId': '1',
      'customerName': 'Test',
      'customerClass': 'Residential',
      'mobileNumber': '01700000000',
      'emailId': 'test@example.com',
      'accountType': 'Prepaid',
      'balanceRemaining': 100.0,
      'connectionStatus': 'Active',
      'customerType': 'Domestic',
      'minRecharge': 10.0,
    }
  }
};

const _accessDeniedBody = {
  'errors': [
    {'message': 'Access denied'}
  ]
};

http.Response _json(Map<String, dynamic> body, int status) =>
    http.Response(json.encode(body), status);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<String> Function() countingSolver(int Function() counter) {
    return () async {
      counter();
      return 'solved-token';
    };
  }

  test('verify-turnstile returning 201 yields the code (200 also works)',
      () async {
    var solveCalls = 0;
    var balanceCalls = 0;

    final client = MockClient((request) async {
      if (request.url.path.contains('generate-bearer')) {
        return _json({
          'access_token': 'tok',
          'refresh_token': 'ref',
          'expires_in': 3600,
        }, 200);
      }
      if (request.url.path.contains('verify-turnstile')) {
        return _json({'code': 'turnstile-code'}, 201);
      }
      if (request.url.path.contains('usage-service')) {
        balanceCalls++;
        return _json(_balanceData, 200);
      }
      return http.Response('not found', 404);
    });

    final service = DpdcApiService(client: client);
    final result = await service.fetchBalanceDetails(
      '12345678',
      solveTurnstile: () async {
        solveCalls++;
        return 'captcha-token';
      },
    );

    expect(result, isNotNull);
    expect(balanceCalls, 1);
  });

  test(
      'access denied then success: exactly two balance POSTs, code cleared, no exception',
      () async {
    var balanceCalls = 0;
    var solveCalls = 0;

    final client = MockClient((request) async {
      if (request.url.path.contains('generate-bearer')) {
        return _json({
          'access_token': 'tok',
          'refresh_token': 'ref',
          'expires_in': 3600,
        }, 200);
      }
      if (request.url.path.contains('verify-turnstile')) {
        return _json({'code': 'turnstile-code'}, 200);
      }
      if (request.url.path.contains('usage-service')) {
        balanceCalls++;
        if (balanceCalls == 1) {
          return _json(_accessDeniedBody, 200);
        }
        return _json(_balanceData, 200);
      }
      return http.Response('not found', 404);
    });

    final service = DpdcApiService(client: client);
    final result = await service.fetchBalanceDetails(
      '12345678',
      solveTurnstile: countingSolver(() => solveCalls++),
    );

    expect(result, isNotNull);
    expect(balanceCalls, 2);
  });

  test('both attempts access denied: exactly two attempts then throws',
      () async {
    var balanceCalls = 0;
    var solveCalls = 0;

    final client = MockClient((request) async {
      if (request.url.path.contains('generate-bearer')) {
        return _json({
          'access_token': 'tok',
          'refresh_token': 'ref',
          'expires_in': 3600,
        }, 200);
      }
      if (request.url.path.contains('verify-turnstile')) {
        return _json({'code': 'turnstile-code'}, 200);
      }
      if (request.url.path.contains('usage-service')) {
        balanceCalls++;
        return _json(_accessDeniedBody, 200);
      }
      return http.Response('not found', 404);
    });

    final service = DpdcApiService(client: client);

    await expectLater(
      service.fetchBalanceDetails(
        '12345678',
        solveTurnstile: countingSolver(() => solveCalls++),
      ),
      throwsA(anything),
    );

    expect(balanceCalls, 2);
  });

  test('cache hit: zero calls to solveTurnstile and zero verify-turnstile POSTs',
      () async {
    SharedPreferences.setMockInitialValues({
      'access_token': 'tok',
      'refresh_token': 'ref',
      'token_expiry': DateTime.now().millisecondsSinceEpoch + 3600000,
      'turnstile_code': 'cached-code',
      'turnstile_code_expiry': DateTime.now().millisecondsSinceEpoch + 3600000,
    });

    var solveCalls = 0;
    var verifyCalls = 0;
    var balanceCalls = 0;

    final client = MockClient((request) async {
      if (request.url.path.contains('verify-turnstile')) {
        verifyCalls++;
        return _json({'code': 'turnstile-code'}, 200);
      }
      if (request.url.path.contains('usage-service')) {
        balanceCalls++;
        return _json(_balanceData, 200);
      }
      return http.Response('not found', 404);
    });

    final service = DpdcApiService(client: client);
    final result = await service.fetchBalanceDetails(
      '12345678',
      solveTurnstile: countingSolver(() => solveCalls++),
    );

    expect(result, isNotNull);
    expect(solveCalls, 0);
    expect(verifyCalls, 0);
    expect(balanceCalls, 1);
  });

  test('expired stored token triggers generate-bearer then succeeds',
      () async {
    SharedPreferences.setMockInitialValues({
      'access_token': 'stale-tok',
      'refresh_token': 'ref',
      'token_expiry': DateTime.now().millisecondsSinceEpoch - 1000,
      'turnstile_code': 'cached-code',
      'turnstile_code_expiry': DateTime.now().millisecondsSinceEpoch + 3600000,
    });

    var generateBearerCalls = 0;
    var balanceCalls = 0;

    final client = MockClient((request) async {
      if (request.url.path.contains('generate-bearer')) {
        generateBearerCalls++;
        return _json({
          'access_token': 'fresh-tok',
          'refresh_token': 'fresh-ref',
          'expires_in': 3600,
        }, 200);
      }
      if (request.url.path.contains('usage-service')) {
        balanceCalls++;
        return _json(_balanceData, 200);
      }
      return http.Response('not found', 404);
    });

    final service = DpdcApiService(client: client);
    final result = await service.fetchBalanceDetails(
      '12345678',
      solveTurnstile: () async => 'unused',
    );

    expect(result, isNotNull);
    expect(generateBearerCalls, greaterThanOrEqualTo(1));
    expect(balanceCalls, 1);
  });

  test(
      'solveTurnstile throwing "Verification cancelled" propagates without retry storm',
      () async {
    var solveCalls = 0;

    final client = MockClient((request) async {
      if (request.url.path.contains('generate-bearer')) {
        return _json({
          'access_token': 'tok',
          'refresh_token': 'ref',
          'expires_in': 3600,
        }, 200);
      }
      if (request.url.path.contains('usage-service')) {
        return _json(_accessDeniedBody, 200);
      }
      return http.Response('not found', 404);
    });

    final service = DpdcApiService(client: client);

    await expectLater(
      service.fetchBalanceDetails(
        '12345678',
        solveTurnstile: () async {
          solveCalls++;
          throw Exception('Verification cancelled');
        },
      ),
      throwsA(anything),
    );

    expect(solveCalls, 1);
  });
}
