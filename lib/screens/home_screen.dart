import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../models/candle_lighting.dart';
import '../services/hebcal_service.dart';
import '../services/location_service.dart';
import '../services/notification_service.dart';
import 'settings_screen.dart';
import 'about_screen.dart';

class HomeScreen extends StatefulWidget {
  final String locale;
  final Function(String) onLocaleChanged;

  const HomeScreen({
    super.key,
    required this.locale,
    required this.onLocaleChanged,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final HebcalService _hebcalService = HebcalService();
  final LocationService _locationService = LocationService();
  final NotificationService _notificationService = NotificationService();

  List<CandleLighting> _candleLightings = [];
  LocationInfo? _location;
  bool _isLoading = true;
  String? _error;

  bool get isHebrew => widget.locale == 'he';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _notificationService.initialize();
    await _loadData();
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
          locale: widget.locale,
        );

        final futureTimes = times.where((t) => t.candleLightingTime.isAfter(now)).toList();

        setState(() {
          _candleLightings = futureTimes;
          _isLoading = false;
        });

        await _notificationService.scheduleNotifications(
          futureTimes.take(10).toList(),
          locale: widget.locale,
        );
      } else {
        setState(() {
          _isLoading = false;
          _error = isHebrew ? 'נא לבחור מיקום' : 'Please select a location';
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
    return Directionality(
      textDirection: isHebrew ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final titleColumn = Column(
      crossAxisAlignment: isHebrew ? CrossAxisAlignment.end : CrossAxisAlignment.start,
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
          Row(
            mainAxisSize: MainAxisSize.min,
            textDirection: isHebrew ? TextDirection.rtl : TextDirection.ltr,
            children: [
              Icon(Icons.location_on_outlined, size: 14, color: Colors.grey[500]),
              const SizedBox(width: 4),
              Text(
                _location!.displayName,
                style: TextStyle(fontSize: 13, color: Colors.grey[500]),
              ),
            ],
          ),
      ],
    );

    final iconsRow = Row(
      textDirection: isHebrew ? TextDirection.rtl : TextDirection.ltr,
      children: [
        Text(
          'בס״ד',
          style: TextStyle(fontSize: 14, color: Colors.grey[400]),
        ),
        const SizedBox(width: 16),
        _buildIconButton(Icons.settings_outlined, () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SettingsScreen(
                locale: widget.locale,
                onLocaleChanged: widget.onLocaleChanged,
                onLocationChanged: _loadData,
              ),
            ),
          );
        }),
        const SizedBox(width: 8),
        _buildIconButton(Icons.info_outline, () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => AboutScreen(locale: widget.locale)),
          );
        }),
      ],
    );

    return Container(
      padding: EdgeInsetsDirectional.fromSTEB(24, 16, 24, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        textDirection: isHebrew ? TextDirection.rtl : TextDirection.ltr,
        children: isHebrew
            ? [iconsRow, titleColumn] // RTL: icons on left, title on right
            : [titleColumn, iconsRow], // LTR: title on left, icons on right
      ),
    );
  }

  Widget _buildIconButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, size: 20, color: const Color(0xFF1A1A1A)),
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
          const SizedBox(height: 24),
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
            ..._candleLightings.skip(1).take(5).map((lighting) => 
              _buildUpcomingCard(lighting),
            ),
          ],
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildNextCandleLighting(CandleLighting lighting) {
    final timeFormat = DateFormat('h:mm a'); // 12-hour format with AM/PM
    final dateFormat = DateFormat('EEEE, MMM d');
    
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
      countdown = isHebrew ? '$hours שעות $minutes דק\'' : '${hours}h ${minutes}m';
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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                  Icon(Icons.schedule, size: 14, color: Colors.white.withValues(alpha: 0.5)),
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
            dateFormat.format(lighting.date),
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
          
          if (lighting.hebrewParasha != null && lighting.isShabbat) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                textDirection: isHebrew ? TextDirection.rtl : TextDirection.ltr,
                children: [
                  Icon(
                    Icons.menu_book,
                    size: 14,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      isHebrew 
                          ? 'פרשת השבוע: ${lighting.hebrewParasha}'
                          : 'Parshat Shevua: ${lighting.parasha ?? lighting.hebrewParasha}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w500,
                      ),
                      textDirection: isHebrew ? TextDirection.rtl : TextDirection.ltr,
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          const SizedBox(height: 28),
          
          Row(
            children: [
              _buildTimeDisplay(
                icon: Icons.local_fire_department,
                iconColor: const Color(0xFFE8B923),
                label: isHebrew ? 'הדלקת נרות' : 'Candle Lighting',
                time: timeFormat.format(lighting.candleLightingTime),
              ),
              if (lighting.havdalahTime != null) ...[
                const SizedBox(width: 32),
                _buildTimeDisplay(
                  icon: Icons.nightlight_round,
                  iconColor: Colors.white.withValues(alpha: 0.5),
                  label: isHebrew ? 'הבדלה' : 'Havdalah',
                  time: timeFormat.format(lighting.havdalahTime!),
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
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          time,
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            height: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildUpcomingCard(CandleLighting lighting) {
    final timeFormat = DateFormat('h:mm a'); // 12-hour format with AM/PM
    final dateFormat = DateFormat('EEE, MMM d');

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
              lighting.isYomTov ? Icons.celebration : Icons.local_fire_department,
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
                  dateFormat.format(lighting.date),
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
            Icon(Icons.location_off_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 24),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SettingsScreen(
                      locale: widget.locale,
                      onLocaleChanged: widget.onLocaleChanged,
                      onLocationChanged: _loadData,
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A1A1A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(isHebrew ? 'בחר מיקום' : 'Select Location'),
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
}
