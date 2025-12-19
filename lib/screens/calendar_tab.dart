import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../models/candle_lighting.dart';
import '../services/hebcal_service.dart';
import '../services/location_service.dart';
import 'candle_lighting_detail_screen.dart';

class CalendarTab extends StatefulWidget {
  final String locale;

  const CalendarTab({
    super.key,
    required this.locale,
  });

  @override
  State<CalendarTab> createState() => _CalendarTabState();
}

class _CalendarTabState extends State<CalendarTab> {
  final HebcalService _hebcalService = HebcalService();
  final LocationService _locationService = LocationService();

  DateTime _currentMonth = DateTime.now();
  List<CandleLighting> _events = [];
  LocationInfo? _location;
  bool _isLoading = true;
  String? _error;

  bool get isHebrew => widget.locale == 'he';

  @override
  void initState() {
    super.initState();
    _loadData();
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
        await _loadMonthData();
      } else {
        setState(() {
          _isLoading = false;
          _error = isHebrew ? 'נא לבחור מיקום בהגדרות' : 'Please select a location in Settings';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _loadMonthData() async {
    if (_location == null) return;

    setState(() => _isLoading = true);

    try {
      // Get events for current month and surrounding months
      final startDate = DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
      final endDate = DateTime(_currentMonth.year, _currentMonth.month + 2, 0);

      final events = await _hebcalService.getExtendedCandleLightingTimes(
        latitude: _location!.latitude,
        longitude: _location!.longitude,
        startDate: startDate,
        endDate: endDate,
        timezone: _location!.timezone,
      );

      setState(() {
        _events = events;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  void _previousMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
    });
    _loadMonthData();
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
    });
    _loadMonthData();
  }

  void _goToToday() {
    setState(() {
      _currentMonth = DateTime.now();
    });
    _loadMonthData();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFE8B923)))
          : _error != null
              ? _buildErrorState()
              : SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: [
                      _buildHeader(),
                      _buildCalendarContent(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isHebrew ? 'לוח שנה עברי' : 'Hebrew Calendar',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              if (_location != null)
                Row(
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
          ),
          Text(
            'בס״ד',
            style: TextStyle(fontSize: 14, color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarContent() {
    return Column(
      children: [
        _buildMonthNavigation(),
        _buildDayHeaders(),
        _buildCalendarGrid(),
        _buildEventsForSelectedMonth(),
      ],
    );
  }

  Widget _buildMonthNavigation() {
    final monthFormat = DateFormat('MMMM yyyy');
    final hebrewMonthFormat = DateFormat('MMMM yyyy', 'he');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: _previousMonth,
            icon: Icon(
              isHebrew ? Icons.chevron_right : Icons.chevron_left,
              color: const Color(0xFF1A1A1A),
            ),
          ),
          GestureDetector(
            onTap: _goToToday,
            child: Column(
              children: [
                Text(
                  isHebrew 
                      ? hebrewMonthFormat.format(_currentMonth)
                      : monthFormat.format(_currentMonth),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isHebrew ? 'לחץ לחזור להיום' : 'Tap to go to today',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _nextMonth,
            icon: Icon(
              isHebrew ? Icons.chevron_left : Icons.chevron_right,
              color: const Color(0xFF1A1A1A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayHeaders() {
    final dayLabels = isHebrew 
        ? ['א׳', 'ב׳', 'ג׳', 'ד׳', 'ה׳', 'ו׳', 'ש׳']
        : ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: dayLabels.map((day) {
          final isFriday = day == 'Fri' || day == 'ו׳';
          final isSaturday = day == 'Sat' || day == 'ש׳';
          return Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                day,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isFriday 
                      ? const Color(0xFFE8B923) 
                      : isSaturday 
                          ? const Color(0xFF5C6BC0)
                          : Colors.grey[500],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCalendarGrid() {
    final firstDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final lastDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
    
    int startWeekday = firstDayOfMonth.weekday % 7;
    final daysInMonth = lastDayOfMonth.day;
    final totalCells = ((startWeekday + daysInMonth) / 7).ceil() * 7;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 7,
          childAspectRatio: 1,
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
        ),
        itemCount: totalCells,
        itemBuilder: (context, index) {
          final dayNumber = index - startWeekday + 1;
          
          if (dayNumber < 1 || dayNumber > daysInMonth) {
            return const SizedBox();
          }
          
          final currentDate = DateTime(_currentMonth.year, _currentMonth.month, dayNumber);
          return _buildCalendarDay(currentDate, dayNumber);
        },
      ),
    );
  }

  Widget _buildCalendarDay(DateTime date, int dayNumber) {
    final now = DateTime.now();
    final isToday = date.year == now.year && date.month == now.month && date.day == now.day;
    
    // Check if this date has any events
    final dayEvents = _events.where((e) => _isSameDay(e.candleLightingTime, date)).toList();
    final hasEvent = dayEvents.isNotEmpty;
    final isShabbat = date.weekday == DateTime.saturday;
    final isFriday = date.weekday == DateTime.friday;
    
    // Check for candle lighting on Friday
    final hasCandleLighting = _events.any((e) => _isSameDay(e.candleLightingTime, date));
    // Check for havdalah on Saturday
    final hasHavdalah = _events.any((e) => e.havdalahTime != null && _isSameDay(e.havdalahTime!, date));
    
    // Check if it's a Yom Tov
    final yomTovEvent = _events.where((e) => 
      e.isYomTov && (_isSameDay(e.candleLightingTime, date) || 
      (e.havdalahTime != null && _isSameDay(e.havdalahTime!, date)))
    ).toList();
    final isYomTov = yomTovEvent.isNotEmpty;

    Color? bgColor;
    Color textColor = const Color(0xFF1A1A1A);
    BoxBorder? border;

    if (hasCandleLighting) {
      bgColor = const Color(0xFFE8B923);
      textColor = const Color(0xFF1A1A1A);
    } else if (hasHavdalah) {
      bgColor = const Color(0xFF5C6BC0);
      textColor = Colors.white;
    } else if (isYomTov) {
      bgColor = const Color(0xFFE8B923).withValues(alpha: 0.3);
    } else if (isShabbat) {
      bgColor = const Color(0xFF5C6BC0).withValues(alpha: 0.1);
    } else if (isFriday) {
      bgColor = const Color(0xFFE8B923).withValues(alpha: 0.1);
    }

    if (isToday) {
      border = Border.all(color: const Color(0xFF1A1A1A), width: 2);
    }

    return GestureDetector(
      onTap: () {
        if (dayEvents.isNotEmpty) {
          _openDetailScreen(dayEvents.first);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: border,
        ),
        child: Stack(
          children: [
            Center(
              child: Text(
                dayNumber.toString(),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: (hasCandleLighting || hasHavdalah || isToday) 
                      ? FontWeight.w700 
                      : FontWeight.w500,
                  color: textColor,
                ),
              ),
            ),
            if (hasEvent || isYomTov)
              Positioned(
                bottom: 4,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color: hasCandleLighting || hasHavdalah 
                          ? textColor.withValues(alpha: 0.7)
                          : const Color(0xFFE8B923),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventsForSelectedMonth() {
    final monthEvents = _events.where((e) => 
      e.candleLightingTime.year == _currentMonth.year && 
      e.candleLightingTime.month == _currentMonth.month
    ).toList();

    if (monthEvents.isEmpty) {
      return const SizedBox(height: 20);
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isHebrew ? 'אירועים החודש' : 'Events This Month',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 12),
          ...monthEvents.map((event) => _buildEventCard(event)),
        ],
      ),
    );
  }

  Widget _buildEventCard(CandleLighting event) {
    final timeFormat = DateFormat('h:mm a');
    final dateFormat = DateFormat('EEE, MMM d');

    return GestureDetector(
      onTap: () => _openDetailScreen(event),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: event.isYomTov 
              ? const Color(0xFFFFF8E1)
              : const Color(0xFFF8F8F8),
          borderRadius: BorderRadius.circular(16),
          border: event.isYomTov 
              ? Border.all(color: const Color(0xFFE8B923).withValues(alpha: 0.3))
              : null,
        ),
        child: Row(
          children: [
            // Left icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: event.isYomTov 
                    ? const Color(0xFFE8B923).withValues(alpha: 0.2)
                    : const Color(0xFFE8B923).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                event.isYomTov ? Icons.celebration : Icons.local_fire_department,
                size: 22,
                color: const Color(0xFFE8B923),
              ),
            ),
            const SizedBox(width: 14),
            // Event details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isHebrew ? event.hebrewDisplayName : event.displayName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dateFormat.format(event.candleLightingTime),
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            // Time on the right
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.local_fire_department, size: 14, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(
                      timeFormat.format(event.candleLightingTime),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFE8B923),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  isHebrew ? 'הדלקת נרות' : 'Candle lighting',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ],
        ),
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

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
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
            const SizedBox(height: 16),
            Text(
              isHebrew ? 'עבור להגדרות לבחירת מיקום' : 'Go to Settings to select a location',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }
}


