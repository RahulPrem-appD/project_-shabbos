import 'package:flutter/material.dart';
import '../models/city.dart';
import '../models/candle_lighting.dart';
import '../services/location_service.dart';
import '../services/notification_service.dart';
import '../services/audio_service.dart';
import '../services/hebcal_service.dart';
import 'sound_screen.dart';

class SettingsScreen extends StatefulWidget {
  final String locale;
  final Function(String) onLocaleChanged;
  final VoidCallback onLocationChanged;
  final bool showAppBar;

  const SettingsScreen({
    super.key,
    required this.locale,
    required this.onLocaleChanged,
    required this.onLocationChanged,
    this.showAppBar = true,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final LocationService _locationService = LocationService();
  final NotificationService _notificationService = NotificationService();
  final AudioService _audioService = AudioService();
  final HebcalService _hebcalService = HebcalService();

  bool _useGps = true;
  LocationInfo? _savedLocation;
  bool _notificationsEnabled = true;
  int _preMinutes = 20;
  bool _candleNotificationEnabled = true;
  String _preSound = 'default';
  String _candleSound = 'default';

  bool get isHebrew => widget.locale == 'he';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final useGps = await _locationService.getUseGps();
    final savedLocation = await _locationService.getSavedLocation();
    final notificationsEnabled = await _notificationService
        .getNotificationsEnabled();
    final preMinutes = await _notificationService.getPreNotificationMinutes();
    final candleEnabled = await _notificationService
        .getCandleNotificationEnabled();
    final preSound = await _audioService.getEarlyReminderSound();
    final candleSound = _audioService.getCandleLightingSound();

    setState(() {
      _useGps = useGps;
      _savedLocation = savedLocation;
      _notificationsEnabled = notificationsEnabled;
      _preMinutes = preMinutes;
      _candleNotificationEnabled = candleEnabled;
      _preSound = preSound;
      _candleSound = candleSound;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: isHebrew ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: widget.showAppBar
            ? AppBar(
                backgroundColor: Colors.white,
                elevation: 0,
                surfaceTintColor: Colors.transparent,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A1A)),
                  onPressed: () => Navigator.pop(context),
                ),
                title: Text(
                  isHebrew ? 'הגדרות' : 'Settings',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              )
            : null,
        body: Column(
          children: [
            if (!widget.showAppBar) _buildHeader(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                children: [
                  _buildSection(
                    title: isHebrew ? 'שפה' : 'Language',
                    children: [_buildLanguageSelector()],
                  ),

                  _buildSection(
                    title: isHebrew ? 'מיקום' : 'Location',
                    children: [
                      _buildSwitchTile(
                        icon: Icons.gps_fixed,
                        title: isHebrew ? 'מיקום אוטומטי' : 'Auto Location',
                        subtitle: isHebrew ? 'השתמש ב-GPS' : 'Use GPS',
                        value: _useGps,
                        onChanged: _onGpsChanged,
                      ),
                      _buildActionTile(
                        icon: Icons.location_city,
                        title: isHebrew ? 'בחר עיר' : 'Select City',
                        subtitle: _savedLocation?.displayName,
                        onTap: _showCityPicker,
                      ),
                    ],
                  ),

                  _buildSection(
                    title: isHebrew ? 'התראות' : 'Notifications',
                    children: [
                      _buildSwitchTile(
                        icon: Icons.notifications_outlined,
                        title: isHebrew
                            ? 'הפעל התראות'
                            : 'Enable Notifications',
                        value: _notificationsEnabled,
                        onChanged: _onNotificationsChanged,
                      ),
                      if (_notificationsEnabled) ...[
                        _buildTimePicker(),
                        _buildSwitchTile(
                          icon: Icons.local_fire_department,
                          title: isHebrew ? 'בזמן הדלקה' : 'At Candle Lighting',
                          subtitle: isHebrew
                              ? 'התראה בזמן ההדלקה'
                              : 'Notification at lighting time',
                          value: _candleNotificationEnabled,
                          onChanged: _onCandleNotificationChanged,
                        ),
                        _buildActionTile(
                          icon: Icons.play_circle_outline,
                          title: isHebrew ? 'בדוק התראה' : 'Test Notification',
                          subtitle: isHebrew
                              ? 'התראה מיידית'
                              : 'Immediate notification',
                          onTap: _testNotification,
                        ),
                        _buildActionTile(
                          icon: Icons.schedule_send,
                          title: isHebrew
                              ? 'בדוק התראה מתוזמנת'
                              : 'Test Scheduled Notification',
                          subtitle: isHebrew
                              ? 'התראה בעוד 10 שניות (סגור את האפליקציה)'
                              : 'Notification in 10 seconds (close app)',
                          onTap: _testDelayedNotification,
                        ),
                      ],
                    ],
                  ),

                  _buildSection(
                    title: isHebrew ? 'צלילים' : 'Sounds',
                    children: [
                      _buildActionTile(
                        icon: Icons.music_note,
                        title: isHebrew
                            ? 'צליל תזכורת מוקדמת'
                            : 'Early Reminder Sound',
                        subtitle: _getSoundName(_preSound),
                        onTap: () => _openSoundScreen(),
                      ),
                      _buildActionTile(
                        icon: Icons.notifications_active,
                        title: isHebrew
                            ? 'צליל הדלקת נרות'
                            : 'Candle Lighting Sound',
                        subtitle: _getSoundName(_candleSound),
                        onTap: () => _openSoundScreen(),
                      ),
                    ],
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 24, 4, 12),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey[500],
              letterSpacing: 1,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8F8F8),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              for (int i = 0; i < children.length; i++) ...[
                children[i],
                if (i < children.length - 1)
                  Divider(height: 1, indent: 56, color: Colors.grey[200]),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: const Color(0xFF1A1A1A)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                  ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFFE8B923),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: const Color(0xFF1A1A1A)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                    ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.language,
              size: 20,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isHebrew ? 'שפה' : 'Language',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1A1A1A),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButton<String>(
              value: widget.locale,
              underline: const SizedBox(),
              isDense: true,
              items: const [
                DropdownMenuItem(value: 'en', child: Text('English')),
                DropdownMenuItem(value: 'he', child: Text('עברית')),
              ],
              onChanged: (value) {
                if (value != null) widget.onLocaleChanged(value);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimePicker() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.timer_outlined,
              size: 20,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isHebrew ? 'תזכורת מוקדמת' : 'Early Reminder',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                Text(
                  isHebrew
                      ? '$_preMinutes דקות לפני'
                      : '$_preMinutes min before',
                  style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButton<int>(
              value: _preMinutes,
              underline: const SizedBox(),
              isDense: true,
              items: [20, 40, 60].map((m) {
                return DropdownMenuItem(value: m, child: Text('$m'));
              }).toList(),
              onChanged: (value) async {
                if (value != null) {
                  setState(() => _preMinutes = value);
                  await _notificationService.setPreNotificationMinutes(value);
                  await _rescheduleNotifications();
                  widget.onLocationChanged();
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  void _onGpsChanged(bool value) async {
    setState(() => _useGps = value);
    await _locationService.setUseGps(value);
    if (value) {
      final hasPermission = await _locationService.hasLocationPermission();
      if (!hasPermission) {
        await _locationService.requestLocationPermission();
      }
      final location = await _locationService.getCurrentLocation();
      if (location != null) {
        await _locationService.saveLocation(location);
        setState(() => _savedLocation = location);
        widget.onLocationChanged();
      }
    }
  }

  void _onNotificationsChanged(bool value) async {
    if (value) {
      final granted = await _notificationService.requestPermissions();
      if (!granted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isHebrew
                  ? 'נא לאפשר התראות בהגדרות'
                  : 'Please enable notifications in settings',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
    setState(() => _notificationsEnabled = value);
    await _notificationService.setNotificationsEnabled(value);
    widget.onLocationChanged();
  }

  void _onCandleNotificationChanged(bool value) async {
    setState(() => _candleNotificationEnabled = value);
    await _notificationService.setCandleNotificationEnabled(value);
    widget.onLocationChanged();
  }

  void _testNotification() async {
    // Send the notification
    await _notificationService.sendTestNotification();

    // Play the selected sound
    final soundId = _audioService.getCandleLightingSound();
    if (soundId != 'default' && soundId != 'silent') {
      await _audioService.playSound(soundId);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isHebrew ? 'התראה נשלחה!' : 'Notification sent!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _testDelayedNotification() async {
    // Schedule the full candle lighting test flow:
    // - Pre-notification (with countdown) in 10 seconds
    // - Candle lighting notification in 70 seconds (60 seconds after early reminder)
    // iOS needs 60 second gap so the 30-second sound can finish playing
    await _notificationService.sendDelayedTestNotification(
      preNotificationSeconds: 10,
      candleLightingSeconds: 70,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isHebrew
                    ? '🕯️ בדיקת זרימת הדלקת נרות'
                    : '🕯️ Testing Candle Lighting Flow',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                isHebrew
                    ? '• תזכורת מוקדמת (עם ספירה לאחור): 10 שניות\n• התראת הדלקת נרות: 70 שניות\n\nסגור את האפליקציה לבדיקה!'
                    : '• Early reminder (with countdown): 10 sec\n• Candle lighting alert: 70 sec\n\nClose the app to test!',
                style: const TextStyle(fontSize: 13),
              ),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 8),
          backgroundColor: const Color(0xFF1A1A1A),
          action: SnackBarAction(
            label: isHebrew ? 'הבנתי' : 'OK',
            textColor: const Color(0xFFE8B923),
            onPressed: () {},
          ),
        ),
      );
    }
  }

  String _getSoundName(String soundId) {
    // Find sound in all available sounds
    final sound = SoundOption.findById(soundId);
    if (sound != null) {
      return isHebrew ? sound.nameHe : sound.nameEn;
    }
    // Default fallback
    return isHebrew ? 'ברירת מחדל' : 'System Default';
  }

  void _openSoundScreen() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SoundScreen(locale: widget.locale)),
    );
    // Reload settings after returning
    _loadSettings();
  }

  void _showCityPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CityPicker(
        isHebrew: isHebrew,
        onSelected: (city) async {
          final location = _locationService.locationFromCity(city);
          await _locationService.saveLocation(location);
          await _locationService.setUseGps(false);
          setState(() {
            _savedLocation = location;
            _useGps = false;
          });
          widget.onLocationChanged();
          if (context.mounted) Navigator.pop(context);
        },
      ),
    );
  }

  Widget _buildHeader() {
    return Builder(
      builder: (context) => Container(
        padding: EdgeInsets.fromLTRB(
          24,
          MediaQuery.of(context).padding.top + 16,
          24,
          8,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isHebrew ? 'הגדרות' : 'Settings',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A1A),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Reschedule all notifications with current settings
  Future<void> _rescheduleNotifications() async {
    try {
      debugPrint('SettingsScreen: Rescheduling notifications...');

      // Get current location
      final location = await _locationService.getSavedLocation();
      if (location == null) {
        debugPrint('SettingsScreen: No location saved, skipping reschedule');
        return;
      }

      // Calculate date range (today + 30 days)
      final now = DateTime.now();
      final startDate = DateTime(now.year, now.month, now.day);
      final endDate = startDate.add(const Duration(days: 30));

      // Fetch candle lighting times
      final times = await _hebcalService.getExtendedCandleLightingTimes(
        latitude: location.latitude,
        longitude: location.longitude,
        startDate: startDate,
        endDate: endDate,
        locale: widget.locale,
      );

      final futureTimes = times
          .where((t) => t.candleLightingTime.isAfter(now))
          .toList();

      if (futureTimes.isEmpty) {
        debugPrint('SettingsScreen: No future times, skipping reschedule');
        return;
      }

      // Reschedule with new settings
      await _notificationService.rescheduleAllNotifications(
        futureTimes.take(10).toList(),
      );

      debugPrint('SettingsScreen: Notifications rescheduled successfully');
    } catch (e) {
      debugPrint('SettingsScreen: Error rescheduling: $e');
    }
  }
}

class _CityPicker extends StatefulWidget {
  final bool isHebrew;
  final Function(City) onSelected;

  const _CityPicker({required this.isHebrew, required this.onSelected});

  @override
  State<_CityPicker> createState() => _CityPickerState();
}

class _CityPickerState extends State<_CityPicker> {
  String _query = '';

  List<City> get _filtered {
    if (_query.isEmpty) return City.majorCities;
    final q = _query.toLowerCase();
    return City.majorCities
        .where(
          (c) =>
              c.name.toLowerCase().contains(q) ||
              c.hebrewName.contains(_query) ||
              c.country.toLowerCase().contains(q),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: TextField(
              decoration: InputDecoration(
                hintText: widget.isHebrew ? 'חפש עיר...' : 'Search city...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: const Color(0xFFF5F5F5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _filtered.length,
              itemBuilder: (context, index) {
                final city = _filtered[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFFF5F5F5),
                    child: Text(
                      city.name[0],
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                  ),
                  title: Text(widget.isHebrew ? city.hebrewName : city.name),
                  subtitle: Text(city.country),
                  onTap: () => widget.onSelected(city),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
