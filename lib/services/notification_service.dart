import 'dart:io';
import 'dart:async';
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

  // Log storage for diagnostic reports (stores last 500 log entries)
  final List<String> _diagnosticLogs = [];
  static const int _maxLogEntries = 500;
  static const String _diagnosticLogsPrefsKey = 'diagnostic_logs_v1';
  bool _diagnosticLogsLoaded = false;
  Timer? _diagnosticPersistTimer;

  // Edge Case Handling: Debouncing and state tracking
  DateTime? _lastRescheduleTime;
  Future<void>? _pendingReschedule;
  static const Duration _rescheduleDebounceDelay = Duration(milliseconds: 500);
  
  // Track previous settings for comparison (Edge Cases 2, 13, 14)
  static const String _previousPreNotificationMinutesKey = 'previous_pre_notification_minutes';
  static const String _previousTimezoneKey = 'previous_timezone';
  static const String _lastClockCheckKey = 'last_clock_check';
  static const String _alarmVersionKey = 'alarm_version';
  static const int _currentAlarmVersion = 1; // Increment when alarm structure changes

  Future<void> initialize() async {
    if (_isInitialized) return;

    debugPrint('NotificationService: Initializing...');

    // Load persisted diagnostic logs so reports work on-device without USB debugging
    await _loadPersistedDiagnosticLogs();

    // Edge Case 19: Check alarm version and migrate if needed
    await _checkAlarmVersion();

    // Initialize timezone
    tzdata.initializeTimeZones();
    _setLocalTimezone();
    
    // Edge Case 20: Initialize clock check
    await _checkClockManipulation();

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
      
      // Edge Cases 4, 5, 11: Detect timezone/DST changes
      _checkTimezoneChange(offsetMinutes);

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

  /// Store scheduled time for a notification (for iOS upcoming notifications display)
  Future<void> _storeNotificationScheduledTime(int notificationId, DateTime scheduledTime) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('notification_scheduled_time_$notificationId', scheduledTime.millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('NotificationService: Error storing scheduled time: $e');
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

  /// Checks the OS-level notification permission WITHOUT prompting the user.
  /// Distinct from [getNotificationsEnabled], which reads the in-app toggle.
  /// Used by the home screen to warn when alerts won't fire because the user
  /// declined the system permission. Returns true on any error (fail-safe:
  /// don't nag the user with a false warning).
  Future<bool> areOsNotificationsEnabled() async {
    try {
      if (Platform.isIOS) {
        final ios = _notifications
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >();
        if (ios == null) return true;
        final status = await ios.checkPermissions();
        return status?.isEnabled ?? false;
      } else if (Platform.isAndroid) {
        final android = _notifications
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >();
        if (android == null) return true;
        return await android.areNotificationsEnabled() ?? true;
      }
    } catch (e) {
      debugPrint('NotificationService: areOsNotificationsEnabled error: $e');
    }
    return true;
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

  /// CRITICAL: Validate all Android conditions before scheduling alarms
  /// Returns validation result with issues list
  Future<Map<String, dynamic>> _validateAndroidConditions() async {
    final issues = <String>[];
    bool canSchedule = true;

    // 1. Check notification permission (Android 13+)
    if (Platform.isAndroid) {
      final android = _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      
      if (android != null) {
        final notificationsEnabled = await android.areNotificationsEnabled() ?? false;
        if (!notificationsEnabled) {
          issues.add('Notifications disabled');
          canSchedule = false;
          debugPrint('NotificationService: ✗ Notifications are disabled');
        } else {
          debugPrint('NotificationService: ✓ Notifications enabled');
        }
      }
    }

    // 2. Check exact alarm permission (Android 12+)
    final canScheduleExact = await NativeAlarmService.canScheduleExactAlarms();
    if (!canScheduleExact) {
      issues.add('Exact alarm permission missing');
      canSchedule = false;
      debugPrint('NotificationService: ✗ Exact alarm permission missing');
    } else {
      debugPrint('NotificationService: ✓ Exact alarm permission granted');
    }

    // 3. Check battery optimization
    final isIgnoringBattery = await NativeAlarmService.isIgnoringBatteryOptimizations();
    if (!isIgnoringBattery) {
      issues.add('Battery optimization enabled (may cause failures)');
      // Don't set canSchedule = false for this - it's a warning, not a blocker
      // Alarms can still work with battery optimization, just less reliably
      debugPrint('NotificationService: ⚠️ Battery optimization enabled (reliability reduced)');
    } else {
      debugPrint('NotificationService: ✓ Battery optimization disabled');
    }

    return {
      'canSchedule': canSchedule,
      'issues': issues,
      'warnings': isIgnoringBattery ? <String>[] : ['Battery optimization enabled'],
    };
  }

  /// Check if app can schedule exact alarms (Android 12+)
  /// Returns true if permission is granted or not required (Android < 12)
  Future<bool> canScheduleExactAlarms() async {
    if (Platform.isAndroid) {
      return await NativeAlarmService.canScheduleExactAlarms();
    }
    // iOS and older Android don't need this permission
    return true;
  }

  /// Check if app is ignoring battery optimizations (Android)
  /// Returns true if optimization is disabled (good), false if enabled (bad)
  Future<bool> isIgnoringBatteryOptimizations() async {
    if (Platform.isAndroid) {
      return await NativeAlarmService.isIgnoringBatteryOptimizations();
    }
    // iOS doesn't have battery optimization in the same way
    return true;
  }

  /// Request exact alarm permission (Android 12+)
  /// Opens system settings where user can grant the permission
  Future<void> requestExactAlarmPermission() async {
    if (Platform.isAndroid) {
      await NativeAlarmService.requestExactAlarmPermission();
    }
  }

  /// Request to disable battery optimization (Android)
  /// Opens system settings where user can disable optimization
  Future<void> requestDisableBatteryOptimization() async {
    if (Platform.isAndroid) {
      await NativeAlarmService.requestDisableBatteryOptimization();
    }
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
    debugPrint('🔊 NotificationService._getSoundIdForNotification called:');
    debugPrint('   isPreNotification: $isPreNotification');
    debugPrint('   isYomTov: $isYomTov');
    
    if (!isPreNotification) {
      // Candle lighting notification: ALWAYS use Rav Shalom Shofar
      final soundId = _audioService.getCandleLightingSound();
      debugPrint('🔊 → Selected candle lighting sound: "$soundId"');
      return soundId;
    }

    // Pre-notification (early reminder)
    if (isYomTov) {
      // Yom Tov events use Yom Tov sound
      final soundId = await _audioService.getYomTovSound();
      debugPrint('🔊 → Selected Yom Tov pre-notification sound: "$soundId"');
      return soundId;
    } else {
      // Shabbos events use early reminder music
      debugPrint('🔊 → Fetching early reminder sound from AudioService...');
      final soundId = await _audioService.getEarlyReminderSound();
      debugPrint('🔊 → Got early reminder sound: "$soundId"');
      
      // VERIFY: Check if this sound exists in the sound options
      final sound = SoundOption.findById(soundId);
      if (sound != null) {
        debugPrint('🔊 ✓ Sound found: ${sound.nameEn} (${sound.nameHe})');
        debugPrint('🔊 ✓ Asset path: ${sound.assetPath}');
      } else {
        debugPrint('🔊 ✗ WARNING: Sound ID "$soundId" not found in SoundOption list!');
      }
      
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
  /// - ISSUR MELACHA notification PLAYS SHOFAR at candle lighting time - notification appears at candle lighting but message shows Issur Melacha time (18 minutes later)
  /// 
  /// [skipCancellation] - If true, skip cancelling existing alarms (used when rescheduling with protection)
  Future<void> scheduleNotifications(
    List<CandleLighting> candleLightings,
    {String locale = 'en', bool skipCancellation = false}
  ) async {
    debugPrint(
      'NotificationService: Scheduling ${candleLightings.length} events for locale: $locale',
    );

    await initialize();

    // CRITICAL: Proactive validation before scheduling
    // Check all permissions and system settings to ensure alarms will work
    if (Platform.isAndroid) {
      final validationResult = await _validateAndroidConditions();
      if (!validationResult['canSchedule']) {
        final issues = validationResult['issues'] as List<String>;
        debugPrint('NotificationService: ⚠️ CRITICAL: Cannot schedule alarms reliably!');
        debugPrint('NotificationService: Issues found: ${issues.join(", ")}');
        _addDiagnosticLog('⚠️ CRITICAL: Cannot schedule alarms - ${issues.join(", ")}');
        _addDiagnosticLog('⚠️ User action required before alarms will work');
        
        // Still attempt to schedule (user might fix issues before alarm time)
        // But log the warning clearly
      } else {
        debugPrint('NotificationService: ✓ All conditions validated - alarms should work');
        _addDiagnosticLog('✓ All conditions validated - alarms should work reliably');
      }
    }

    // Cancel all existing notifications and alarms (unless skipping cancellation)
    // ALWAYS protect test notification IDs (996, 997, 998) from cancellation
    if (!skipCancellation) {
      debugPrint('NotificationService: Cancelling old notifications...');
      
      // Get pending notifications and cancel all except test IDs
      final pending = await _notifications.pendingNotificationRequests();
      for (final notification in pending) {
        // Skip test notification IDs (996, 997, 998)
        if (notification.id == 996 || notification.id == 997 || notification.id == 998) {
          debugPrint('NotificationService: Protecting test notification #${notification.id}');
          continue;
        }
        await _notifications.cancel(notification.id);
      }
      debugPrint('NotificationService: Cancelled ${pending.length - 3} notifications, kept 3 test notifications');
      
      if (Platform.isAndroid) {
        // Cancel all Android alarms except test IDs
        final androidAlarms = await NativeAlarmService.getScheduledAlarms();
        for (final alarm in androidAlarms) {
          final id = alarm['id'] as int;
          // Skip test notification IDs (996, 997, 998)
          if (id == 996 || id == 997 || id == 998) {
            debugPrint('NotificationService: Protecting test alarm #$id');
            continue;
          }
          await NativeAlarmService.cancelAlarm(id);
        }
        debugPrint('NotificationService: Cancelled Android alarms, kept test alarms');
      }
    } else {
      debugPrint('NotificationService: Skipping cancellation (protected alarms will remain)');
    }

    // Clean up old Yom Tov status entries
    await _cleanupNotificationYomTovStatus();

    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_notificationsEnabledKey) ?? true;

    if (!enabled) {
      debugPrint('NotificationService: Notifications disabled');
      return;
    }

    final preMinutes = prefs.getInt(_preNotificationMinutesKey) ?? 40;
    final candleEnabled = prefs.getBool(_candleNotificationEnabledKey) ?? true;

    debugPrint('NotificationService: ========================================');
    debugPrint('NotificationService: SCHEDULING NOTIFICATIONS');
    debugPrint('NotificationService: preMinutes=$preMinutes');
    debugPrint('NotificationService: candleEnabled=$candleEnabled');
    debugPrint('NotificationService: Total events: ${candleLightings.length}');
    debugPrint('NotificationService: ========================================');
    
    _addDiagnosticLog('=== START SCHEDULING ===');
    _addDiagnosticLog('preMinutes=$preMinutes, candleEnabled=$candleEnabled, events=${candleLightings.length}');

    int id = 0;
    int scheduled = 0;
    int skipped = 0;
    final now = DateTime.now();
    debugPrint('NotificationService: Current time: $now');

    for (final lighting in candleLightings) {
      debugPrint('NotificationService: ----------------------------------------');
      debugPrint('NotificationService: Processing event: ${lighting.displayName}');
      debugPrint('NotificationService: Candle lighting time: ${lighting.candleLightingTime}');
      debugPrint('NotificationService: Is Yom Tov: ${lighting.isYomTov}');

      _addDiagnosticLog('Processing: ${lighting.displayName} at ${lighting.candleLightingTime}');

      if (_shouldSkipYomTovAlertsForEvent(lighting, candleLightings)) {
        debugPrint(
          'NotificationService: ✗ SKIPPED all notifications for ${lighting.displayName} - follow-on Yom Tov candle lighting',
        );
        _addDiagnosticLog(
          '✗ SKIPPED all notifications for ${lighting.displayName} - follow-on Yom Tov candle lighting',
        );
        skipped += 2;
        continue;
      }

      // Calculate pre-notification time (preMinutes before candle lighting)
      final preTime = lighting.candleLightingTime.subtract(Duration(minutes: preMinutes));
      final candleTime = lighting.candleLightingTime;

      // Format candle lighting time for display
      final candleHour = candleTime.hour;
      final candleMinute = candleTime.minute.toString().padLeft(2, '0');
      final candlePeriod = candleHour >= 12 ? 'PM' : 'AM';
      final candleHour12 = candleHour == 0 ? 12 : (candleHour > 12 ? candleHour - 12 : candleHour);
      final candleTimeFormatted = '$candleHour12:$candleMinute $candlePeriod';

      // Get localized notification strings
      final strings = _getLocalizedNotificationStrings(
        locale: locale,
        isYomTov: lighting.isYomTov,
        preMinutes: preMinutes,
        candleTimeFormatted: candleTimeFormatted,
      );

      // 1. Schedule PRE-notification (early reminder)
      if (preTime.isAfter(now)) {
        final canPlayPre = _canPlayAlarmAt(preTime, candleLightings);
        debugPrint('NotificationService: Checking pre-notification');
        debugPrint('NotificationService: preTime=$preTime, isAfter=${preTime.isAfter(now)}, canPlayPre=$canPlayPre');

        if (canPlayPre) {
          final preNotificationId = id++;
          debugPrint('NotificationService: Attempting to schedule pre-notification #$preNotificationId');
          final preSuccess = await _scheduleNotification(
            id: preNotificationId,
            title: strings['preTitle']!,
            body: strings['preBody']!,
            scheduledTime: preTime,
            isPreNotification: true,
            isYomTov: lighting.isYomTov,
            isSilent: false,
            useDefaultSound: false,
            candleLightingTime: candleTime,
          );
          debugPrint('NotificationService: Pre-notification scheduling result: $preSuccess');
          if (preSuccess) {
            scheduled++;
            await _storeNotificationYomTov(preNotificationId, lighting.isYomTov);
            await _storeNotificationType(preNotificationId, 'pre');
            await _storeNotificationScheduledTime(preNotificationId, preTime);
            debugPrint(
              'NotificationService: ✓ Scheduled pre-notification for ${lighting.displayName}',
            );
            _addDiagnosticLog('✓ Scheduled PRE-notification #$preNotificationId for ${lighting.displayName} at $preTime');
          } else {
            debugPrint(
              'NotificationService: ✗ FAILED to schedule pre-notification for ${lighting.displayName}',
            );
            _addDiagnosticLog('✗ FAILED to schedule PRE-notification #$preNotificationId for ${lighting.displayName}');
          }
        } else {
          debugPrint(
            'NotificationService: ✗ SKIPPED pre-notification - blocked by Shabbat rules',
          );
          _addDiagnosticLog('✗ SKIPPED PRE-notification - blocked (canPlayPre=$canPlayPre)');
        }
      } else {
        debugPrint(
          'NotificationService: ✗ SKIPPED pre-notification - in the past',
        );
        _addDiagnosticLog('✗ SKIPPED PRE-notification - in past');
      }

      // 2. Schedule ISSUR MELACHA notification at candle lighting time
      // Notification appears at candle lighting time but message shows Issur Melacha time (18 minutes later)
      final issurTime = candleTime; // Notification appears at candle lighting time

      // Calculate Issur Melacha time (18 minutes after candle lighting) for display in message
      final issurMelachaTime = candleTime.add(const Duration(minutes: 18));
      final issurHour = issurMelachaTime.hour;
      final issurMinute = issurMelachaTime.minute.toString().padLeft(2, '0');
      final issurPeriod = issurHour >= 12 ? 'PM' : 'AM';
      final issurHour12 = issurHour == 0 ? 12 : (issurHour > 12 ? issurHour - 12 : issurHour);
      final issurTimeFormatted = '$issurHour12:$issurMinute $issurPeriod';

      debugPrint('NotificationService: Checking Issur Melacha notification');
      debugPrint('NotificationService: issurTime=$issurTime (notification appears at candle lighting time), issurMelachaTime=$issurMelachaTime (shown in message), isAfter=${issurTime.isAfter(now)}');

      // Check if Issur notification would be blocked
      final canPlayIssur = _canPlayAlarmAt(issurTime, candleLightings);
      debugPrint('NotificationService: canPlayIssur=$canPlayIssur for Issur notification at $issurTime');

      if (candleEnabled && issurTime.isAfter(now) && canPlayIssur) {
        final isHebrew = locale == 'he';
        final issurTitle = isHebrew
            ? '⏰ איסור מלאכה • Issur Melacha'
            : '⏰ Issur Melacha • איסור מלאכה';
        final issurBody = isHebrew
            ? 'איסור מלאכה ב-$issurTimeFormatted 🕯️\nIssur Melacha is at $issurTimeFormatted'
            : 'Issur Melacha is at $issurTimeFormatted 🕯️\nאיסור מלאכה ב-$issurTimeFormatted';

        final issurNotificationId = id++;
        debugPrint('NotificationService: Attempting to schedule Issur Melacha notification #$issurNotificationId');
        // Schedule Issur Melacha at candle lighting time with SHOFAR sound
        // Message displays Issur Melacha time (18 minutes after candle lighting)
        // isPreNotification=false + useDefaultSound=false → calls _getSoundIdForNotification
        // which returns 'rav_shalom_shofar' (the shofar sound)
        final issurSuccess = await _scheduleNotification(
          id: issurNotificationId,
          title: issurTitle,
          body: issurBody,
          scheduledTime: issurTime,
          isPreNotification: false, // This triggers shofar sound selection
          isYomTov: lighting.isYomTov,
          isSilent: false,
          useDefaultSound: false, // Use shofar sound (rav_shalom_shofar), not default
        );
        debugPrint('NotificationService: Issur Melacha notification scheduling result: $issurSuccess');
        if (issurSuccess) {
          scheduled++;
          // Store Yom Tov status and notification type for this notification
          await _storeNotificationYomTov(
            issurNotificationId,
            lighting.isYomTov,
          );
          await _storeNotificationType(issurNotificationId, 'issur');
          // Store scheduled time for iOS upcoming notifications display
          await _storeNotificationScheduledTime(issurNotificationId, issurTime);
          debugPrint(
            'NotificationService: ✓ Scheduled Issur Melacha notification (appears at candle lighting time, message shows Issur Melacha at $issurTimeFormatted) with SHOFAR sound for ${lighting.displayName}',
          );
          _addDiagnosticLog('✓ Scheduled ISSUR MELACHA #$issurNotificationId for ${lighting.displayName} at $issurTime (message shows Issur Melacha at $issurTimeFormatted)');
        } else {
          debugPrint(
            'NotificationService: ✗ FAILED to schedule Issur Melacha notification for ${lighting.displayName}',
          );
          _addDiagnosticLog('✗ FAILED to schedule ISSUR MELACHA #$issurNotificationId for ${lighting.displayName}');
        }
      } else {
        if (!candleEnabled) {
          debugPrint(
            'NotificationService: ✗ SKIPPED Issur Melacha notification - candle notification disabled in settings',
          );
          _addDiagnosticLog('✗ SKIPPED ISSUR MELACHA - disabled (candleEnabled=false)');
        } else {
          debugPrint(
            'NotificationService: ✗ SKIPPED Issur Melacha notification - blocked by Shabbat rules or in the past',
          );
          _addDiagnosticLog('✗ SKIPPED ISSUR MELACHA - blocked or in past (canPlayIssur=$canPlayIssur, isAfter=${issurTime.isAfter(now)})');
        }
      }
    }

    debugPrint('NotificationService: ========================================');
    debugPrint('NotificationService: SCHEDULING SUMMARY');
    debugPrint('NotificationService: Total scheduled: $scheduled');
    debugPrint('NotificationService: Total skipped: $skipped');
    debugPrint('NotificationService: ========================================');
    
    _addDiagnosticLog('=== SCHEDULING COMPLETE ===');
    _addDiagnosticLog('Total scheduled: $scheduled, skipped: $skipped');

    // Verify scheduled notifications
    await _verifyPendingNotifications();
    
    // On Android, also verify native alarms
    if (Platform.isAndroid) {
      try {
        final nativeAlarms = await NativeAlarmService.getScheduledAlarms();
        debugPrint('NotificationService: ========================================');
        debugPrint('NotificationService: NATIVE ANDROID ALARMS VERIFICATION');
        debugPrint('NotificationService: Total native alarms: ${nativeAlarms.length}');
        for (final alarm in nativeAlarms.take(10)) {
          final id = alarm['id'];
          final title = alarm['title'];
          final isPre = alarm['isPreNotification'];
          final timestamp = alarm['timestampMillis'] as int;
          final time = DateTime.fromMillisecondsSinceEpoch(timestamp);
          debugPrint('NotificationService:   - #$id: "$title" (isPre=$isPre) at $time');
        }
        if (nativeAlarms.length > 10) {
          debugPrint('NotificationService:   ... and ${nativeAlarms.length - 10} more alarms');
        }
        debugPrint('NotificationService: ========================================');
      } catch (e) {
        debugPrint('NotificationService: ✗ Error verifying native alarms: $e');
      }
    }
  }

  /// Check if an alarm can be played at the given time
  /// Returns FALSE if the time falls during Shabbat or Yom Tov
  ///
  /// Rules:
  /// - No alarms on Friday night (after candle lighting)
  /// - No alarms on Saturday (until after Havdalah)
  /// - No alarms on Saturday night if a Yom Tov starts
  /// - No alarms during any Yom Tov day
  /// - Exception: Allow informational notifications within 20 minutes after candle lighting (for Issur Melacha reminder)
  /// 
  /// IMPORTANT: First check if alarm is within 20 minutes of ANY candle lighting (allow it),
  /// then check if it falls during a Shabbat/Yom Tov period (block it).
  bool _canPlayAlarmAt(DateTime alarmTime, List<CandleLighting> allEvents) {
    debugPrint('NotificationService: _canPlayAlarmAt checking alarm at $alarmTime');
    debugPrint('NotificationService: Total events to check against: ${allEvents.length}');
    
    // FIRST PASS: Check if alarm is within 20 minutes of ANY candle lighting time
    // This allows Issur Melacha reminders (scheduled 18 minutes after candle lighting)
    for (final event in allEvents) {
      final candleLighting = event.candleLightingTime;
      
      if (alarmTime.isAfter(candleLighting)) {
        final timeSinceCandleLighting = alarmTime.difference(candleLighting);
        if (timeSinceCandleLighting.inMinutes <= 20 && timeSinceCandleLighting.inMinutes >= 0) {
          debugPrint(
            'NotificationService: ✓ Allowing notification at $alarmTime (${timeSinceCandleLighting.inMinutes}m after ${event.displayName} candle lighting)',
          );
          return true; // Allow informational notifications within 20 minutes after candle lighting
        }
      } else if (alarmTime.isAtSameMomentAs(candleLighting)) {
        // Exact candle lighting time is allowed (for shofar sound)
        debugPrint(
          'NotificationService: ✓ Allowing notification at exact candle lighting time for ${event.displayName}',
        );
        return true;
      }
    }
    
    // SECOND PASS: Check if alarm falls during any Shabbat/Yom Tov period
    for (final event in allEvents) {
      final candleLighting = event.candleLightingTime;
      final havdalah = event.havdalahTime;

      // If alarm time is AFTER candle lighting (more than 20 minutes after) and BEFORE havdalah, it's during Shabbat/Yom Tov
      if (alarmTime.isAfter(candleLighting)) {
        final timeSinceCandleLighting = alarmTime.difference(candleLighting);
        
        // Already checked <= 20 minutes in first pass, so this is > 20 minutes
        if (timeSinceCandleLighting.inMinutes > 20) {
          if (havdalah != null) {
            // There's a havdalah time - check if alarm is before it
            if (alarmTime.isBefore(havdalah)) {
              debugPrint(
                'NotificationService: ✗ Alarm at $alarmTime blocked - during ${event.displayName} (candle: $candleLighting, havdalah: $havdalah)',
              );
              return false;
            }
          } else {
            // No havdalah time - assume it's a multi-day event
            // Block alarms for 25 hours after candle lighting (typical Shabbat duration)
            final assumedEnd = candleLighting.add(const Duration(hours: 25));
            if (alarmTime.isBefore(assumedEnd)) {
              debugPrint(
                'NotificationService: ✗ Alarm at $alarmTime blocked - during ${event.displayName} (candle: $candleLighting, no havdalah, assumed end: $assumedEnd)',
              );
              return false;
            }
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
              'NotificationService: ✗ Alarm at $alarmTime blocked - Saturday before Yom Tov ${event.displayName}',
            );
            return false;
          }
        }
      }
    }

    debugPrint('NotificationService: ✓ Alarm at $alarmTime is allowed');
    return true;
  }

  /// Do not alert for Yom Tov candle lighting when the user is already coming
  /// from a candle-lighting event on the immediately previous calendar day.
  ///
  /// This suppresses diaspora second-day Yom Tov alerts while still showing the
  /// event in the UI, and it also avoids Saturday-night Yom Tov alerts when the
  /// user is already in Shabbat.
  bool _shouldSkipYomTovAlertsForEvent(
    CandleLighting lighting,
    List<CandleLighting> allEvents,
  ) {
    if (!lighting.isYomTov) return false;

    // Explicit Day-2 flag from the parser is authoritative when present.
    // Day 1 of Yom Tov: alarms allowed. Day 2 (Diaspora only): alarms blocked.
    if (lighting.isSecondDayYomTov) {
      debugPrint(
        'NotificationService: Skipping alerts for ${lighting.displayName} - flagged as second day of Yom Tov',
      );
      return true;
    }

    final lightingDay = DateTime(
      lighting.candleLightingTime.year,
      lighting.candleLightingTime.month,
      lighting.candleLightingTime.day,
    );

    for (final otherEvent in allEvents) {
      if (identical(otherEvent, lighting)) continue;

      final otherDay = DateTime(
        otherEvent.candleLightingTime.year,
        otherEvent.candleLightingTime.month,
        otherEvent.candleLightingTime.day,
      );
      final dayDiff = lightingDay.difference(otherDay).inDays;

      if (dayDiff == 1 &&
          otherEvent.candleLightingTime.isBefore(lighting.candleLightingTime)) {
        debugPrint(
          'NotificationService: Skipping alerts for ${lighting.displayName} - prior candle lighting on previous day (${otherEvent.displayName}) means user is already in Shabbat/Yom Tov',
        );
        return true;
      }
    }

    return false;
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  /// Edge Cases 4, 5, 11: Detect timezone/DST changes and reschedule alarms
  Future<void> _checkTimezoneChange(int currentOffsetMinutes) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final previousOffset = prefs.getInt(_previousTimezoneKey);
      
      if (previousOffset != null && previousOffset != currentOffsetMinutes) {
        debugPrint('NotificationService: ⚠️ TIMEZONE CHANGE DETECTED!');
        debugPrint('NotificationService: Previous offset: $previousOffset minutes');
        debugPrint('NotificationService: Current offset: $currentOffsetMinutes minutes');
        debugPrint('NotificationService: Difference: ${currentOffsetMinutes - previousOffset} minutes');
        debugPrint('NotificationService: ⚠️ Alarms need to be rescheduled for new timezone');
        
        // Store new timezone
        await prefs.setInt(_previousTimezoneKey, currentOffsetMinutes);
        
        // Note: Actual rescheduling should be triggered by location service or app lifecycle
        // This just detects and logs the change
      } else if (previousOffset == null) {
        // First time - store current timezone
        await prefs.setInt(_previousTimezoneKey, currentOffsetMinutes);
      }
    } catch (e) {
      debugPrint('NotificationService: Error checking timezone change: $e');
    }
  }

  /// Edge Case 20: Detect clock manipulation (user changes device time)
  Future<void> _checkClockManipulation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastCheck = prefs.getInt(_lastClockCheckKey);
      final now = DateTime.now().millisecondsSinceEpoch;
      
      if (lastCheck != null) {
        final timeDiff = now - lastCheck;
        // If more than 2 hours passed but device was only off for < 1 hour, clock was manipulated
        // Or if time went backwards significantly
        if (timeDiff > 2 * 60 * 60 * 1000) {
          debugPrint('NotificationService: ⚠️ Significant time jump detected: ${timeDiff / 1000 / 60} minutes');
          debugPrint('NotificationService: ⚠️ This might indicate clock manipulation or device was off');
          // Could trigger reschedule here, but for now just log
        } else if (timeDiff < -60 * 60 * 1000) {
          debugPrint('NotificationService: ⚠️ WARNING: Time went backwards! Clock manipulation detected');
          debugPrint('NotificationService: ⚠️ Alarms may fire at wrong time');
        }
      }
      
      await prefs.setInt(_lastClockCheckKey, now);
    } catch (e) {
      debugPrint('NotificationService: Error checking clock manipulation: $e');
    }
  }

  /// Edge Case 19: Check alarm version and migrate if needed
  Future<void> _checkAlarmVersion() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedVersion = prefs.getInt(_alarmVersionKey);
      
      if (savedVersion == null) {
        // First time - set version
        await prefs.setInt(_alarmVersionKey, _currentAlarmVersion);
        debugPrint('NotificationService: Setting alarm version to $_currentAlarmVersion');
      } else if (savedVersion != _currentAlarmVersion) {
        debugPrint('NotificationService: ⚠️ Alarm version mismatch!');
        debugPrint('NotificationService: Saved version: $savedVersion, Current: $_currentAlarmVersion');
        debugPrint('NotificationService: Rescheduling all alarms with new structure...');
        
        // Clear old alarms and reschedule
        await _notifications.cancelAll();
        if (Platform.isAndroid) {
          await NativeAlarmService.cancelAllAlarms(protectImminent: false);
        }
        
        // Update version
        await prefs.setInt(_alarmVersionKey, _currentAlarmVersion);
        debugPrint('NotificationService: ✓ Alarms migrated to version $_currentAlarmVersion');
      }
    } catch (e) {
      debugPrint('NotificationService: Error checking alarm version: $e');
    }
  }

  /// Edge Case 22: Adjust protection threshold for very short pre-notifications
  Duration _getImminentThreshold(int preMinutes) {
    // Edge Case 22: If pre-notification is very short (1-5 min), use minimum threshold
    if (preMinutes <= 5) {
      // Use minimum of 2 minutes for very short pre-notifications
      return const Duration(minutes: 2, seconds: 1);
    }
    // Standard threshold for normal pre-notifications
    return const Duration(minutes: 5, seconds: 1);
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
      // 
      // IMPORTANT: Sound ID is LOCKED IN at scheduling time:
      // - Android: Stored in Intent extras, read by AlarmReceiver when alarm fires
      // - iOS: Stored in notification payload, played by system when notification fires
      // This ensures alarms always play their originally scheduled sound, even if settings change later
      final soundId = isSilent
          ? 'silent'
          : useDefaultSound
              ? 'default'
              : await _getSoundIdForNotification(
                  isPreNotification: isPreNotification,
                  isYomTov: isYomTov,
                );
      
      debugPrint('NotificationService: Sound ID selected: $soundId');
      debugPrint('NotificationService: ⚠️ Sound ID is LOCKED IN - alarm will use this sound even if settings change');

      if (Platform.isAndroid) {
        // Use native alarm scheduler for maximum reliability on Android
        debugPrint('NotificationService: Calling NativeAlarmService.scheduleAlarm for #$id...');
        debugPrint('NotificationService:   - scheduledTime: $scheduledTime');
        debugPrint('NotificationService:   - title: "$title"');
        debugPrint('NotificationService:   - body: "$body"');
        debugPrint('NotificationService:   - isPreNotification: $isPreNotification');
        debugPrint('NotificationService:   - soundId: $soundId');
        debugPrint('NotificationService:   - candleLightingTime: $candleLightingTime');
        
        bool success = false;
        String? errorMessage;
        try {
          success = await NativeAlarmService.scheduleAlarm(
            id: id,
            scheduledTime: scheduledTime,
            title: title,
            body: body,
            isPreNotification: isPreNotification,
            candleLightingTime: candleLightingTime, // Pass for countdown display
            soundId: soundId, // Pass sound ID for Android playback (or 'silent')
          );
          debugPrint('NotificationService: NativeAlarmService.scheduleAlarm returned: $success');
        } catch (e, stackTrace) {
          errorMessage = e.toString();
          debugPrint('NotificationService: ✗ EXCEPTION in NativeAlarmService.scheduleAlarm: $e');
          debugPrint('NotificationService: Stack trace: $stackTrace');
          _addDiagnosticLog('✗ EXCEPTION scheduling #$id: $e');
        }

        if (!success) {
          final error = errorMessage ?? 'NativeAlarmService.scheduleAlarm returned false';
          debugPrint('NotificationService: ✗ FAILED to schedule native alarm #$id: $error');
          _addDiagnosticLog('✗ FAILED native alarm #$id: $error');
        } else {
          debugPrint(
            'NotificationService: ✓ Scheduled native alarm #$id for $scheduledTime (isPre=$isPreNotification, isYomTov=$isYomTov, sound=$soundId, silent=$isSilent)',
          );
        }
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
          final found = pending.any((n) => n.id == id);
          if (found) {
            debugPrint('NotificationService: ✓ Verified notification #$id is in pending list');
          } else {
            debugPrint('NotificationService: ⚠️ Warning: notification #$id not found in pending list');
          }
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
      _addDiagnosticLog('✗ ERROR scheduling notification #$id: $e');
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

  /// Schedule daily test notifications for testing
  /// Schedules notifications for TOMORROW at specified times
  /// This allows daily testing without waiting for actual Shabbat
  Future<void> scheduleDailyTestNotifications({
    required String locale,
    int preNotificationHour = 20, // 8 PM
    int preNotificationMinute = 0,
    int candleLightingHour = 20, // 8:20 PM
    int candleLightingMinute = 20,
  }) async {
    debugPrint('==========================================');
    debugPrint('NotificationService: SCHEDULING DAILY TEST NOTIFICATIONS');
    debugPrint('==========================================');

    await initialize();
    await requestPermissions();

    final now = DateTime.now();
    
    // Schedule for tomorrow (or today if times haven't passed yet)
    var preTime = DateTime(
      now.year,
      now.month,
      now.day,
      preNotificationHour,
      preNotificationMinute,
    );
    
    var candleTime = DateTime(
      now.year,
      now.month,
      now.day,
      candleLightingHour,
      candleLightingMinute,
    );

    // If times have already passed today, schedule for tomorrow
    if (preTime.isBefore(now)) {
      preTime = preTime.add(const Duration(days: 1));
    }
    if (candleTime.isBefore(now)) {
      candleTime = candleTime.add(const Duration(days: 1));
    }

    debugPrint('NotificationService: Current time: $now');
    debugPrint('NotificationService: Pre-notification scheduled: $preTime');
    debugPrint('NotificationService: Candle lighting scheduled: $candleTime');

    // Cancel any existing test notifications
    await _notifications.cancel(996);
    await _notifications.cancel(997);
    await _notifications.cancel(998);
    if (Platform.isAndroid) {
      await NativeAlarmService.cancelAlarm(996);
      await NativeAlarmService.cancelAlarm(997);
      await NativeAlarmService.cancelAlarm(998);
    }

    // Get sounds
    final earlyReminderSoundId = await _audioService.getEarlyReminderSound();
    final candleLightingSoundId = _audioService.getCandleLightingSound();

    final preMinutes = (candleTime.difference(preTime).inMinutes);
    final candleTimeFormatted = '${candleTime.hour}:${candleTime.minute.toString().padLeft(2, '0')}';

    final strings = _getLocalizedNotificationStrings(
      locale: locale,
      isYomTov: false,
      preMinutes: preMinutes,
      candleTimeFormatted: candleTimeFormatted,
    );

    if (Platform.isAndroid) {
      // Schedule pre-notification
      final preSuccess = await NativeAlarmService.scheduleAlarm(
        id: 996,
        scheduledTime: preTime,
        title: '🧪 TEST: ${strings['preTitle']!}',
        body: 'Daily test alarm\n${strings['preBody']!}',
        isPreNotification: true,
        candleLightingTime: candleTime,
        soundId: earlyReminderSoundId,
      );
      debugPrint('NotificationService: Pre-notification scheduled: $preSuccess');

      // Schedule candle lighting notification
      final candleSuccess = await NativeAlarmService.scheduleAlarm(
        id: 997,
        scheduledTime: candleTime,
        title: '🧪 TEST: ${strings['candleTitle']!}',
        body: 'Daily test alarm\n${strings['candleBody']!}',
        isPreNotification: false,
        soundId: candleLightingSoundId,
      );
      debugPrint('NotificationService: Candle lighting scheduled: $candleSuccess');

      // Schedule issur melacha (18 seconds after for quick testing)
      final issurTime = candleTime.add(const Duration(seconds: 18));
      final issurSuccess = await NativeAlarmService.scheduleAlarm(
        id: 998,
        scheduledTime: issurTime,
        title: '🧪 TEST: ⏰ Issur Melacha',
        body: 'Daily test alarm - Issur Melacha notification',
        isPreNotification: false,
        soundId: candleLightingSoundId, // Shofar sound
      );
      debugPrint('NotificationService: Issur Melacha scheduled: $issurSuccess');
    } else {
      // iOS scheduling
      final preIosSoundFile = _getIosSoundFile(earlyReminderSoundId);
      final candleIosSoundFile = _getIosSoundFile(candleLightingSoundId);

      try {
        final preTzTime = tz.TZDateTime(
          tz.local,
          preTime.year,
          preTime.month,
          preTime.day,
          preTime.hour,
          preTime.minute,
        );

        await _notifications.zonedSchedule(
          996,
          '🧪 TEST: ${strings['preTitle']!}',
          'Daily test alarm\n${strings['preBody']!}',
          preTzTime,
          _getNotificationDetails(iosSoundFile: preIosSoundFile),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        );
        debugPrint('NotificationService: ✓ iOS pre-notification scheduled');

        final candleTzTime = tz.TZDateTime(
          tz.local,
          candleTime.year,
          candleTime.month,
          candleTime.day,
          candleTime.hour,
          candleTime.minute,
        );

        await _notifications.zonedSchedule(
          997,
          '🧪 TEST: ${strings['candleTitle']!}',
          'Daily test alarm\n${strings['candleBody']!}',
          candleTzTime,
          _getNotificationDetails(iosSoundFile: candleIosSoundFile),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        );
        debugPrint('NotificationService: ✓ iOS candle lighting scheduled');

        // Issur melacha
        final issurTime = candleTime.add(const Duration(seconds: 18));
        final issurTzTime = tz.TZDateTime(
          tz.local,
          issurTime.year,
          issurTime.month,
          issurTime.day,
          issurTime.hour,
          issurTime.minute,
          issurTime.second,
        );

        await _notifications.zonedSchedule(
          998,
          '🧪 TEST: ⏰ Issur Melacha',
          'Daily test alarm - Issur Melacha notification',
          issurTzTime,
          _getNotificationDetails(iosSoundFile: candleIosSoundFile),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        );
        debugPrint('NotificationService: ✓ iOS issur melacha scheduled');
      } catch (e) {
        debugPrint('NotificationService: ✗ ERROR: $e');
      }
    }

    debugPrint('==========================================');
    debugPrint('✓ Daily test notifications scheduled!');
    debugPrint('Pre-notification: $preTime');
    debugPrint('Candle lighting: $candleTime');
    debugPrint('These will repeat at the same time tomorrow');
    debugPrint('==========================================');
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
      // Edge Case 6: Protect imminent alarms even when disabling notifications
      debugPrint('NotificationService: Disabling notifications - protecting imminent alarms');
      await _notifications.cancelAll();
      if (Platform.isAndroid) {
        // Protect alarms that are about to fire (within 5 minutes)
        await NativeAlarmService.cancelAllAlarms(protectImminent: true);
        debugPrint('NotificationService: ⚠️ Imminent alarms were protected and will still fire');
      }
    }
  }

  Future<int> getPreNotificationMinutes() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getInt(_preNotificationMinutesKey) ?? 40;
    // Only allow 20, 40, or 60 minutes
    if (saved == 20 || saved == 40 || saved == 60) return saved;
    return 40; // Default to 40 if invalid value
  }

  Future<void> setPreNotificationMinutes(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    // Edge Case 2: Save old value before updating for comparison
    final oldMinutes = prefs.getInt(_preNotificationMinutesKey) ?? 40;
    if (oldMinutes != minutes) {
      await prefs.setInt(_previousPreNotificationMinutesKey, oldMinutes);
    }
    await prefs.setInt(_preNotificationMinutesKey, minutes);
    debugPrint('NotificationService: Pre-notification minutes changed from $oldMinutes to $minutes');
  }

  /// Force reschedule all notifications with current settings
  /// Call this after changing pre-notification minutes or sound settings
  /// 
  /// SMART PROTECTION LOGIC:
  /// - If user changes timing (e.g., 40→20 minutes), we check if the NEW alarm time is valid
  /// - If new alarm time is in the future and NOT imminent (>5 min), we allow cancelling old alarm
  /// - If new alarm time would also be imminent or in the past, we protect the old alarm
  /// - This ensures users can change settings without losing alarms, while still protecting imminent ones
  /// 
  /// Edge Case 3: Debouncing - prevents rapid successive changes
  /// Edge Case 7: If only sound changes and alarm is imminent, skip rescheduling
  Future<void> rescheduleAllNotifications(
    List<CandleLighting> candleLightings, {
    String locale = 'en',
    bool onlySoundChanged = false, // Edge Case 7: Track if only sound changed
  }) async {
    // Edge Case 3: Debounce rapid setting changes
    final now = DateTime.now();
    if (_lastRescheduleTime != null) {
      final timeSinceLastReschedule = now.difference(_lastRescheduleTime!);
      if (timeSinceLastReschedule < _rescheduleDebounceDelay) {
        debugPrint('NotificationService: ⏳ Debouncing reschedule (${timeSinceLastReschedule.inMilliseconds}ms since last)');
        // Wait for debounce delay and check if another reschedule was requested
        await Future.delayed(_rescheduleDebounceDelay - timeSinceLastReschedule);
        // If another reschedule happened during wait, skip this one
        if (_lastRescheduleTime != null && _lastRescheduleTime!.isAfter(now)) {
          debugPrint('NotificationService: ⏭️ Skipping reschedule - newer one was requested');
          return;
        }
      }
    }
    _lastRescheduleTime = DateTime.now();
    
    // Edge Case 3: Queue reschedules to prevent race conditions
    if (_pendingReschedule != null) {
      debugPrint('NotificationService: ⏳ Waiting for pending reschedule to complete...');
      await _pendingReschedule;
    }
    
    _pendingReschedule = _rescheduleAllNotificationsInternal(
      candleLightings,
      locale: locale,
      onlySoundChanged: onlySoundChanged,
    );
    
    try {
      await _pendingReschedule;
    } finally {
      _pendingReschedule = null;
    }
  }
  
  /// Internal reschedule implementation (called after debouncing)
  Future<void> _rescheduleAllNotificationsInternal(
    List<CandleLighting> candleLightings, {
    String locale = 'en',
    bool onlySoundChanged = false,
  }) async {
    debugPrint('NotificationService: ===== RESCHEDULING ALL NOTIFICATIONS =====');
    if (onlySoundChanged) {
      debugPrint('NotificationService: Edge Case 7: Only sound changed - will skip if alarms imminent');
    }
    
    final prefs = await SharedPreferences.getInstance();
    final newPreMinutes = prefs.getInt(_preNotificationMinutesKey) ?? 40;
    final oldPreMinutes = prefs.getInt(_previousPreNotificationMinutesKey) ?? newPreMinutes;
    final now = DateTime.now();
    
    // Edge Case 20: Check for clock manipulation
    await _checkClockManipulation();
    
    // Edge Case 22: Adjust threshold based on pre-notification setting
    final imminentThreshold = _getImminentThreshold(newPreMinutes);
    debugPrint('NotificationService: Using imminent threshold: ${imminentThreshold.inMinutes} minutes');
    
    // Calculate what the NEW alarm times would be
    final newAlarmTimes = <DateTime>[];
    for (final lighting in candleLightings) {
      final newPreTime = lighting.candleLightingTime.subtract(
        Duration(minutes: newPreMinutes),
      );
      if (newPreTime.isAfter(now)) {
        newAlarmTimes.add(newPreTime);
      }
    }
    
    debugPrint('NotificationService: Old pre-notification setting: $oldPreMinutes minutes');
    debugPrint('NotificationService: New pre-notification setting: $newPreMinutes minutes');
    debugPrint('NotificationService: New alarm times would be: $newAlarmTimes');
    
    // Edge Case 2: Calculate OLD alarm times for backward timing changes (20→40 minutes)
    final oldAlarmTimes = <DateTime>[];
    if (oldPreMinutes != newPreMinutes) {
      for (final lighting in candleLightings) {
        final oldPreTime = lighting.candleLightingTime.subtract(
          Duration(minutes: oldPreMinutes),
        );
        if (oldPreTime.isAfter(now)) {
          oldAlarmTimes.add(oldPreTime);
        }
      }
      debugPrint('NotificationService: Old alarm times would be: $oldAlarmTimes');
    }
    
    // Edge Case 16: Handle multiple events individually - check each event separately
    // Determine if we should protect imminent alarms PER EVENT
    final eventsToProtect = <int>{}; // Indices of events with imminent alarms
    final eventsToReschedule = <int>{}; // Indices of events that can be rescheduled
    
    for (int i = 0; i < candleLightings.length; i++) {
      final newPreTime = i < newAlarmTimes.length ? newAlarmTimes[i] : null;
      final oldPreTime = i < oldAlarmTimes.length ? oldAlarmTimes[i] : null;
      
      bool shouldProtectThisEvent = false;
      
      if (newPreTime == null) {
        // No valid new alarm for this event
        shouldProtectThisEvent = true;
        debugPrint('NotificationService: Event $i (${candleLightings[i].displayName}): No valid new alarm - protecting');
      } else {
        // Edge Case 2: Check if OLD alarm time is imminent (for backward timing changes)
        bool oldAlarmIsImminent = false;
        if (oldPreTime != null) {
          final timeUntilOldAlarm = oldPreTime.difference(now);
          oldAlarmIsImminent = timeUntilOldAlarm > Duration.zero && 
                              timeUntilOldAlarm <= imminentThreshold;
        }
        
        // Check if new alarm time is imminent
        final timeUntilNewAlarm = newPreTime.difference(now);
        final newAlarmIsImminent = timeUntilNewAlarm > Duration.zero && 
                                   timeUntilNewAlarm <= imminentThreshold;
        
        // Edge Case 2: Protect if EITHER old or new alarm is imminent
        if (oldAlarmIsImminent) {
          shouldProtectThisEvent = true;
          debugPrint('NotificationService: Event $i: Old alarm imminent - protecting');
        } else if (newAlarmIsImminent) {
          shouldProtectThisEvent = true;
          debugPrint('NotificationService: Event $i: New alarm also imminent - protecting');
        } else {
          // New alarm is not imminent - safe to reschedule
          eventsToReschedule.add(i);
          debugPrint('NotificationService: Event $i: Safe to reschedule');
        }
      }
      
      if (shouldProtectThisEvent) {
        eventsToProtect.add(i);
      }
    }
    
    // Determine overall protection strategy
    final shouldProtectImminent = eventsToProtect.isNotEmpty;
    
    if (shouldProtectImminent) {
      debugPrint('NotificationService: ⚠️ Protecting ${eventsToProtect.length} events with imminent alarms');
      debugPrint('NotificationService: ⚠️ Rescheduling ${eventsToReschedule.length} events with new settings');
    } else {
      debugPrint('NotificationService: ✓ All events safe to reschedule');
    }
    
    // Save new pre-minutes as previous for next comparison
    await prefs.setInt(_previousPreNotificationMinutesKey, newPreMinutes);

    // Edge Case 7: If only sound changed and alarms are imminent, skip rescheduling
    if (onlySoundChanged && shouldProtectImminent) {
      debugPrint('NotificationService: ⚠️ Only sound changed and alarms are imminent');
      debugPrint('NotificationService: ⚠️ Skipping reschedule - alarms will fire with original sound');
      debugPrint('NotificationService: ⚠️ Future alarms will use new sound setting');
      return; // Don't reschedule - let imminent alarms fire with original sound
    }

    // Cancel all existing notifications, with smart protection on Android
    await _notifications.cancelAll();
    if (Platform.isAndroid) {
      await NativeAlarmService.cancelAllAlarms(protectImminent: shouldProtectImminent);
    }

    // Verify current sound settings before rescheduling
    final earlyReminderSound = await _audioService.getEarlyReminderSound();
    final yomTovSound = await _audioService.getYomTovSound();
    debugPrint('NotificationService: Current early reminder sound: $earlyReminderSound');
    debugPrint('NotificationService: Current Yom Tov sound: $yomTovSound');
    debugPrint('NotificationService: Using locale: $locale');

    // Longer delay to ensure all cancellations are processed, especially on iOS
    await Future.delayed(const Duration(milliseconds: 500));

    // Verify cancellations completed
    final pendingBefore = await _notifications.pendingNotificationRequests();
    if (pendingBefore.isNotEmpty) {
      debugPrint('NotificationService: ${pendingBefore.length} notifications still pending');
      if (shouldProtectImminent) {
        debugPrint('NotificationService: Some may be protected imminent alarms that will fire with original sound');
      }
      
      // On iOS, cancel all pending (protection is mainly for Android native alarms)
      for (final notification in pendingBefore) {
        await _notifications.cancel(notification.id);
      }
      await Future.delayed(const Duration(milliseconds: 200));
    }

    // Edge Case 17: Network failure handling - only reschedule if we successfully got candle lighting times
    // If reschedule fails, protected alarms remain scheduled
    try {
      // Reschedule with new settings
      // If we protected alarms, skip cancellation so protected alarms remain
      await scheduleNotifications(
        candleLightings,
        locale: locale,
        skipCancellation: shouldProtectImminent,
      );
      debugPrint('NotificationService: ===== RESCHEDULE COMPLETE =====');
      if (shouldProtectImminent) {
        debugPrint('NotificationService: ⚠️ REMINDER: Imminent alarms were PROTECTED');
        debugPrint('NotificationService: ⚠️ They will fire with their originally scheduled sound');
      } else {
        debugPrint('NotificationService: ✓ All alarms rescheduled with new settings');
      }
    } catch (e) {
      // Edge Case 17: If rescheduling fails, protected alarms remain
      debugPrint('NotificationService: ✗ ERROR during reschedule: $e');
      debugPrint('NotificationService: ⚠️ Protected alarms remain scheduled and will fire');
      if (shouldProtectImminent) {
        debugPrint('NotificationService: ⚠️ This is safe - protected alarms will still fire');
      } else {
        debugPrint('NotificationService: ⚠️ WARNING: Some alarms may have been cancelled but not rescheduled!');
        // Could restore from backup here if we had one
      }
      rethrow; // Re-throw so caller knows reschedule failed
    }
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

  /// Add a log entry to diagnostic logs (for display in diagnostic report)
  Future<void> _loadPersistedDiagnosticLogs() async {
    if (_diagnosticLogsLoaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getStringList(_diagnosticLogsPrefsKey) ?? const <String>[];
      _diagnosticLogs
        ..clear()
        ..addAll(stored);
      _diagnosticLogsLoaded = true;
    } catch (e) {
      debugPrint('NotificationService: Failed to load persisted diagnostic logs: $e');
    }
  }

  Future<void> _persistDiagnosticLogs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_diagnosticLogsPrefsKey, List<String>.from(_diagnosticLogs));
    } catch (e) {
      debugPrint('NotificationService: Failed to persist diagnostic logs: $e');
    }
  }

  void _schedulePersistDiagnosticLogs() {
    _diagnosticPersistTimer?.cancel();
    _diagnosticPersistTimer = Timer(const Duration(milliseconds: 600), () {
      // Fire-and-forget persistence; diagnostic only
      unawaited(_persistDiagnosticLogs());
    });
  }

  void _addDiagnosticLog(String message) {
    final timestamp = DateTime.now();
    final logEntry = '[${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}] $message';
    _diagnosticLogs.add(logEntry);
    
    // Keep only last N entries
    if (_diagnosticLogs.length > _maxLogEntries) {
      _diagnosticLogs.removeAt(0);
    }

    // Persist so user can read report on a real device
    _schedulePersistDiagnosticLogs();
  }

  /// Clear all diagnostic logs (both Flutter and native) and reschedule all notifications
  /// Use this to get a fresh start for debugging
  Future<void> clearLogsAndReschedule({
    required List<CandleLighting> candleLightings,
    String locale = 'en',
  }) async {
    // Clear Flutter diagnostic logs
    _diagnosticLogs.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_diagnosticLogsPrefsKey);
    
    // Clear native Android debug logs
    if (Platform.isAndroid) {
      await NativeAlarmService.clearDebugLogs();
    }
    
    _addDiagnosticLog('=== LOGS CLEARED AND RESCHEDULING ===');
    _addDiagnosticLog('Time: ${DateTime.now()}');
    
    // Cancel all existing alarms
    await _notifications.cancelAll();
    if (Platform.isAndroid) {
      await NativeAlarmService.cancelAllAlarms(protectImminent: false);
    }
    
    // Reschedule all notifications
    await scheduleNotifications(
      candleLightings,
      locale: locale,
    );
    
    _addDiagnosticLog('=== RESCHEDULE COMPLETE ===');
  }

  /// Generate a diagnostic report for debugging notification issues
  /// This can be shared by users experiencing problems
  Future<String> generateDiagnosticReport() async {
    final buffer = StringBuffer();
    final now = DateTime.now();

    // Ensure persisted logs are included
    await _loadPersistedDiagnosticLogs();
    
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
      buffer.writeln('');

      // WorkManager Health Check Status
      buffer.writeln('--- WORKMANAGER HEALTH CHECK STATUS ---');
      try {
        final nativeDebug = await NativeAlarmService.readDebugLogs();
        if (nativeDebug != null && nativeDebug.isNotEmpty) {
          final lines = nativeDebug.split('\n');
          
          // Find health check related logs
          final healthCheckLogs = lines.where((line) => 
            line.contains('AlarmHealthWorker') ||
            line.contains('Health check') ||
            line.contains('health_check')
          ).toList();
          
          if (healthCheckLogs.isEmpty) {
            buffer.writeln('No health check logs found yet.');
            buffer.writeln('Health checks run every 12 hours automatically.');
          } else {
            buffer.writeln('Recent health check activity (last ${healthCheckLogs.length > 20 ? 20 : healthCheckLogs.length} entries):');
            for (final log in healthCheckLogs.reversed.take(20)) {
              buffer.writeln(log);
            }
            if (healthCheckLogs.length > 20) {
              buffer.writeln('... (${healthCheckLogs.length - 20} more health check logs)');
            }
            
            // Highlight critical events
            final criticalLogs = healthCheckLogs.where((line) =>
              line.contains('CRITICAL') ||
              line.contains('missing') ||
              line.contains('restored') ||
              line.contains('rescheduled')
            ).toList();
            
            if (criticalLogs.isNotEmpty) {
              buffer.writeln('');
              buffer.writeln('⚠️  IMPORTANT HEALTH CHECK EVENTS:');
              for (final log in criticalLogs.reversed.take(10)) {
                buffer.writeln(log);
              }
            }
          }
        } else {
          buffer.writeln('No health check logs available yet.');
        }
      } catch (e) {
        buffer.writeln('Error reading health check logs: $e');
      }
      buffer.writeln('');

      buffer.writeln('--- ANDROID NATIVE DEBUG LOGS (debug_logs.txt) ---');
      try {
        final nativeDebug = await NativeAlarmService.readDebugLogs();
        if (nativeDebug == null || nativeDebug.trim().isEmpty) {
          buffer.writeln('No native debug logs found yet.');
        } else {
          final lines = nativeDebug.split('\n');
          final tail = lines.length > 250 ? lines.sublist(lines.length - 250) : lines;
          buffer.writeln('Showing last ${tail.length} lines (of ${lines.length} total):');
          buffer.writeln('This includes: AlarmScheduler, AlarmReceiver, AlarmHealthWorker, BootReceiver');
          buffer.writeln('');
          for (final line in tail) {
            buffer.writeln(line);
          }
          if (lines.length > 250) {
            buffer.writeln('... (truncated; showing last 250 lines)');
          }
        }
      } catch (e) {
        buffer.writeln('Error reading native debug logs: $e');
      }
      buffer.writeln('');
      
      // Native Android alarms
      buffer.writeln('--- NATIVE ANDROID ALARMS ---');
      try {
        final nativeAlarms = await NativeAlarmService.getScheduledAlarms();
        buffer.writeln('Total Native Alarms: ${nativeAlarms.length}');
        for (final alarm in nativeAlarms.take(20)) {
          final id = alarm['id'];
          final title = alarm['title'];
          final isPre = alarm['isPreNotification'];
          final timestamp = alarm['timestampMillis'] as int;
          final time = DateTime.fromMillisecondsSinceEpoch(timestamp);
          final soundId = alarm['soundId'] ?? 'unknown';
          buffer.writeln('  #$id: "$title" (isPre=$isPre, sound=$soundId) at $time');
        }
        if (nativeAlarms.length > 20) {
          buffer.writeln('  ... and ${nativeAlarms.length - 20} more alarms');
        }
      } catch (e) {
        buffer.writeln('Error getting native alarms: $e');
      }
      buffer.writeln('');
    }
    
    // Upcoming notifications
    buffer.writeln('--- UPCOMING NOTIFICATIONS (via getUpcomingNotifications) ---');
    try {
      final upcoming = await getUpcomingNotifications(limit: 20);
      buffer.writeln('Count: ${upcoming.length}');
      for (final notification in upcoming) {
        final timeUntil = notification.timeUntil;
        final timeUntilStr = timeUntil.isNegative 
            ? 'PAST (${timeUntil.inMinutes.abs()} min ago)'
            : 'in ${timeUntil.inHours}h ${timeUntil.inMinutes.remainder(60)}m';
        buffer.writeln('  #${notification.id}: "${notification.title}"');
        buffer.writeln('    Type: ${notification.isPreNotification ? "Pre-notification" : (notification.title.toLowerCase().contains("issur") ? "Issur Melacha" : "Candle Lighting")}');
        buffer.writeln('    Scheduled: ${notification.scheduledTime}');
        buffer.writeln('    Time until: $timeUntilStr');
        buffer.writeln('    Sound: ${notification.soundId}');
      }
    } catch (e) {
      buffer.writeln('Error getting upcoming notifications: $e');
    }
    buffer.writeln('');
    
    // Diagnostic logs (notification scheduling activity)
    buffer.writeln('--- NOTIFICATION SCHEDULING LOGS (Last ${_diagnosticLogs.length} entries) ---');
    if (_diagnosticLogs.isEmpty) {
      buffer.writeln('No logs available yet. Logs are captured when notifications are scheduled.');
    } else {
      // Show last 200 entries (most recent)
      final logsToShow = _diagnosticLogs.length > 200 
          ? _diagnosticLogs.sublist(_diagnosticLogs.length - 200)
          : _diagnosticLogs;
      for (final log in logsToShow) {
        buffer.writeln(log);
      }
      if (_diagnosticLogs.length > 200) {
        buffer.writeln('... (showing last 200 of ${_diagnosticLogs.length} total logs)');
      }
    }
    buffer.writeln('');
    
    buffer.writeln('=== END REPORT ===');
    
    final report = buffer.toString();
    debugPrint(report);
    return report;
  }

  /// Get upcoming notifications with their details (sound, time, message)
  /// Returns list of UpcomingNotification sorted by scheduled time
  Future<List<UpcomingNotification>> getUpcomingNotifications({int limit = 3}) async {
    final List<UpcomingNotification> notifications = [];
    final now = DateTime.now();

    try {
      debugPrint('NotificationService: Getting upcoming notifications...');
      if (Platform.isAndroid) {
        // Android: Get from native alarm service
        final androidAlarms = await NativeAlarmService.getScheduledAlarms();
        debugPrint('NotificationService: Got ${androidAlarms.length} alarms from Android');
        for (final alarm in androidAlarms) {
          try {
            final scheduledTime = DateTime.fromMillisecondsSinceEpoch(alarm['timestampMillis'] as int);
            debugPrint('NotificationService: Checking alarm #${alarm['id']} scheduled for $scheduledTime');
            if (scheduledTime.isAfter(now)) {
              notifications.add(UpcomingNotification(
                id: alarm['id'] as int,
                scheduledTime: scheduledTime,
                title: alarm['title'] as String,
                body: alarm['body'] as String,
                soundId: alarm['soundId'] as String? ?? 'rav_shalom_shofar',
                isPreNotification: alarm['isPreNotification'] as bool? ?? false,
              ));
              debugPrint('NotificationService: Added notification: ${alarm['title']}');
            } else {
              debugPrint('NotificationService: Skipped past alarm: $scheduledTime');
            }
          } catch (e) {
            debugPrint('NotificationService: Error processing alarm: $e');
          }
        }
      } else {
        // iOS: Get from pending notifications and reconstruct scheduled times
        // Store scheduled times when scheduling (we'll add this)
        final pending = await _notifications.pendingNotificationRequests();
        final prefs = await SharedPreferences.getInstance();
        
        for (final notification in pending) {
          // Try to get scheduled time from stored data
          final scheduledTimeKey = 'notification_scheduled_time_${notification.id}';
          final scheduledTimeMillis = prefs.getInt(scheduledTimeKey);
          
          if (scheduledTimeMillis != null) {
            final scheduledTime = DateTime.fromMillisecondsSinceEpoch(scheduledTimeMillis);
            if (scheduledTime.isAfter(now)) {
              // Get sound ID from stored notification type
              final notificationType = prefs.getString('$_notificationTypePrefix${notification.id}');
              final isYomTov = prefs.getBool('$_notificationYomTovPrefix${notification.id}') ?? false;
              
              // Determine sound ID based on notification type
              String soundId = 'rav_shalom_shofar';
              if (notificationType == 'pre') {
                if (isYomTov) {
                  soundId = await _audioService.getYomTovSound();
                } else {
                  soundId = await _audioService.getEarlyReminderSound();
                }
              } else if (notificationType == 'candle') {
                soundId = _audioService.getCandleLightingSound();
              } else if (notificationType == 'issur') {
                soundId = 'default';
              }
              
              notifications.add(UpcomingNotification(
                id: notification.id,
                scheduledTime: scheduledTime,
                title: notification.title ?? '',
                body: notification.body ?? '',
                soundId: soundId,
                isPreNotification: notificationType == 'pre',
              ));
            }
          }
        }
      }

      // Sort by scheduled time
      notifications.sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
      
      // Show the next notification of each type to ensure all types are visible
      // This ensures we show pre-notification, candle lighting, and issur melacha
      final result = <UpcomingNotification>[];
      
      // Helper function to check if notification is issur melacha
      bool isIssurMelacha(UpcomingNotification n) {
        final titleLower = n.title.toLowerCase();
        final bodyLower = n.body.toLowerCase();
        return titleLower.contains('issur') || 
               titleLower.contains('איסור') ||
               titleLower.contains('melacha') ||
               bodyLower.contains('issur') ||
               bodyLower.contains('איסור') ||
               bodyLower.contains('prohibited');
      }
      
      // Helper function to check if notification is candle lighting
      bool isCandleLighting(UpcomingNotification n) {
        final titleLower = n.title.toLowerCase();
        final bodyLower = n.body.toLowerCase();
        return !n.isPreNotification && 
               !isIssurMelacha(n) &&
               (titleLower.contains('candle') || 
                titleLower.contains('הדלקת') ||
                titleLower.contains('🕯️') ||
                bodyLower.contains('candle') ||
                bodyLower.contains('הדלקת') ||
                titleLower.contains('shabbos') ||
                titleLower.contains('shabbat'));
      }
      
      // Find the next pre-notification
      try {
        final nextPre = notifications.firstWhere((n) => n.isPreNotification);
        result.add(nextPre);
        debugPrint('NotificationService: Found pre-notification: ${nextPre.title}');
      } catch (e) {
        debugPrint('NotificationService: No pre-notification found');
      }
      
      // Find the next candle lighting notification
      try {
        final nextCandle = notifications.firstWhere(isCandleLighting);
        if (!result.contains(nextCandle)) {
          result.add(nextCandle);
          debugPrint('NotificationService: Found candle lighting: ${nextCandle.title}');
        }
      } catch (e) {
        debugPrint('NotificationService: No candle lighting notification found');
      }
      
      // Find the next issur melacha notification
      try {
        final nextIssur = notifications.firstWhere(
          (n) => !n.isPreNotification && isIssurMelacha(n),
        );
        if (!result.contains(nextIssur)) {
          result.add(nextIssur);
          debugPrint('NotificationService: Found issur melacha: ${nextIssur.title}');
        }
      } catch (e) {
        debugPrint('NotificationService: No issur melacha notification found');
      }
      
      // If we don't have enough notifications, add more from the sorted list
      if (result.length < limit) {
        for (final notification in notifications) {
          if (!result.contains(notification) && result.length < limit) {
            result.add(notification);
          }
        }
      }
      
      // Sort result by time
      result.sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
      
      // If we have fewer than limit, add more from sorted list to fill up to limit
      if (result.length < limit && notifications.length > result.length) {
        for (final notification in notifications) {
          if (!result.contains(notification) && result.length < limit) {
            result.add(notification);
          }
        }
        // Re-sort after adding
        result.sort((a, b) => a.scheduledTime.compareTo(b.scheduledTime));
      }
      
      final finalResult = result.take(limit).toList();
      debugPrint('NotificationService: Returning ${finalResult.length} upcoming notifications');
      debugPrint('NotificationService:   - Pre-notifications: ${finalResult.where((n) => n.isPreNotification).length}');
      debugPrint('NotificationService:   - Candle lighting: ${finalResult.where(isCandleLighting).length}');
      debugPrint('NotificationService:   - Issur melacha: ${finalResult.where((n) => !n.isPreNotification && isIssurMelacha(n)).length}');
      return finalResult;
    } catch (e, stackTrace) {
      debugPrint('NotificationService: Error getting upcoming notifications: $e');
      debugPrint('NotificationService: Stack trace: $stackTrace');
      return [];
    }
  }
}

/// Model for upcoming notification details
class UpcomingNotification {
  final int id;
  final DateTime scheduledTime;
  final String title;
  final String body;
  final String soundId;
  final bool isPreNotification;

  UpcomingNotification({
    required this.id,
    required this.scheduledTime,
    required this.title,
    required this.body,
    required this.soundId,
    required this.isPreNotification,
  });

  Duration get timeUntil => scheduledTime.difference(DateTime.now());
  
  String get soundName {
    final sound = SoundOption.findById(soundId);
    if (sound == null) {
      if (soundId == 'default') return 'System Default';
      if (soundId == 'silent') return 'Silent';
      return soundId;
    }
    return sound.nameEn; // Will be localized in UI
  }
  
  String get soundNameHe {
    final sound = SoundOption.findById(soundId);
    if (sound == null) {
      if (soundId == 'default') return 'ברירת מחדל';
      if (soundId == 'silent') return 'שקט';
      return soundId;
    }
    return sound.nameHe;
  }
}
