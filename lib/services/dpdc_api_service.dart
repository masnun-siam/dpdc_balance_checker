import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/balance_details.dart';
import 'storage_service.dart';

/// True when the decoded response body represents Cloudflare Turnstile's
/// "Access denied" rejection. Total: never throws on missing/odd shapes.
bool isAccessDenied(Map<String, dynamic> body) {
  final errors = body['errors'];
  if (errors is! List) return false;
  for (final entry in errors) {
    if (entry is! Map) continue;
    if (entry['message'] == 'Access denied') return true;
  }
  return false;
}

class DpdcApiService {
  static const String _authUrl =
      'https://amiapp.dpdc.org.bd/auth/login/generate-bearer';
  static const String _balanceUrl =
      'https://amiapp.dpdc.org.bd/usage/usage-service';
  static const String _verifyTurnstileUrl =
      'https://amiapp.dpdc.org.bd/auth/login/verify-turnstile';
  static const String _clientId = 'auth-ui';
  static const String _clientSecret = '0yFsAl4nN9jX1GGkgOrvpUxDarf2DT40';
  static const String _tenantCode = 'DPDC';

  // Provisionally 10 minutes pending the issue's Phase 0b measurement of the
  // server's actual turnstile code lifetime, which needs a live server and
  // has not been run yet. Lives here (not in storage_service.dart) because
  // this is the call site that owns the TTL decision.
  static const int _turnstileCodeTtlSeconds = 600;

  // Overall budget for fetchBalanceDetails, covering both attempts of the
  // retry loop. The access-denied retry path requires a second interactive
  // solve (up to 45s) plus user reaction time before any network call, so
  // 90s was exhausted before the retry's own network calls even started.
  // 150s still bounds the stacked-socket hang this budget exists for while
  // leaving room for two interactive solves.
  static const Duration _fetchBalanceOverallTimeout = Duration(seconds: 150);

  final StorageService _storageService = StorageService();
  final http.Client client;

  DpdcApiService({http.Client? client}) : client = client ?? http.Client();

