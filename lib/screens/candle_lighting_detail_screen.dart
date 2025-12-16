import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../models/candle_lighting.dart';

class CandleLightingDetailScreen extends StatelessWidget {
  final CandleLighting lighting;
  final String locale;
  final String? locationName;

  const CandleLightingDetailScreen({
    super.key,
    required this.lighting,
    required this.locale,
    this.locationName,
  });

  bool get isHebrew => locale == 'he';

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: isHebrew ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: CustomScrollView(
          slivers: [
            _buildAppBar(context),
            SliverToBoxAdapter(
              child: _buildContent(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      backgroundColor: const Color(0xFF1A1A1A),
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
        ),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Center(
            child: Text(
              'בס״ד',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: _buildHeroSection(),
      ),
    );
  }

  Widget _buildHeroSection() {
    final dateFormat = DateFormat('EEEE');
    final fullDateFormat = DateFormat('MMMM d, yyyy');
    final hebrewDateFormat = DateFormat('d בMMMM, yyyy', 'he');

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF2D2D2D),
            Color(0xFF1A1A1A),
          ],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Event type badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8B923),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      lighting.isYomTov ? Icons.celebration : Icons.local_fire_department,
                      size: 16,
                      color: const Color(0xFF1A1A1A),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      lighting.isYomTov
                          ? (isHebrew ? 'יום טוב' : 'Yom Tov')
                          : (isHebrew ? 'שבת' : 'Shabbat'),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1A1A),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Holiday/Event name
              Text(
                isHebrew ? lighting.hebrewDisplayName : lighting.displayName,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 1.2,
                ),
              ),

              const SizedBox(height: 8),

              // Date
              Text(
                isHebrew
                    ? hebrewDateFormat.format(lighting.date)
                    : '${dateFormat.format(lighting.date)}, ${fullDateFormat.format(lighting.date)}',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),

              if (locationName != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 16,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      locationName!,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Calendar section
          _buildSectionTitle(isHebrew ? 'לוח שנה' : 'Calendar'),
          const SizedBox(height: 16),
          _buildCalendarCard(),

          const SizedBox(height: 32),

          // Times section
          _buildSectionTitle(isHebrew ? 'זמנים' : 'Times'),
          const SizedBox(height: 16),
          _buildTimesCard(),

          const SizedBox(height: 32),

          // Countdown section
          _buildSectionTitle(isHebrew ? 'ספירה לאחור' : 'Countdown'),
          const SizedBox(height: 16),
          _buildCountdownCard(),

          const SizedBox(height: 32),

          // Details section
          _buildSectionTitle(isHebrew ? 'פרטים' : 'Details'),
          const SizedBox(height: 16),
          _buildDetailsCard(),

          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildCalendarCard() {
    final eventDate = lighting.candleLightingTime;
    final havdalahDate = lighting.havdalahTime;
    
    // Get the first day of the month
    final firstDayOfMonth = DateTime(eventDate.year, eventDate.month, 1);
    final lastDayOfMonth = DateTime(eventDate.year, eventDate.month + 1, 0);
    
    // Get the weekday of the first day (0 = Sunday in our calendar)
    int startWeekday = firstDayOfMonth.weekday % 7; // Convert Monday=1 to Sunday=0
    
    // Calculate total cells needed
    final daysInMonth = lastDayOfMonth.day;
    
    // Day labels
    final dayLabels = isHebrew 
        ? ['א׳', 'ב׳', 'ג׳', 'ד׳', 'ה׳', 'ו׳', 'ש׳']
        : ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          // Month and Year header
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                DateFormat('MMMM yyyy').format(eventDate),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 20),
          
          // Day labels row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: dayLabels.map((day) {
              final isFriday = day == 'Fri' || day == 'ו׳';
              final isSaturday = day == 'Sat' || day == 'ש׳';
              return SizedBox(
                width: 36,
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
              );
            }).toList(),
          ),
          
          const SizedBox(height: 12),
          
          // Calendar grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
            ),
            itemCount: ((startWeekday + daysInMonth) / 7).ceil() * 7,
            itemBuilder: (context, index) {
              final dayNumber = index - startWeekday + 1;
              
              if (dayNumber < 1 || dayNumber > daysInMonth) {
                return const SizedBox();
              }
              
              final currentDate = DateTime(eventDate.year, eventDate.month, dayNumber);
              final isToday = _isSameDay(currentDate, DateTime.now());
              final isCandleLighting = _isSameDay(currentDate, eventDate);
              final isHavdalah = havdalahDate != null && _isSameDay(currentDate, havdalahDate);
              final isShabbatDay = isCandleLighting || isHavdalah || 
                  (havdalahDate != null && 
                   currentDate.isAfter(DateTime(eventDate.year, eventDate.month, eventDate.day)) &&
                   currentDate.isBefore(DateTime(havdalahDate.year, havdalahDate.month, havdalahDate.day)));
              
              return _buildCalendarDay(
                day: dayNumber,
                isToday: isToday,
                isCandleLighting: isCandleLighting,
                isHavdalah: isHavdalah,
                isShabbatDay: isShabbatDay,
              );
            },
          ),
          
          const SizedBox(height: 16),
          
          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem(
                color: const Color(0xFFE8B923),
                label: isHebrew ? 'הדלקת נרות' : 'Candle Lighting',
              ),
              const SizedBox(width: 20),
              _buildLegendItem(
                color: const Color(0xFF5C6BC0),
                label: isHebrew ? 'הבדלה' : 'Havdalah',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarDay({
    required int day,
    required bool isToday,
    required bool isCandleLighting,
    required bool isHavdalah,
    required bool isShabbatDay,
  }) {
    Color? bgColor;
    Color textColor = const Color(0xFF1A1A1A);
    BoxBorder? border;
    
    if (isCandleLighting) {
      bgColor = const Color(0xFFE8B923);
      textColor = const Color(0xFF1A1A1A);
    } else if (isHavdalah) {
      bgColor = const Color(0xFF5C6BC0);
      textColor = Colors.white;
    } else if (isShabbatDay) {
      bgColor = const Color(0xFFE8B923).withValues(alpha: 0.15);
    }
    
    if (isToday && !isCandleLighting && !isHavdalah) {
      border = Border.all(color: const Color(0xFF1A1A1A), width: 2);
    }

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: border,
      ),
      child: Center(
        child: Text(
          day.toString(),
          style: TextStyle(
            fontSize: 14,
            fontWeight: (isCandleLighting || isHavdalah || isToday) 
                ? FontWeight.w700 
                : FontWeight.w500,
            color: textColor,
          ),
        ),
      ),
    );
  }

  Widget _buildLegendItem({required Color color, required String label}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: Colors.grey[500],
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildTimesCard() {
    final timeFormat = DateFormat('h:mm');

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          // Candle Lighting Time
          _buildTimeRow(
            icon: Icons.local_fire_department,
            iconColor: const Color(0xFFE8B923),
            iconBgColor: const Color(0xFFFFF8E1),
            label: isHebrew ? 'הדלקת נרות' : 'Candle Lighting',
            time: timeFormat.format(lighting.candleLightingTime),
            amPm: DateFormat('a').format(lighting.candleLightingTime),
            date: DateFormat('EEE, MMM d').format(lighting.candleLightingTime),
          ),

          if (lighting.havdalahTime != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Row(
                children: [
                  const SizedBox(width: 24),
                  Container(
                    width: 2,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          const Color(0xFFE8B923).withValues(alpha: 0.5),
                          Colors.grey.withValues(alpha: 0.3),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Container(
                      height: 1,
                      color: Colors.grey.withValues(alpha: 0.2),
                    ),
                  ),
                ],
              ),
            ),

            // Havdalah Time
            _buildTimeRow(
              icon: Icons.nightlight_round,
              iconColor: const Color(0xFF5C6BC0),
              iconBgColor: const Color(0xFFE8EAF6),
              label: isHebrew ? 'הבדלה' : 'Havdalah',
              time: timeFormat.format(lighting.havdalahTime!),
              amPm: DateFormat('a').format(lighting.havdalahTime!),
              date: DateFormat('EEE, MMM d').format(lighting.havdalahTime!),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTimeRow({
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String label,
    required String time,
    required String amPm,
    required String date,
  }) {
    return Row(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: iconBgColor,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: iconColor, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                date,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[400],
                ),
              ),
            ],
          ),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              time,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A1A),
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
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[500],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCountdownCard() {
    final now = DateTime.now();
    final diff = lighting.candleLightingTime.difference(now);

    final isPast = diff.isNegative;
    final days = diff.inDays.abs();
    final hours = (diff.inHours % 24).abs();
    final minutes = (diff.inMinutes % 60).abs();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: isPast
            ? const LinearGradient(
                colors: [Color(0xFFF5F5F5), Color(0xFFEEEEEE)],
              )
            : const LinearGradient(
                colors: [Color(0xFF1A1A1A), Color(0xFF2D2D2D)],
              ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          if (isPast)
            Text(
              isHebrew ? 'עבר' : 'Past Event',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            )
          else ...[
            Text(
              isHebrew ? 'זמן שנותר' : 'Time Remaining',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildCountdownUnit(
                  value: days,
                  label: isHebrew ? 'ימים' : 'Days',
                  isPast: isPast,
                ),
                _buildCountdownDivider(isPast),
                _buildCountdownUnit(
                  value: hours,
                  label: isHebrew ? 'שעות' : 'Hours',
                  isPast: isPast,
                ),
                _buildCountdownDivider(isPast),
                _buildCountdownUnit(
                  value: minutes,
                  label: isHebrew ? 'דקות' : 'Minutes',
                  isPast: isPast,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCountdownUnit({
    required int value,
    required String label,
    required bool isPast,
  }) {
    return Column(
      children: [
        Text(
          value.toString().padLeft(2, '0'),
          style: TextStyle(
            fontSize: 42,
            fontWeight: FontWeight.w700,
            color: isPast ? Colors.grey[400] : Colors.white,
            height: 1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isPast ? Colors.grey[500] : Colors.white.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildCountdownDivider(bool isPast) {
    return Text(
      ':',
      style: TextStyle(
        fontSize: 36,
        fontWeight: FontWeight.w300,
        color: isPast ? Colors.grey[300] : Colors.white.withValues(alpha: 0.3),
      ),
    );
  }

  Widget _buildDetailsCard() {
    final duration = lighting.havdalahTime?.difference(lighting.candleLightingTime);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          _buildDetailRow(
            icon: Icons.event,
            label: isHebrew ? 'סוג' : 'Type',
            value: lighting.isYomTov
                ? (isHebrew ? 'יום טוב' : 'Yom Tov')
                : (isHebrew ? 'שבת' : 'Shabbat'),
          ),
          _buildDetailDivider(),
          _buildDetailRow(
            icon: Icons.calendar_today,
            label: isHebrew ? 'תאריך' : 'Date',
            value: DateFormat('MMMM d, yyyy').format(lighting.date),
          ),
          if (duration != null) ...[
            _buildDetailDivider(),
            _buildDetailRow(
              icon: Icons.timelapse,
              label: isHebrew ? 'משך' : 'Duration',
              value: isHebrew
                  ? '${duration.inHours} שעות'
                  : '${duration.inHours} hours',
            ),
          ],
          if (lighting.holidayName != null &&
              lighting.holidayName!.isNotEmpty &&
              lighting.holidayName != 'Shabbat') ...[
            _buildDetailDivider(),
            _buildDetailRow(
              icon: Icons.celebration,
              label: isHebrew ? 'חג' : 'Holiday',
              value: isHebrew
                  ? (lighting.hebrewHolidayName ?? lighting.holidayName!)
                  : lighting.holidayName!,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
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
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ),
          Text(
            value,
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

  Widget _buildDetailDivider() {
    return Divider(
      height: 1,
      indent: 56,
      color: Colors.grey[200],
    );
  }
}

