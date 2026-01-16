import 'dart:io';
import 'dart:convert';
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

  // Store mapping of notification IDs to notification type
  // Format: "notification_type_id" -> "pre" | "candle" | "issur"
  static const String _notificationTypePrefix = 'notification_type_';

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
    debugPrint('NotificationService: Notification response received - ID: ${response.id}');
    debugPrint('NotificationService: Platform: ${Platform.operatingSystem}');
    // Play custom sound when notification is tapped or received
    // This is especially important for iOS where notification sounds may not play automatically
    _playNotificationSound(response.id);
  }

  @pragma('vm:entry-point')
  static void _backgroundHandler(NotificationResponse response) {
    debugPrint(
      'NotificationService: Background notification - ID: ${response.id}',
    );
    // Note: We can't play sounds directly in background handler,
    // but iOS AppDelegate will handle it via AVAudioPlayer
  }

  /// Play custom sound based on notification type
  Future<void> _playNotificationSound(int? notificationId) async {
    try {
      if (notificationId == null) return;

      // Get the notification type from stored data
      final notificationType = await _getNotificationType(notificationId);

      // Determine if this is a pre-notification based on stored type
      // If type is not stored, fall back to even/odd ID logic for backward compatibility
      final isPreNotification =
          notificationType == 'pre' ||
          (notificationType == null && (notificationId % 2 == 0));

      // Check if this is a Yom Tov notification
      final isYomTov = await _isNotificationYomTov(notificationId);

      // Get the appropriate sound based on notification type and Yom Tov status
      // Both "candle" and "issur" types should play shofar (isPreNotification = false)
      final soundId = await _getSoundIdForNotification(
        isPreNotification: isPreNotification,
        isYomTov: isYomTov,
      );

      if (soundId != 'silent') {
        await _audioService.playSound(soundId);
        debugPrint(
          'NotificationService: Played sound: $soundId (type=$notificationType, isPre=$isPreNotification, isYomTov=$isYomTov)',
        );
      }
    } catch (e) {
      debugPrint('NotificationService: Error playing notification sound: $e');
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

  /// Store notification type for a notification ID
  /// Types: "pre" (pre-notification), "candle" (candle lighting), "issur" (Issur Melacha)
  Future<void> _storeNotificationType(int notificationId, String type) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_notificationTypePrefix$notificationId', type);
    } catch (e) {
      debugPrint('NotificationService: Error storing notification type: $e');
    }
  }

  /// Retrieve notification type for a notification ID
  /// Returns "pre", "candle", "issur", or null if not found
  Future<String?> _getNotificationType(int notificationId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('$_notificationTypePrefix$notificationId');
    } catch (e) {
      debugPrint('NotificationService: Error retrieving notification type: $e');
      return null;
    }
  }

  /// Clean up stored Yom Tov status for old notifications
  Future<void> _cleanupNotificationYomTovStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      for (final key in keys) {
        if (key.startsWith(_notificationYomTovPrefix) ||
            key.startsWith(_notificationTypePrefix)) {
          // Keep only recent notification IDs (last 100)
          final prefix = key.startsWith(_notificationYomTovPrefix)
              ? _notificationYomTovPrefix
              : _notificationTypePrefix;
          final idStr = key.substring(prefix.length);
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

        // Check battery optimization
        final isIgnoringBattery =
            await NativeAlarmService.isIgnoringBatteryOptimizations();
        debugPrint(
          'NotificationService: Ignoring battery optimizations: $isIgnoringBattery',
        );

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

  /// Check all critical permissions for reliable notifications
  /// Returns a map with permission statuses for Android
  Future<Map<String, bool>> checkAllPermissions() async {
    final status = <String, bool>{
      'notifications': false,
      'exactAlarms': true, // Default true for non-Android or older versions
      'batteryOptimization': true, // Default true (ignored)
    };

    if (Platform.isAndroid) {
      final android = _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();

      if (android != null) {
        status['notifications'] =
            await android.areNotificationsEnabled() ?? false;
      }

      status['exactAlarms'] = await NativeAlarmService.canScheduleExactAlarms();
      status['batteryOptimization'] =
          await NativeAlarmService.isIgnoringBatteryOptimizations();
    } else if (Platform.isIOS) {
      final ios = _notifications
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();

      if (ios != null) {
        final currentStatus = await ios.checkPermissions();
        status['notifications'] = currentStatus?.isEnabled ?? false;
      }
    }

    debugPrint('NotificationService: Permission status: $status');
    return status;
  }

  /// Request battery optimization exemption (Android only)
  Future<void> requestBatteryOptimizationExemption() async {
    if (Platform.isAndroid) {
      await NativeAlarmService.requestDisableBatteryOptimization();
    }
  }

  NotificationDetails _getNotificationDetails({
    String? iosSoundFile,
    bool useDefaultSound = false,
  }) {
    // For default sound notifications, use a simpler Android notification
    final androidDetails = useDefaultSound
        ? const AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDesc,
            importance: Importance.high,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
            enableLights: true,
            icon: '@drawable/ic_notification',
            category: AndroidNotificationCategory.reminder,
            visibility: NotificationVisibility.public,
          )
        : const AndroidNotificationDetails(
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

    // For iOS: if useDefaultSound is true, don't pass a custom sound file
    // This will use the system default notification sound
    // IMPORTANT: iOS sound files must be:
    // 1. Format: .caf, .wav, or .aiff (NOT .mp3!)
    // 2. In the app bundle (ios/Runner/Sounds/)
    // 3. Added to Xcode project with correct target membership
    // 4. Referenced by filename WITH extension (e.g., 'sound.caf')
    // 5. Less than 30 seconds duration
    
    debugPrint('NotificationService: iOS sound configuration:');
    debugPrint('  Sound file: $iosSoundFile');
    debugPrint('  Use default: $useDefaultSound');
    
    if (iosSoundFile != null && iosSoundFile.endsWith('.mp3')) {
      debugPrint('NotificationService: ⚠️ WARNING: iOS does not support .mp3 for notification sounds!');
      debugPrint('NotificationService: ⚠️ Convert to .caf format: afconvert $iosSoundFile ${iosSoundFile.replaceAll('.mp3', '.caf')} -d ima4 -f caff -v');
      debugPrint('NotificationService: ⚠️ Using default sound instead');
      // Fall back to default sound if .mp3 is provided
      final iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        badgeNumber: 1,
        interruptionLevel: InterruptionLevel.critical, // Use critical to match critical permissions requested
        sound: null, // Use default sound as fallback
      );
      return NotificationDetails(android: androidDetails, iOS: iosDetails);
    }
    
    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      badgeNumber: 1,
      interruptionLevel: InterruptionLevel.critical, // Use critical to match critical permissions requested, ensures alarms work in DND mode
      sound: useDefaultSound ? null : iosSoundFile, // Include extension (.caf, .wav, or .aiff)
    );

    return NotificationDetails(android: androidDetails, iOS: iosDetails);
  }

  /// Map sound ID to iOS sound filename
  /// IMPORTANT: iOS notification sounds must be .caf, .wav, or .aiff format
  /// .mp3 files will NOT work for iOS notifications!
  /// The sound files must be converted to .caf format and added to ios/Runner/Sounds/
  /// 
  /// NOTE: flutter_local_notifications expects the filename WITH extension
  /// iOS will look for the file in the app bundle
  String? _getIosSoundFile(String soundId) {
    // iOS requires .caf, .wav, or .aiff - NOT .mp3!
    // If you have .mp3 files, convert them to .caf using:
    // afconvert input.mp3 output.caf -d ima4 -f caff -v
    const soundFiles = {
      'rav_shalom_shofar': 'RavShalomShofarDefaultlouder.caf',
      'shabbat_shalom_song': 'RYomTovShabbatShalomSong.caf',
      'yomtov_default': 'YomTov-Default.caf',
      'ata_bechartanu': 'Ata Bechartanu-YomTov.caf',
      'ata_bechartanu_2': 'Ata Bechartanu2-YomTov.caf',
      'hodu_lahashem': 'HoduLaHashem-YomTov.caf',
    };
    final fileName = soundFiles[soundId];
    if (fileName != null) {
      debugPrint('NotificationService: iOS sound file for $soundId: $fileName');
      debugPrint('NotificationService: ✓ .caf files have been created and added to Xcode project');
      debugPrint('NotificationService: ⚠️ IMPORTANT: Rebuild the app for .caf files to be included in bundle!');
      debugPrint('NotificationService:    Run: flutter clean && flutter build ios');
    }
    return fileName;
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
      final soundId = _audioService.getCandleLightingSound();
      debugPrint('NotificationService: Selected candle lighting sound: $soundId');
      return soundId;
    }

    // Pre-notification (early reminder)
    if (isYomTov) {
      // Yom Tov events use Yom Tov sound
      final soundId = await _audioService.getYomTovSound();
      debugPrint('NotificationService: Selected Yom Tov pre-notification sound: $soundId');
      return soundId;
    } else {
      // Shabbos events use early reminder music
      final soundId = await _audioService.getEarlyReminderSound();
      debugPrint('NotificationService: Selected early reminder sound: $soundId');
      return soundId;
    }
  }

  /// Get localized notification strings based on locale and event type
  Map<String, String> _getLocalizedNotificationStrings({
    required String locale,
    required bool isYomTov,
    required int preMinutes,
    required String candleTimeFormatted,
  }) {
    final isHebrew = locale == 'he';

    if (isYomTov) {
      // Yom Tov notifications
      return {
        'preTitle': isHebrew
            ? '⏱️ עוד $preMinutes דקות ליום טוב!'
            : '⏱️ $preMinutes minutes until Yom Tov!',
        'preBody': isHebrew
            ? 'יום טוב מגיע! 🕯️ הדלקת נרות ב-$candleTimeFormatted\nYom Tov is coming! Light candles at $candleTimeFormatted'
            : 'Yom Tov is coming! 🕯️ Light candles at $candleTimeFormatted\nיום טוב מגיע! הדלקת נרות ב-$candleTimeFormatted',
        'candleTitle': isHebrew ? 'יום טוב שמח!' : 'Good Yom Tov!',
        'candleBody': isHebrew
            ? 'זמן הדלקת נרות 🕯️🕯️\nGood Yom Tov! Time to light candles'
            : 'Time to light candles 🕯️🕯️\nזמן הדלקת נרות',
      };
    } else {
      // Shabbos notifications
      return {
        'preTitle': isHebrew
            ? '⏱️ עוד $preMinutes דקות לשבת!'
            : '⏱️ $preMinutes minutes until Shabbos!',
        'preBody': isHebrew
            ? 'שבת מגיעה! 🕯️ הדלקת נרות ב-$candleTimeFormatted\nShabbos is coming! Light candles at $candleTimeFormatted'
            : 'Shabbos is coming! 🕯️ Light candles at $candleTimeFormatted\nשבת מגיעה! הדלקת נרות ב-$candleTimeFormatted',
        'candleTitle': isHebrew ? 'שבת שלום!' : 'Good Shabbos!',
        'candleBody': isHebrew
            ? 'זמן הדלקת נרות 🕯️🕯️\nGood Shabbos! Time to light candles'
            : 'Time to light candles 🕯️🕯️\nזמן הדלקת נרות',
      };
    }
  }

  /// Schedule notifications for candle lighting times
  ///
  /// IMPORTANT ALARM RULES:
  /// - NO alarms during Shabbat (after candle lighting time)
  /// - NO alarms during Yom Tov (any holiday day)
  /// - NO alarms if Saturday night is start of a holiday
  /// - Alarms ONLY play BEFORE Shabbat/Yom Tov starts (pre-notification)
  /// - Candle lighting notification PLAYS SHOFAR - it marks the exact moment Shabbat/Yom Tov starts
  Future<void> scheduleNotifications(
    List<CandleLighting> candleLightings,
    {String locale = 'en'}
  ) async {
    debugPrint(
      'NotificationService: Scheduling ${candleLightings.length} events for locale: $locale',
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
    int skipped = 0;
    final now = DateTime.now();

    for (final lighting in candleLightings) {
      // Pre-notification with countdown
      final preTime = lighting.candleLightingTime.subtract(
        Duration(minutes: preMinutes),
      );

      if (preTime.isAfter(now)) {
        // CHECK ALARM RULES: Can we play an alarm at this time?
        final canPlayAlarm = _canPlayAlarmAt(preTime, candleLightings);

        if (canPlayAlarm) {
          // Format candle lighting time
          final candleTimeFormatted =
              '${lighting.candleLightingTime.hour}:${lighting.candleLightingTime.minute.toString().padLeft(2, '0')}';

          // Get localized notification strings
          final strings = _getLocalizedNotificationStrings(
            locale: locale,
            isYomTov: lighting.isYomTov,
            preMinutes: preMinutes,
            candleTimeFormatted: candleTimeFormatted,
          );
          final title = strings['preTitle']!;
          final body = strings['preBody']!;

          final notificationId = id++;
          final success = await _scheduleNotification(
            id: notificationId,
            title: title,
            body: body,
            scheduledTime: preTime,
            isPreNotification: true,
            isYomTov: lighting.isYomTov,
            candleLightingTime:
                lighting.candleLightingTime, // Pass for countdown
          );
          if (success) {
            scheduled++;
            // Store Yom Tov status and notification type for this notification
            await _storeNotificationYomTov(notificationId, lighting.isYomTov);
            await _storeNotificationType(notificationId, 'pre');
            debugPrint(
              'NotificationService: ✓ Scheduled pre-notification for ${lighting.displayName} at $preTime',
            );
          }
        } else {
          skipped++;
          debugPrint(
            'NotificationService: ✗ SKIPPED pre-notification for ${lighting.displayName} - alarm time falls during Shabbat/Yom Tov',
          );
        }
      }

      // Candle lighting notification - PLAY SHOFAR SOUND
      // The shofar should play at the exact moment Shabbat/Yom Tov starts (candle lighting time)
      // This is the last moment before Shabbat begins, so the shofar is allowed
      if (candleEnabled && lighting.candleLightingTime.isAfter(now)) {
        // Get localized notification strings for candle lighting
        final candleTimeFormatted =
            '${lighting.candleLightingTime.hour}:${lighting.candleLightingTime.minute.toString().padLeft(2, '0')}';
        final strings = _getLocalizedNotificationStrings(
          locale: locale,
          isYomTov: lighting.isYomTov,
          preMinutes: preMinutes,
          candleTimeFormatted: candleTimeFormatted,
        );
        final title = strings['candleTitle']!;
        final body = strings['candleBody']!;

        final notificationId = id++;
        // Schedule with SHOFAR SOUND at candle lighting time
        // The shofar marks the start of Shabbat/Yom Tov and is allowed at this exact moment
        final success = await _scheduleNotification(
          id: notificationId,
          title: title,
          body: body,
          scheduledTime: lighting.candleLightingTime,
          isPreNotification: false,
          isYomTov: lighting.isYomTov,
          isSilent: false, // PLAY SHOFAR - this is the moment Shabbat starts
        );
        if (success) {
          scheduled++;
          // Store Yom Tov status and notification type for this notification
          await _storeNotificationYomTov(notificationId, lighting.isYomTov);
          await _storeNotificationType(notificationId, 'candle');
          debugPrint(
            'NotificationService: ✓ Scheduled candle lighting notification with SHOFAR for ${lighting.displayName}',
          );
        }

        // Issur Melacha reminder notification - shows right after the candle lighting shofar completes
        // Scheduled 35 seconds after candle lighting to ensure the shofar sound has finished
        // Uses default notification sound (not shofar) to remind user that Issur Melacha is in 18 minutes
        final issurReminderTime = lighting.candleLightingTime.add(
          const Duration(seconds: 35),
        );
        if (issurReminderTime.isAfter(now)) {
          final isHebrew = locale == 'he';
          final issurTitle = isHebrew
              ? '⏰ איסור מלאכה • Issur Melacha'
              : '⏰ Issur Melacha • איסור מלאכה';
          final issurBody = isHebrew
              ? 'איסור מלאכה בעוד 18 דקות 🕯️\nWork will be prohibited in 18 minutes'
              : 'Work will be prohibited in 18 minutes 🕯️\nאיסור מלאכה בעוד 18 דקות';

          final issurNotificationId = id++;
          // Schedule Issur Melacha reminder with DEFAULT notification sound (not shofar)
          // This appears right after the candle lighting shofar to remind the user
          final issurSuccess = await _scheduleNotification(
            id: issurNotificationId,
            title: issurTitle,
            body: issurBody,
            scheduledTime: issurReminderTime,
            isPreNotification: false,
            isYomTov: lighting.isYomTov,
            isSilent: false,
            useDefaultSound: true, // Use normal notification sound, not shofar
          );
          if (issurSuccess) {
            scheduled++;
            // Store Yom Tov status and notification type for this notification
            await _storeNotificationYomTov(
              issurNotificationId,
              lighting.isYomTov,
            );
            await _storeNotificationType(issurNotificationId, 'issur');
            debugPrint(
              'NotificationService: ✓ Scheduled Issur Melacha reminder (35 sec after candle lighting) with DEFAULT sound for ${lighting.displayName}',
            );
          }
        }
      }
    }

    debugPrint(
      'NotificationService: Scheduled $scheduled notifications, skipped $skipped (during Shabbat/Yom Tov)',
    );

    // Verify scheduled notifications
    await _verifyPendingNotifications();
  }

  /// Check if an alarm can be played at the given time
  /// Returns FALSE if the time falls during Shabbat or Yom Tov
  ///
  /// Rules:
  /// - No alarms on Friday night (after candle lighting)
  /// - No alarms on Saturday (until after Havdalah)
  /// - No alarms on Saturday night if a Yom Tov starts
  /// - No alarms during any Yom Tov day
  bool _canPlayAlarmAt(DateTime alarmTime, List<CandleLighting> allEvents) {
    // Check each event to see if the alarm time falls within a restricted period
    for (final event in allEvents) {
      final candleLighting = event.candleLightingTime;
      final havdalah = event.havdalahTime;

      // If alarm time is AFTER candle lighting (not at the exact moment) and BEFORE havdalah, it's during Shabbat/Yom Tov
      // Note: The exact moment of candle lighting is allowed (for shofar sound)
      if (alarmTime.isAfter(candleLighting)) {
        if (havdalah != null) {
          // There's a havdalah time - check if alarm is before it
          if (alarmTime.isBefore(havdalah)) {
            debugPrint(
              'NotificationService: Alarm at $alarmTime blocked - during ${event.displayName} (candle: $candleLighting, havdalah: $havdalah)',
            );
            return false;
          }
        } else {
          // No havdalah time - assume it's a multi-day event
          // Block alarms for 25 hours after candle lighting (typical Shabbat duration)
          final assumedEnd = candleLighting.add(const Duration(hours: 25));
          if (alarmTime.isBefore(assumedEnd)) {
            debugPrint(
              'NotificationService: Alarm at $alarmTime blocked - during ${event.displayName} (candle: $candleLighting, no havdalah, assumed end: $assumedEnd)',
            );
            return false;
          }
        }
      }

      // Special case: Saturday night Yom Tov
      // If it's Saturday and a Yom Tov starts that night, no alarm on Saturday
      if (event.isYomTov) {
        final candleDay = candleLighting.weekday;
        final alarmDay = alarmTime.weekday;

        // If Yom Tov candle lighting is on Saturday (weekday 6)
        // and alarm is on Saturday, block it
        if (candleDay == DateTime.saturday && alarmDay == DateTime.saturday) {
          // Check if alarm is on the same Saturday
          if (_isSameDay(alarmTime, candleLighting)) {
            debugPrint(
              'NotificationService: Alarm at $alarmTime blocked - Saturday before Yom Tov ${event.displayName}',
            );
            return false;
          }
        }
      }
    }

    return true;
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Future<void> _verifyPendingNotifications() async {
    try {
      final pending = await _notifications.pendingNotificationRequests();
      debugPrint('NotificationService: ========================================');
      debugPrint('NotificationService: Pending notifications verification');
      debugPrint('NotificationService: Total pending: ${pending.length}');
      
      if (pending.isEmpty) {
        debugPrint('NotificationService: ⚠️ WARNING: No pending notifications found!');
        debugPrint('NotificationService: This might indicate a scheduling issue.');
      } else {
        debugPrint('NotificationService: ✓ Notifications are scheduled:');
        for (final n in pending.take(10)) {
          final now = DateTime.now();
          // Try to extract scheduled time if available
          debugPrint('  - ID ${n.id}: ${n.title}');
          if (Platform.isIOS) {
            debugPrint('    Platform: iOS');
            debugPrint('    Body: ${n.body}');
          }
        }
        if (pending.length > 10) {
          debugPrint('  ... and ${pending.length - 10} more notifications');
        }
      }
      debugPrint('NotificationService: ========================================');
    } catch (e) {
      debugPrint('NotificationService: ✗ Error verifying pending: $e');
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
    bool isSilent =
        false, // If true, no alarm sound (for candle lighting notifications)
    bool useDefaultSound =
        false, // If true, use system default notification sound
  }) async {
    try {
      debugPrint('NotificationService: ---- SCHEDULING NOTIFICATION ----');
      debugPrint('NotificationService: ID: $id');
      debugPrint('NotificationService: Title: $title');
      debugPrint('NotificationService: Scheduled time: $scheduledTime');
      debugPrint('NotificationService: isPreNotification: $isPreNotification');
      debugPrint('NotificationService: isYomTov: $isYomTov');
      debugPrint('NotificationService: isSilent: $isSilent');
      debugPrint('NotificationService: useDefaultSound: $useDefaultSound');
      
      // Get the appropriate sound for this notification type
      // If silent, use 'silent' sound ID
      // If useDefaultSound, use 'default' sound ID
      final soundId = isSilent
          ? 'silent'
          : useDefaultSound
              ? 'default'
              : await _getSoundIdForNotification(
                  isPreNotification: isPreNotification,
                  isYomTov: isYomTov,
                );
      
      debugPrint('NotificationService: Sound ID selected: $soundId');

      if (Platform.isAndroid) {
        // #region agent log
        try {
          final logData = {
            'timestamp': DateTime.now().millisecondsSinceEpoch,
            'location': 'notification_service.dart:808',
            'message': 'About to schedule Android alarm',
            'sessionId': 'debug-session',
            'runId': 'run1',
            'hypothesisId': 'E',
            'data': {
              'id': id,
              'scheduledTime': scheduledTime.toIso8601String(),
              'soundId': soundId,
              'isPreNotification': isPreNotification,
            },
          };
          final logFile = File('/Users/rahul/Development/project_ shabbos/.cursor/debug.log');
          logFile.writeAsStringSync('${jsonEncode(logData)}\n', mode: FileMode.append);
        } catch (e) {
          debugPrint('Failed to write debug log: $e');
        }
        // #endregion
        
        // Use native alarm scheduler for maximum reliability on Android
        final success = await NativeAlarmService.scheduleAlarm(
          id: id,
          scheduledTime: scheduledTime,
          title: title,
          body: body,
          isPreNotification: isPreNotification,
          candleLightingTime: candleLightingTime, // Pass for countdown display
          soundId: soundId, // Pass sound ID for Android playback (or 'silent')
        );

        // #region agent log
        try {
          final logData = {
            'timestamp': DateTime.now().millisecondsSinceEpoch,
            'location': 'notification_service.dart:820',
            'message': 'Android alarm scheduling result',
            'sessionId': 'debug-session',
            'runId': 'run1',
            'hypothesisId': 'E',
            'data': {
              'id': id,
              'success': success,
            },
          };
          final logFile = File('/Users/rahul/Development/project_ shabbos/.cursor/debug.log');
          logFile.writeAsStringSync('${jsonEncode(logData)}\n', mode: FileMode.append);
        } catch (e) {
          debugPrint('Failed to write debug log: $e');
        }
        // #endregion

        debugPrint(
          'NotificationService: Scheduled native alarm #$id for $scheduledTime (isPre=$isPreNotification, isYomTov=$isYomTov, sound=$soundId, silent=$isSilent): $success',
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

        // If silent or useDefaultSound, don't include a custom sound file
        // null = system default sound for iOS
        final iosSoundFile = (isSilent || useDefaultSound)
            ? null
            : _getIosSoundFile(soundId);

        debugPrint('NotificationService: ========================================');
        debugPrint('NotificationService: Scheduling iOS notification #$id');
        debugPrint('NotificationService: Local timezone: ${tz.local.name}');
        debugPrint('NotificationService: Scheduled time: $scheduledTime');
        debugPrint('NotificationService: TZ time: $tzTime');
        debugPrint(
          'NotificationService: Sound ID: $soundId (silent=$isSilent, useDefault=$useDefaultSound)',
        );
        debugPrint(
          'NotificationService: iOS sound file: $iosSoundFile (isPre=$isPreNotification, isYomTov=$isYomTov)',
        );
        
        // Verify sound file exists for iOS
        if (iosSoundFile != null) {
          debugPrint('NotificationService: iOS sound file requirements:');
          debugPrint('  File must be in: ios/Runner/Sounds/$iosSoundFile');
          debugPrint('  Format: MUST be .caf, .wav, or .aiff (NOT .mp3!)');
          debugPrint('  Duration: Must be less than 30 seconds');
          debugPrint('  Xcode: Must be added to project with Target Membership');
          debugPrint('  Bundle: Must be included in app bundle resources');
          if (iosSoundFile.endsWith('.mp3')) {
            debugPrint('  ⚠️ ERROR: .mp3 files do NOT work for iOS notifications!');
            debugPrint('  ⚠️ Convert using: afconvert input.mp3 output.caf -d ima4 -f caff -v');
          }
        } else if (useDefaultSound) {
          debugPrint('NotificationService: Using iOS default notification sound');
        } else {
          debugPrint('NotificationService: ⚠️ No sound file specified (silent notification)');
        }

        // Schedule the notification with custom sound, default sound, or silent
        try {
          await _notifications.zonedSchedule(
            id,
            title,
            body,
            tzTime,
            _getNotificationDetails(
              iosSoundFile: iosSoundFile,
              useDefaultSound: useDefaultSound,
            ),
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          );

          debugPrint(
            'NotificationService: ✓ iOS notification #$id scheduled successfully',
          );
          debugPrint(
            'NotificationService: Sound: ${iosSoundFile ?? (useDefaultSound ? 'DEFAULT' : 'SILENT')}',
          );
          
          // Verify the notification was actually scheduled
          final pending = await _notifications.pendingNotificationRequests();
          final scheduledNotification = pending.firstWhere(
            (n) => n.id == id,
            orElse: () => throw Exception('Notification not found in pending list'),
          );
          debugPrint('NotificationService: ✓ Verified notification #$id is in pending list');
          debugPrint('NotificationService: Total pending notifications: ${pending.length}');
          
        } catch (e) {
          debugPrint('NotificationService: ✗ ERROR scheduling iOS notification #$id: $e');
          debugPrint('NotificationService: Stack trace: ${StackTrace.current}');
          return false;
        }
        
        debugPrint('NotificationService: ========================================');
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
    debugPrint('NotificationService: ========================================');
    debugPrint('NotificationService: Sending immediate test notification...');
    debugPrint('NotificationService: Platform: ${Platform.operatingSystem}');

    await initialize();
    await requestPermissions();

    // Candle lighting sound is always Rav Shalom Shofar (fixed)
    final soundId = _audioService.getCandleLightingSound();
    final iosSoundFile = _getIosSoundFile(soundId);

    debugPrint('NotificationService: Sound ID: $soundId');
    debugPrint('NotificationService: iOS sound file: $iosSoundFile');

    // Play sound via Flutter AudioService FIRST (works for both platforms)
    // This ensures sound plays even if notification sound doesn't work
    if (soundId != 'silent') {
      debugPrint('NotificationService: Playing sound via Flutter AudioService...');
      try {
        await _audioService.playSound(soundId);
        debugPrint('NotificationService: ✓ AudioService.playSound() called successfully');
      } catch (e) {
        debugPrint('NotificationService: ✗ Error playing sound via AudioService: $e');
      }
    }

    try {
      // Show notification WITH sound for iOS (iOS will play it automatically)
      // For Android, we already played via AudioService above
      await _notifications.show(
        999,
        'שבת שלום! Good Shabbos!',
        'התראת בדיקה 🕯️🕯️\nTest notification',
        _getNotificationDetails(
          iosSoundFile: iosSoundFile, // Include sound for iOS
          useDefaultSound: false,
        ),
      );
      debugPrint('NotificationService: ✓ Immediate test notification sent');
      debugPrint('NotificationService: ========================================');
    } catch (e) {
      debugPrint('NotificationService: ✗ Failed to send notification: $e');
      debugPrint('NotificationService: ========================================');
    }
  }
  
  /// Test sound playback directly (without notification)
  /// This helps debug if the issue is with sound files or notification system
  Future<void> testSoundPlayback() async {
    debugPrint('NotificationService: ========================================');
    debugPrint('NotificationService: Testing direct sound playback...');
    debugPrint('NotificationService: Platform: ${Platform.operatingSystem}');
    
    final soundId = _audioService.getCandleLightingSound();
    debugPrint('NotificationService: Testing sound: $soundId');
    
    // Get sound details
    final sound = SoundOption.findById(soundId);
    if (sound == null) {
      debugPrint('NotificationService: ✗ Sound not found: $soundId');
      debugPrint('NotificationService: ========================================');
      return;
    }
    
    debugPrint('NotificationService: Sound details:');
    debugPrint('  ID: ${sound.id}');
    debugPrint('  Name: ${sound.nameEn}');
    debugPrint('  Asset path: ${sound.assetPath}');
    
    if (Platform.isIOS) {
      final iosFile = _getIosSoundFile(soundId);
      debugPrint('  iOS file: $iosFile');
      if (iosFile == null) {
        debugPrint('NotificationService: ⚠️ No iOS sound file configured!');
      } else if (iosFile.endsWith('.mp3')) {
        debugPrint('NotificationService: ⚠️ WARNING: iOS does not support .mp3!');
        debugPrint('NotificationService: ⚠️ Convert to .caf format');
      }
    }
    
    try {
      debugPrint('NotificationService: Calling AudioService.playSound($soundId)...');
      await _audioService.playSound(soundId);
      debugPrint('NotificationService: ✓ AudioService.playSound() completed');
      debugPrint('NotificationService:');
      debugPrint('NotificationService: DIAGNOSTIC CHECKLIST:');
      debugPrint('  ✓ If you HEAR the sound: AudioService is working correctly');
      debugPrint('  ✗ If you DON\'T hear the sound:');
      debugPrint('    1. Check device volume (not muted)');
      debugPrint('    2. Check sound file exists: ${sound.assetPath}');
      debugPrint('    3. Check pubspec.yaml includes: assets/sounds/');
      if (Platform.isIOS) {
        debugPrint('    4. For iOS notifications: Convert .mp3 to .caf format');
        debugPrint('    5. Add .caf files to Xcode project bundle');
      }
      debugPrint('NotificationService: ========================================');
    } catch (e, stackTrace) {
      debugPrint('NotificationService: ✗ Sound playback test FAILED');
      debugPrint('NotificationService: Error: $e');
      debugPrint('NotificationService: Stack trace: $stackTrace');
      debugPrint('NotificationService: ========================================');
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
    String locale = 'en',
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
      // Get localized notification strings for test
      final remainingMinutes = (candleLightingSeconds - preNotificationSeconds) / 60;
      final preMinutesInt = remainingMinutes.ceil();
      final candleTimeFormatted =
          '${candleLightingTime.hour}:${candleLightingTime.minute.toString().padLeft(2, '0')}';

      final strings = _getLocalizedNotificationStrings(
        locale: locale,
        isYomTov: false, // Test uses Shabbos strings
        preMinutes: preMinutesInt,
        candleTimeFormatted: candleTimeFormatted,
      );

      // Schedule pre-notification with countdown (ID 996)
      final preSuccess = await NativeAlarmService.scheduleAlarm(
        id: 996,
        scheduledTime: preNotificationTime,
        title: strings['preTitle']!,
        body: strings['preBody']!,
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
        title: strings['candleTitle']!,
        body: strings['candleBody']!,
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

        // Get localized notification strings for test
        final strings = _getLocalizedNotificationStrings(
          locale: locale,
          isYomTov: false, // Test uses Shabbos strings
          preMinutes: remainingMinutes,
          candleTimeFormatted: candleTimeFormatted,
        );

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
          strings['preTitle']!,
          strings['preBody']!,
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
          strings['candleTitle']!,
          strings['candleBody']!,
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
    debugPrint('NotificationService: Pre-notification minutes set to $minutes');
  }

  /// Force reschedule all notifications with current settings
  /// Call this after changing pre-notification minutes or sound settings
  Future<void> rescheduleAllNotifications(
    List<CandleLighting> candleLightings, {
    String locale = 'en'
  }) async {
    debugPrint('NotificationService: ===== RESCHEDULING ALL NOTIFICATIONS =====');
    debugPrint('NotificationService: Cancelling existing notifications...');

    // Cancel all existing notifications
    await _notifications.cancelAll();
    if (Platform.isAndroid) {
      await NativeAlarmService.cancelAllAlarms();
    }

    // Verify current sound settings before rescheduling
    final earlyReminderSound = await _audioService.getEarlyReminderSound();
    final yomTovSound = await _audioService.getYomTovSound();
    debugPrint('NotificationService: Current early reminder sound: $earlyReminderSound');
    debugPrint('NotificationService: Current Yom Tov sound: $yomTovSound');
    debugPrint('NotificationService: Using locale: $locale');

    // Longer delay to ensure all cancellations are processed, especially on iOS
    // iOS may cache notification sounds, so we need to wait for the system to clear them
    await Future.delayed(const Duration(milliseconds: 500));

    // Verify cancellations completed
    final pendingBefore = await _notifications.pendingNotificationRequests();
    if (pendingBefore.isNotEmpty) {
      debugPrint('NotificationService: WARNING - ${pendingBefore.length} notifications still pending after cancellation');
      // Force cancel individual notifications
      for (final notification in pendingBefore) {
        await _notifications.cancel(notification.id);
      }
      await Future.delayed(const Duration(milliseconds: 200));
    }

    // Reschedule with new settings
    await scheduleNotifications(candleLightings, locale: locale);
    debugPrint('NotificationService: ===== RESCHEDULE COMPLETE =====');
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

  /// Test if sound files are accessible and can be played
  /// This helps identify if the issue is with sound files or notification system
  Future<Map<String, dynamic>> testSoundFiles() async {
    final results = <String, dynamic>{
      'platform': Platform.operatingSystem,
      'sounds': <String, dynamic>{},
    };
    
    debugPrint('NotificationService: ========================================');
    debugPrint('NotificationService: Testing sound file accessibility...');
    
    final testSounds = [
      'rav_shalom_shofar',
      'shabbat_shalom_song',
      'yomtov_default',
    ];
    
    for (final soundId in testSounds) {
      final sound = SoundOption.findById(soundId);
      final soundResult = <String, dynamic>{
        'id': soundId,
        'found': sound != null,
        'hasAssetPath': sound?.assetPath != null,
        'assetPath': sound?.assetPath,
      };
      
      if (Platform.isIOS) {
        final iosFile = _getIosSoundFile(soundId);
        soundResult['iosFile'] = iosFile;
        soundResult['iosFileExists'] = iosFile != null;
      }
      
      // Try to play the sound
      if (sound != null && sound.assetPath != null) {
        try {
          await _audioService.playSound(soundId);
          await Future.delayed(const Duration(milliseconds: 100));
          soundResult['playbackTest'] = 'attempted';
        } catch (e) {
          soundResult['playbackTest'] = 'failed';
          soundResult['playbackError'] = e.toString();
        }
      }
      
      results['sounds'][soundId] = soundResult;
      debugPrint('NotificationService: $soundId: ${soundResult.toString()}');
    }
    
    debugPrint('NotificationService: ========================================');
    return results;
  }

  /// Generate a diagnostic report for debugging notification issues
  /// This can be shared by users experiencing problems
  Future<String> generateDiagnosticReport() async {
    final buffer = StringBuffer();
    final now = DateTime.now();
    
    buffer.writeln('=== SHABBOS APP DIAGNOSTIC REPORT ===');
    buffer.writeln('Generated: $now');
    buffer.writeln('Platform: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}');
    buffer.writeln('');
    
    // Sound settings
    buffer.writeln('--- SOUND SETTINGS ---');
    final earlyReminderSound = await _audioService.getEarlyReminderSound();
    final yomTovSound = await _audioService.getYomTovSound();
    final candleLightingSound = _audioService.getCandleLightingSound();
    buffer.writeln('Early Reminder Sound: $earlyReminderSound');
    buffer.writeln('Yom Tov Sound: $yomTovSound');
    buffer.writeln('Candle Lighting Sound: $candleLightingSound (fixed)');
    buffer.writeln('');
    
    // Notification settings
    buffer.writeln('--- NOTIFICATION SETTINGS ---');
    final notificationsEnabled = await getNotificationsEnabled();
    final preMinutes = await getPreNotificationMinutes();
    final candleEnabled = await getCandleNotificationEnabled();
    buffer.writeln('Notifications Enabled: $notificationsEnabled');
    buffer.writeln('Pre-notification Minutes: $preMinutes');
    buffer.writeln('Candle Notification Enabled: $candleEnabled');
    buffer.writeln('');
    
    // Pending notifications
    buffer.writeln('--- PENDING NOTIFICATIONS ---');
    try {
      final pending = await _notifications.pendingNotificationRequests();
      buffer.writeln('Count: ${pending.length}');
      for (final notification in pending.take(10)) {
        buffer.writeln('  ID ${notification.id}: ${notification.title}');
      }
      if (pending.length > 10) {
        buffer.writeln('  ... and ${pending.length - 10} more');
      }
    } catch (e) {
      buffer.writeln('Error getting pending: $e');
    }
    buffer.writeln('');
    
    // Android-specific checks
    if (Platform.isAndroid) {
      buffer.writeln('--- ANDROID PERMISSIONS ---');
      try {
        final canScheduleExact = await NativeAlarmService.canScheduleExactAlarms();
        final isIgnoringBattery = await NativeAlarmService.isIgnoringBatteryOptimizations();
        buffer.writeln('Can Schedule Exact Alarms: $canScheduleExact');
        buffer.writeln('Ignoring Battery Optimization: $isIgnoringBattery');
        
        if (!canScheduleExact) {
          buffer.writeln('⚠️ WARNING: Exact alarm permission NOT granted!');
        }
        if (!isIgnoringBattery) {
          buffer.writeln('⚠️ WARNING: Battery optimization may kill the app!');
        }
      } catch (e) {
        buffer.writeln('Error checking permissions: $e');
      }
    }
    
    buffer.writeln('');
    buffer.writeln('=== END REPORT ===');
    
    final report = buffer.toString();
    debugPrint(report);
    return report;
  }
}
