import 'dart:developer';
import 'package:workmanager/workmanager.dart';
import 'dpdc_api_service.dart';
import 'notification_service.dart';
import 'storage_service.dart';

/// Callback dispatcher for WorkManager
/// Must be a top-level function
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      // Only handle our specific task
      if (task != BackgroundService.taskName) {
        return Future.value(true);
      }

      log('Background balance check started');

      final storageService = StorageService();
      final apiService = DpdcApiService();

      // Get all saved customer IDs
      final savedIds = await storageService.getSavedCustomerIds();

      if (savedIds.isEmpty) {
        log('No saved customer IDs found, skipping check');
        return Future.value(true);
      }

      log('Checking ${savedIds.length} customer(s)');

      // Check each customer's balance
      for (final customerId in savedIds) {
        try {
          final balanceDetails = await apiService.fetchBalanceDetails(
            customerId,
          );

          // Check if balance is below zero
          if (balanceDetails.balanceRemaining < 0) {
            log(
              'Negative balance detected for $customerId: ${balanceDetails.balanceRemaining}',
            );

            // Get label if available
            final label = await storageService.getLabel(customerId);
            final displayName = (label != null && label.isNotEmpty)
                ? label
                : balanceDetails.customerName;

            // Show notification
            await NotificationService.showBalanceAlert(
              customerName: displayName,
              accountId: balanceDetails.accountId,
              balance: balanceDetails.balanceRemaining,
            );
          } else {
            log(
              'Balance OK for $customerId: ${balanceDetails.balanceRemaining}',
            );
          }
        } catch (e) {
          // Log error but continue with other customers
          log('Error checking balance for $customerId: $e');
        }
      }

      log('Background balance check completed');
      return Future.value(true);
    } catch (e) {
      log('Background task failed: $e');
      return Future.value(false);
    }
  });
}

class BackgroundService {
  static const String taskName = 'dailyBalanceCheck';
  static final StorageService _storageService = StorageService();

  /// Initialize background service
  /// Registers task if monitoring is enabled
  static Future<void> initialize() async {
    // Initialize WorkManager
    await Workmanager().initialize(callbackDispatcher);

    // Register task if monitoring is enabled
    final isEnabled = await isMonitoringEnabled();
    if (isEnabled) {
      await registerPeriodicTask();
    }
  }

  /// Register periodic background task (once daily)
  static Future<void> registerPeriodicTask() async {
    await Workmanager().registerPeriodicTask(
      taskName,
      taskName,
      frequency: const Duration(hours: 24),
      constraints: Constraints(
        networkType: NetworkType.connected,
        requiresBatteryNotLow: true,
      ),
      backoffPolicy: BackoffPolicy.linear,
      backoffPolicyDelay: const Duration(minutes: 15),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    );
    log('Background monitoring task registered');
  }

  /// Cancel background task
  static Future<void> cancelTask() async {
    await Workmanager().cancelByUniqueName(taskName);
    log('Background monitoring task cancelled');
  }

  /// Check if monitoring is enabled
  static Future<bool> isMonitoringEnabled() async {
    return await _storageService.isBackgroundMonitoringEnabled();
  }

  /// Enable or disable monitoring
  static Future<void> setMonitoringEnabled(bool enabled) async {
    await _storageService.setBackgroundMonitoringEnabled(enabled);

    if (enabled) {
      await registerPeriodicTask();
    } else {
      await cancelTask();
    }
  }
}
