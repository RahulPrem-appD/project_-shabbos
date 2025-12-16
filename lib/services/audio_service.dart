import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';

class SoundOption {
  final String id;
  final String nameEn;
  final String nameHe;
  final String? assetPath;
  final String? filePath; // For custom uploaded sounds
  final bool isSystemDefault;
  final bool isCustom;

  const SoundOption({
    required this.id,
    required this.nameEn,
    required this.nameHe,
    this.assetPath,
    this.filePath,
    this.isSystemDefault = false,
    this.isCustom = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'nameEn': nameEn,
    'nameHe': nameHe,
    'assetPath': assetPath,
    'filePath': filePath,
    'isSystemDefault': isSystemDefault,
    'isCustom': isCustom,
  };

  factory SoundOption.fromJson(Map<String, dynamic> json) => SoundOption(
    id: json['id'] as String,
    nameEn: json['nameEn'] as String,
    nameHe: json['nameHe'] as String,
    assetPath: json['assetPath'] as String?,
    filePath: json['filePath'] as String?,
    isSystemDefault: json['isSystemDefault'] as bool? ?? false,
    isCustom: json['isCustom'] as bool? ?? false,
  );

  static const List<SoundOption> builtInSounds = [
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
  static const String _customSoundsKey = 'custom_sounds';

  AudioPlayer get player {
    _player ??= AudioPlayer();
    return _player!;
  }

  /// Get all available sounds (built-in + custom)
  Future<List<SoundOption>> getAllSounds() async {
    final customSounds = await getCustomSounds();
    return [...SoundOption.builtInSounds, ...customSounds];
  }

  /// Get custom sounds from storage
  Future<List<SoundOption>> getCustomSounds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = prefs.getStringList(_customSoundsKey) ?? [];
      return jsonList
          .map((json) => SoundOption.fromJson(jsonDecode(json)))
          .toList();
    } catch (e) {
      debugPrint('AudioService: Error loading custom sounds: $e');
      return [];
    }
  }

  /// Save a custom sound
  Future<SoundOption?> saveCustomSound(String sourcePath, String fileName) async {
    try {
      // Get app documents directory
      final appDir = await getApplicationDocumentsDirectory();
      final soundsDir = Directory('${appDir.path}/custom_sounds');
      
      // Create directory if it doesn't exist
      if (!await soundsDir.exists()) {
        await soundsDir.create(recursive: true);
      }

      // Generate unique ID
      final id = 'custom_${DateTime.now().millisecondsSinceEpoch}';
      
      // Get file extension
      final extension = fileName.split('.').last.toLowerCase();
      final newFileName = '$id.$extension';
      final destPath = '${soundsDir.path}/$newFileName';

      // Copy file to app directory
      final sourceFile = File(sourcePath);
      await sourceFile.copy(destPath);

      // Create sound option
      final displayName = fileName.replaceAll(RegExp(r'\.[^.]+$'), ''); // Remove extension
      final soundOption = SoundOption(
        id: id,
        nameEn: displayName,
        nameHe: displayName,
        filePath: destPath,
        isCustom: true,
      );

      // Save to preferences
      final prefs = await SharedPreferences.getInstance();
      final customSounds = await getCustomSounds();
      customSounds.add(soundOption);
      
      final jsonList = customSounds.map((s) => jsonEncode(s.toJson())).toList();
      await prefs.setStringList(_customSoundsKey, jsonList);

      debugPrint('AudioService: Saved custom sound: $displayName at $destPath');
      return soundOption;
    } catch (e) {
      debugPrint('AudioService: Error saving custom sound: $e');
      return null;
    }
  }

  /// Delete a custom sound
  Future<bool> deleteCustomSound(String soundId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final customSounds = await getCustomSounds();
      
      // Find the sound to delete
      final soundToDelete = customSounds.firstWhere(
        (s) => s.id == soundId,
        orElse: () => const SoundOption(id: '', nameEn: '', nameHe: ''),
      );

      if (soundToDelete.id.isEmpty) {
        return false;
      }

      // Delete the file
      if (soundToDelete.filePath != null) {
        final file = File(soundToDelete.filePath!);
        if (await file.exists()) {
          await file.delete();
        }
      }

      // Remove from list and save
      customSounds.removeWhere((s) => s.id == soundId);
      final jsonList = customSounds.map((s) => jsonEncode(s.toJson())).toList();
      await prefs.setStringList(_customSoundsKey, jsonList);

      // Reset to default if this sound was selected
      final preSound = await getPreNotificationSound();
      final candleSound = await getCandleLightingSound();
      
      if (preSound == soundId) {
        await setPreNotificationSound('default');
      }
      if (candleSound == soundId) {
        await setCandleLightingSound('default');
      }

      debugPrint('AudioService: Deleted custom sound: $soundId');
      return true;
    } catch (e) {
      debugPrint('AudioService: Error deleting custom sound: $e');
      return false;
    }
  }

  /// Play a sound by ID
  Future<void> playSound(String soundId) async {
    debugPrint('AudioService: Attempting to play sound: $soundId');

    try {
      // Get all sounds including custom
      final allSounds = await getAllSounds();
      final sound = allSounds.firstWhere(
        (s) => s.id == soundId,
        orElse: () => SoundOption.builtInSounds.first,
      );

      if (sound.isSystemDefault) {
        debugPrint('AudioService: System default sound - skipping custom playback');
        return;
      }

      if (sound.id == 'silent') {
        debugPrint('AudioService: Silent mode');
        return;
      }

      // Stop any currently playing sound
      await player.stop();

      // Play from file path (custom sound) or asset path (built-in)
      if (sound.filePath != null) {
        debugPrint('AudioService: Playing custom file: ${sound.filePath}');
        await player.setSource(DeviceFileSource(sound.filePath!));
      } else if (sound.assetPath != null) {
        debugPrint('AudioService: Playing asset: ${sound.assetPath}');
        await player.setSource(AssetSource(sound.assetPath!));
      } else {
        debugPrint('AudioService: No audio source available');
        return;
      }

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
