import 'package:flutter/material.dart';
import '../models/candle_lighting.dart';
import '../services/audio_service.dart';
import '../services/notification_service.dart';
import '../services/hebcal_service.dart';
import '../services/location_service.dart';

class SoundScreen extends StatefulWidget {
  final String locale;
  final VoidCallback? onSoundChanged;

  const SoundScreen({super.key, required this.locale, this.onSoundChanged});

  @override
  State<SoundScreen> createState() => _SoundScreenState();
}

class _SoundScreenState extends State<SoundScreen> {
  final AudioService _audioService = AudioService();
  final NotificationService _notificationService = NotificationService();
  final HebcalService _hebcalService = HebcalService();
  final LocationService _locationService = LocationService();

  String _earlyReminderSound = AudioService.defaultEarlyReminderSound;
  String _yomTovSound = AudioService.defaultYomTovSound;
  String? _playingId;
  bool _isLoading = true;

  bool get isHebrew => widget.locale == 'he';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);

    final earlySound = await _audioService.getEarlyReminderSound();
    final yomTovSound = await _audioService.getYomTovSound();

    setState(() {
      _earlyReminderSound = earlySound;
      _yomTovSound = yomTovSound;
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _audioService.stop();
    super.dispose();
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
            icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A1A)),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            isHebrew ? 'צלילים' : 'Sounds',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A1A),
            ),
          ),
          actions: [
            Padding(
              padding: EdgeInsetsDirectional.only(end: 16),
              child: Center(
                child: Text(
                  'בס״ד',
                  style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                ),
              ),
            ),
          ],
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFFE8B923)),
              )
            : ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                children: [
                  const SizedBox(height: 8),

                  // Early Reminder Section (Music only - selectable)
                  _buildEarlyReminderSection(),

                  const SizedBox(height: 24),

                  // Candle Lighting Section (FIXED - Rav Shalom Shofar)
                  _buildCandleLightingSection(),

                  const SizedBox(height: 24),

                  // Yom Tov Section (selectable)
                  _buildYomTovSection(),

                  const SizedBox(height: 32),

                  // Info text
                  _buildInfoBox(),

                  const SizedBox(height: 40),
                ],
              ),
      ),
    );
  }

  Widget _buildEarlyReminderSection() {
    final sounds = _audioService.getEarlyReminderSounds();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          title: isHebrew ? 'תזכורת מוקדמת' : 'Early Reminder',
          subtitle: isHebrew
              ? 'מוזיקה בלבד • לפני הדלקת נרות'
              : 'Music only • Before candle lighting',
          icon: Icons.music_note,
        ),
        const SizedBox(height: 8),

        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8F8F8),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              for (int i = 0; i < sounds.length; i++) ...[
                _buildSoundTile(
                  sound: sounds[i],
                  isSelected: _earlyReminderSound == sounds[i].id,
                  onTap: () async {
                    setState(() => _earlyReminderSound = sounds[i].id);
                    await _audioService.setEarlyReminderSound(sounds[i].id);

                    // Verify the sound was saved
                    final savedSound = await _audioService
                        .getEarlyReminderSound();
                    debugPrint(
                      'SoundScreen: Saved early reminder sound: $savedSound (expected: ${sounds[i].id})',
                    );

                    if (savedSound != sounds[i].id) {
                      debugPrint(
                        'SoundScreen: WARNING - Sound mismatch! Retrying save...',
                      );
                      await _audioService.setEarlyReminderSound(sounds[i].id);
                    }

                    await _rescheduleNotifications();
                  },
                ),
                if (i < sounds.length - 1)
                  Divider(height: 1, indent: 56, color: Colors.grey[200]),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCandleLightingSection() {
    final fixedSound = _audioService.getCandleLightingSoundOption();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          title: isHebrew ? 'הדלקת נרות' : 'Candle Lighting',
          subtitle: isHebrew
              ? 'שופר רב שלום • קבוע'
              : 'Rav Shalom Shofar • Fixed',
          icon: Icons.campaign,
          isFixed: true,
        ),
        const SizedBox(height: 8),

        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBEB),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFE8B923).withValues(alpha: 0.5),
            ),
          ),
          child: _buildFixedSoundTile(sound: fixedSound),
        ),

        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            isHebrew
                ? '🔒 צליל זה קבוע כדי להבדיל בין התזכורת להדלקה'
                : '🔒 This sound is fixed to distinguish from early reminder',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[500],
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildYomTovSection() {
    final sounds = _audioService.getYomTovSounds();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          title: isHebrew ? 'יום טוב' : 'Yom Tov',
          subtitle: isHebrew ? 'צלילים לחגים' : 'Holiday sounds',
          icon: Icons.celebration,
        ),
        const SizedBox(height: 8),

        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8F8F8),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              for (int i = 0; i < sounds.length; i++) ...[
                _buildSoundTile(
                  sound: sounds[i],
                  isSelected: _yomTovSound == sounds[i].id,
                  onTap: () async {
                    setState(() => _yomTovSound = sounds[i].id);
                    await _audioService.setYomTovSound(sounds[i].id);

                    // Verify the sound was saved
                    final savedSound = await _audioService.getYomTovSound();
                    debugPrint(
                      'SoundScreen: Saved Yom Tov sound: $savedSound (expected: ${sounds[i].id})',
                    );

                    if (savedSound != sounds[i].id) {
                      debugPrint(
                        'SoundScreen: WARNING - Sound mismatch! Retrying save...',
                      );
                      await _audioService.setYomTovSound(sounds[i].id);
                    }

                    await _rescheduleNotifications();
                  },
                ),
                if (i < sounds.length - 1)
                  Divider(height: 1, indent: 56, color: Colors.grey[200]),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required String subtitle,
    required IconData icon,
    bool isFixed = false,
  }) {
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(4, 16, 4, 0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isFixed
                  ? const Color(0xFFE8B923).withValues(alpha: 0.2)
                  : const Color(0xFFE8B923).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: const Color(0xFFE8B923)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    if (isFixed) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8B923),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isHebrew ? 'קבוע' : 'FIXED',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSoundTile({
    required SoundOption sound,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final isPlaying = _playingId == sound.id;
    final hasPlayableSound = sound.assetPath != null;

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
                color: isSelected ? const Color(0xFFE8B923) : Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _getIconForSound(sound),
                size: 20,
                color: isSelected ? Colors.white : const Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                isHebrew ? sound.nameHe : sound.nameEn,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: const Color(0xFF1A1A1A),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (hasPlayableSound) ...[
              IconButton(
                onPressed: () => _previewSound(sound),
                icon: Icon(
                  isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded,
                  color: const Color(0xFFE8B923),
                ),
              ),
            ],
            if (isSelected)
              const Icon(
                Icons.check_circle,
                color: Color(0xFFE8B923),
                size: 24,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFixedSoundTile({required SoundOption sound}) {
    final isPlaying = _playingId == sound.id;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFE8B923),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.campaign, size: 20, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isHebrew ? sound.nameHe : sound.nameEn,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                Text(
                  isHebrew ? 'צליל ברירת מחדל' : 'Default sound',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _previewSound(sound),
            icon: Icon(
              isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded,
              color: const Color(0xFFE8B923),
            ),
          ),
          const Icon(Icons.lock_outline, color: Color(0xFFE8B923), size: 20),
        ],
      ),
    );
  }

  Widget _buildInfoBox() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFE8B923).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, color: Colors.grey[600], size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isHebrew
                      ? 'התזכורת המוקדמת משמיעה מוזיקה כדי להבדיל מהשופר בזמן הדלקת הנרות.'
                      : 'Early reminder plays music to distinguish from the shofar at candle lighting time.',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _getIconForSound(SoundOption sound) {
    switch (sound.id) {
      case 'rav_shalom_shofar':
        return Icons.campaign;
      case 'shabbat_shalom_song':
        return Icons.music_note;
      case 'yomtov_default':
        return Icons.celebration;
      case 'ata_bechartanu':
      case 'ata_bechartanu_2':
        return Icons.star;
      case 'hodu_lahashem':
        return Icons.favorite;
      case 'silent':
        return Icons.notifications_off;
      default:
        return Icons.music_note;
    }
  }

  Future<void> _previewSound(SoundOption sound) async {
    if (_playingId == sound.id) {
      await _audioService.stop();
      setState(() => _playingId = null);
    } else {
      setState(() => _playingId = sound.id);
      await _audioService.previewSound(sound.id);
      await Future.delayed(const Duration(seconds: 3));
      if (mounted) {
        setState(() => _playingId = null);
      }
    }
  }

  /// Reschedule all notifications with the new sound settings
  Future<void> _rescheduleNotifications() async {
    try {
      debugPrint('SoundScreen: Rescheduling notifications with new sound...');

      // Get current location
      final location = await _locationService.getSavedLocation();
      if (location == null) {
        debugPrint('SoundScreen: No location saved, skipping reschedule');
        return;
      }

      // Calculate date range (today + 30 days)
      final now = DateTime.now();
      final startDate = DateTime(now.year, now.month, now.day);
      final endDate = startDate.add(const Duration(days: 30));

      // Edge Case 17: Network failure handling - wrap in try-catch
      List<CandleLighting> futureTimes;
      try {
        // Fetch candle lighting times
        final times = await _hebcalService.getExtendedCandleLightingTimes(
          latitude: location.latitude,
          longitude: location.longitude,
          startDate: startDate,
          endDate: endDate,
          timezone: location.timezone,
          locale: widget.locale,
        );

        futureTimes = times
            .where((t) => t.candleLightingTime.isAfter(now))
            .toList();

        if (futureTimes.isEmpty) {
          debugPrint('SoundScreen: No future times, skipping reschedule');
          return;
        }
      } catch (e) {
        // Edge Case 17: Network failure - don't cancel existing alarms
        debugPrint('SoundScreen: ✗ Network error fetching candle lighting times: $e');
        debugPrint('SoundScreen: ⚠️ NOT cancelling existing alarms due to network failure');
        return; // Don't reschedule if network fails
      }

      // Reschedule with new sound settings
      // Edge Case 7: Pass onlySoundChanged flag to skip rescheduling if alarms are imminent
      await _notificationService.rescheduleAllNotifications(
        futureTimes.take(10).toList(),
        locale: widget.locale,
        onlySoundChanged: true, // Edge Case 7: Indicate only sound changed
      );

      debugPrint('SoundScreen: Notifications rescheduled successfully');

      // Notify parent if callback provided
      widget.onSoundChanged?.call();
    } catch (e) {
      debugPrint('SoundScreen: Error rescheduling: $e');
    }
  }
}
