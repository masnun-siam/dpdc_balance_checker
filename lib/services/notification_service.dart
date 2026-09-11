import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'balance_alerts';
  static const String _channelName = 'Balance Alerts';
  static const String _channelDescription =
      'Notifications for negative balance alerts';

  /// Initialize notification service
  static Future<void> initialize() async {
    // Android initialization settings
    const androidSettings = AndroidInitializationSettings('app_icon');

    // Initialization settings
    const initSettings = InitializationSettings(android: androidSettings);

    // Initialize the plugin
    await _notifications.initialize(initSettings);

    // Create notification channel for Android
    await _createNotificationChannel();

    // Request notification permission for Android 13+
    await _requestPermission();
  }

  /// Create notification channel for Android
  static Future<void> _createNotificationChannel() async {
    const channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDescription,
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    await _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
  }

  /// Request notification permission for Android 13+
  static Future<void> _requestPermission() async {
    final android = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (android != null) {
      await android.requestNotificationsPermission();
    }
  }

  /// Show balance alert notification
  static Future<void> showBalanceAlert({
    required String customerName,
    required String accountId,
    required double balance,
  }) async {
    // Format balance with sign
    final balanceStr = balance < 0
        ? '-৳${balance.abs().toStringAsFixed(2)}'
        : '৳${balance.toStringAsFixed(2)}';

    // Android notification details
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      icon: 'app_icon',
    );

    const notificationDetails = NotificationDetails(android: androidDetails);

    // Show notification
    await _notifications.show(
      accountId.hashCode, // Unique ID per account
      '⚠️ DPDC Balance Alert',
      '⚠️ $customerName ($accountId): Balance is $balanceStr',
      notificationDetails,
    );
  }
}
