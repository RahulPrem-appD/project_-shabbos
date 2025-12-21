import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../models/candle_lighting.dart';
import '../services/hebcal_service.dart';
import '../services/location_service.dart';
import '../services/notification_service.dart';
import 'candle_lighting_detail_screen.dart';

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

class _HomeTabState extends State<HomeTab> {
  final HebcalService _hebcalService = HebcalService();
  final LocationService _locationService = LocationService();
  final NotificationService _notificationService = NotificationService();

  List<CandleLighting> _candleLightings = [];
  LocationInfo? _location;
  bool _isLoading = true;
  bool _isDetectingLocation = false;
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
              ? 'שירותי המיקום כבויים. אנא הפעל אותם בהגדרות.'
              : 'Location services are disabled. Please enable them in settings.';
        });
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
        );

        final futureTimes = times
            .where((t) => t.candleLightingTime.isAfter(now))
            .toList();

        setState(() {
          _candleLightings = futureTimes;
          _isLoading = false;
        });

        await _notificationService.scheduleNotifications(
          futureTimes.take(10).toList(),
        );

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
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isHebrew ? '!!שבת' : 'Shabbos!!',
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
                          Icon(
                            Icons.my_location,
                            size: 14,
                            color: Colors.grey[400],
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Text('בס״ד', style: TextStyle(fontSize: 14, color: Colors.grey[400])),
        ],
      ),
    );
  }

  void _openDetailScreen(CandleLighting lighting) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CandleLightingDetailScreen(
          lighting: lighting,
          locale: widget.locale,
          locationName: _location?.displayName,
        ),
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
          GestureDetector(
            onTap: () => _openDetailScreen(_candleLightings.first),
            child: _buildNextCandleLighting(_candleLightings.first),
          ),
          const SizedBox(height: 32),
          if (_candleLightings.length > 1) ...[
            Text(
              isHebrew ? 'קרוב' : 'Upcoming',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            ..._candleLightings
                .skip(1)
                .take(5)
                .map(
                  (lighting) => GestureDetector(
                    onTap: () => _openDetailScreen(lighting),
                    child: _buildUpcomingCard(lighting),
                  ),
                ),
          ],
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildNextCandleLighting(CandleLighting lighting) {
    final timeFormat = DateFormat('h:mm');
    final amPm = DateFormat('a').format(lighting.candleLightingTime);
    final dateFormat = DateFormat('EEEE, MMM d');

    final now = DateTime.now();
    final diff = lighting.candleLightingTime.difference(now);
    final days = diff.inDays;
    final hours = diff.inHours % 24;
    final minutes = diff.inMinutes % 60;

    String countdown;
    if (days > 0) {
      countdown = isHebrew ? '$days ימים' : '$days days';
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
            dateFormat.format(lighting.date),
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),

          const SizedBox(height: 28),

          Row(
            children: [
              _buildTimeDisplay(
                icon: Icons.local_fire_department,
                iconColor: const Color(0xFFE8B923),
                label: isHebrew ? 'הדלקת נרות' : 'Candle Lighting',
                time: timeFormat.format(lighting.candleLightingTime),
                amPm: amPm,
              ),
              if (lighting.havdalahTime != null) ...[
                const SizedBox(width: 32),
                _buildTimeDisplay(
                  icon: Icons.nightlight_round,
                  iconColor: Colors.white.withValues(alpha: 0.5),
                  label: isHebrew ? 'הבדלה' : 'Havdalah',
                  time: timeFormat.format(lighting.havdalahTime!),
                  amPm: DateFormat('a').format(lighting.havdalahTime!),
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
    required String amPm,
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
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              time,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                height: 1,
              ),
            ),
            const SizedBox(width: 4),
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                amPm,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildUpcomingCard(CandleLighting lighting) {
    final timeFormat = DateFormat('h:mm a');
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
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A1A1A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
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
}
