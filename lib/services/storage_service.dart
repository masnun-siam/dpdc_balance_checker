import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const String _savedIdsKey = 'saved_customer_ids';
  static const String _idsLabelsKey = 'customer_ids_labels';

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
}
