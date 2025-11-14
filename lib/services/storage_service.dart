import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const String _savedIdsKey = 'saved_customer_ids';
  static const String _idsLabelsKey = 'customer_ids_labels';
  static const String _accessTokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _tokenExpiryKey = 'token_expiry';

  /// Save a customer ID with an optional label
  Future<void> saveCustomerId(String id, {String? label}) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Get existing IDs
      final savedIds = await getSavedCustomerIds();

      // Add new ID if not already saved
      if (!savedIds.contains(id)) {
        savedIds.add(id);
        await prefs.setStringList(_savedIdsKey, savedIds);
      }

      // Save label if provided
      if (label != null && label.isNotEmpty) {
        final labels = await _getLabels();
        labels[id] = label;
        await prefs.setString(_idsLabelsKey, json.encode(labels));
      }
    } catch (e) {
      throw Exception('Failed to save customer ID: ${e.toString()}');
    }
  }

  /// Get all saved customer IDs
  Future<List<String>> getSavedCustomerIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList(_savedIdsKey) ?? [];
    } catch (e) {
      return [];
    }
  }

  /// Get label for a customer ID
  Future<String?> getLabel(String id) async {
    try {
      final labels = await _getLabels();
      return labels[id];
    } catch (e) {
      return null;
    }
  }

  /// Get all labels
  Future<Map<String, String>> _getLabels() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final labelsJson = prefs.getString(_idsLabelsKey);
      if (labelsJson == null) return {};
      final decoded = json.decode(labelsJson);
      return Map<String, String>.from(decoded);
    } catch (e) {
      return {};
    }
  }

  /// Delete a saved customer ID
  Future<void> deleteCustomerId(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Remove from IDs list
      final savedIds = await getSavedCustomerIds();
      savedIds.remove(id);
      await prefs.setStringList(_savedIdsKey, savedIds);

      // Remove label
      final labels = await _getLabels();
      labels.remove(id);
      await prefs.setString(_idsLabelsKey, json.encode(labels));
    } catch (e) {
      throw Exception('Failed to delete customer ID: ${e.toString()}');
    }
  }

  /// Check if a customer ID is saved
  Future<bool> isIdSaved(String id) async {
    final savedIds = await getSavedCustomerIds();
    return savedIds.contains(id);
  }

  /// Get saved IDs with their labels
  Future<Map<String, String?>> getSavedIdsWithLabels() async {
    final ids = await getSavedCustomerIds();
    final Map<String, String?> result = {};

    for (final id in ids) {
      result[id] = await getLabel(id);
    }

    return result;
  }

  /// Clear all saved data
  Future<void> clearAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_savedIdsKey);
      await prefs.remove(_idsLabelsKey);
    } catch (e) {
      throw Exception('Failed to clear data: ${e.toString()}');
    }
  }

  /// Save authentication tokens
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    required int ttl,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_accessTokenKey, accessToken);
      await prefs.setString(_refreshTokenKey, refreshToken);

      // Calculate expiry time (current time + TTL in seconds)
      final expiryTime = DateTime.now().millisecondsSinceEpoch + (ttl * 1000);
      await prefs.setInt(_tokenExpiryKey, expiryTime);
    } catch (e) {
      throw Exception('Failed to save tokens: ${e.toString()}');
    }
  }

  /// Get stored access token
  Future<String?> getAccessToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_accessTokenKey);
    } catch (e) {
      return null;
    }
  }

  /// Get stored refresh token
  Future<String?> getRefreshToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_refreshTokenKey);
    } catch (e) {
      return null;
    }
  }

  /// Check if the current token is expired
  Future<bool> isTokenExpired() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final expiryTime = prefs.getInt(_tokenExpiryKey);

      if (expiryTime == null) return true;

      final currentTime = DateTime.now().millisecondsSinceEpoch;
      return currentTime >= expiryTime;
    } catch (e) {
      return true;
    }
  }

  /// Clear stored tokens
  Future<void> clearTokens() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_accessTokenKey);
      await prefs.remove(_refreshTokenKey);
      await prefs.remove(_tokenExpiryKey);
    } catch (e) {
      throw Exception('Failed to clear tokens: ${e.toString()}');
    }
  }
}
