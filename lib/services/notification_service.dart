import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import '../models/candle_lighting.dart';
import 'audio_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  
  static const String _notificationsEnabledKey = 'notifications_enabled';
  static const String _preNotificationMinutesKey = 'pre_notification_minutes';
  static const String _candleNotificationEnabledKey = 'candle_notification_enabled';

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    debugPrint('NotificationService: Initializing...');

    // Initialize timezone database
    tz.initializeTimeZones();
    
    // Set local timezone based on device offset
    _setLocalTimezone();

    // Initialize notifications
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

    // Create Android channel
    if (Platform.isAndroid) {
      final android = _notifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        await android.createNotificationChannel(
          const AndroidNotificationChannel(
            'shabbos_notifications',
            'Shabbos Notifications',
            description: 'Candle lighting reminders',
            importance: Importance.high,
            playSound: true,
            enableVibration: true,
          ),
        );
      }
    }

    // Request permissions
    await requestPermissions();

    _isInitialized = true;
    debugPrint('NotificationService: Initialized successfully');
  }

  void _setLocalTimezone() {
    try {
      // Get the device's timezone offset
      final now = DateTime.now();
      final offset = now.timeZoneOffset;
      final offsetHours = offset.inHours;
      
      debugPrint('NotificationService: Device timezone offset: $offsetHours hours');
      
      // Map common offsets to timezone names
      String tzName;
      
      // Try to find a matching timezone
      if (offsetHours >= -5 && offsetHours <= -4) {
        tzName = 'America/New_York'; // EST/EDT
      } else if (offsetHours >= -6 && offsetHours <= -5) {
        tzName = 'America/Chicago'; // CST/CDT
      } else if (offsetHours >= -7 && offsetHours <= -6) {
        tzName = 'America/Denver'; // MST/MDT
      } else if (offsetHours >= -8 && offsetHours <= -7) {
        tzName = 'America/Los_Angeles'; // PST/PDT
      } else if (offsetHours >= 2 && offsetHours <= 3) {
        tzName = 'Asia/Jerusalem'; // IST/IDT
      } else if (offsetHours >= 0 && offsetHours <= 1) {
        tzName = 'Europe/London'; // GMT/BST
      } else if (offsetHours >= 1 && offsetHours <= 2) {
        tzName = 'Europe/Paris'; // CET/CEST
      } else {
        // Create a fixed offset timezone
        tzName = 'Etc/GMT${offsetHours >= 0 ? '-' : '+'}${offsetHours.abs()}';
      }
      
      try {
        tz.setLocalLocation(tz.getLocation(tzName));
        debugPrint('NotificationService: Timezone set to $tzName');
      } catch (e) {
        // If the specific timezone fails, use a generic approach
        // Find any timezone with matching offset
        final locations = tz.timeZoneDatabase.locations;
        for (final entry in locations.entries) {
          final location = entry.value;
          final tzOffset = location.currentTimeZone.offset ~/ 1000 ~/ 3600;
          if (tzOffset == offsetHours) {
            tz.setLocalLocation(location);
            debugPrint('NotificationService: Timezone set to ${entry.key} (fallback)');
            return;
          }
        }
        // Last resort - use UTC
        tz.setLocalLocation(tz.getLocation('UTC'));
        debugPrint('NotificationService: Timezone set to UTC (last resort)');
      }
    } catch (e) {
      debugPrint('NotificationService: Timezone error: $e');
      tz.setLocalLocation(tz.getLocation('UTC'));
    }
  }

  void _onNotificationResponse(NotificationResponse response) {
    debugPrint('NotificationService: Notification tapped');
  }

  @pragma('vm:entry-point')
  static void _backgroundHandler(NotificationResponse response) {
    debugPrint('NotificationService: Background notification');
  }

  Future<bool> requestPermissions() async {
    debugPrint('NotificationService: Requesting permissions...');
    
    if (Platform.isAndroid) {
      final android = _notifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        final granted = await android.requestNotificationsPermission();
        await android.requestExactAlarmsPermission();
        debugPrint('NotificationService: Android permission: $granted');
        return granted ?? false;
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

  /// Schedule notifications for candle lighting times
  Future<void> scheduleNotifications(List<CandleLighting> candleLightings) async {
    debugPrint('NotificationService: Scheduling ${candleLightings.length} events...');
    
    await _notifications.cancelAll();

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
        await _scheduleOne(
          id: id++,
          title: lighting.isYomTov ? 'יום טוב מגיע!' : 'שבת מגיעה!',
          body: lighting.isYomTov 
              ? 'Yom Tov in $preMinutes minutes • $preMinutes דקות ליום טוב'
              : 'Shabbos in $preMinutes minutes • $preMinutes דקות לשבת',
          time: preTime,
        );
        scheduled++;
      }

      // Candle lighting notification
      if (candleEnabled && lighting.candleLightingTime.isAfter(now)) {
        await _scheduleOne(
          id: id++,
          title: lighting.isYomTov ? 'יום טוב שמח!' : 'שבת שלום!',
          body: lighting.isYomTov 
              ? 'Good Yom Tov! Time to light candles 🕯️🕯️'
              : 'Good Shabbos! Time to light candles 🕯️🕯️',
          time: lighting.candleLightingTime,
        );
        scheduled++;
      }
    }

    debugPrint('NotificationService: Scheduled $scheduled notifications');
  }

  Future<void> _scheduleOne({
    required int id,
    required String title,
    required String body,
    required DateTime time,
  }) async {
    try {
      // Convert local DateTime to TZDateTime
      final tzTime = tz.TZDateTime(
        tz.local,
        time.year,
        time.month,
        time.day,
        time.hour,
        time.minute,
        time.second,
      );
      
      const androidDetails = AndroidNotificationDetails(
        'shabbos_notifications',
        'Shabbos Notifications',
        channelDescription: 'Candle lighting reminders',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        icon: '@mipmap/ic_launcher',
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        badgeNumber: 1,
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notifications.zonedSchedule(
        id,
        title,
        body,
        tzTime,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
      
      debugPrint('NotificationService: Scheduled #$id for $time (local)');
    } catch (e) {
      debugPrint('NotificationService: Schedule error: $e');
    }
  }

  /// Send test notification immediately
  Future<void> sendTestNotification() async {
    debugPrint('NotificationService: Sending test notification...');
    
    await requestPermissions();

    // Get the audio service to play the selected sound
    final audioService = AudioService();
    final candleSoundId = await audioService.getCandleLightingSound();
    
    // Play the custom sound
    await audioService.playSound(candleSoundId);

    const androidDetails = AndroidNotificationDetails(
      'shabbos_notifications',
      'Shabbos Notifications',
      channelDescription: 'Candle lighting reminders',
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      badgeNumber: 1,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      999,
      'שבת שלום! Good Shabbos!',
      'Test notification 🕯️🕯️',
      details,
    );
    
    debugPrint('NotificationService: Test notification sent');
  }

  // Settings
  Future<bool> getNotificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_notificationsEnabledKey) ?? true;
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notificationsEnabledKey, enabled);
    if (!enabled) await _notifications.cancelAll();
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
