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
  static const List<SoundOption> earlyReminderSounds = [
    SoundOption(
      id: 'shabbat_shalom_song',
      nameEn: 'Shabbat Shalom Song',
      nameHe: 'שיר שבת שלום',
      assetPath: 'sounds/RYomTovShabbatShalomSong.mp3',
      category: SoundCategory.earlyReminder,
    ),
    SoundOption(
      id: 'yomtov_default',
      nameEn: 'Yom Tov Music',
      nameHe: 'מוזיקת יום טוב',
      assetPath: 'sounds/YomTov-Default.mp3',
      category: SoundCategory.earlyReminder,
    ),
    SoundOption(
      id: 'ata_bechartanu',
      nameEn: 'Ata Bechartanu',
      nameHe: 'אתה בחרתנו',
      assetPath: 'sounds/Ata Bechartanu-YomTov.mp3',
      category: SoundCategory.earlyReminder,
    ),
    SoundOption(
      id: 'ata_bechartanu_2',
      nameEn: 'Ata Bechartanu 2',
      nameHe: 'אתה בחרתנו 2',
      assetPath: 'sounds/Ata Bechartanu2-YomTov.mp3',
      category: SoundCategory.earlyReminder,
    ),
    SoundOption(
      id: 'hodu_lahashem',
      nameEn: 'Hodu LaHashem Ki Tov',
      nameHe: 'הודו לה׳ כי טוב',
      assetPath: "sounds/Hodu La'Hashem Ki Tov-YomTov.mp3",
      category: SoundCategory.earlyReminder,
    ),
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
    assetPath: 'sounds/RavShalomShofarDefaultlouder.mp3',
    category: SoundCategory.candleLighting,
  );

  /// Yom Tov sounds - separate section with clear default
  /// Default: Yom Tov Default
  static const List<SoundOption> yomTovSounds = [
    SoundOption(
      id: 'yomtov_default',
      nameEn: 'Yom Tov Default',
      nameHe: 'יום טוב ברירת מחדל',
      assetPath: 'sounds/YomTov-Default.mp3',
      category: SoundCategory.yomTov,
    ),
    SoundOption(
      id: 'ata_bechartanu',
      nameEn: 'Ata Bechartanu',
      nameHe: 'אתה בחרתנו',
      assetPath: 'sounds/Ata Bechartanu-YomTov.mp3',
      category: SoundCategory.yomTov,
    ),
    SoundOption(
      id: 'ata_bechartanu_2',
      nameEn: 'Ata Bechartanu 2',
      nameHe: 'אתה בחרתנו 2',
      assetPath: 'sounds/Ata Bechartanu2-YomTov.mp3',
      category: SoundCategory.yomTov,
    ),
    SoundOption(
      id: 'hodu_lahashem',
      nameEn: 'Hodu LaHashem Ki Tov',
      nameHe: 'הודו לה׳ כי טוב',
      assetPath: "sounds/Hodu La'Hashem Ki Tov-YomTov.mp3",
      category: SoundCategory.yomTov,
    ),
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
    final prefs = await SharedPreferences.getInstance();
    final soundId = prefs.getString(_earlyReminderSoundKey);
    // Default to Shabbat Shalom Song if not set
    if (soundId == null || !SoundOption.earlyReminderSounds.any((s) => s.id == soundId)) {
      return defaultEarlyReminderSound;
    }
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
