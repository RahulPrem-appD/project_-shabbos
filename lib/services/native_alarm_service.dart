import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class NativeAlarmService {
  static const MethodChannel _channel = MethodChannel(
    'app.shabbos.android/alarms',
  );

  /// Check if the app can schedule exact alarms (Android 12+)
  static Future<bool> canScheduleExactAlarms() async {
    if (!Platform.isAndroid) {
      return true;
    }

    try {
      final result = await _channel.invokeMethod('canScheduleExactAlarms');
      debugPrint('NativeAlarmService: Can schedule exact alarms: $result');
      return result as bool? ?? false;
    } catch (e) {
      debugPrint('NativeAlarmService: Error checking alarm permission: $e');
      return false;
    }
  }

  /// Request exact alarm permission (Android 12+)
  static Future<void> requestExactAlarmPermission() async {
    if (!Platform.isAndroid) {
      return;
    }

    try {
      await _channel.invokeMethod('requestExactAlarmPermission');
      debugPrint('NativeAlarmService: Requested exact alarm permission');
    } catch (e) {
      debugPrint('NativeAlarmService: Error requesting alarm permission: $e');
    }
  }

  /// Check if battery optimization is disabled for this app
  static Future<bool> isIgnoringBatteryOptimizations() async {
    if (!Platform.isAndroid) {
      return true;
    }

    try {
      final result = await _channel.invokeMethod('isIgnoringBatteryOptimizations');
      debugPrint('NativeAlarmService: Ignoring battery optimizations: $result');
      return result as bool? ?? false;
    } catch (e) {
      debugPrint('NativeAlarmService: Error checking battery optimization: $e');
      return false;
    }
  }

  /// Request to disable battery optimization for this app
  static Future<void> requestDisableBatteryOptimization() async {
    if (!Platform.isAndroid) {
      return;
    }

    try {
      await _channel.invokeMethod('requestDisableBatteryOptimization');
      debugPrint('NativeAlarmService: Requested battery optimization exemption');
    } catch (e) {
      debugPrint('NativeAlarmService: Error requesting battery exemption: $e');
    }
  }

  /// Schedule a native alarm that will trigger even if the app is killed
  static Future<bool> scheduleAlarm({
    required int id,
    required DateTime scheduledTime,
    required String title,
    required String body,
    bool isPreNotification = false,
    DateTime? candleLightingTime,
    String? soundId,
  }) async {
    if (!Platform.isAndroid) {
      debugPrint('NativeAlarmService: Only supported on Android');
      return false;
    }

    try {
      final timestampMillis = scheduledTime.millisecondsSinceEpoch;
      final candleLightingMillis = candleLightingTime?.millisecondsSinceEpoch ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;

      debugPrint('NativeAlarmService: ========================================');
      debugPrint('NativeAlarmService: Scheduling alarm #$id');
      debugPrint('NativeAlarmService: Current time: ${DateTime.now()}');
      debugPrint('NativeAlarmService: Scheduled time: $scheduledTime');
      debugPrint('NativeAlarmService: Timestamp: $timestampMillis');
      debugPrint('NativeAlarmService: Is pre-notification: $isPreNotification');
      debugPrint('NativeAlarmService: Sound ID: $soundId');
      debugPrint('NativeAlarmService: Candle lighting time: $candleLightingTime');
      debugPrint('NativeAlarmService: Candle lighting millis: $candleLightingMillis');
      debugPrint(
        'NativeAlarmService: Seconds from now: ${(timestampMillis - now) / 1000}',
      );
      if (candleLightingMillis > 0) {
        debugPrint(
          'NativeAlarmService: Candle lighting in: ${(candleLightingMillis - now) / 1000} seconds',
        );
      }

      final result = await _channel.invokeMethod('scheduleAlarm', {
        'id': id,
        'timestampMillis': timestampMillis,
        'title': title,
        'body': body,
        'isPreNotification': isPreNotification,
        'candleLightingTime': candleLightingMillis,
        'soundId': soundId ?? 'rav_shalom_shofar',
      });

      debugPrint(
        'NativeAlarmService: Alarm #$id scheduled successfully: $result',
      );
      debugPrint('NativeAlarmService: ========================================');
      return result as bool? ?? false;
    } catch (e, stack) {
      debugPrint('NativeAlarmService: Error scheduling alarm #$id: $e');
      debugPrint('NativeAlarmService: Stack trace: $stack');
      return false;
    }
  }

  /// Cancel a specific alarm
  static Future<bool> cancelAlarm(int id) async {
    if (!Platform.isAndroid) {
      return false;
    }

    try {
      final result = await _channel.invokeMethod('cancelAlarm', {'id': id});
      debugPrint('NativeAlarmService: Cancelled alarm #$id: $result');
      return result as bool? ?? false;
    } catch (e) {
      debugPrint('NativeAlarmService: Error cancelling alarm #$id: $e');
      return false;
    }
  }

  /// Cancel all alarms
  /// [protectImminent] - If true, alarms scheduled to fire within 5 minutes will NOT be cancelled
  /// This ensures alarms cannot be missed even if settings are changed at the last moment
  static Future<bool> cancelAllAlarms({bool protectImminent = true}) async {
    if (!Platform.isAndroid) {
      return false;
    }

    try {
      final result = await _channel.invokeMethod('cancelAllAlarms', {
        'protectImminent': protectImminent,
      });
      debugPrint('NativeAlarmService: Cancelled all alarms (protectImminent=$protectImminent): $result');
      return result as bool? ?? false;
    } catch (e) {
      debugPrint('NativeAlarmService: Error cancelling all alarms: $e');
      return false;
    }
  }

  /// Check if the app has overlay (draw over other apps) permission
  static Future<bool> canDrawOverlays() async {
    if (!Platform.isAndroid) return true;
    try {
      final result = await _channel.invokeMethod('canDrawOverlays');
      return result as bool? ?? false;
    } catch (e) {
      debugPrint('NativeAlarmService: Error checking overlay permission: $e');
      return false;
    }
  }

  /// Check if the overlay permission settings page is available on this device.
  /// Returns false on devices where the OS restricts overlay permission entirely.
  static Future<bool> isOverlaySettingsAvailable() async {
    if (!Platform.isAndroid) return true;
    try {
      final result =
          await _channel.invokeMethod('isOverlaySettingsAvailable');
      return result as bool? ?? true;
    } catch (e) {
      debugPrint(
        'NativeAlarmService: Error checking overlay settings availability: $e',
      );
      return true; // Assume available if check fails
    }
  }

  /// Android: package first install time (ms since epoch). Used to detect backup-restored
  /// SharedPreferences vs a fresh install on this device. Returns null on non-Android.
  static Future<int?> getFirstInstallTimeMillis() async {
    if (!Platform.isAndroid) return null;
    try {
      final result = await _channel.invokeMethod('getFirstInstallTimeMillis');
      if (result == null) return null;
      if (result is int) return result;
      if (result is num) return result.toInt();
      return int.tryParse(result.toString());
    } catch (e) {
      debugPrint('NativeAlarmService: Error reading first install time: $e');
      return null;
    }
  }

  /// Request overlay (draw over other apps) permission
  static Future<void> requestOverlayPermission() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('requestOverlayPermission');
    } catch (e) {
      debugPrint('NativeAlarmService: Error requesting overlay permission: $e');
    }
  }

  /// Check if the app can use full screen intents (Android 14+)
  static Future<bool> canUseFullScreenIntent() async {
    if (!Platform.isAndroid) return true;
    try {
      final result = await _channel.invokeMethod('canUseFullScreenIntent');
      return result as bool? ?? false;
    } catch (e) {
      debugPrint('NativeAlarmService: Error checking full screen intent permission: $e');
      return false;
    }
  }

  /// Request full screen intent permission (Android 14+)
  static Future<void> requestFullScreenIntentPermission() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('requestFullScreenIntentPermission');
    } catch (e) {
      debugPrint('NativeAlarmService: Error requesting full screen intent permission: $e');
    }
  }

  /// Read Android debug logs from device
  static Future<String?> readDebugLogs() async {
    if (!Platform.isAndroid) {
      return null;
    }

    try {
      final result = await _channel.invokeMethod('readDebugLogs');
      return result as String?;
    } catch (e) {
      debugPrint('NativeAlarmService: Error reading debug logs: $e');
      return null;
    }
  }

  /// Clear Android debug logs
  static Future<bool> clearDebugLogs() async {
    if (!Platform.isAndroid) {
      return false;
    }

    try {
      final result = await _channel.invokeMethod('clearDebugLogs');
      return result as bool? ?? false;
    } catch (e) {
      debugPrint('NativeAlarmService: Error clearing debug logs: $e');
      return false;
    }
  }

  /// Get all scheduled alarms (Android only)
  /// Returns list of alarm data maps with: id, timestampMillis, title, body, isPreNotification, soundId
  static Future<List<Map<String, dynamic>>> getScheduledAlarms() async {
    if (!Platform.isAndroid) {
      return [];
    }

    try {
      final result = await _channel.invokeMethod('getScheduledAlarms');
      if (result is List) {
        return result.cast<Map<dynamic, dynamic>>().map((map) {
          return Map<String, dynamic>.from(map);
        }).toList();
      }
      return [];
    } catch (e) {
      debugPrint('NativeAlarmService: Error getting scheduled alarms: $e');
      return [];
    }
  }
}