  /// Generate bearer token from DPDC auth endpoint
  Future<String> generateBearerToken({String? refreshToken}) async {
    try {
      final headers = {
        'Content-Type': 'application/json;charset=UTF-8',
        'clientId': _clientId,
        'clientSecret': _clientSecret,
        'tenantCode': _tenantCode,
      };

      // If refresh token is provided, add it to headers
      if (refreshToken != null) {
        headers['Authorization'] = 'Bearer $refreshToken';
      }

      final response = await client
          .post(
            Uri.parse(_authUrl),
            headers: headers,
            body: json.encode({}),
          )
          .timeout(
            const Duration(minutes: 5),
          );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        final token = data['access_token'];
        final refresh = data['refresh_token'];
        final expiresIn = data['expires_in'];

        if (token == null || token.isEmpty) {
          throw Exception('Token not found in response');
        }

        // Save tokens if we have all required data
        if (refresh != null && expiresIn != null) {
          await _storageService.saveTokens(
            accessToken: token,
            refreshToken: refresh,
            ttl: expiresIn is int ? expiresIn : int.parse(expiresIn.toString()),
          );
        }

        return token;
      } else {
        throw Exception(
            'Failed to generate token. Status: ${response.statusCode}');
      }
    } catch (e) {
      if (e.toString().contains('SocketException') ||
          e.toString().contains('TimeoutException')) {
        throw Exception(
            'Network error: Please check your internet connection.');
      }
      throw Exception('Failed to generate token: ${e.toString()}');
    }
  }

  /// Get a valid access token (from cache or by refreshing)
  Future<String> _getValidAccessToken() async {
    // Check if we have a stored token
    final storedToken = await _storageService.getAccessToken();
    final isExpired = await _storageService.isTokenExpired();

    // If we have a valid non-expired token, use it
    if (storedToken != null && !isExpired) {
      return storedToken;
    }

    // If token is expired, try to refresh it
    if (storedToken != null && isExpired) {
      final refreshToken = await _storageService.getRefreshToken();
      if (refreshToken != null) {
        try {
          // Try to refresh the token
          return await generateBearerToken(refreshToken: refreshToken);
        } catch (e) {
          // If refresh fails, generate a new token
          debugPrint('Token refresh failed, generating new token: ${e.runtimeType}');
          return await generateBearerToken();
        }
      }
    }

    // No valid token, generate a new one
    return await generateBearerToken();
  }

  /// Exchange a solved Turnstile token for the short-lived code required by
  /// the balance endpoint.
  Future<String> _verifyTurnstile(String token, String turnstileToken) async {
    final response = await client
        .post(
          Uri.parse(_verifyTurnstileUrl),
          headers: {
            'Content-Type': 'application/json;charset=UTF-8',
            'accessToken': token,
            'tenantCode': _tenantCode,
          },
          body: json.encode({
            'turnstileToken': turnstileToken,
            'action': 'quickpay_balance',
          }),
        )
        .timeout(const Duration(minutes: 5));

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = json.decode(response.body);
      final code = data['code'];
      if (code == null) {
        throw Exception('Turnstile code not found in response');
      }
      return code as String;
    }
    throw Exception(
        'Failed to verify turnstile. Status: ${response.statusCode}');
  }

  /// Fetch balance details using customer ID
  Future<BalanceDetails> fetchBalanceDetails(
    String customerId, {
    required Future<String> Function() solveTurnstile,
  }) async {
    try {
      return await _fetchBalanceDetailsUnbounded(
        customerId,
        solveTurnstile: solveTurnstile,
      ).timeout(_fetchBalanceOverallTimeout);
    } on TimeoutException catch (e) {
      // This is the aggregate budget above expiring, not a socket-level
      // timeout — don't blame the user's connection for it.
      debugPrint('fetchBalanceDetails overall budget exceeded: $e');
      throw Exception('Verification took too long, please try again.');
    } catch (e) {
      if (e.toString().contains('SocketException') ||
          e.toString().contains('TimeoutException')) {
        throw Exception(
            'Network error: Please check your internet connection.');
      }
      rethrow;
    }
  }

  /// The actual fetch logic, with no overall time budget of its own — the
  /// budget is applied once by the caller ([fetchBalanceDetails]) so it
  /// covers both passes of the retry loop, not just a single call.
  Future<BalanceDetails> _fetchBalanceDetailsUnbounded(
    String customerId, {
    required Future<String> Function() solveTurnstile,
  }) async {
      // Get a valid bearer token (from cache or generate new)
      final token = await _getValidAccessToken();

      // GraphQL query for balance details
      final query = '''
query {
  postBalanceDetails(input: {
    customerNumber: "$customerId",
    tenantCode: "DPDC"
  }) {
    accountId
    customerName
    customerClass
    mobileNumber
    emailId
    accountType
    balanceRemaining
    connectionStatus
    customerType
    minRecharge
  }
}
''';

      Map<String, dynamic>? lastBody;

      // Exactly two passes: first attempt (cached or fresh turnstile code),
      // and one retry after a fresh code if the first was denied. A counted
      // loop makes "no infinite loop" structural rather than a matter of care.
      for (var attempt = 0; attempt < 2; attempt++) {
        var turnstileCode = await _storageService.getTurnstileCode();
        if (turnstileCode == null) {
          final turnstileToken = await solveTurnstile();
          turnstileCode = await _verifyTurnstile(token, turnstileToken);
          await _storageService.saveTurnstileCode(
            turnstileCode,
            ttl: _turnstileCodeTtlSeconds,
          );
        }

        final response = await client
            .post(
              Uri.parse(_balanceUrl),
              headers: {
                'Content-Type': 'application/json;charset=UTF-8',
                'accessToken': token,
                'tenantCode': _tenantCode,
                'x-turnstile-code': turnstileCode,
              },
              body: json.encode({'query': query}),
            )
            .timeout(const Duration(minutes: 5));

        // Access denied can come back on a non-200 status too (e.g. 403), so
        // this is checked before branching on statusCode — otherwise the
        // self-healing retry would be unreachable in exactly the case it
        // exists for.
        Map<String, dynamic>? decodedBody;
        try {
          decodedBody = json.decode(response.body) as Map<String, dynamic>;
        } catch (e) {
          debugPrint('Balance response body was not valid JSON: ${e.runtimeType}');
          decodedBody = null;
        }

        if (decodedBody != null && isAccessDenied(decodedBody)) {
          lastBody = decodedBody;
          await _storageService.clearTurnstileCode();
          continue;
        }

        if (response.statusCode == 200) {
          if (decodedBody == null) {
            throw Exception('Failed to parse balance response.');
          }
          final data = decodedBody;

          // Check for other GraphQL errors
          if (data['errors'] != null &&
              (data['errors'] as List).isNotEmpty) {
            final errorMessage =
                (data['errors'][0]['message']) ?? 'Unknown error';
            throw Exception('API Error: $errorMessage');
          }

          // Extract balance details from response
          final balanceData = data['data']?['postBalanceDetails'];
          if (balanceData == null) {
            throw Exception(
                'Customer ID not found or no data available. Please verify your customer ID.');
          }

          return BalanceDetails.fromJson(balanceData);
        } else if (response.statusCode == 404) {
          throw Exception(
              'Customer ID not found. Please verify and try again.');
        } else if (response.statusCode >= 500) {
          throw Exception('Server error. Please try again later.');
        } else {
          throw Exception(
              'Failed to fetch balance. Status: ${response.statusCode}');
        }
      }

      if (lastBody != null && isAccessDenied(lastBody)) {
        throw Exception('Verification failed. Please try again.');
      }
      throw Exception('Failed to fetch balance. Please try again.');
  }

  /// Validate customer ID format
  static bool validateCustomerId(String customerId) {
    if (customerId.isEmpty) return false;
    // Check if it's numeric and has reasonable length (8-12 digits)
    final numericRegex = RegExp(r'^[0-9]{8,12}$');
    return numericRegex.hasMatch(customerId);
  }
}
