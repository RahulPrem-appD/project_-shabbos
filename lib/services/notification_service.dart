import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tzdata;
import '../models/candle_lighting.dart';
import 'audio_service.dart';
import 'native_alarm_service.dart';
import 'live_activity_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  final AudioService _audioService = AudioService();
  final LiveActivityService _liveActivityService = LiveActivityService();

  static const String _notificationsEnabledKey = 'notifications_enabled';
  static const String _preNotificationMinutesKey = 'pre_notification_minutes';
  static const String _candleNotificationEnabledKey =
      'candle_notification_enabled';

  static const String _channelId = 'shabbos_alerts';
  static const String _channelName = 'Shabbos Alerts';
  static const String _channelDesc = 'Candle lighting time reminders';

  bool _isInitialized = false;

  // Store mapping of notification IDs to Yom Tov status
  // Format: "notification_id:isYomTov" -> "true"/"false"
  static const String _notificationYomTovPrefix = 'notification_yomtov_';

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

    // Initialize Live Activities for iOS
    if (Platform.isIOS) {
      await _liveActivityService.initialize();
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
        'NotificationService: Device offset: ${offset.inHours}h ${offset.inMinutes % 60}m ($offsetMinutes minutes)',
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
    // Play custom sound when notification is tapped (iOS foreground scenario)
    _playNotificationSound(response.id);
  }

  @pragma('vm:entry-point')
  static void _backgroundHandler(NotificationResponse response) {
    debugPrint(
      'NotificationService: Background notification - ID: ${response.id}',
    );
  }

  /// Play custom sound based on notification type
  Future<void> _playNotificationSound(int? notificationId) async {
    try {
      // Determine if this is a pre-notification (even IDs) or candle lighting (odd IDs)
      // In scheduling loop: pre-notification gets even IDs (0, 2, 4...), candle lighting gets odd IDs (1, 3, 5...)
      final isPreNotification = (notificationId ?? 0) % 2 == 0;

      // Check if this is a Yom Tov notification
      final isYomTov = await _isNotificationYomTov(notificationId ?? 0);

      // Get the appropriate sound based on notification type and Yom Tov status
      final soundId = await _getSoundIdForNotification(
        isPreNotification: isPreNotification,
        isYomTov: isYomTov,
      );

      if (soundId != 'silent') {
        await _audioService.playSound(soundId);
        debugPrint(
          'NotificationService: Played sound: $soundId (isPre=$isPreNotification, isYomTov=$isYomTov)',
        );
      }
    } catch (e) {
      debugPrint('NotificationService: Error playing sound: $e');
    }
  }

  /// Store Yom Tov status for a notification ID
  Future<void> _storeNotificationYomTov(
    int notificationId,
    bool isYomTov,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(
        '$_notificationYomTovPrefix$notificationId',
        isYomTov,
      );
    } catch (e) {
      debugPrint('NotificationService: Error storing Yom Tov status: $e');
    }
  }

  /// Retrieve Yom Tov status for a notification ID
  Future<bool> _isNotificationYomTov(int notificationId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('$_notificationYomTovPrefix$notificationId') ??
          false;
    } catch (e) {
      debugPrint('NotificationService: Error retrieving Yom Tov status: $e');
      return false;
    }
  }

  /// Clean up stored Yom Tov status for old notifications
  Future<void> _cleanupNotificationYomTovStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      for (final key in keys) {
        if (key.startsWith(_notificationYomTovPrefix)) {
          // Keep only recent notification IDs (last 100)
          final idStr = key.substring(_notificationYomTovPrefix.length);
          final id = int.tryParse(idStr);
          if (id != null && id < 0) {
            // Remove old negative test IDs or very old IDs
            await prefs.remove(key);
          }
        }
      }
    } catch (e) {
      debugPrint('NotificationService: Error cleaning up Yom Tov status: $e');
    }
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

  NotificationDetails _getNotificationDetails({String? iosSoundFile}) {
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

    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      badgeNumber: 1,
      interruptionLevel: InterruptionLevel.timeSensitive,
      sound: iosSoundFile, // Custom sound file from app bundle
    );

    return NotificationDetails(android: androidDetails, iOS: iosDetails);
  }

  /// Map sound ID to iOS sound filename
  String? _getIosSoundFile(String soundId) {
    const soundFiles = {
      'rav_shalom_shofar': 'RavShalomShofarDefaultlouder.mp3',
      'shabbat_shalom_song': 'RYomTovShabbatShalomSong.mp3',
      'yomtov_default': 'YomTov-Default.mp3',
      'ata_bechartanu': 'Ata Bechartanu-YomTov.mp3',
      'ata_bechartanu_2': 'Ata Bechartanu2-YomTov.mp3',
      'hodu_lahashem': 'HoduLaHashem-YomTov.mp3',
    };
    return soundFiles[soundId];
  }

  /// Get the appropriate sound ID for a notification type
  /// - Early reminder: Music (user selected) for Shabbos, Yom Tov sound for Yom Tov
  /// - Candle lighting: ALWAYS Rav Shalom Shofar (fixed)
  Future<String> _getSoundIdForNotification({
    required bool isPreNotification,
    required bool isYomTov,
  }) async {
    if (!isPreNotification) {
      // Candle lighting notification: ALWAYS use Rav Shalom Shofar
      return _audioService.getCandleLightingSound();
    }

    // Pre-notification (early reminder)
    if (isYomTov) {
      // Yom Tov events use Yom Tov sound
      return await _audioService.getYomTovSound();
    } else {
      // Shabbos events use early reminder music
      return await _audioService.getEarlyReminderSound();
    }
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

    // Clean up old Yom Tov status entries
    await _cleanupNotificationYomTovStatus();

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
      // Pre-notification with countdown
      final preTime = lighting.candleLightingTime.subtract(
        Duration(minutes: preMinutes),
      );
      if (preTime.isAfter(now)) {
        // Format candle lighting time
        final candleTimeFormatted =
            '${lighting.candleLightingTime.hour}:${lighting.candleLightingTime.minute.toString().padLeft(2, '0')}';

        final title = lighting.isYomTov
            ? '⏱️ $preMinutes min to Yom Tov!'
            : '⏱️ $preMinutes min to Shabbos!';
        final body = lighting.isYomTov
            ? '🕯️ Light candles at $candleTimeFormatted\nיום טוב מגיע • Yom Tov is coming!'
            : '🕯️ Light candles at $candleTimeFormatted\nשבת מגיעה • Shabbos is coming!';

        final notificationId = id++;
        final success = await _scheduleNotification(
          id: notificationId,
          title: title,
          body: body,
          scheduledTime: preTime,
          isPreNotification: true,
          isYomTov: lighting.isYomTov,
          candleLightingTime: lighting.candleLightingTime, // Pass for countdown
        );
        if (success) {
          scheduled++;
          // Store Yom Tov status for this notification
          await _storeNotificationYomTov(notificationId, lighting.isYomTov);
        }
      }

      // Candle lighting notification
      if (candleEnabled && lighting.candleLightingTime.isAfter(now)) {
        final title = lighting.isYomTov ? '!יום טוב שמח' : '!שבת שלום';
        final body = lighting.isYomTov
            ? 'Good Yom Tov! Time to light candles 🕯️🕯️'
            : 'Good Shabbos! Time to light candles 🕯️🕯️';

        final notificationId = id++;
        final success = await _scheduleNotification(
          id: notificationId,
          title: title,
          body: body,
          scheduledTime: lighting.candleLightingTime,
          isPreNotification: false,
          isYomTov: lighting.isYomTov,
        );
        if (success) {
          scheduled++;
          // Store Yom Tov status for this notification
          await _storeNotificationYomTov(notificationId, lighting.isYomTov);
        }
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
    bool isPreNotification = false,
    bool isYomTov = false,
    DateTime? candleLightingTime,
  }) async {
    try {
      // Get the appropriate sound for this notification type
      final soundId = await _getSoundIdForNotification(
        isPreNotification: isPreNotification,
        isYomTov: isYomTov,
      );

      if (Platform.isAndroid) {
        // Use native alarm scheduler for maximum reliability on Android
        final success = await NativeAlarmService.scheduleAlarm(
          id: id,
          scheduledTime: scheduledTime,
          title: title,
          body: body,
          isPreNotification: isPreNotification,
          candleLightingTime: candleLightingTime, // Pass for countdown display
          soundId: soundId, // Pass sound ID for Android playback
        );

        debugPrint(
          'NotificationService: Scheduled native alarm #$id for $scheduledTime (isPre=$isPreNotification, isYomTov=$isYomTov, sound=$soundId): $success',
        );
        return success;
      } else {
        // iOS: Use zonedSchedule with custom sound
        // All sounds are now trimmed to 30 seconds for iOS compatibility
        final tzTime = tz.TZDateTime(
          tz.local,
          scheduledTime.year,
          scheduledTime.month,
          scheduledTime.day,
          scheduledTime.hour,
          scheduledTime.minute,
          scheduledTime.second,
        );

        final iosSoundFile = _getIosSoundFile(soundId);

        debugPrint('NotificationService: Scheduling iOS notification #$id');
        debugPrint('NotificationService: Local timezone: ${tz.local.name}');
        debugPrint('NotificationService: Scheduled time: $scheduledTime');
        debugPrint('NotificationService: TZ time: $tzTime');
        debugPrint('NotificationService: Sound ID: $soundId');
        debugPrint(
          'NotificationService: iOS sound file: $iosSoundFile (isPre=$isPreNotification, isYomTov=$isYomTov)',
        );

        // Schedule the notification with custom sound
        await _notifications.zonedSchedule(
          id,
          title,
          body,
          tzTime,
          _getNotificationDetails(iosSoundFile: iosSoundFile),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        );

        debugPrint(
          'NotificationService: iOS notification #$id scheduled with sound: $iosSoundFile',
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

    // Candle lighting sound is always Rav Shalom Shofar (fixed)
    final soundId = _audioService.getCandleLightingSound();
    final iosSoundFile = _getIosSoundFile(soundId);

    debugPrint('NotificationService: Using sound ID: $soundId');
    debugPrint('NotificationService: iOS sound file: $iosSoundFile');

    // Play sound via Flutter AudioService (works for both platforms)
    // iOS notification sounds have a 30-second limit, so we play via AudioService
    if (soundId != 'silent') {
      debugPrint(
        'NotificationService: Playing sound via Flutter AudioService...',
      );
      await _audioService.playSound(soundId);
    }

    try {
      // Show notification without sound (we play our own)
      await _notifications.show(
        999,
        '!שבת שלום Good Shabbos!',
        'Test notification 🕯️🕯️',
        _getNotificationDetails(
          iosSoundFile: null,
        ), // No notification sound - we play via AudioService
      );
      debugPrint('NotificationService: Immediate test sent');
    } catch (e) {
      debugPrint('NotificationService: Failed to send: $e');
    }
  }

  /// Send a delayed test notification that simulates the full candle lighting flow
  /// - Pre-notification (early reminder) fires after [preNotificationSeconds]
  /// - Candle lighting notification fires after [candleLightingSeconds]
  /// - On Android: Pre-notification shows countdown timer to candle lighting
  /// - On iOS: Starts Live Activity with countdown
  Future<void> sendDelayedTestNotification({
    int preNotificationSeconds = 10,
    int candleLightingSeconds = 30,
  }) async {
    debugPrint('==========================================');
    debugPrint('NotificationService: SCHEDULING CANDLE LIGHTING TEST FLOW');
    debugPrint('==========================================');
    debugPrint(
      'NotificationService: Pre-notification in: $preNotificationSeconds seconds',
    );
    debugPrint(
      'NotificationService: Candle lighting in: $candleLightingSeconds seconds',
    );

    await initialize();
    await requestPermissions();

    final now = DateTime.now();
    final preNotificationTime = now.add(
      Duration(seconds: preNotificationSeconds),
    );
    final candleLightingTime = now.add(
      Duration(seconds: candleLightingSeconds),
    );

    debugPrint('NotificationService: Current time: $now');
    debugPrint(
      'NotificationService: Pre-notification at: $preNotificationTime',
    );
    debugPrint('NotificationService: Candle lighting at: $candleLightingTime');

    // Cancel any existing test notifications
    await _notifications.cancel(996);
    await _notifications.cancel(997);
    await _notifications.cancel(998);
    if (Platform.isAndroid) {
      await NativeAlarmService.cancelAlarm(996);
      await NativeAlarmService.cancelAlarm(997);
    }

    // Get sounds for the test (using Shabbos sounds, not Yom Tov)
    final earlyReminderSoundId = await _audioService.getEarlyReminderSound();
    final candleLightingSoundId = _audioService.getCandleLightingSound();

    if (Platform.isAndroid) {
      // Schedule pre-notification with countdown (ID 996)
      final preSuccess = await NativeAlarmService.scheduleAlarm(
        id: 996,
        scheduledTime: preNotificationTime,
        title: '🕯️ Candle Lighting Soon!',
        body: 'Time to prepare for Shabbos!',
        isPreNotification: true,
        candleLightingTime: candleLightingTime,
        soundId: earlyReminderSoundId,
      );
      debugPrint(
        'NotificationService: Android pre-notification scheduled: $preSuccess (sound: $earlyReminderSoundId)',
      );

      // Schedule candle lighting notification (ID 997)
      final candleSuccess = await NativeAlarmService.scheduleAlarm(
        id: 997,
        scheduledTime: candleLightingTime,
        title: '!שבת שלום Good Shabbos!',
        body: 'Time to light candles 🕯️🕯️',
        isPreNotification: false,
        soundId: candleLightingSoundId,
      );
      debugPrint(
        'NotificationService: Android candle lighting scheduled: $candleSuccess (sound: $candleLightingSoundId)',
      );
    } else {
      // iOS: Schedule both notifications with custom sounds
      // All sounds are now trimmed to 30 seconds for iOS compatibility
      debugPrint('NotificationService: Setting up iOS notifications...');
      debugPrint(
        'NotificationService: Early reminder sound ID: $earlyReminderSoundId',
      );
      debugPrint(
        'NotificationService: Candle lighting sound ID: $candleLightingSoundId',
      );

      // Get iOS sound filenames
      final preIosSoundFile = _getIosSoundFile(earlyReminderSoundId);
      final candleIosSoundFile = _getIosSoundFile(candleLightingSoundId);

      try {
        // Calculate remaining time for the notification body
        final remainingSeconds = candleLightingSeconds - preNotificationSeconds;
        final remainingMinutes = (remainingSeconds / 60).ceil();
        final candleTimeFormatted =
            '${candleLightingTime.hour}:${candleLightingTime.minute.toString().padLeft(2, '0')}';

        // Schedule pre-notification with countdown info in body
        final preTzTime = tz.TZDateTime(
          tz.local,
          preNotificationTime.year,
          preNotificationTime.month,
          preNotificationTime.day,
          preNotificationTime.hour,
          preNotificationTime.minute,
          preNotificationTime.second,
        );

        // Schedule with custom sound (trimmed to 30s)
        await _notifications.zonedSchedule(
          996,
          '⏱️ $remainingMinutes min until Candle Lighting',
          '🕯️ Light candles at $candleTimeFormatted\nTime to prepare for Shabbos!',
          preTzTime,
          _getNotificationDetails(iosSoundFile: preIosSoundFile),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        );
        debugPrint(
          'NotificationService: ✓ iOS pre-notification scheduled with sound: $preIosSoundFile',
        );

        // Start Live Activity countdown (requires Widget Extension setup in Xcode)
        await startLiveActivityCountdown(
          candleLightingTime: candleLightingTime,
          eventName: 'Test Shabbos Candle Lighting',
          isYomTov: false,
        );
        debugPrint(
          'NotificationService: ✓ iOS Live Activity started for countdown',
        );

        // Schedule candle lighting notification
        final candleTzTime = tz.TZDateTime(
          tz.local,
          candleLightingTime.year,
          candleLightingTime.month,
          candleLightingTime.day,
          candleLightingTime.hour,
          candleLightingTime.minute,
          candleLightingTime.second,
        );

        // Schedule with custom shofar sound
        await _notifications.zonedSchedule(
          997,
          '!שבת שלום Good Shabbos!',
          '🕯️🕯️ Time to light candles!',
          candleTzTime,
          _getNotificationDetails(iosSoundFile: candleIosSoundFile),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        );
        debugPrint(
          'NotificationService: ✓ iOS candle lighting notification scheduled with sound: $candleIosSoundFile',
        );

        // Verify notifications were scheduled
        final pending = await _notifications.pendingNotificationRequests();
        debugPrint(
          'NotificationService: Pending notifications: ${pending.length}',
        );
        for (final n in pending) {
          debugPrint('  ✓ ID ${n.id}: ${n.title}');
        }
      } catch (e, stack) {
        debugPrint('NotificationService: ✗ ERROR scheduling notifications: $e');
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

  // ============================================
  // Live Activity Methods (iOS Countdown)
  // ============================================

  /// Start a Live Activity countdown for the upcoming candle lighting
  /// Call this when the pre-notification fires or when user opens the app
  /// within the pre-notification window
  Future<void> startLiveActivityCountdown({
    required DateTime candleLightingTime,
    required String eventName,
    required bool isYomTov,
  }) async {
    if (!Platform.isIOS) {
      debugPrint('NotificationService: Live Activities only supported on iOS');
      return;
    }

    try {
      await _liveActivityService.startCandleLightingCountdown(
        candleLightingTime: candleLightingTime,
        eventName: eventName,
        isYomTov: isYomTov,
      );
      debugPrint(
        'NotificationService: Started Live Activity countdown to $candleLightingTime',
      );
    } catch (e) {
      debugPrint('NotificationService: Error starting Live Activity: $e');
    }
  }

  /// End any active Live Activity countdown
  Future<void> endLiveActivityCountdown() async {
    if (!Platform.isIOS) return;

    try {
      await _liveActivityService.endCurrentActivity();
      debugPrint('NotificationService: Ended Live Activity countdown');
    } catch (e) {
      debugPrint('NotificationService: Error ending Live Activity: $e');
    }
  }

  /// Check if Live Activities are enabled
  Future<bool> areLiveActivitiesEnabled() async {
    if (!Platform.isIOS) return false;
    return await _liveActivityService.areActivitiesEnabled();
  }

  /// Check if we should start a Live Activity based on current time and next candle lighting
  Future<void> checkAndStartLiveActivity(
    List<CandleLighting> candleLightings,
  ) async {
    if (!Platform.isIOS) return;

    final now = DateTime.now();
    final preMinutes = await getPreNotificationMinutes();

    for (final lighting in candleLightings) {
      final preTime = lighting.candleLightingTime.subtract(
        Duration(minutes: preMinutes),
      );

      // If we're within the pre-notification window (between preTime and candleLightingTime)
      if (now.isAfter(preTime) && now.isBefore(lighting.candleLightingTime)) {
        // Start the Live Activity
        await startLiveActivityCountdown(
          candleLightingTime: lighting.candleLightingTime,
          eventName: lighting.displayName,
          isYomTov: lighting.isYomTov,
        );
        return;
      }
    }

    // If we're not in any pre-notification window, end any existing activity
    await endLiveActivityCountdown();
  }
}
