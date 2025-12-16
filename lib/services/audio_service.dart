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

  static const List<SoundOption> availableSounds = [
    SoundOption(
      id: 'default',
      nameEn: 'System Default',
      nameHe: 'ברירת מחדל',
      isSystemDefault: true,
    ),
    SoundOption(
      id: 'gentle_chime',
      nameEn: 'Gentle Chime',
      nameHe: 'צלצול עדין',
      assetPath: 'sounds/gentle_chime.aiff',
    ),
    SoundOption(
      id: 'peaceful_bell',
      nameEn: 'Peaceful Bell',
      nameHe: 'פעמון שלו',
      assetPath: 'sounds/peaceful_bell.aiff',
    ),
    SoundOption(
      id: 'soft_tone',
      nameEn: 'Soft Tone',
      nameHe: 'צליל רך',
      assetPath: 'sounds/soft_tone.aiff',
    ),
    SoundOption(id: 'silent', nameEn: 'Silent', nameHe: 'שקט'),
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

  /// Play a sound by ID
  Future<void> playSound(String soundId) async {
    debugPrint('AudioService: Attempting to play sound: $soundId');

    try {
      final sound = SoundOption.availableSounds.firstWhere(
        (s) => s.id == soundId,
        orElse: () => SoundOption.availableSounds.first,
      );

      if (sound.isSystemDefault) {
        debugPrint(
          'AudioService: System default sound - skipping custom playback',
        );
        return;
      }

      if (sound.id == 'silent' || sound.assetPath == null) {
        debugPrint('AudioService: Silent mode or no asset path');
        return;
      }

      debugPrint('AudioService: Playing asset: ${sound.assetPath}');

      // Stop any currently playing sound
      await player.stop();

      // Set the source and play
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
    return prefs.getString(_preNotificationSoundKey) ?? 'default';
  }

  Future<void> setPreNotificationSound(String soundId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_preNotificationSoundKey, soundId);
    debugPrint('AudioService: Pre-notification sound set to: $soundId');
  }

  // Candle lighting sound settings
  Future<String> getCandleLightingSound() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_candleLightingSoundKey) ?? 'default';
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
