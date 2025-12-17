import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'home_tab.dart';
import 'calendar_tab.dart';
import 'about_screen.dart';
import 'settings_screen.dart';
import '../services/notification_service.dart';
import '../services/native_alarm_service.dart';

class MainShell extends StatefulWidget {
  final String locale;
  final Function(String) onLocaleChanged;

  const MainShell({
    super.key,
    required this.locale,
    required this.onLocaleChanged,
  });

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  int _currentIndex = 0;

  // Key to force refresh of tabs when location changes
  Key _refreshKey = UniqueKey();

  bool get isHebrew => widget.locale == 'he';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Check permissions after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndRequestPermissions();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-check permissions when app resumes (user might have changed settings)
    if (state == AppLifecycleState.resumed) {
      _checkAndRequestPermissions();
    }
  }

  Future<void> _checkAndRequestPermissions() async {
    // Check notification permission
    final notificationStatus = await Permission.notification.status;

    // Check location permission
    final locationStatus = await Permission.locationWhenInUse.status;

    // Check exact alarm permission on Android
    bool exactAlarmGranted = true;
    if (Platform.isAndroid) {
      exactAlarmGranted = await NativeAlarmService.canScheduleExactAlarms();
    }

    debugPrint('MainShell: Notification permission: $notificationStatus');
    debugPrint('MainShell: Location permission: $locationStatus');
    debugPrint('MainShell: Exact alarm permission: $exactAlarmGranted');

    // If any critical permission is denied, show dialog
    if (notificationStatus.isDenied ||
        notificationStatus.isPermanentlyDenied ||
        locationStatus.isDenied ||
        locationStatus.isPermanentlyDenied ||
        !exactAlarmGranted) {
      if (mounted) {
        _showPermissionDialog(
          notificationGranted: notificationStatus.isGranted,
          locationGranted: locationStatus.isGranted,
          exactAlarmGranted: exactAlarmGranted,
        );
      }
    }
  }

  Future<void> _showPermissionDialog({
    required bool notificationGranted,
    required bool locationGranted,
    required bool exactAlarmGranted,
  }) async {
    final missingPermissions = <String>[];

    if (!notificationGranted) {
      missingPermissions.add(isHebrew ? '• התראות' : '• Notifications');
    }
    if (!locationGranted) {
      missingPermissions.add(isHebrew ? '• מיקום' : '• Location');
    }
    if (!exactAlarmGranted && Platform.isAndroid) {
      missingPermissions.add(isHebrew ? '• התראות מדויקות' : '• Exact Alarms');
    }

    if (missingPermissions.isEmpty) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: Color(0xFFE8B923),
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                isHebrew ? 'נדרשות הרשאות' : 'Permissions Required',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isHebrew
                  ? 'כדי לקבל התראות על זמני הדלקת נרות, האפליקציה צריכה את ההרשאות הבאות:'
                  : 'To receive candle lighting time notifications, the app needs the following permissions:',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            ...missingPermissions.map(
              (p) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  p,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isHebrew
                  ? 'האם לאפשר הרשאות אלה?'
                  : 'Would you like to enable these permissions?',
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              isHebrew ? 'אחר כך' : 'Later',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _requestAllPermissions(
                notificationGranted: notificationGranted,
                locationGranted: locationGranted,
                exactAlarmGranted: exactAlarmGranted,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A1A1A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(isHebrew ? 'אפשר' : 'Enable'),
          ),
        ],
      ),
    );
  }

  Future<void> _requestAllPermissions({
    required bool notificationGranted,
    required bool locationGranted,
    required bool exactAlarmGranted,
  }) async {
    // Request notification permission
    if (!notificationGranted) {
      final status = await Permission.notification.request();
      debugPrint('MainShell: Notification permission result: $status');

      if (status.isPermanentlyDenied) {
        _showOpenSettingsDialog(isHebrew ? 'התראות' : 'Notifications');
        return;
      }

      // Also request via NotificationService for iOS
      await NotificationService().requestPermissions();
    }

    // Request location permission
    if (!locationGranted) {
      final status = await Permission.locationWhenInUse.request();
      debugPrint('MainShell: Location permission result: $status');

      if (status.isPermanentlyDenied) {
        _showOpenSettingsDialog(isHebrew ? 'מיקום' : 'Location');
        return;
      }
    }

    // Request exact alarm permission on Android
    if (!exactAlarmGranted && Platform.isAndroid) {
      await NativeAlarmService.requestExactAlarmPermission();
    }

    // Show success message if all permissions are now granted
    final newNotifStatus = await Permission.notification.status;
    final newLocStatus = await Permission.locationWhenInUse.status;
    bool newExactAlarm = true;
    if (Platform.isAndroid) {
      newExactAlarm = await NativeAlarmService.canScheduleExactAlarms();
    }

    if (newNotifStatus.isGranted && newLocStatus.isGranted && newExactAlarm) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isHebrew ? '✓ כל ההרשאות אושרו!' : '✓ All permissions granted!',
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    }
  }

  void _showOpenSettingsDialog(String permissionName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          isHebrew ? 'נדרשת פעולה' : 'Action Required',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          isHebrew
              ? 'הרשאת $permissionName נדחתה לצמיתות. אנא אפשר אותה בהגדרות המכשיר.'
              : '$permissionName permission was permanently denied. Please enable it in device settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(isHebrew ? 'ביטול' : 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings();
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

  void _onLocationChanged() {
    setState(() {
      _refreshKey = UniqueKey();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: isHebrew ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: KeyedSubtree(
          key: _refreshKey,
          child: IndexedStack(
            index: _currentIndex,
            children: [
              HomeTab(
                locale: widget.locale,
                onLocaleChanged: widget.onLocaleChanged,
              ),
              CalendarTab(locale: widget.locale),
              AboutScreen(locale: widget.locale, showAppBar: false),
              SettingsScreen(
                locale: widget.locale,
                onLocaleChanged: widget.onLocaleChanged,
                onLocationChanged: _onLocationChanged,
                showAppBar: false,
              ),
            ],
          ),
        ),
        bottomNavigationBar: _buildBottomNavBar(),
      ),
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                index: 0,
                icon: Icons.home_outlined,
                activeIcon: Icons.home,
                label: isHebrew ? 'בית' : 'Home',
              ),
              _buildNavItem(
                index: 1,
                icon: Icons.calendar_month_outlined,
                activeIcon: Icons.calendar_month,
                label: isHebrew ? 'לוח שנה' : 'Calendar',
              ),
              _buildNavItem(
                index: 2,
                icon: Icons.info_outline,
                activeIcon: Icons.info,
                label: isHebrew ? 'אודות' : 'About',
              ),
              _buildNavItem(
                index: 3,
                icon: Icons.settings_outlined,
                activeIcon: Icons.settings,
                label: isHebrew ? 'הגדרות' : 'Settings',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
  }) {
    final isActive = _currentIndex == index;

    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF1A1A1A) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              size: 22,
              color: isActive ? const Color(0xFFE8B923) : Colors.grey[500],
            ),
            if (isActive) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
