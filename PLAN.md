# Implementation Plan: Background Daily Balance Check with Android Notifications

**Issue**: #7 - Background daily balance check with Android notification when balance < 0
**Repo**: masnun-siam/dpdc_balance_checker
**Date**: 2026-06-22

## Goal

Add automatic background balance monitoring for all saved DPDC customer IDs. Check balance API once daily via Android WorkManager, trigger system notification when any account's balance drops below zero.

## Steps

### Step 1: Add Dependencies

**File**: `pubspec.yaml`

Add packages:

```yaml
workmanager: ^0.5.2
flutter_local_notifications: ^18.0.1
```

Run `flutter pub get`.

---

### Step 2: Create Notification Service

**New File**: `lib/services/notification_service.dart`

**Responsibilities**:

- Initialize `flutter_local_notifications`
- Request Android 13+ notification permission at runtime
- Show balance alert notifications
- Channel setup for balance alerts

**Key Methods**:

```dart
class NotificationService {
  static Future<void> initialize()
  static Future<void> showBalanceAlert({
    required String customerName,
    required String accountId,
    required double balance,
  })
}
```

**Notification Content Format**:

- Title: "⚠️ DPDC Balance Alert"
- Body: "⚠️ {customerName} ({accountId}): Balance is -৳{balance}"
- Channel: "balance_alerts" (high importance)

---

### Step 3: Create Background Service

**New File**: `lib/services/background_service.dart`

**Responsibilities**:

- Register periodic WorkManager task (once daily ~24h)
- Background task callback: load saved IDs → fetch balances → notify if < 0
- Handle API failures gracefully (log, don't crash)
- Persist monitoring toggle in SharedPreferences

**Key Methods**:

```dart
class BackgroundService {
  static const String taskName = "dailyBalanceCheck"
  
  static Future<void> initialize()
  static Future<void> registerPeriodicTask()
  static Future<void> cancelTask()
  static Future<bool> isMonitoringEnabled()
  static Future<void> setMonitoringEnabled(bool enabled)
  
  // Callback for WorkManager
  @pragma('vm:entry-point')
  static void callbackDispatcher()
}
```

**Background Task Logic**:

1. Load all saved customer IDs from `StorageService`
2. If no IDs → exit gracefully
3. For each ID, call `DpdcApiService.fetchBalanceDetails()`
4. If `balanceRemaining < 0` → fire notification
5. Wrap in try-catch → log errors, don't crash worker

**Edge Cases**:

- No saved IDs → exit silently
- API failure → log error, retry next cycle
- Token expiry → `DpdcApiService` handles refresh automatically
- Network unavailable → exit, retry next cycle

---

### Step 4: Add Monitoring Toggle to StorageService

**File**: `lib/services/storage_service.dart`

Add methods:

```dart
static const String _monitoringEnabledKey = 'background_monitoring_enabled';

Future<bool> isBackgroundMonitoringEnabled()
Future<void> setBackgroundMonitoringEnabled(bool enabled)
```

Default: `false` (opt-in).

---

### Step 5: Create Settings Screen

**New File**: `lib/screens/settings_screen.dart`

**UI Components**:

1. AppBar with "Settings" title
2. Toggle switch for "Background Monitoring"
   - Subtitle: "Check balance daily and notify when below zero"
3. When toggled ON → request notification permission → register WorkManager
4. When toggled OFF → cancel WorkManager task
5. Info card explaining:
   - Checks once every 24 hours
   - Android only
   - May need to disable battery optimization on some devices (Xiaomi, Huawei)

**Navigation**: Add settings icon button in HomeScreen AppBar or as a FAB/menu item.

---

### Step 6: Update Android Manifest

**File**: `android/app/src/main/AndroidManifest.xml`

Add permissions:

```xml
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
<uses-permission android:name="android.permission.WAKE_LOCK"/>
```

---

### Step 7: Update main.dart Initialization

**File**: `lib/main.dart`

Add initialization:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize notifications
  await NotificationService.initialize();
  
  // Initialize background service (registers task if enabled)
  await BackgroundService.initialize();
  
  runApp(const DpdcBalanceCheckerApp());
}
```

---

### Step 8: Add Settings Navigation to HomeScreen

**File**: `lib/screens/home_screen.dart`

Add settings icon in AppBar or header area that navigates to SettingsScreen.

---

## New Files Summary

| File | Purpose |
|------|---------|
| `lib/services/notification_service.dart` | Local notification setup and display |
| `lib/services/background_service.dart` | WorkManager task registration and balance check logic |
| `lib/screens/settings_screen.dart` | Toggle for background monitoring |

## Modified Files Summary

| File | Changes |
|------|---------|
| `pubspec.yaml` | Add `workmanager`, `flutter_local_notifications` |
| `android/app/src/main/AndroidManifest.xml` | Add notification, boot, alarm permissions |
| `lib/main.dart` | Initialize NotificationService and BackgroundService |
| `lib/services/storage_service.dart` | Add monitoring toggle persistence |
| `lib/screens/home_screen.dart` | Add settings navigation |

## Acceptance Criteria

- [ ] Background balance check runs once every 24h on Android (survives app kill + reboot)
- [ ] Notification appears when `balanceRemaining < 0` for any saved customer ID
- [ ] Notification shows: customer name, account ID, formatted balance (e.g., "-৳50.20")
- [ ] User can enable/disable background monitoring from settings
- [ ] Background task handles API failures gracefully — no crash, retries next cycle
- [ ] Token refresh works transparently in background
- [ ] Android 13+ notification permission requested at runtime
- [ ] No regression: existing manual balance check flow continues to work

## Rollback

If implementation fails:

1. Remove added packages from `pubspec.yaml`
2. Delete new files (`notification_service.dart`, `background_service.dart`, `settings_screen.dart`)
3. Revert changes to `main.dart`, `storage_service.dart`, `home_screen.dart`
4. Revert `AndroidManifest.xml` permission additions

## Notes

- **Android-only**: iOS background fetch unreliable for this use case. Scope is Android only.
- **Threshold**: Hardcoded to `balanceRemaining < 0`. Not configurable for now.
- **Battery optimization**: WorkManager respects Doze mode. Document that users may need to disable battery optimization on some OEMs (Xiaomi, Huawei).
- **Package versions**: Use stable releases (`workmanager: ^0.5.2`, `flutter_local_notifications: ^18.0.1`)
