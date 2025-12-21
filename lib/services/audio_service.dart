import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SoundOption {
  final String id;
  final String nameEn;
  final String nameHe;
  final String? assetPath;
  final bool isSystemDefault;

  const SoundOption({
    required this.id,
    required this.nameEn,
    required this.nameHe,
    this.assetPath,
    this.isSystemDefault = false,
  });

  /// Built-in sounds from assets/sounds/
  static const List<SoundOption> builtInSounds = [
    // Candle Lighting Alarm
    SoundOption(
      id: 'shofar_candle',
      nameEn: 'Shofar (Candle Alarm)',
      nameHe: 'שופר (התראת נרות)',
      assetPath: 'sounds/Shofar-CandleAlarm.mp3',
    ),
    // Default Shofar
    SoundOption(
      id: 'rav_shalom_shofar',
      nameEn: 'Rav Shalom Shofar',
      nameHe: 'שופר רב שלום',
      assetPath: 'sounds/RavShalomShofarDefaultlouder.mp3',
    ),
    // Shabbat Shalom Song
    SoundOption(
      id: 'shabbat_shalom_song',
      nameEn: 'Shabbat Shalom Song',
      nameHe: 'שיר שבת שלום',
      assetPath: 'sounds/RYomTovShabbatShalomSong.mp3',
    ),
    // Yom Tov Default
    SoundOption(
      id: 'yomtov_default',
      nameEn: 'Yom Tov Default',
      nameHe: 'יום טוב ברירת מחדל',
      assetPath: 'sounds/YomTov-Default.mp3',
    ),
    // Ata Bechartanu
    SoundOption(
      id: 'ata_bechartanu',
      nameEn: 'Ata Bechartanu',
      nameHe: 'אתה בחרתנו',
      assetPath: 'sounds/Ata Bechartanu-YomTov.mp3',
    ),
    // Ata Bechartanu 2
    SoundOption(
      id: 'ata_bechartanu_2',
      nameEn: 'Ata Bechartanu 2',
      nameHe: 'אתה בחרתנו 2',
      assetPath: 'sounds/Ata Bechartanu2-YomTov.mp3',
    ),
    // Hodu LaHashem Ki Tov
    SoundOption(
      id: 'hodu_lahashem',
      nameEn: 'Hodu LaHashem Ki Tov',
      nameHe: 'הודו לה׳ כי טוב',
      assetPath: "sounds/Hodu La'Hashem Ki Tov-YomTov.mp3",
    ),
    // Silent option
    SoundOption(
      id: 'silent',
      nameEn: 'Silent',
      nameHe: 'שקט',
    ),
  ];
}

class AudioService {
  static final AudioService _instance = AudioService._internal();
  factory AudioService() => _instance;
  AudioService._internal();

  AudioPlayer? _player;

  static const String _preNotificationSoundKey = 'pre_notification_sound';
  static const String _candleLightingSoundKey = 'candle_lighting_sound';

  AudioPlayer get player {
    _player ??= AudioPlayer();
    return _player!;
  }

  /// Get all available sounds
  List<SoundOption> getAllSounds() {
    return SoundOption.builtInSounds;
  }

  /// Play a sound by ID
  Future<void> playSound(String soundId) async {
    debugPrint('AudioService: Attempting to play sound: $soundId');

    try {
      final sound = SoundOption.builtInSounds.firstWhere(
        (s) => s.id == soundId,
        orElse: () => SoundOption.builtInSounds.first,
      );

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

  // Pre-notification sound settings
  Future<String> getPreNotificationSound() async {
    final prefs = await SharedPreferences.getInstance();
    final soundId = prefs.getString(_preNotificationSoundKey);
    // Default to shofar_candle if not set or invalid
    if (soundId == null || !SoundOption.builtInSounds.any((s) => s.id == soundId)) {
      return 'shofar_candle';
    }
    return soundId;
  }

  Future<void> setPreNotificationSound(String soundId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_preNotificationSoundKey, soundId);
    debugPrint('AudioService: Pre-notification sound set to: $soundId');
  }

  // Candle lighting sound settings
  Future<String> getCandleLightingSound() async {
    final prefs = await SharedPreferences.getInstance();
    final soundId = prefs.getString(_candleLightingSoundKey);
    // Default to shofar_candle if not set or invalid
    if (soundId == null || !SoundOption.builtInSounds.any((s) => s.id == soundId)) {
      return 'shofar_candle';
    }
    return soundId;
  }

  Future<void> setCandleLightingSound(String soundId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_candleLightingSoundKey, soundId);
    debugPrint('AudioService: Candle lighting sound set to: $soundId');
  }

  void dispose() {
    _player?.dispose();
    _player = null;
  }
}
