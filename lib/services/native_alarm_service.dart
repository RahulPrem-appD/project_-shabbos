import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class NativeAlarmService {
  static const MethodChannel _channel = MethodChannel(
    'com.shabbos.shabbos_app/alarms',
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
  }) async {
    if (!Platform.isAndroid) {
      debugPrint('NativeAlarmService: Only supported on Android');
      return false;
    }

    try {
      final timestampMillis = scheduledTime.millisecondsSinceEpoch;
      final now = DateTime.now().millisecondsSinceEpoch;

      debugPrint('NativeAlarmService: ========================================');
      debugPrint('NativeAlarmService: Scheduling alarm #$id');
      debugPrint('NativeAlarmService: Current time: ${DateTime.now()}');
      debugPrint('NativeAlarmService: Scheduled time: $scheduledTime');
      debugPrint('NativeAlarmService: Timestamp: $timestampMillis');
      debugPrint(
        'NativeAlarmService: Seconds from now: ${(timestampMillis - now) / 1000}',
      );

      final result = await _channel.invokeMethod('scheduleAlarm', {
        'id': id,
        'timestampMillis': timestampMillis,
        'title': title,
        'body': body,
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
  static Future<bool> cancelAllAlarms() async {
    if (!Platform.isAndroid) {
      return false;
    }

    try {
      final result = await _channel.invokeMethod('cancelAllAlarms');
      debugPrint('NativeAlarmService: Cancelled all alarms: $result');
      return result as bool? ?? false;
    } catch (e) {
      debugPrint('NativeAlarmService: Error cancelling all alarms: $e');
      return false;
    }
  }
}
