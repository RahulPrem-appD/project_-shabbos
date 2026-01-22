import 'package:flutter/material.dart';
import '../services/notification_service.dart';
import 'dart:async';

class UpcomingNotificationsScreen extends StatefulWidget {
  final String locale;

  const UpcomingNotificationsScreen({
    super.key,
    required this.locale,
  });

  @override
  State<UpcomingNotificationsScreen> createState() => _UpcomingNotificationsScreenState();
}

class _UpcomingNotificationsScreenState extends State<UpcomingNotificationsScreen> {
  final NotificationService _notificationService = NotificationService();
  List<UpcomingNotification> _notifications = [];
  bool _isLoading = true;
  Timer? _countdownTimer;

  bool get isHebrew => widget.locale == 'he';

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    // Update countdown every second
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {}); // Trigger rebuild to update countdown
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Request more notifications to ensure all types are shown
      // (pre-notification, candle lighting, issur melacha)
      final notifications = await _notificationService.getUpcomingNotifications(limit: 20);
      debugPrint('UpcomingNotificationsScreen: Loaded ${notifications.length} notifications');
      for (final n in notifications) {
        debugPrint('  - ${n.id}: ${n.title} (isPre=${n.isPreNotification}) at ${n.scheduledTime}');
      }
      if (mounted) {
        setState(() {
          _notifications = notifications;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('UpcomingNotificationsScreen: Error loading notifications: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _formatTimeUntil(Duration duration) {
    final isPast = duration.isNegative;
    final absDuration = duration.abs();
    final days = absDuration.inDays;
    final hours = absDuration.inHours.remainder(24);
    final minutes = absDuration.inMinutes.remainder(60);
    final seconds = absDuration.inSeconds.remainder(60);

    if (isPast) {
      return isHebrew ? 'עבר' : 'Past';
    }

    if (days > 0) {
      return isHebrew
          ? '$days ימים, $hours שעות'
          : '$days days, $hours hours';
    } else if (hours > 0) {
      return isHebrew
          ? '$hours שעות, $minutes דקות'
          : '$hours hours, $minutes minutes';
    } else if (minutes > 0) {
      return isHebrew
          ? '$minutes דקות, $seconds שניות'
          : '$minutes minutes, $seconds seconds';
    } else {
      return isHebrew
          ? '$seconds שניות'
          : '$seconds seconds';
    }
  }

  String _formatScheduledTime(DateTime scheduledTime) {
    final now = DateTime.now();
    final isToday = scheduledTime.year == now.year &&
                    scheduledTime.month == now.month &&
                    scheduledTime.day == now.day;
    
    if (isToday) {
      final hour = scheduledTime.hour;
      final minute = scheduledTime.minute.toString().padLeft(2, '0');
      return isHebrew ? 'היום ב-$hour:$minute' : 'Today at $hour:$minute';
    } else {
      final weekday = isHebrew
          ? _getHebrewWeekday(scheduledTime.weekday)
          : _getEnglishWeekday(scheduledTime.weekday);
      final month = isHebrew
          ? _getHebrewMonth(scheduledTime.month)
          : _getEnglishMonth(scheduledTime.month);
      final day = scheduledTime.day;
      final hour = scheduledTime.hour;
      final minute = scheduledTime.minute.toString().padLeft(2, '0');
      
      return isHebrew
          ? '$weekday, $day ב$month ב-$hour:$minute'
          : '$weekday, $month $day at $hour:$minute';
    }
  }

  String _getEnglishWeekday(int weekday) {
    const weekdays = ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return weekdays[weekday];
  }

  String _getHebrewWeekday(int weekday) {
    const weekdays = ['', 'ב׳', 'ג׳', 'ד׳', 'ה׳', 'ו׳', 'ש׳', 'א׳'];
    return weekdays[weekday];
  }

  String _getEnglishMonth(int month) {
    const months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return months[month];
  }

  String _getHebrewMonth(int month) {
    const months = [
      '',
      'ינואר',
      'פברואר',
      'מרץ',
      'אפריל',
      'מאי',
      'יוני',
      'יולי',
      'אוגוסט',
      'ספטמבר',
      'אוקטובר',
      'נובמבר',
      'דצמבר'
    ];
    return months[month];
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: isHebrew ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              isHebrew ? Icons.arrow_forward : Icons.arrow_back,
              color: const Color(0xFF1A1A1A),
            ),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            isHebrew ? 'התראות קרובות' : 'Upcoming Notifications',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A1A),
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, color: Color(0xFF1A1A1A)),
              onPressed: _loadNotifications,
              tooltip: isHebrew ? 'רענן' : 'Refresh',
            ),
          ],
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFFE8B923),
                ),
              )
            : _notifications.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.notifications_none,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          isHebrew
                              ? 'אין התראות מתוזמנות'
                              : 'No scheduled notifications',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isHebrew
                              ? 'התראות יופיעו כאן לאחר תזמון'
                              : 'Notifications will appear here after scheduling',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadNotifications,
                    color: const Color(0xFFE8B923),
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _notifications.length,
                      itemBuilder: (context, index) {
                        return _buildNotificationCard(_notifications[index]);
                      },
                    ),
                  ),
      ),
    );
  }

  Widget _buildNotificationCard(UpcomingNotification notification) {
    final timeUntil = notification.timeUntil;
    final isPast = timeUntil.isNegative;
    final soundName = isHebrew ? notification.soundNameHe : notification.soundName;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: notification.isPreNotification
              ? const Color(0xFFE8B923).withValues(alpha: 0.3)
              : Colors.grey[300]!,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with icon and type
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: notification.isPreNotification
                        ? const Color(0xFFE8B923).withValues(alpha: 0.2)
                        : const Color(0xFF1A1A1A).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    notification.isPreNotification
                        ? Icons.schedule
                        : (notification.title.toLowerCase().contains('issur') ||
                                notification.title.contains('איסור'))
                            ? Icons.block
                            : Icons.local_fire_department,
                    size: 24,
                    color: notification.isPreNotification
                        ? const Color(0xFFE8B923)
                        : const Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notification.isPreNotification
                            ? (isHebrew ? 'תזכורת מוקדמת' : 'Early Reminder')
                            : (notification.title.toLowerCase().contains('issur') ||
                                    notification.title.contains('איסור'))
                                ? (isHebrew ? 'איסור מלאכה' : 'Issur Melacha')
                                : (isHebrew ? 'הדלקת נרות' : 'Candle Lighting'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[600],
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notification.title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Message
            Text(
              notification.body,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            // Details row
            Row(
              children: [
                // Sound
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        Icons.music_note,
                        size: 16,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          soundName,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Time until
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 16,
                      color: isPast ? Colors.red : const Color(0xFFE8B923),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _formatTimeUntil(timeUntil),
                      style: TextStyle(
                        fontSize: 13,
                        color: isPast ? Colors.red : const Color(0xFFE8B923),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Scheduled time
            Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 14,
                  color: Colors.grey[500],
                ),
                const SizedBox(width: 6),
                Text(
                  _formatScheduledTime(notification.scheduledTime),
                  style: TextStyle(
                    fontSize: 12,
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
}
