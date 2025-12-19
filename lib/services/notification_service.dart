import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tzdata;
import '../models/candle_lighting.dart';
import 'audio_service.dart';
import 'native_alarm_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  final AudioService _audioService = AudioService();

  static const String _notificationsEnabledKey = 'notifications_enabled';
  static const String _preNotificationMinutesKey = 'pre_notification_minutes';
  static const String _candleNotificationEnabledKey =
      'candle_notification_enabled';

  static const String _channelId = 'shabbos_alerts';
  static const String _channelName = 'Shabbos Alerts';
  static const String _channelDesc = 'Candle lighting time reminders';

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    debugPrint('NotificationService: Initializing...');

    // Initialize timezone
    tzdata.initializeTimeZones();
    _setLocalTimezone();

    // Initialize Flutter Local Notifications
    const androidSettings = AndroidInitializationSettings(
      '@drawable/ic_notification',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      defaultPresentAlert: true,
      defaultPresentBadge: true,
      defaultPresentSound: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: _backgroundHandler,
    );

    // Create Android notification channel
    if (Platform.isAndroid) {
      await _createAndroidChannel();
    }

    _isInitialized = true;
    debugPrint('NotificationService: Initialization complete');
  }

  Future<void> _createAndroidChannel() async {
    final android = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (android == null) return;

    await android.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDesc,
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        enableLights: true,
        showBadge: true,
      ),
    );

    debugPrint('NotificationService: Android channel created');
  }

  void _setLocalTimezone() {
    try {
      final now = DateTime.now();
      final offset = now.timeZoneOffset;
      final offsetMinutes = offset.inMinutes;

      debugPrint(
        'NotificationService: Device offset: ${offset.inHours}h ${offset.inMinutes % 60}m (${offsetMinutes} minutes)',
      );

      // Use minutes for accurate timezone detection (handles half-hour offsets like India +5:30)
      final tzMappings = {
        // Americas
        -300: 'America/New_York', // -5:00
        -240: 'America/New_York', // -4:00 (DST)
        -360: 'America/Chicago', // -6:00
        -420: 'America/Denver', // -7:00
        -480: 'America/Los_Angeles', // -8:00
        -180: 'America/Sao_Paulo', // -3:00
        // Europe
        0: 'Europe/London', // +0:00
        60: 'Europe/Paris', // +1:00
        // Middle East (Israel uses +2:00 standard, +3:00 DST)
        120: 'Asia/Jerusalem', // +2:00 (Israel standard)
        180: 'Asia/Jerusalem', // +3:00 (Israel DST)
        210: 'Asia/Tehran', // +3:30 (Iran)
        // Asia
        270: 'Asia/Kabul', // +4:30 (Afghanistan)
        300: 'Asia/Karachi', // +5:00 (Pakistan)
        330: 'Asia/Kolkata', // +5:30 (India) ← THIS IS THE FIX!
        345: 'Asia/Kathmandu', // +5:45 (Nepal)
        360: 'Asia/Dhaka', // +6:00 (Bangladesh)
        390: 'Asia/Yangon', // +6:30 (Myanmar)
        420: 'Asia/Bangkok', // +7:00
        480: 'Asia/Shanghai', // +8:00
        540: 'Asia/Tokyo', // +9:00
        570: 'Australia/Adelaide', // +9:30 (Adelaide)
        600: 'Australia/Sydney', // +10:00
        660: 'Australia/Sydney', // +11:00 (DST)
      };

      String? tzName = tzMappings[offsetMinutes];

      if (tzName != null) {
        try {
          tz.setLocalLocation(tz.getLocation(tzName));
          debugPrint('NotificationService: Timezone set to $tzName');
          return;
        } catch (e) {
          debugPrint('NotificationService: Failed to set $tzName: $e');
        }
      }

      // Fallback: try to find any timezone with matching offset
      debugPrint(
        'NotificationService: No exact match for offset $offsetMinutes, trying fallback...',
      );

      // Fallback to UTC with offset adjustment
      tz.setLocalLocation(tz.getLocation('UTC'));
      debugPrint('NotificationService: Using UTC as fallback');
    } catch (e) {
      debugPrint('NotificationService: Timezone error: $e');
    }
  }

  void _onNotificationResponse(NotificationResponse response) {
    debugPrint('NotificationService: Notification tapped - ID: ${response.id}');
  }

  @pragma('vm:entry-point')
  static void _backgroundHandler(NotificationResponse response) {
    debugPrint(
      'NotificationService: Background notification - ID: ${response.id}',
    );
  }

  Future<bool> requestPermissions() async {
    debugPrint('NotificationService: Checking permissions...');

    if (Platform.isAndroid) {
      final android = _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

      if (android != null) {
        // Check if notifications are already enabled
        final areEnabled = await android.areNotificationsEnabled() ?? false;
        debugPrint(
          'NotificationService: Notifications already enabled: $areEnabled',
        );

        bool notifPermission = areEnabled;
        if (!areEnabled) {
          // Only request if not already enabled
          notifPermission =
              await android.requestNotificationsPermission() ?? false;
          debugPrint(
            'NotificationService: Notification permission result: $notifPermission',
          );
        }

        // Check exact alarm permission using native method
        final canScheduleExact =
            await NativeAlarmService.canScheduleExactAlarms();
        debugPrint(
          'NotificationService: Can schedule exact alarms: $canScheduleExact',
        );

        if (!canScheduleExact) {
          debugPrint(
            'NotificationService: Requesting exact alarm permission...',
          );
          await NativeAlarmService.requestExactAlarmPermission();
        }

        return notifPermission;
      }
    } else if (Platform.isIOS) {
      final ios = _notifications
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();

      if (ios != null) {
        // Check current permission status first
        final currentStatus = await ios.checkPermissions();
        final isAlreadyGranted = currentStatus?.isEnabled ?? false;
        debugPrint(
          'NotificationService: iOS notifications already enabled: $isAlreadyGranted',
        );

        if (isAlreadyGranted) {
          return true;
        }

        // Only request if not already granted
        final granted = await ios.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
          critical: true,
        );
        debugPrint('NotificationService: iOS permission granted: $granted');
        return granted ?? false;
      }
    }

    return false;
  }

  NotificationDetails _getNotificationDetails() {
    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      enableVibration: true,
      enableLights: true,
      icon: '@drawable/ic_notification',
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
      fullScreenIntent: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      badgeNumber: 1,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    return const NotificationDetails(android: androidDetails, iOS: iosDetails);
  }

  /// Schedule notifications for candle lighting times
  Future<void> scheduleNotifications(
    List<CandleLighting> candleLightings,
  ) async {
    debugPrint(
      'NotificationService: Scheduling ${candleLightings.length} events...',
    );

    await initialize();

    // Cancel all existing notifications and alarms
    await _notifications.cancelAll();
    if (Platform.isAndroid) {
      await NativeAlarmService.cancelAllAlarms();
    }

    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_notificationsEnabledKey) ?? true;

    if (!enabled) {
      debugPrint('NotificationService: Notifications disabled');
      return;
    }

    final preMinutes = prefs.getInt(_preNotificationMinutesKey) ?? 20;
    final candleEnabled = prefs.getBool(_candleNotificationEnabledKey) ?? true;

    int id = 0;
    int scheduled = 0;
    final now = DateTime.now();

    for (final lighting in candleLightings) {
      // Pre-notification
      final preTime = lighting.candleLightingTime.subtract(
        Duration(minutes: preMinutes),
      );
      if (preTime.isAfter(now)) {
        final title = lighting.isYomTov ? '!יום טוב מגיע' : '!שבת מגיעה';
        final body = lighting.isYomTov
            ? 'Yom Tov in $preMinutes minutes • $preMinutes דקות ליום טוב'
            : 'Shabbos in $preMinutes minutes • $preMinutes דקות לשבת';

        final success = await _scheduleNotification(
          id: id++,
          title: title,
          body: body,
          scheduledTime: preTime,
        );
        if (success) scheduled++;
      }

      // Candle lighting notification
      if (candleEnabled && lighting.candleLightingTime.isAfter(now)) {
        final title = lighting.isYomTov ? '!יום טוב שמח' : '!שבת שלום';
        final body = lighting.isYomTov
            ? 'Good Yom Tov! Time to light candles 🕯️🕯️'
            : 'Good Shabbos! Time to light candles 🕯️🕯️';

        final success = await _scheduleNotification(
          id: id++,
          title: title,
          body: body,
          scheduledTime: lighting.candleLightingTime,
        );
        if (success) scheduled++;
      }
    }

    debugPrint('NotificationService: Scheduled $scheduled notifications');

    // Verify scheduled notifications
    await _verifyPendingNotifications();
  }

  Future<void> _verifyPendingNotifications() async {
    try {
      final pending = await _notifications.pendingNotificationRequests();
      debugPrint(
        'NotificationService: Pending notifications count: ${pending.length}',
      );
      for (final n in pending.take(5)) {
        debugPrint('  - ID ${n.id}: ${n.title}');
      }
    } catch (e) {
      debugPrint('NotificationService: Error verifying pending: $e');
    }
  }

  Future<bool> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
  }) async {
    try {
      if (Platform.isAndroid) {
        // Use native alarm scheduler for maximum reliability on Android
        final success = await NativeAlarmService.scheduleAlarm(
          id: id,
          scheduledTime: scheduledTime,
          title: title,
          body: body,
        );

        debugPrint(
          'NotificationService: Scheduled native alarm #$id for $scheduledTime: $success',
        );
        return success;
      } else {
        // iOS: Use zonedSchedule with REQUIRED uiLocalNotificationDateInterpretation
        final tzTime = tz.TZDateTime(
          tz.local,
          scheduledTime.year,
          scheduledTime.month,
          scheduledTime.day,
          scheduledTime.hour,
          scheduledTime.minute,
          scheduledTime.second,
        );

        debugPrint('NotificationService: Scheduling iOS notification #$id');
        debugPrint('NotificationService: Local timezone: ${tz.local.name}');
        debugPrint('NotificationService: Scheduled time: $scheduledTime');
        debugPrint('NotificationService: TZ time: $tzTime');

        // Schedule the notification using zonedSchedule
        await _notifications.zonedSchedule(
          id,
          title,
          body,
          tzTime,
          _getNotificationDetails(),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        );

        debugPrint(
          'NotificationService: iOS notification #$id scheduled successfully',
        );
        return true;
      }
    } catch (e, stack) {
      debugPrint('NotificationService: Failed to schedule #$id: $e');
      debugPrint('Stack: $stack');
      return false;
    }
  }

  /// Send an immediate test notification
  Future<void> sendTestNotification() async {
    debugPrint('NotificationService: Sending immediate test notification...');

    await initialize();
    await requestPermissions();

    // Play sound
    final soundId = await _audioService.getCandleLightingSound();
    if (soundId != 'default' && soundId != 'silent') {
      await _audioService.playSound(soundId);
    }

    try {
      await _notifications.show(
        999,
        '!שבת שלום Good Shabbos!',
        'Test notification 🕯️🕯️',
        _getNotificationDetails(),
      );
      debugPrint('NotificationService: Immediate test sent');
    } catch (e) {
      debugPrint('NotificationService: Failed to send: $e');
    }
  }

  /// Send a delayed test notification
  Future<void> sendDelayedTestNotification({int seconds = 10}) async {
    debugPrint('==========================================');
    debugPrint('NotificationService: SCHEDULING TEST NOTIFICATION');
    debugPrint('==========================================');
    debugPrint('NotificationService: Delay: $seconds seconds');

    await initialize();
    await requestPermissions();

    final now = DateTime.now();
    final scheduledTime = now.add(Duration(seconds: seconds));

    debugPrint('NotificationService: Current time: $now');
    debugPrint('NotificationService: Scheduled for: $scheduledTime');
    debugPrint('NotificationService: Time difference: $seconds seconds');

    if (Platform.isAndroid) {
      // Use native alarm for Android
      final success = await NativeAlarmService.scheduleAlarm(
        id: 998,
        scheduledTime: scheduledTime,
        title: 'שבת שלום! Good Shabbos!',
        body: 'Scheduled test notification 🕯️🕯️ (Background test)',
      );

      debugPrint('NotificationService: Android alarm scheduled: $success');
      debugPrint('NotificationService: Will fire at: $scheduledTime');
    } else {
      // iOS: Use zonedSchedule
      debugPrint('NotificationService: Setting up iOS notification...');
      debugPrint('NotificationService: Local timezone: ${tz.local.name}');

      final tzTime = tz.TZDateTime(
        tz.local,
        scheduledTime.year,
        scheduledTime.month,
        scheduledTime.day,
        scheduledTime.hour,
        scheduledTime.minute,
        scheduledTime.second,
      );

      final nowTz = tz.TZDateTime.now(tz.local);
      final difference = tzTime.difference(nowTz);

      debugPrint('NotificationService: Current TZ time: $nowTz');
      debugPrint('NotificationService: Scheduled TZ time: $tzTime');
      debugPrint(
        'NotificationService: Difference: ${difference.inSeconds} seconds',
      );

      try {
        // Cancel any existing test notifications first
        await _notifications.cancel(998);
        debugPrint(
          'NotificationService: Cancelled previous test notifications',
        );

        // Schedule the test notification
        await _notifications.zonedSchedule(
          998,
          '!שבת שלום Good Shabbos!',
          'Scheduled test notification 🕯️🕯️ (Background test)',
          tzTime,
          _getNotificationDetails(),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        );

        debugPrint(
          'NotificationService: ✓ iOS notification scheduled successfully!',
        );

        // Verify notification was scheduled
        final pending = await _notifications.pendingNotificationRequests();
        debugPrint(
          'NotificationService: Pending notifications: ${pending.length}',
        );

        if (pending.isEmpty) {
          debugPrint(
            'NotificationService: ⚠️ WARNING: No pending notifications found!',
          );
        } else {
          for (final n in pending) {
            debugPrint('  ✓ ID ${n.id}: ${n.title}');
          }
        }
      } catch (e, stack) {
        debugPrint('NotificationService: ✗ ERROR scheduling notification: $e');
        debugPrint('Stack trace: $stack');
      }
    }

    debugPrint('==========================================');
  }

  // Settings
  Future<bool> getNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_notificationsEnabledKey) ?? true;
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notificationsEnabledKey, enabled);
    if (!enabled) {
      await _notifications.cancelAll();
      if (Platform.isAndroid) {
        await NativeAlarmService.cancelAllAlarms();
      }
    }
  }

  Future<int> getPreNotificationMinutes() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getInt(_preNotificationMinutesKey) ?? 20;
    // Only allow 20, 40, or 60 minutes
    if (saved == 40 || saved == 60) return saved;
    return 20; // Default to 20 if invalid value
  }

  Future<void> setPreNotificationMinutes(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_preNotificationMinutesKey, minutes);
  }

  Future<bool> getCandleNotificationEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_candleNotificationEnabledKey) ?? true;
  }

  Future<void> setCandleNotificationEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_candleNotificationEnabledKey, enabled);
  }
}
