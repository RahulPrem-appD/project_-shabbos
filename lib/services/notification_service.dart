import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tzdata;
import '../models/candle_lighting.dart';
import 'audio_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  final AudioService _audioService = AudioService();
  
  static const String _notificationsEnabledKey = 'notifications_enabled';
  static const String _preNotificationMinutesKey = 'pre_notification_minutes';
  static const String _candleNotificationEnabledKey = 'candle_notification_enabled';
  
  // Single channel for all notifications - simpler and more reliable
  static const String _channelId = 'shabbos_alerts';
  static const String _channelName = 'Shabbos Alerts';
  static const String _channelDesc = 'Candle lighting time reminders';

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    debugPrint('NotificationService: Initializing...');

    // Initialize timezone database
    tzdata.initializeTimeZones();
    _setLocalTimezone();

    // Android initialization settings
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    
    // iOS initialization settings
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      defaultPresentAlert: true,
      defaultPresentBadge: true,
      defaultPresentSound: true,
    );

    final initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    final initialized = await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: _backgroundHandler,
    );
    
    debugPrint('NotificationService: Plugin initialized: $initialized');

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
    
    if (android == null) {
      debugPrint('NotificationService: Could not get Android implementation');
      return;
    }

    // Create a single high-importance channel
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
      final offsetMinutes = offset.inMinutes % 60;
      
      debugPrint('NotificationService: Device offset: ${offsetHours}h ${offsetMinutes}m');
      
      // Try common timezones first
      final tzMappings = {
        -5: 'America/New_York',
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
          debugPrint('NotificationService: Failed to set $tzName: $e');
        }
      }
      
      // Fallback: search all locations
      for (final entry in tz.timeZoneDatabase.locations.entries) {
        final loc = entry.value;
        final locOffset = loc.currentTimeZone.offset ~/ (1000 * 60 * 60);
        if (locOffset == offsetHours) {
          tz.setLocalLocation(loc);
          debugPrint('NotificationService: Timezone set to ${entry.key} (fallback)');
          return;
        }
      }
      
      // Last resort: UTC
      tz.setLocalLocation(tz.getLocation('UTC'));
      debugPrint('NotificationService: Using UTC');
    } catch (e) {
      debugPrint('NotificationService: Timezone error: $e');
      try {
        tz.setLocalLocation(tz.getLocation('UTC'));
      } catch (_) {}
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
        // Request notification permission (Android 13+)
        final notifPermission = await android.requestNotificationsPermission();
        debugPrint('NotificationService: Notification permission: $notifPermission');
        
        // Check exact alarm capability
        final canScheduleExact = await android.canScheduleExactNotifications();
        debugPrint('NotificationService: Can schedule exact: $canScheduleExact');
        
        if (canScheduleExact != true) {
          // Request exact alarm permission
          await android.requestExactAlarmsPermission();
          final canScheduleAfter = await android.canScheduleExactNotifications();
          debugPrint('NotificationService: Can schedule exact (after): $canScheduleAfter');
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
        debugPrint('NotificationService: iOS permission: $granted');
        return granted ?? false;
      }
    }
    
    return false;
  }

  /// Get notification details for Android and iOS
  NotificationDetails _getNotificationDetails({bool playSound = true}) {
    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.max,
      priority: Priority.max,
      playSound: playSound,
      enableVibration: true,
      enableLights: true,
      icon: '@mipmap/ic_launcher',
      styleInformation: const BigTextStyleInformation(''),
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
      fullScreenIntent: true,
    );

    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: playSound,
      badgeNumber: 1,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    return NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
  }

  /// Schedule notifications for candle lighting times
  Future<void> scheduleNotifications(List<CandleLighting> candleLightings) async {
    debugPrint('NotificationService: Scheduling ${candleLightings.length} events...');
    
    await initialize();
    await _notifications.cancelAll();

    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_notificationsEnabledKey) ?? true;
    
    if (!enabled) {
      debugPrint('NotificationService: Notifications disabled by user');
      return;
    }

    final preMinutes = prefs.getInt(_preNotificationMinutesKey) ?? 20;
    final candleEnabled = prefs.getBool(_candleNotificationEnabledKey) ?? true;

    int id = 0;
    int scheduled = 0;
    final now = DateTime.now();
    final details = _getNotificationDetails();

    for (final lighting in candleLightings) {
      // Pre-notification (X minutes before)
      final preTime = lighting.candleLightingTime.subtract(Duration(minutes: preMinutes));
      if (preTime.isAfter(now)) {
        final success = await _scheduleNotification(
          id: id++,
          title: lighting.isYomTov ? 'יום טוב מגיע!' : 'שבת מגיעה!',
          body: lighting.isYomTov 
              ? 'Yom Tov in $preMinutes minutes • $preMinutes דקות ליום טוב'
              : 'Shabbos in $preMinutes minutes • $preMinutes דקות לשבת',
          scheduledTime: preTime,
          details: details,
        );
        if (success) scheduled++;
      }

      // Candle lighting notification
      if (candleEnabled && lighting.candleLightingTime.isAfter(now)) {
        final success = await _scheduleNotification(
          id: id++,
          title: lighting.isYomTov ? 'יום טוב שמח!' : 'שבת שלום!',
          body: lighting.isYomTov 
              ? 'Good Yom Tov! Time to light candles 🕯️🕯️'
              : 'Good Shabbos! Time to light candles 🕯️🕯️',
          scheduledTime: lighting.candleLightingTime,
          details: details,
        );
        if (success) scheduled++;
      }
    }

    debugPrint('NotificationService: Successfully scheduled $scheduled notifications');
    
    // Verify pending notifications
    await _logPendingNotifications();
  }

  Future<bool> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    required NotificationDetails details,
  }) async {
    try {
      final tzTime = tz.TZDateTime(
        tz.local,
        scheduledTime.year,
        scheduledTime.month,
        scheduledTime.day,
        scheduledTime.hour,
        scheduledTime.minute,
        scheduledTime.second,
      );
      
      // Use inexactAllowWhileIdle for better compatibility with older Android versions
      // and devices with aggressive battery optimization
      await _notifications.zonedSchedule(
        id,
        title,
        body,
        tzTime,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: 'shabbos_notification_$id',
      );
      
      debugPrint('NotificationService: Scheduled #$id for $scheduledTime');
      return true;
    } catch (e, stack) {
      debugPrint('NotificationService: Failed to schedule #$id: $e');
      debugPrint('Stack: $stack');
      return false;
    }
  }

  Future<void> _logPendingNotifications() async {
    try {
      final pending = await _notifications.pendingNotificationRequests();
      debugPrint('NotificationService: ${pending.length} pending notifications:');
      for (final n in pending.take(10)) {
        debugPrint('  - ID ${n.id}: ${n.title}');
      }
    } catch (e) {
      debugPrint('NotificationService: Could not get pending: $e');
    }
  }

  /// Send an immediate test notification
  Future<void> sendTestNotification() async {
    debugPrint('NotificationService: Sending immediate test notification...');
    
    await initialize();
    await requestPermissions();

    // Play sound via audio service for immediate feedback
    final soundId = await _audioService.getCandleLightingSound();
    if (soundId != 'default' && soundId != 'silent') {
      await _audioService.playSound(soundId);
    }

    final details = _getNotificationDetails();

    try {
      await _notifications.show(
        999,
        'שבת שלום! Good Shabbos!',
        'Test notification 🕯️🕯️',
        details,
        payload: 'test_immediate',
      );
      debugPrint('NotificationService: Immediate test notification sent');
    } catch (e) {
      debugPrint('NotificationService: Failed to send immediate: $e');
    }
  }

  /// Send a delayed test notification (for testing scheduled notifications)
  Future<void> sendDelayedTestNotification({int seconds = 10}) async {
    debugPrint('NotificationService: Scheduling test notification for $seconds seconds...');
    
    await initialize();
    await requestPermissions();

    final scheduledTime = DateTime.now().add(Duration(seconds: seconds));
    final details = _getNotificationDetails();

    // Cancel any existing test notification
    await _notifications.cancel(998);

    final success = await _scheduleNotification(
      id: 998,
      title: 'שבת שלום! Good Shabbos!',
      body: 'Scheduled test notification 🕯️🕯️',
      scheduledTime: scheduledTime,
      details: details,
    );

    if (success) {
      debugPrint('NotificationService: Test notification scheduled for $scheduledTime');
      await _logPendingNotifications();
    }
  }

  /// Alternative delayed notification using Future.delayed (backup method)
  Future<void> sendDelayedTestNotificationAlt({int seconds = 10}) async {
    debugPrint('NotificationService: Starting backup timer for $seconds seconds...');
    
    await initialize();
    
    Future.delayed(Duration(seconds: seconds), () async {
      debugPrint('NotificationService: Backup timer fired!');
      
      final details = _getNotificationDetails();
      
      try {
        await _notifications.show(
          997,
          'שבת שלום! Good Shabbos!',
          'Backup test notification 🕯️🕯️',
          details,
          payload: 'test_backup',
        );
        
        // Also play sound
        final soundId = await _audioService.getCandleLightingSound();
        if (soundId != 'default' && soundId != 'silent') {
          await _audioService.playSound(soundId);
        }
        
        debugPrint('NotificationService: Backup notification sent');
      } catch (e) {
        debugPrint('NotificationService: Backup notification failed: $e');
      }
    });
  }

  // Settings getters/setters
  Future<bool> getNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_notificationsEnabledKey) ?? true;
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notificationsEnabledKey, enabled);
    if (!enabled) {
      await _notifications.cancelAll();
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
