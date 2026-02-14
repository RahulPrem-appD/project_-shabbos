import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SoundOption {
  final String id;
  final String nameEn;
  final String nameHe;
  final String? assetPath;
  final SoundCategory category;

  const SoundOption({
    required this.id,
    required this.nameEn,
    required this.nameHe,
    this.assetPath,
    required this.category,
  });

  /// Early Reminder sounds (music only - no shofar)
  /// Default: Shabbat Shalom Song
  /// NOTE: Only sounds that exist in assets/sounds/ are included
  static const List<SoundOption> earlyReminderSounds = [
    SoundOption(
      id: 'shabbat_shalom_song',
      nameEn: 'Shabbat Shalom Song',
      nameHe: 'שיר שבת שלום',
      assetPath: 'sounds/RaYomTovShabbosDefault-Android.mp3',
      category: SoundCategory.earlyReminder,
    ),
    SoundOption(
      id: 'yomtov_default',
      nameEn: 'Yom Tov Music',
      nameHe: 'מוזיקת יום טוב',
      assetPath: 'sounds/Vesamachta-YomTov-Default-Android.mp3',
      category: SoundCategory.earlyReminder,
    ),
    // NOTE: The following sounds were removed because the files don't exist:
    // - ata_bechartanu (Ata Bechartanu-YomTov.mp3 - MISSING)
    // - ata_bechartanu_2 (Ata Bechartanu2-YomTov.mp3 - MISSING)
    // - hodu_lahashem (Hodu La'Hashem Ki Tov-YomTov.mp3 - MISSING)
    // Add these files to assets/sounds/ to re-enable these options
    SoundOption(
      id: 'silent',
      nameEn: 'Silent',
      nameHe: 'שקט',
      category: SoundCategory.earlyReminder,
    ),
  ];

  /// Candle Lighting sound (FIXED - Rav Shalom Shofar only)
  /// Users cannot change this
  static const SoundOption candleLightingSound = SoundOption(
    id: 'rav_shalom_shofar',
    nameEn: 'Rav Shalom Shofar',
    nameHe: 'שופר רב שלום',
    assetPath: 'sounds/RavShalomShofarDefaultCandle_Default.mp3',
    category: SoundCategory.candleLighting,
  );

  /// Yom Tov sounds - separate section with clear default
  /// Default: Yom Tov Default
  /// NOTE: Only sounds that exist in assets/sounds/ are included
  static const List<SoundOption> yomTovSounds = [
    SoundOption(
      id: 'yomtov_default',
      nameEn: 'Yom Tov Default',
      nameHe: 'יום טוב ברירת מחדל',
      assetPath: 'sounds/Vesamachta-YomTov-Default-Android.mp3',
      category: SoundCategory.yomTov,
    ),
    // NOTE: The following sounds were removed because the files don't exist:
    // - ata_bechartanu (Ata Bechartanu-YomTov.mp3 - MISSING)
    // - ata_bechartanu_2 (Ata Bechartanu2-YomTov.mp3 - MISSING)
    // - hodu_lahashem (Hodu La'Hashem Ki Tov-YomTov.mp3 - MISSING)
    // Add these files to assets/sounds/ to re-enable these options
    SoundOption(
      id: 'silent',
      nameEn: 'Silent',
      nameHe: 'שקט',
      category: SoundCategory.yomTov,
    ),
  ];

  /// All sounds (for lookup purposes)
  static List<SoundOption> get allSounds => [
    candleLightingSound,
    ...earlyReminderSounds,
    ...yomTovSounds,
  ];

  /// Find sound by ID
  static SoundOption? findById(String id) {
    try {
      return allSounds.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }
}

enum SoundCategory {
  earlyReminder,
  candleLighting,
  yomTov,
}

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  AudioPlayer? _player;

  static const String _earlyReminderSoundKey = 'early_reminder_sound';
  static const String _yomTovSoundKey = 'yomtov_sound';
  static const String _alarmVolumeKey = 'alarm_volume';
  static const double defaultAlarmVolume = 1.0;
  
  // Default sound IDs
  static const String defaultEarlyReminderSound = 'shabbat_shalom_song';
  static const String defaultYomTovSound = 'yomtov_default';

  AudioPlayer get player {
    _player ??= AudioPlayer();
    return _player!;
  }

  /// Get Early Reminder sounds (music only)
  List<SoundOption> getEarlyReminderSounds() {
    return SoundOption.earlyReminderSounds;
  }

  /// Get Yom Tov sounds
  List<SoundOption> getYomTovSounds() {
    return SoundOption.yomTovSounds;
  }

  /// Get the fixed Candle Lighting sound (Rav Shalom Shofar)
  SoundOption getCandleLightingSoundOption() {
    return SoundOption.candleLightingSound;
  }

  /// Play a sound by ID
  Future<void> playSound(String soundId) async {
    debugPrint('AudioService: Attempting to play sound: $soundId');

    try {
      final sound = SoundOption.findById(soundId);
      
      if (sound == null) {
        debugPrint('AudioService: Sound not found: $soundId');
        return;
      }

      if (sound.id == 'silent') {
        debugPrint('AudioService: Silent mode');
        return;
      }

      if (sound.assetPath == null) {
        debugPrint('AudioService: No audio source available for ${sound.id}');
        return;
      }

      // Stop any currently playing sound
      await player.stop();

      debugPrint('AudioService: Playing asset: ${sound.assetPath}');
      await player.setSource(AssetSource(sound.assetPath!));
      final volume = await getAlarmVolume();
      await player.setVolume(volume);
      await player.resume();
      debugPrint('AudioService: Successfully started playing ${sound.id}');
    } catch (e, stackTrace) {
      debugPrint('AudioService: Error playing sound: $e');
      debugPrint('AudioService: Stack trace: $stackTrace');
    }
  }

  /// Preview a sound (same as play)
  Future<void> previewSound(String soundId) async {
    await playSound(soundId);
  }

  /// Stop playing
  Future<void> stop() async {
    try {
      await player.stop();
      debugPrint('AudioService: Stopped playback');
    } catch (e) {
      debugPrint('AudioService: Error stopping: $e');
    }
  }

  // ============================================
  // Early Reminder sound settings
  // ============================================
  
  Future<String> getEarlyReminderSound() async {
    debugPrint('🔊 AudioService.getEarlyReminderSound() called');
    final prefs = await SharedPreferences.getInstance();
    final soundId = prefs.getString(_earlyReminderSoundKey);
    debugPrint('🔊 → Raw value from SharedPreferences: "$soundId"');
    
    // Default to Shabbat Shalom Song if not set
    if (soundId == null) {
      debugPrint('🔊 → Sound ID is null, using default: "$defaultEarlyReminderSound"');
      return defaultEarlyReminderSound;
    }
    
    // Verify sound ID exists in early reminder sounds list
    final soundExists = SoundOption.earlyReminderSounds.any((s) => s.id == soundId);
    if (!soundExists) {
      debugPrint('🔊 ✗ WARNING: Sound ID "$soundId" not found in earlyReminderSounds list!');
      debugPrint('🔊 → Available IDs: ${SoundOption.earlyReminderSounds.map((s) => s.id).join(", ")}');
      debugPrint('🔊 → Falling back to default: "$defaultEarlyReminderSound"');
      return defaultEarlyReminderSound;
    }
    
    debugPrint('🔊 ✓ Returning sound ID: "$soundId"');
    return soundId;
  }

  Future<void> setEarlyReminderSound(String soundId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_earlyReminderSoundKey, soundId);
    debugPrint('AudioService: Early reminder sound set to: $soundId');
  }

  // ============================================
  // Candle Lighting sound (FIXED - no user selection)
  // ============================================
  
  /// Always returns Rav Shalom Shofar - users cannot change this
  String getCandleLightingSound() {
    return SoundOption.candleLightingSound.id;
  }

  // ============================================
  // Yom Tov sound settings
  // ============================================
  
  Future<String> getYomTovSound() async {
    final prefs = await SharedPreferences.getInstance();
    final soundId = prefs.getString(_yomTovSoundKey);
    // Default to Yom Tov Default if not set
    if (soundId == null || !SoundOption.yomTovSounds.any((s) => s.id == soundId)) {
      return defaultYomTovSound;
    }
    return soundId;
  }

  Future<void> setYomTovSound(String soundId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_yomTovSoundKey, soundId);
    debugPrint('AudioService: Yom Tov sound set to: $soundId');
  }

  // ============================================
  // Alarm Volume settings (Android only)
  // ============================================

  Future<double> getAlarmVolume() async {
    final prefs = await SharedPreferences.getInstance();
    final volumeStr = prefs.getString(_alarmVolumeKey);
    if (volumeStr == null) return defaultAlarmVolume;
    final volume = double.tryParse(volumeStr) ?? defaultAlarmVolume;
    return volume.clamp(0.1, 1.0);
  }

  Future<void> setAlarmVolume(double volume) async {
    final clampedVolume = volume.clamp(0.1, 1.0);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_alarmVolumeKey, clampedVolume.toString());
    debugPrint('AudioService: Alarm volume set to: $clampedVolume');
  }

  // ============================================
  // Legacy compatibility methods (deprecated)
  // ============================================
  
  @Deprecated('Use getEarlyReminderSound() instead')
  Future<String> getPreNotificationSound() async {
    return await getEarlyReminderSound();
  }

  @Deprecated('Use setEarlyReminderSound() instead')
  Future<void> setPreNotificationSound(String soundId) async {
    await setEarlyReminderSound(soundId);
  }

  void dispose() {
    _player?.dispose();
    _player = null;
  }
}
