import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import '../models/candle_lighting.dart';
import 'audio_service.dart';
import 'native_alarm_service.dart';

// Top-level function for alarm callback - MUST be top-level or static
@pragma('vm:entry-point')
Future<void> alarmCallback(int id) async {
  debugPrint('AlarmCallback: Triggered for ID $id');
  
  // Initialize notifications in the isolate
  final notifications = FlutterLocalNotificationsPlugin();
  
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosSettings = DarwinInitializationSettings();
  const initSettings = InitializationSettings(android: androidSettings, iOS: iosSettings);
  
  await notifications.initialize(initSettings);
  
  // Get notification data from SharedPreferences
  final prefs = await SharedPreferences.getInstance();
  final title = prefs.getString('notification_${id}_title') ?? 'שבת שלום!';
  final body = prefs.getString('notification_${id}_body') ?? 'Time to light candles 🕯️🕯️';
  
  const androidDetails = AndroidNotificationDetails(
    'shabbos_alerts',
    'Shabbos Alerts',
    channelDescription: 'Candle lighting time reminders',
    importance: Importance.max,
    priority: Priority.max,
    playSound: true,
    enableVibration: true,
    enableLights: true,
    icon: '@mipmap/ic_launcher',
    category: AndroidNotificationCategory.alarm,
    visibility: NotificationVisibility.public,
    fullScreenIntent: true,
  );

  const iosDetails = DarwinNotificationDetails(
    presentAlert: true,
    presentBadge: true,
    presentSound: true,
    badgeNumber: 1,
  );

  const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

  await notifications.show(id, title, body, details);
  
  debugPrint('AlarmCallback: Notification shown for ID $id');
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  final AudioService _audioService = AudioService();
  
  static const String _notificationsEnabledKey = 'notifications_enabled';
  static const String _preNotificationMinutesKey = 'pre_notification_minutes';
  static const String _candleNotificationEnabledKey = 'candle_notification_enabled';
  
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

    // Initialize Android Alarm Manager
    if (Platform.isAndroid) {
      await AndroidAlarmManager.initialize();
      debugPrint('NotificationService: AndroidAlarmManager initialized');
    }

    // Initialize Flutter Local Notifications
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
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
    final android = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    
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
      final offsetHours = offset.inHours;
      
      debugPrint('NotificationService: Device offset: ${offsetHours}h');
      
      final tzMappings = {
        -5: 'America/New_York',
        -4: 'America/New_York',
        -6: 'America/Chicago',
        -7: 'America/Denver',
        -8: 'America/Los_Angeles',
        2: 'Asia/Jerusalem',
        3: 'Asia/Jerusalem',
        0: 'Europe/London',
        1: 'Europe/Paris',
      };
      
      String? tzName = tzMappings[offsetHours];
      
      if (tzName != null) {
        try {
          tz.setLocalLocation(tz.getLocation(tzName));
          debugPrint('NotificationService: Timezone set to $tzName');
          return;
        } catch (e) {
          debugPrint('NotificationService: Failed to set $tzName');
        }
      }
      
      // Fallback to UTC
      tz.setLocalLocation(tz.getLocation('UTC'));
      debugPrint('NotificationService: Using UTC');
    } catch (e) {
      debugPrint('NotificationService: Timezone error: $e');
    }
  }

  void _onNotificationResponse(NotificationResponse response) {
    debugPrint('NotificationService: Notification tapped - ID: ${response.id}');
  }

  @pragma('vm:entry-point')
  static void _backgroundHandler(NotificationResponse response) {
    debugPrint('NotificationService: Background notification - ID: ${response.id}');
  }

  Future<bool> requestPermissions() async {
    debugPrint('NotificationService: Requesting permissions...');
    
    if (Platform.isAndroid) {
      final android = _notifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      
      if (android != null) {
        final notifPermission = await android.requestNotificationsPermission();
        debugPrint('NotificationService: Notification permission: $notifPermission');
        
        // Check exact alarm permission using native method
        final canScheduleExact = await NativeAlarmService.canScheduleExactAlarms();
        debugPrint('NotificationService: Can schedule exact alarms (native): $canScheduleExact');
        
        if (!canScheduleExact) {
          debugPrint('NotificationService: Requesting exact alarm permission...');
          await NativeAlarmService.requestExactAlarmPermission();
        }
        
        return notifPermission ?? false;
      }
    } else if (Platform.isIOS) {
      final ios = _notifications.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      
      if (ios != null) {
        final granted = await ios.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
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
      icon: '@mipmap/ic_launcher',
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
  Future<void> scheduleNotifications(List<CandleLighting> candleLightings) async {
    debugPrint('NotificationService: Scheduling ${candleLightings.length} events...');
    
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
      final preTime = lighting.candleLightingTime.subtract(Duration(minutes: preMinutes));
      if (preTime.isAfter(now)) {
        final title = lighting.isYomTov ? 'יום טוב מגיע!' : 'שבת מגיעה!';
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
        final title = lighting.isYomTov ? 'יום טוב שמח!' : 'שבת שלום!';
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
        
        debugPrint('NotificationService: Scheduled native alarm #$id for $scheduledTime: $success');
        return success;
      } else {
        // iOS: Use zonedSchedule
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
        
        await _notifications.zonedSchedule(
          id,
          title,
          body,
          tzTime,
          _getNotificationDetails(),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        );
        
        debugPrint('NotificationService: iOS notification #$id scheduled successfully');
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
        'שבת שלום! Good Shabbos!',
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
    debugPrint('NotificationService: Scheduling test for $seconds seconds...');
    
    await initialize();
    await requestPermissions();

    final scheduledTime = DateTime.now().add(Duration(seconds: seconds));

    if (Platform.isAndroid) {
      // Use native alarm for Android
      final success = await NativeAlarmService.scheduleAlarm(
        id: 998,
        scheduledTime: scheduledTime,
        title: 'שבת שלום! Good Shabbos!',
        body: 'Scheduled test notification 🕯️🕯️ (Background test)',
      );
      
      debugPrint('NotificationService: Test alarm scheduled: $success');
      debugPrint('NotificationService: Will fire at: $scheduledTime');
    } else {
      // iOS
      final tzTime = tz.TZDateTime(
        tz.local,
        scheduledTime.year,
        scheduledTime.month,
        scheduledTime.day,
        scheduledTime.hour,
        scheduledTime.minute,
        scheduledTime.second,
      );
      
      debugPrint('NotificationService: Scheduling iOS test notification');
      debugPrint('NotificationService: Scheduled time: $scheduledTime');
      debugPrint('NotificationService: TZ time: $tzTime');
      
      await _notifications.zonedSchedule(
        998,
        'שבת שלום! Good Shabbos!',
        'Scheduled test notification 🕯️🕯️ (Background test)',
        tzTime,
        _getNotificationDetails(),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
      
      // Verify notification was scheduled
      final pending = await _notifications.pendingNotificationRequests();
      debugPrint('NotificationService: Pending iOS notifications: ${pending.length}');
      for (final n in pending) {
        debugPrint('  - ID ${n.id}: ${n.title}');
      }
    }
  }

  /// Backup method using Future.delayed
  Future<void> sendDelayedTestNotificationAlt({int seconds = 10}) async {
    debugPrint('NotificationService: Starting backup timer...');
    
    await initialize();
    
    Future.delayed(Duration(seconds: seconds), () async {
      debugPrint('NotificationService: Backup timer fired!');
      
      try {
        await _notifications.show(
          997,
          'שבת שלום! Good Shabbos!',
          'Backup notification 🕯️🕯️',
          _getNotificationDetails(),
        );
        
        final soundId = await _audioService.getCandleLightingSound();
        if (soundId != 'default' && soundId != 'silent') {
          await _audioService.playSound(soundId);
        }
      } catch (e) {
        debugPrint('NotificationService: Backup failed: $e');
      }
    });
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
    return prefs.getInt(_preNotificationMinutesKey) ?? 20;
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
