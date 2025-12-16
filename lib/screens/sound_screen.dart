import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/audio_service.dart';

class SoundScreen extends StatefulWidget {
  final String locale;

  const SoundScreen({super.key, required this.locale});

  @override
  State<SoundScreen> createState() => _SoundScreenState();
}

class _SoundScreenState extends State<SoundScreen> {
  final AudioService _audioService = AudioService();
  
  String _preNotificationSound = 'default';
  String _candleLightingSound = 'default';
  String? _playingId;
  List<SoundOption> _allSounds = [];
  bool _isLoading = true;

  bool get isHebrew => widget.locale == 'he';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    
    final preSnd = await _audioService.getPreNotificationSound();
    final candleSnd = await _audioService.getCandleLightingSound();
    final allSounds = await _audioService.getAllSounds();
    
    setState(() {
      _preNotificationSound = preSnd;
      _candleLightingSound = candleSnd;
      _allSounds = allSounds;
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _audioService.stop();
    super.dispose();
  }

  Future<void> _uploadCustomSound() async {
    try {
      // Use FileType.custom with audio extensions to open Files app on iOS
      // instead of the Music Library
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'wav', 'm4a', 'aac', 'aiff', 'flac', 'ogg', 'wma'],
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        
        if (file.path == null) {
          _showError(isHebrew ? 'לא ניתן לגשת לקובץ' : 'Cannot access file');
          return;
        }

        // Show loading
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => Center(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: Color(0xFFE8B923)),
                    const SizedBox(height: 16),
                    Text(
                      isHebrew ? 'שומר צליל...' : 'Saving sound...',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final savedSound = await _audioService.saveCustomSound(
          file.path!,
          file.name,
        );

        // Hide loading
        if (mounted) Navigator.pop(context);

        if (savedSound != null) {
          await _loadSettings();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  isHebrew 
                      ? 'הצליל "${savedSound.nameEn}" נשמר בהצלחה'
                      : 'Sound "${savedSound.nameEn}" saved successfully',
                ),
                behavior: SnackBarBehavior.floating,
                backgroundColor: const Color(0xFF1A1A1A),
              ),
            );
          }
        } else {
          _showError(isHebrew ? 'שגיאה בשמירת הצליל' : 'Error saving sound');
        }
      }
    } catch (e) {
      debugPrint('Error picking file: $e');
      _showError(isHebrew ? 'שגיאה בבחירת קובץ' : 'Error picking file');
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red[700],
        ),
      );
    }
  }

  Future<void> _deleteCustomSound(SoundOption sound) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isHebrew ? 'מחק צליל' : 'Delete Sound'),
        content: Text(
          isHebrew 
              ? 'האם אתה בטוח שברצונך למחוק את "${sound.nameEn}"?'
              : 'Are you sure you want to delete "${sound.nameEn}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(isHebrew ? 'ביטול' : 'Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(isHebrew ? 'מחק' : 'Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await _audioService.deleteCustomSound(sound.id);
      if (success) {
        await _loadSettings();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isHebrew ? 'הצליל נמחק' : 'Sound deleted'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
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
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text('בס״ד', style: TextStyle(fontSize: 14, color: Colors.grey[400])),
              ),
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFFE8B923)))
            : ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                children: [
                  // Upload custom sound button
                  _buildUploadButton(),
                  
                  const SizedBox(height: 24),
                  
                  _buildSection(
                    title: isHebrew ? 'תזכורת מוקדמת' : 'Early Reminder',
                    subtitle: isHebrew ? '20 דקות לפני הדלקת נרות' : '20 minutes before candle lighting',
                    selectedSound: _preNotificationSound,
                    onSoundSelected: (id) async {
                      setState(() => _preNotificationSound = id);
                      await _audioService.setPreNotificationSound(id);
                    },
                  ),
                  
                  const SizedBox(height: 24),
                  
                  _buildSection(
                    title: isHebrew ? 'הדלקת נרות' : 'Candle Lighting',
                    subtitle: isHebrew ? 'בזמן ההדלקה' : 'At candle lighting time',
                    selectedSound: _candleLightingSound,
                    onSoundSelected: (id) async {
                      setState(() => _candleLightingSound = id);
                      await _audioService.setCandleLightingSound(id);
                    },
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // Info text
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE8B923).withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.grey[600], size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            isHebrew 
                                ? 'הצלילים ינוגנו יחד עם ההתראות. ניתן להעלות קבצי MP3, WAV, M4A ועוד.'
                                : 'Sounds will play with notifications. You can upload MP3, WAV, M4A and more.',
                            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                ],
              ),
      ),
    );
  }

  Widget _buildUploadButton() {
    return GestureDetector(
      onTap: _uploadCustomSound,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1A1A1A), Color(0xFF2D2D2D)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: const Color(0xFFE8B923),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.add_rounded,
                color: Color(0xFF1A1A1A),
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isHebrew ? 'העלה צליל מותאם' : 'Upload Custom Sound',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isHebrew ? 'בחר קובץ שמע מהמכשיר' : 'Choose audio file from device',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.file_upload_outlined,
              color: Colors.white.withValues(alpha: 0.6),
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required String subtitle,
    required String selectedSound,
    required Function(String) onSoundSelected,
  }) {
    // Separate built-in and custom sounds
    final builtInSounds = _allSounds.where((s) => !s.isCustom).toList();
    final customSounds = _allSounds.where((s) => s.isCustom).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(fontSize: 13, color: Colors.grey[500]),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        
        // Built-in sounds
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8F8F8),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              for (int i = 0; i < builtInSounds.length; i++) ...[
                _buildSoundTile(
                  sound: builtInSounds[i],
                  isSelected: selectedSound == builtInSounds[i].id,
                  onTap: () => onSoundSelected(builtInSounds[i].id),
                ),
                if (i < builtInSounds.length - 1)
                  Divider(height: 1, indent: 56, color: Colors.grey[200]),
              ],
            ],
          ),
        ),
        
        // Custom sounds section
        if (customSounds.isNotEmpty) ...[
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
            child: Text(
              isHebrew ? 'צלילים מותאמים' : 'Custom Sounds',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey[500],
                letterSpacing: 0.5,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF8F8F8),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFE8B923).withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                for (int i = 0; i < customSounds.length; i++) ...[
                  _buildSoundTile(
                    sound: customSounds[i],
                    isSelected: selectedSound == customSounds[i].id,
                    onTap: () => onSoundSelected(customSounds[i].id),
                    showDelete: true,
                  ),
                  if (i < customSounds.length - 1)
                    Divider(height: 1, indent: 56, color: Colors.grey[200]),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSoundTile({
    required SoundOption sound,
    required bool isSelected,
    required VoidCallback onTap,
    bool showDelete = false,
  }) {
    final isPlaying = _playingId == sound.id;
    final hasPlayableSound = sound.assetPath != null || sound.filePath != null;
    
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
                color: isSelected 
                    ? const Color(0xFFE8B923) 
                    : sound.isCustom 
                        ? const Color(0xFFFFF8E1)
                        : Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _getIconForSound(sound),
                size: 20,
                color: isSelected 
                    ? Colors.white 
                    : sound.isCustom 
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
                    isHebrew ? sound.nameHe : sound.nameEn,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: const Color(0xFF1A1A1A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (sound.isCustom)
                    Text(
                      isHebrew ? 'צליל מותאם' : 'Custom',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[500],
                      ),
                    ),
                ],
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
            if (showDelete && sound.isCustom) ...[
              IconButton(
                onPressed: () => _deleteCustomSound(sound),
                icon: Icon(
                  Icons.delete_outline,
                  color: Colors.grey[400],
                  size: 20,
                ),
              ),
            ],
            if (isSelected)
              const Icon(Icons.check_circle, color: Color(0xFFE8B923), size: 24),
          ],
        ),
      ),
    );
  }

  IconData _getIconForSound(SoundOption sound) {
    if (sound.isCustom) {
      return Icons.library_music;
    }
    switch (sound.id) {
      case 'default':
        return Icons.notifications;
      case 'gentle_chime':
        return Icons.music_note;
      case 'peaceful_bell':
        return Icons.notifications_active;
      case 'soft_tone':
        return Icons.audiotrack;
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
}
