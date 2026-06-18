import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:permission_handler/permission_handler.dart';
import '../models/candle_lighting.dart';
import '../services/hebcal_service.dart';
import '../services/location_service.dart';
import '../services/notification_service.dart';
import '../services/native_alarm_service.dart';

class HomeTab extends StatefulWidget {
  final String locale;
  final Function(String) onLocaleChanged;

  const HomeTab({
    super.key,
    required this.locale,
    required this.onLocaleChanged,
  });

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> with WidgetsBindingObserver {
  final HebcalService _hebcalService = HebcalService();
  final LocationService _locationService = LocationService();
  final NotificationService _notificationService = NotificationService();

  List<CandleLighting> _candleLightings = [];
  LocationInfo? _location;
  bool _isLoading = true;
  bool _isDetectingLocation = false;
  String? _error;

  // Permission status
  bool? _exactAlarmGranted;
  bool? _batteryOptimizationDisabled;
  bool? _overlayPermissionGranted;
  bool _overlaySettingsAvailable = true;
  bool? _fullScreenIntentGranted;
  // iOS-only: tracks the OS-level notification permission so we can warn the
  // user when alerts won't fire. Defaults true so no banner flashes on launch.
  bool _iosNotificationsEnabled = true;
  DateTime? _lastPermissionCheck;

  bool get isHebrew => widget.locale == 'he';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Check permissions immediately when widget is created
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPermissions();
    });
    _init();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-check permissions when app resumes (every time app is opened or brought to foreground)
    if (state == AppLifecycleState.resumed) {
      debugPrint('HomeTab: App resumed/opened, checking permissions');
      // Reset throttle so the check is never skipped after returning from settings
      _lastPermissionCheck = null;
      // Use a small delay to ensure the app is fully active
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _checkPermissions();
        }
      });
    }
  }

  Future<void> _init() async {
    await _notificationService.initialize();
    await _checkPermissions();
    await _loadData();
  }

  Future<void> _checkPermissions() async {
    // Avoid checking too frequently (max once per 2 seconds)
    final now = DateTime.now();
    if (_lastPermissionCheck != null &&
        now.difference(_lastPermissionCheck!).inSeconds < 2) {
      debugPrint(
        'HomeTab: Skipping permission check (checked ${now.difference(_lastPermissionCheck!).inSeconds}s ago)',
      );
      return;
    }
    _lastPermissionCheck = now;

    debugPrint('HomeTab: ===== Checking permissions =====');

    if (Platform.isAndroid) {
      final exactAlarm = await NativeAlarmService.canScheduleExactAlarms();
      final batteryOptimization =
          await NativeAlarmService.isIgnoringBatteryOptimizations();
      final overlayPermission = await NativeAlarmService.canDrawOverlays();
      final overlayAvailable = overlayPermission ||
          await NativeAlarmService.isOverlaySettingsAvailable();
      final fullScreenIntent =
          await NativeAlarmService.canUseFullScreenIntent();

      if (mounted) {
        setState(() {
          _exactAlarmGranted = exactAlarm;
          _batteryOptimizationDisabled = batteryOptimization;
          _overlayPermissionGranted = overlayPermission;
          _overlaySettingsAvailable = overlayAvailable;
          _fullScreenIntentGranted = fullScreenIntent;
        });
      }

      debugPrint('HomeTab: Exact alarm permission: $exactAlarm');
      debugPrint(
        'HomeTab: Battery optimization disabled: $batteryOptimization',
      );
      debugPrint('HomeTab: Overlay permission: $overlayPermission');
      debugPrint('HomeTab: Full screen intent: $fullScreenIntent');
    } else {
      // iOS: the Android-specific permissions don't apply, but we DO check the
      // OS-level notification permission so we can warn the user if alerts are
      // turned off (e.g. they skipped or declined the onboarding prompt).
      final notificationsOn =
          await _notificationService.areOsNotificationsEnabled();
      if (mounted) {
        setState(() {
          _exactAlarmGranted = true;
          _batteryOptimizationDisabled = true;
          _overlayPermissionGranted = true;
          _fullScreenIntentGranted = true;
          _iosNotificationsEnabled = notificationsOn;
        });
      }
      debugPrint('HomeTab: iOS notifications enabled: $notificationsOn');
    }
  }

  Future<void> _detectLocation() async {
    setState(() {
      _isDetectingLocation = true;
      _error = null;
    });

    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _error = isHebrew
              ? 'שירותי המיקום כבויים. נפתחות הגדרות המכשיר…'
              : 'Location services are disabled. Opening device settings…';
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isHebrew
                    ? 'הפעל את שירותי המיקום במכשיר ונסה שוב.'
                    : 'Turn on Location in device settings, then try again.',
              ),
              backgroundColor: Colors.orange[700],
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
        }
        await Geolocator.openLocationSettings();
        return;
      }

      // Check permission status first
      LocationPermission permission = await Geolocator.checkPermission();
      debugPrint('HomeTab: Current location permission: $permission');

      // Only request if not already granted
      if (permission == LocationPermission.denied) {
        debugPrint('HomeTab: Requesting location permission...');
        permission = await Geolocator.requestPermission();
        debugPrint('HomeTab: Permission result: $permission');
      }

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        // Get current location
        debugPrint('HomeTab: Getting current location...');
        final location = await _locationService.getCurrentLocation();

        if (location != null) {
          // Save and enable GPS
          await _locationService.saveLocation(location);
          await _locationService.setUseGps(true);

          // Reload data with new location
          await _loadData();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  isHebrew
                      ? '✓ מיקום זוהה: ${location.displayName}'
                      : '✓ Location detected: ${location.displayName}',
                ),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            );
          }
        } else {
          setState(() {
            _error = isHebrew
                ? 'לא ניתן לזהות מיקום. נסה שוב.'
                : 'Could not detect location. Please try again.';
          });
        }
      } else if (permission == LocationPermission.deniedForever) {
        // Open app settings
        if (mounted) {
          _showLocationSettingsDialog();
        }
      } else {
        setState(() {
          _error = isHebrew
              ? 'נדרשת הרשאת מיקום'
              : 'Location permission is required';
        });
      }
    } catch (e) {
      debugPrint('HomeTab: Error detecting location: $e');
      setState(() {
        _error = isHebrew
            ? 'שגיאה בזיהוי מיקום: $e'
            : 'Error detecting location: $e';
      });
    } finally {
      setState(() {
        _isDetectingLocation = false;
      });
    }
  }

  Future<void> _detectLocationWithReschedule() async {
    final oldLocation = _location;

    setState(() {
      _isDetectingLocation = true;
      _error = null;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isHebrew
                    ? 'הפעל את שירותי המיקום במכשיר ונסה שוב.'
                    : 'Turn on Location in device settings, then try again.',
              ),
              backgroundColor: Colors.orange[700],
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
        }
        await Geolocator.openLocationSettings();
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        final newLocation = await _locationService.getCurrentLocation();

        if (newLocation != null) {
          await _locationService.saveLocation(newLocation);
          await _locationService.setUseGps(true);

          // Check if location meaningfully changed
          final locationChanged =
              oldLocation == null ||
              oldLocation.cityName != newLocation.cityName ||
              _distanceKm(
                    oldLocation.latitude,
                    oldLocation.longitude,
                    newLocation.latitude,
                    newLocation.longitude,
                  ) >
                  5;

          if (locationChanged) {
            // Force reschedule: reload data and schedule notifications
            await _loadData();

            // Force schedule even if smart check says no
            if (_candleLightings.isNotEmpty) {
              await _notificationService.scheduleNotifications(
                _candleLightings.take(10).toList(),
                locale: widget.locale,
              );
            }

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    isHebrew
                        ? '✓ מיקום עודכן ל${newLocation.displayName}. ההתראות תוזמנו מחדש!'
                        : '✓ Location updated to ${newLocation.displayName}. Notifications rescheduled!',
                  ),
                  backgroundColor: Colors.green,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              );
            }
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    isHebrew
                        ? 'המיקום לא השתנה: ${newLocation.displayName}'
                        : 'Location unchanged: ${newLocation.displayName}',
                  ),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              );
            }
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  isHebrew
                      ? 'לא ניתן לזהות מיקום. נסה שוב.'
                      : 'Could not detect location. Please try again.',
                ),
                backgroundColor: Colors.red[400],
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            );
          }
        }
      } else if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          _showLocationSettingsDialog();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isHebrew
                    ? 'נדרשת הרשאת מיקום'
                    : 'Location permission is required',
              ),
              backgroundColor: Colors.red[400],
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('HomeTab: Error detecting location: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isHebrew ? 'שגיאה בזיהוי מיקום' : 'Error detecting location',
            ),
            backgroundColor: Colors.red[400],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDetectingLocation = false;
        });
      }
    }
  }

  /// Distance in km between two coordinates using Geolocator
  double _distanceKm(double lat1, double lon1, double lat2, double lon2) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2) / 1000.0;
  }

  void _showLocationSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          isHebrew ? 'נדרשת הרשאת מיקום' : 'Location Permission Required',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          isHebrew
              ? 'הרשאת המיקום נדחתה. אנא אפשר גישה למיקום בהגדרות המכשיר.'
              : 'Location permission was denied. Please enable location access in device settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(isHebrew ? 'ביטול' : 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Geolocator.openAppSettings();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A1A1A),
              foregroundColor: Colors.white,
            ),
            child: Text(isHebrew ? 'פתח הגדרות' : 'Open Settings'),
          ),
        ],
      ),
    );
  }


  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      var location = await _locationService.getSavedLocation();

      if (location == null) {
        final useGps = await _locationService.getUseGps();
        if (useGps) {
          location = await _locationService.getCurrentLocation();
        }
      }

      if (location != null) {
        _location = location;

        final now = DateTime.now();
        final times = await _hebcalService.getExtendedCandleLightingTimes(
          latitude: location.latitude,
          longitude: location.longitude,
          startDate: now,
          endDate: now.add(const Duration(days: 60)),
          timezone: location.timezone,
          country: location.country,
          locale: widget.locale,
        );

        final futureTimes = times
            .where((t) => t.candleLightingTime.isAfter(now))
            .toList();

        setState(() {
          _candleLightings = futureTimes;
          _isLoading = false;
        });

        // Only reschedule notifications if needed (not every app open)
        final needsRescheduling = await _checkIfNotificationsNeedRescheduling(
          futureTimes,
        );
        if (needsRescheduling) {
          debugPrint('HomeTab: Rescheduling notifications (needed)');
          await _notificationService.scheduleNotifications(
            futureTimes.take(10).toList(),
            locale: widget.locale,
          );
        } else {
          debugPrint(
            'HomeTab: Notifications already scheduled, skipping reschedule',
          );
        }

        // Check and start Live Activity for iOS if within pre-notification window
        await _notificationService.checkAndStartLiveActivity(futureTimes);

      } else {
        setState(() {
          _isLoading = false;
          _error = isHebrew
              ? 'נא לבחור מיקום בהגדרות'
              : 'Please select a location in Settings';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          _buildHeader(),
          if (Platform.isAndroid &&
              (_exactAlarmGranted != true ||
                  _batteryOptimizationDisabled != true))
            _buildPermissionBanner(),
          if (Platform.isIOS && !_iosNotificationsEnabled)
            _buildNotificationWarningBanner(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildLanguageToggle() {
    return GestureDetector(
      onTap: () {
        final newLocale = isHebrew ? 'en' : 'he';
        widget.onLocaleChanged(newLocale);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: const Color(0xFFE8B923).withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          textDirection: isHebrew ? TextDirection.rtl : TextDirection.ltr,
          children: [
            Text(
              isHebrew ? 'עב' : 'EN',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.language,
              size: 16,
              color: const Color(0xFF1A1A1A).withValues(alpha: 0.7),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final titleColumn = Expanded(
      child: Column(
        crossAxisAlignment: isHebrew
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Text(
            isHebrew ? 'שבת!!' : 'Shabbos!!',
            textDirection: isHebrew ? TextDirection.rtl : TextDirection.ltr,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A1A),
            ),
          ),
          if (_location != null)
            GestureDetector(
              onTap: _isDetectingLocation ? null : _detectLocation,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                textDirection: isHebrew ? TextDirection.rtl : TextDirection.ltr,
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 14,
                    color: Colors.grey[500],
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      _location!.displayName,
                      style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  if (_isDetectingLocation)
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: Colors.grey[500],
                      ),
                    )
                  else
                    Icon(Icons.my_location, size: 14, color: Colors.grey[400]),
                ],
              ),
            ),
        ],
      ),
    );

    final languageButton = _buildLanguageToggle();

    return Container(
      padding: EdgeInsetsDirectional.fromSTEB(24, 16, 24, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        textDirection: isHebrew ? TextDirection.rtl : TextDirection.ltr,
        children: isHebrew
            ? [
                languageButton,
                titleColumn,
              ] // RTL: button on left, title on right
            : [
                titleColumn,
                languageButton,
              ], // LTR: title on left, button on right
      ),
    );
  }

  Widget _buildPermissionBanner() {
    if (!Platform.isAndroid) {
      debugPrint('HomeTab: Not Android, skipping permission banner');
      return const SizedBox.shrink();
    }

    debugPrint(
      'HomeTab: Permission status - exactAlarm: $_exactAlarmGranted, batteryOptimization: $_batteryOptimizationDisabled',
    );

    // Show banner if permissions are null (not yet checked) or if either is false
    // Only hide if both are explicitly true
    if (_exactAlarmGranted == true &&
        _batteryOptimizationDisabled == true) {
      debugPrint('HomeTab: All permissions granted, hiding banner');
      return const SizedBox.shrink();
    }

    // If permissions haven't been checked yet, show banner
    if (_exactAlarmGranted == null || _batteryOptimizationDisabled == null) {
      debugPrint('HomeTab: Permissions not yet checked, showing banner');
    }

    final missingPermissions = <String>[];
    if (_exactAlarmGranted != true) {
      missingPermissions.add(isHebrew ? 'התראות מדויקות' : 'Exact Alarms');
    }
    if (_batteryOptimizationDisabled != true) {
      missingPermissions.add(
        isHebrew ? 'אופטימיזציית סוללה' : 'Battery Optimization',
      );
    }

    // If no specific permissions are missing but we're here, show generic message
    if (missingPermissions.isEmpty) {
      missingPermissions.add(
        isHebrew ? 'הרשאות נדרשות' : 'Permissions Required',
      );
    }

    debugPrint(
      'HomeTab: Showing permission banner for: ${missingPermissions.join(', ')}',
    );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3CD),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFE8B923).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Color(0xFFE8B923),
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isHebrew ? 'התראות מוגבלות' : 'Notifications Restricted',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 4),
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[700],
                      height: 1.3,
                    ),
                    children: [
                      TextSpan(
                        text:
                            'To make sure Shabbat and Yom Tov alerts arrive on time\n\n',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const TextSpan(
                        text: 'Android may pause this app to save battery.\n\n',
                      ),
                      const TextSpan(
                        text:
                            'Please allow the Shabbos App to run normally so alerts play at the correct time.\n\n',
                      ),
                      TextSpan(
                        text:
                            'This only applies to the Shabbos App and does not affect any other apps or phone settings.',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () async {
              if (_exactAlarmGranted != true) {
                await NativeAlarmService.requestExactAlarmPermission();
              } else if (_batteryOptimizationDisabled != true) {
                await NativeAlarmService.requestDisableBatteryOptimization();
              } else if (_overlayPermissionGranted != true &&
                  _overlaySettingsAvailable) {
                await NativeAlarmService.requestOverlayPermission();
              } else if (_fullScreenIntentGranted != true) {
                await NativeAlarmService.requestFullScreenIntentPermission();
              }
              // Reset throttle so the permission check runs when the user
              // returns from system settings (via didChangeAppLifecycleState)
              _lastPermissionCheck = null;
            },
            child: Text(
              isHebrew ? 'פתח' : 'Open',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A1A),
              ),
            ),
          ),
        ],
      ),
    );
  }


  /// iOS-only warning shown when the OS notification permission is off, so the
  /// user knows alerts and sounds won't fire — and can turn them on in one tap.
  /// Tapping "Enable" is a user-initiated action, so routing to Settings here
  /// is permitted by App Store guidelines (unlike auto-redirecting in onboarding).
  Widget _buildNotificationWarningBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3CD),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFE8B923).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.notifications_off_outlined,
            color: Color(0xFFE8B923),
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isHebrew ? 'ההתראות כבויות' : 'Notifications are off',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isHebrew
                      ? 'לא תקבל תזכורות וצלילים להדלקת נרות. הקש "הפעל" כדי להפעיל אותן.'
                      : 'You won\'t get candle lighting reminders or sounds. Tap "Enable" to turn them on.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () async {
              // Try an in-app request first — works if iOS hasn't shown the
              // dialog yet. If already declined, iOS won't re-prompt, so send
              // the user to Settings (allowed because they tapped Enable).
              final granted = await _notificationService.requestPermissions();
              if (!granted) {
                await openAppSettings();
              }
              // Re-check when the user returns from Settings.
              _lastPermissionCheck = null;
            },
            child: Text(
              isHebrew ? 'הפעל' : 'Enable',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A1A),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTravelLocationBanner() {
    final textDirection = isHebrew ? TextDirection.rtl : TextDirection.ltr;
    final locationName = _location?.displayName ?? '';
    return GestureDetector(
      onTap: _isDetectingLocation ? null : _detectLocationWithReschedule,
      child: Column(
        children: [
          if (_isDetectingLocation) ...[
            Text(
              isHebrew ? 'מזהה מיקום...' : 'Detecting...',
              textDirection: textDirection,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 8),
          ],
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFE8B923).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFE8B923).withValues(alpha: 0.2),
                width: 0.5,
              ),
            ),
            child: Row(
              textDirection: textDirection,
              children: [
                _isDetectingLocation
                    ? const SizedBox(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFFE8B923),
                        ),
                      )
                    : Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFFE8B923,
                          ).withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.my_location,
                          size: 20,
                          color: Color(0xFFE8B923),
                        ),
                      ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: isHebrew
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    children: [
                      Text(
                        locationName,
                        textDirection: textDirection,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A1A),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isHebrew
                            ? 'הקש לעדכון המיקום'
                            : 'Tap to update your location',
                        textDirection: textDirection,
                        style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
                if (!_isDetectingLocation)
                  Icon(
                    Icons.refresh_rounded,
                    size: 20,
                    color: Colors.grey[400],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFE8B923)),
      );
    }

    if (_error != null) {
      return _buildErrorState();
    }

    if (_candleLightings.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      color: const Color(0xFFE8B923),
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        children: [
          const SizedBox(height: 8),
          _buildTravelLocationBanner(),
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 4),
            child: Text(
              isHebrew
                  ? 'מנהגי המקום עשויים להיות שונים, ויש לנהוג לפיהם כאשר הם ידועים.'
                  : 'Local customs may differ and should be followed when known.',
              textDirection: isHebrew ? TextDirection.rtl : TextDirection.ltr,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[400],
                fontStyle: FontStyle.italic,
                height: 1.3,
              ),
            ),
          ),
          const SizedBox(height: 12),
          _buildNextCandleLighting(_candleLightings.first),
          const SizedBox(height: 32),
          if (_candleLightings.length > 1) ...[
            Text(
              isHebrew ? 'בקרוב' : 'Upcoming',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            ..._candleLightings
                .skip(1)
                .map((lighting) => _buildUpcomingCard(lighting)),
          ],
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildNextCandleLighting(CandleLighting lighting) {
    final timeFormat = DateFormat('h:mm a'); // 12-hour format with AM/PM

    // Use Hebrew date when in Hebrew mode, otherwise use English date format
    final dateString =
        (isHebrew &&
            lighting.hebrewDate != null &&
            lighting.hebrewDate!.isNotEmpty)
        ? lighting.hebrewDate!
        : DateFormat('EEEE, MMM d').format(lighting.date);

    final now = DateTime.now();
    final diff = lighting.candleLightingTime.difference(now);

    // Calculate days, hours, and minutes correctly
    final days = diff.inDays;
    // Hours remaining after subtracting full days (modulo 24)
    final hours = diff.inHours % 24;
    // Minutes remaining after subtracting full hours (modulo 60)
    final minutes = diff.inMinutes % 60;

    String countdown;
    if (days > 0) {
      // Always show days, hours, and minutes when days > 0
      countdown = isHebrew
          ? '$days ימים $hours שעות $minutes דק\''
          : '$days d ${hours}h ${minutes}m';
    } else if (hours > 0) {
      countdown = isHebrew
          ? '$hours שעות $minutes דק\''
          : '${hours}h ${minutes}m';
    } else {
      countdown = isHebrew ? '$minutes דקות' : '${minutes}m';
    }

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8B923),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isHebrew ? 'הבא' : 'NEXT',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A1A),
                    letterSpacing: 1,
                  ),
                ),
              ),
              Row(
                children: [
                  Icon(
                    Icons.schedule,
                    size: 14,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    countdown,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 24),

          Text(
            isHebrew ? lighting.hebrewDisplayName : lighting.displayName,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            dateString,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),

          const SizedBox(height: 28),

          Row(
            children: [
              Expanded(
                child: _buildTimeDisplay(
                  icon: Icons.local_fire_department,
                  iconColor: const Color(0xFFE8B923),
                  label: isHebrew ? 'הדלקת נרות' : 'Candle Lighting',
                  time: timeFormat.format(lighting.candleLightingTime),
                ),
              ),
              if (lighting.havdalahTime != null) ...[
                const SizedBox(width: 24),
                Expanded(
                  child: _buildTimeDisplay(
                    icon: Icons.nightlight_round,
                    iconColor: Colors.white.withValues(alpha: 0.5),
                    label: isHebrew ? 'הבדלה' : 'Havdalah',
                    time: timeFormat.format(lighting.havdalahTime!),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimeDisplay({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String time,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: iconColor),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            time,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUpcomingCard(CandleLighting lighting) {
    final timeFormat = DateFormat('h:mm a'); // 12-hour format with AM/PM

    // Use Hebrew date when in Hebrew mode
    final dateString =
        (isHebrew &&
            lighting.hebrewDate != null &&
            lighting.hebrewDate!.isNotEmpty)
        ? lighting.hebrewDate!
        : DateFormat('EEE, MMM d').format(lighting.date);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              lighting.isYomTov
                  ? Icons.celebration
                  : Icons.local_fire_department,
              color: const Color(0xFFE8B923),
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isHebrew ? lighting.hebrewDisplayName : lighting.displayName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  dateString,
                  style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
          Text(
            timeFormat.format(lighting.candleLightingTime),
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A1A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.location_off_outlined,
              size: 64,
              color: Colors.grey[300],
            ),
            const SizedBox(height: 24),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 32),

            // Detect Location Button
            ElevatedButton.icon(
              onPressed: _isDetectingLocation ? null : _detectLocation,
              icon: _isDetectingLocation
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.my_location),
              label: Text(
                _isDetectingLocation
                    ? (isHebrew ? 'מזהה...' : 'Detecting...')
                    : (isHebrew ? 'זהה מיקום אוטומטית' : 'Detect My Location'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A1A1A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            const SizedBox(height: 16),

            Text(
              isHebrew
                  ? 'או עבור להגדרות לבחירת מיקום ידנית'
                  : 'Or go to Settings to select location manually',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_available, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            isHebrew ? 'אין זמנים קרובים' : 'No upcoming times',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  /// Check if notifications need rescheduling
  /// Returns true if notifications are missing or don't match expected schedule
  /// Returns false if notifications are already properly scheduled
  Future<bool> _checkIfNotificationsNeedRescheduling(
    List<CandleLighting> expectedTimes,
  ) async {
    try {
      debugPrint('HomeTab: Checking if notifications need rescheduling...');

      // Get currently scheduled notifications/alarms
      List<Map<String, dynamic>> scheduledAlarms = [];

      if (Platform.isAndroid) {
        scheduledAlarms = await NativeAlarmService.getScheduledAlarms();
      } else {
        // For iOS, we'd need to check pending notifications
        // For now, just reschedule on iOS (simpler approach)
        debugPrint('HomeTab: iOS - always rescheduling for simplicity');
        return true;
      }

      // Filter out test notifications (996, 997, 998)
      final realAlarms = scheduledAlarms.where((alarm) {
        final id = alarm['id'] as int;
        return id != 996 && id != 997 && id != 998;
      }).toList();

      // Day-2 Yom Tov events get NO alarms (alarms allowed on Day 1 only).
      // Counting them here would inflate expectedCount, mask stale alarms left
      // over from older app versions, and cause the upgrade path to silently
      // keep ringing on Day 2.
      final scheduleableEvents = expectedTimes
          .take(10)
          .where((e) => !e.isSecondDayYomTov)
          .toList();

      debugPrint(
        'HomeTab: Found ${realAlarms.length} real alarms scheduled (excluding tests)',
      );
      debugPrint(
        'HomeTab: Expected ${scheduleableEvents.length * 2} alarms '
        '(pre + issur per non-Day-2 event; ${expectedTimes.take(10).length - scheduleableEvents.length} Day-2 events skipped)',
      );

      // Calculate expected number of alarms (pre-notification + issur melacha for each event)
      final expectedCount = scheduleableEvents.length * 2;

      // If count doesn't match, reschedule
      if (realAlarms.length != expectedCount) {
        debugPrint('HomeTab: Alarm count mismatch - need rescheduling');
        return true;
      }

      // Check if the scheduled times roughly match expected times
      // We'll check the first few alarms to see if they're scheduled correctly
      final now = DateTime.now();
      final preMinutes = await _notificationService.getPreNotificationMinutes();

      // Match against the first few non-Day-2 events; matching against Day-2
      // would expect alarms that we deliberately don't schedule.
      final eventsToVerify = scheduleableEvents.take(3).toList();
      for (int i = 0; i < eventsToVerify.length; i++) {
        final expectedPreTime = eventsToVerify[i].candleLightingTime.subtract(
          Duration(minutes: preMinutes),
        );
        final expectedCandleTime = eventsToVerify[i].candleLightingTime;

        // Skip if times are in the past
        if (expectedPreTime.isBefore(now)) continue;

        // Find alarms that match these times (within 5 minutes tolerance)
        final matchingPreAlarm = realAlarms.any((alarm) {
          final scheduledTime = DateTime.fromMillisecondsSinceEpoch(
            alarm['timestampMillis'] as int,
          );
          final diff = scheduledTime.difference(expectedPreTime).abs();
          return diff.inMinutes < 5;
        });

        final matchingCandleAlarm = realAlarms.any((alarm) {
          final scheduledTime = DateTime.fromMillisecondsSinceEpoch(
            alarm['timestampMillis'] as int,
          );
          final diff = scheduledTime.difference(expectedCandleTime).abs();
          return diff.inMinutes < 5;
        });

        if (!matchingPreAlarm || !matchingCandleAlarm) {
          debugPrint(
            'HomeTab: Alarm times don\'t match expected - need rescheduling',
          );
          return true;
        }
      }

      debugPrint(
        'HomeTab: Notifications are properly scheduled - no rescheduling needed',
      );
      return false;
    } catch (e) {
      debugPrint('HomeTab: Error checking notifications: $e');
      // On error, reschedule to be safe
      return true;
    }
  }
}
