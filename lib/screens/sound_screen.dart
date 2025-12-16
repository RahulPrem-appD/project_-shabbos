import 'package:flutter/material.dart';
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

  bool get isHebrew => widget.locale == 'he';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final preSnd = await _audioService.getPreNotificationSound();
    final candleSnd = await _audioService.getCandleLightingSound();
    
    setState(() {
      _preNotificationSound = preSnd;
      _candleLightingSound = candleSnd;
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
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text('בס״ד', style: TextStyle(fontSize: 14, color: Colors.grey[400])),
              ),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          children: [
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
                          ? 'הצלילים ינוגנו יחד עם ההתראות'
                          : 'Sounds will play with notifications',
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

  Widget _buildSection({
    required String title,
    required String subtitle,
    required String selectedSound,
    required Function(String) onSoundSelected,
  }) {
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
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8F8F8),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              for (int i = 0; i < SoundOption.availableSounds.length; i++) ...[
                _buildSoundTile(
                  sound: SoundOption.availableSounds[i],
                  isSelected: selectedSound == SoundOption.availableSounds[i].id,
                  onTap: () => onSoundSelected(SoundOption.availableSounds[i].id),
                ),
                if (i < SoundOption.availableSounds.length - 1)
                  Divider(height: 1, indent: 56, color: Colors.grey[200]),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSoundTile({
    required SoundOption sound,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final isPlaying = _playingId == sound.id;
    
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
                _getIconForSound(sound.id),
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
              ),
            ),
            if (sound.assetPath != null) ...[
              IconButton(
                onPressed: () => _previewSound(sound),
                icon: Icon(
                  isPlaying ? Icons.stop : Icons.play_arrow,
                  color: const Color(0xFFE8B923),
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

  IconData _getIconForSound(String id) {
    switch (id) {
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
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        setState(() => _playingId = null);
      }
    }
  }
}

