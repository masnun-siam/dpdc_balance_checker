import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/balance_details.dart';

class DpdcApiService {
  static const String _authUrl =
      'https://amiapp.dpdc.org.bd/auth/login/generate-bearer';
  static const String _balanceUrl =
      'https://amiapp.dpdc.org.bd/usage/usage-service';
  static const String _clientId = 'auth-ui';
  static const String _clientSecret = '0yFsAl4nN9jX1GGkgOrvpUxDarf2DT40';
  static const String _tenantCode = 'DPDC';

  /// Generate bearer token from DPDC auth endpoint
  Future<String> generateBearerToken() async {
    try {
      final response = await http
          .post(
            Uri.parse(_authUrl),
            headers: {
              'Content-Type': 'application/json;charset=UTF-8',
              'clientId': _clientId,
              'clientSecret': _clientSecret,
              'tenantCode': _tenantCode,
            },
            body: json.encode({}),
          )
          .timeout(
            const Duration(seconds: 30),
          );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        final token = data['token'];
        if (token == null || token.isEmpty) {
          throw Exception('Token not found in response');
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

  /// Fetch balance details using customer ID
  Future<BalanceDetails> fetchBalanceDetails(String customerId) async {
    try {
      // First, generate the bearer token
      final token = await generateBearerToken();

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

      final response = await http
          .post(
            Uri.parse(_balanceUrl),
            headers: {
              'Content-Type': 'application/json;charset=UTF-8',
              'Authorization': 'Bearer $token',
              'accessToken': token,
              'tenantCode': _tenantCode,
            },
            body: json.encode({'query': query}),
          )
          .timeout(
            const Duration(seconds: 30),
          );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Check for GraphQL errors
        if (data['errors'] != null && data['errors'].isNotEmpty) {
          final errorMessage = data['errors'][0]['message'] ?? 'Unknown error';
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
    } catch (e) {
      if (e.toString().contains('SocketException') ||
          e.toString().contains('TimeoutException')) {
        throw Exception(
            'Network error: Please check your internet connection.');
      }
      rethrow;
    }
  }

  /// Validate customer ID format
  static bool validateCustomerId(String customerId) {
    if (customerId.isEmpty) return false;
    // Check if it's numeric and has reasonable length (8-12 digits)
    final numericRegex = RegExp(r'^[0-9]{8,12}$');
    return numericRegex.hasMatch(customerId);
  }
}
