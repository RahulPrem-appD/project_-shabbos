import 'package:flutter/material.dart';
import 'dart:async';
import '../models/city.dart';
import '../models/candle_lighting.dart';
import '../services/location_service.dart';
import '../services/notification_service.dart';
import 'upcoming_notifications_screen.dart';
import 'diagnostic_report_screen.dart';

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

  bool _useGps = true;
  LocationInfo? _savedLocation;
  bool _notificationsEnabled = true;

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

    setState(() {
      _useGps = useGps;
      _savedLocation = savedLocation;
      _notificationsEnabled = notificationsEnabled;
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
                      if (_notificationsEnabled)
                        _buildActionTile(
                          icon: Icons.schedule,
                          title: isHebrew
                              ? 'התראות קרובות'
                              : 'Upcoming Notifications',
                          subtitle: isHebrew
                              ? 'צפה בכל ההתראות המתוזמנות'
                              : 'View all scheduled notifications',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => UpcomingNotificationsScreen(
                                  locale: widget.locale,
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  ),

                  _buildSection(
                    title: isHebrew ? 'תמיכה' : 'Support',
                    children: [
                      _buildActionTile(
                        icon: Icons.bug_report,
                        title: isHebrew
                            ? 'דו״ח אבחון'
                            : 'Diagnostic Report',
                        subtitle: isHebrew
                            ? 'שתף מידע עם התמיכה'
                            : 'Share info with support',
                        onTap: _showDiagnosticReport,
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
          padding: EdgeInsetsDirectional.fromSTEB(4, 24, 4, 12),
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
            activeThumbColor: const Color(0xFFE8B923),
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
        padding: EdgeInsetsDirectional.fromSTEB(
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

  /// Show diagnostic report for debugging
  Future<void> _showDiagnosticReport() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DiagnosticReportScreen(locale: widget.locale),
      ),
    );
  }

  /// Check and request exact alarm permission (Android 12+)

  /// Check and request battery optimization exemption

  /// Reschedule all notifications with current settings
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
