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
      assetPath: 'assets/sounds/gentle_chime.aiff',
    ),
    SoundOption(
      id: 'peaceful_bell',
      nameEn: 'Peaceful Bell',
      nameHe: 'פעמון שלו',
      assetPath: 'assets/sounds/peaceful_bell.aiff',
    ),
    SoundOption(
      id: 'soft_tone',
      nameEn: 'Soft Tone',
      nameHe: 'צליל רך',
      assetPath: 'assets/sounds/soft_tone.aiff',
    ),
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

  final AudioPlayer _player = AudioPlayer();
  
  static const String _preNotificationSoundKey = 'pre_notification_sound';
  static const String _candleLightingSoundKey = 'candle_lighting_sound';

  /// Play a sound by ID
  Future<void> playSound(String soundId) async {
    try {
      final sound = SoundOption.availableSounds.firstWhere(
        (s) => s.id == soundId,
        orElse: () => SoundOption.availableSounds.first,
      );

      if (sound.isSystemDefault || sound.assetPath == null) {
        debugPrint('AudioService: Using system default sound');
        return;
      }

      if (sound.id == 'silent') {
        debugPrint('AudioService: Silent mode');
        return;
      }

      await _player.stop();
      await _player.play(AssetSource(sound.assetPath!.replaceFirst('assets/', '')));
      debugPrint('AudioService: Playing ${sound.id}');
    } catch (e) {
      debugPrint('AudioService: Error playing sound: $e');
    }
  }

  /// Preview a sound
  Future<void> previewSound(String soundId) async {
    await playSound(soundId);
  }

  /// Stop playing
  Future<void> stop() async {
    await _player.stop();
  }

  // Pre-notification sound settings
  Future<String> getPreNotificationSound() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_preNotificationSoundKey) ?? 'default';
  }

  Future<void> setPreNotificationSound(String soundId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_preNotificationSoundKey, soundId);
  }

  // Candle lighting sound settings
  Future<String> getCandleLightingSound() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_candleLightingSoundKey) ?? 'default';
  }

  Future<void> setCandleLightingSound(String soundId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_candleLightingSoundKey, soundId);
  }

  void dispose() {
    _player.dispose();
  }
}

