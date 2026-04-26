import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/notification_service.dart';
import '../services/native_alarm_service.dart';
import 'main_shell.dart';

// ─────────────────────────────────────────────
// Data model
// ─────────────────────────────────────────────

enum PermissionStepType {
  notifications,
  location,
  exactAlarms,
  batteryOptimization,
  overlay,
  fullScreenIntent,
}

enum PermissionGrantMode {
  inlineDialog,
  opensSettings,
}

class PermissionStep {
  final PermissionStepType type;
  final PermissionGrantMode grantMode;
  final IconData icon;
  final bool isOptional;
  final String titleEn;
  final String titleHe;
  final String descriptionEn;
  final String descriptionHe;
  final String whyEn;
  final String whyHe;
  final List<String> instructionImageAssets;

  const PermissionStep({
    required this.type,
    required this.grantMode,
    required this.icon,
    this.isOptional = false,
    required this.titleEn,
    required this.titleHe,
    required this.descriptionEn,
    required this.descriptionHe,
    required this.whyEn,
    required this.whyHe,
    this.instructionImageAssets = const [],
  });
}

final _allSteps = <PermissionStep>[
  const PermissionStep(
    type: PermissionStepType.notifications,
    grantMode: PermissionGrantMode.inlineDialog,
    icon: Icons.notifications_active_outlined,
    titleEn: 'Candle Lighting Alerts',
    titleHe: 'התראות הדלקת נרות',
    descriptionEn:
        'Allow Shabbos!! to send you timely reminders before candle lighting begins.',
    descriptionHe: 'אפשר לשבת!! לשלוח לך תזכורות לפני הדלקת הנרות.',
    whyEn: 'Without this, you won\'t receive any alerts.',
    whyHe: 'ללא הרשאה זו, לא תקבל התראות.',
  ),
  const PermissionStep(
    type: PermissionStepType.location,
    grantMode: PermissionGrantMode.inlineDialog,
    icon: Icons.location_on_outlined,
    titleEn: 'Your Location',
    titleHe: 'מיקום',
    descriptionEn:
        'Precise candle lighting times depend on where you are. Your location is never shared.',
    descriptionHe:
        'זמני הדלקת נרות מדויקים תלויים במיקומך. המיקום אינו נשמר או משותף.',
    whyEn: 'Used only to calculate local zmanim.',
    whyHe: 'משמש רק לחישוב זמנים מקומיים.',
  ),
  const PermissionStep(
    type: PermissionStepType.exactAlarms,
    grantMode: PermissionGrantMode.opensSettings,
    icon: Icons.alarm_outlined,
    titleEn: 'Precise Alarm Timing',
    titleHe: 'תזמון מדויק',
    descriptionEn:
        'Android requires special permission to ring at the exact candle lighting moment. Tap Grant to open Settings and enable it.',
    descriptionHe:
        'אנדרואיד דורש הרשאה מיוחדת להפעלת התראה בזמן מדויק. לחץ הענק כדי לפתוח הגדרות.',
    whyEn: 'Without this, alarms may fire late.',
    whyHe: 'ללא הרשאה זו, ההתראה עלולה לאחר.',
  ),
  const PermissionStep(
    type: PermissionStepType.batteryOptimization,
    grantMode: PermissionGrantMode.inlineDialog,
    icon: Icons.battery_saver_outlined,
    titleEn: 'Background Reliability',
    titleHe: 'מהימנות ברקע',
    descriptionEn:
        'Exempting this app from battery optimization ensures alerts fire even when the app is in the background.',
    descriptionHe:
        'פטור מאופטימיזציה של סוללה מבטיח שההתראות יופעלו גם כשהאפליקציה ברקע.',
    whyEn: 'Otherwise the OS may silence your alarm.',
    whyHe: 'אחרת מערכת ההפעלה עלולה להשתיק את ההתראה.',
  ),
  const PermissionStep(
    type: PermissionStepType.overlay,
    grantMode: PermissionGrantMode.opensSettings,
    icon: Icons.layers_outlined,
    isOptional: true,
    titleEn: 'Alarm Screen',
    titleHe: 'מסך התראה',
    descriptionEn:
        'Allows the alarm screen to appear over other apps for maximum reliability. Tap Grant to open Settings.',
    descriptionHe:
        'מאפשר למסך ההתראה להופיע מעל אפליקציות אחרות לאמינות מרבית. לחץ הענק כדי לפתוח הגדרות.',
    whyEn: 'Adds an extra layer of reliability for alarm display.',
    whyHe: 'מוסיף שכבת אמינות נוספת להצגת ההתראה.',
    instructionImageAssets: [
      'assets/images/onboarding/overlay_list.png',
      'assets/images/onboarding/overlay_toggle.png',
    ],
  ),
  const PermissionStep(
    type: PermissionStepType.fullScreenIntent,
    grantMode: PermissionGrantMode.opensSettings,
    icon: Icons.fullscreen_outlined,
    isOptional: true,
    titleEn: 'Full-Screen Alerts',
    titleHe: 'התראות מסך מלא',
    descriptionEn:
        'Android 14+ requires explicit permission to display full-screen notifications at candle lighting time. Tap Grant to open Settings.',
    descriptionHe:
        'אנדרואיד 14+ דורש הרשאה מיוחדת להצגת התראות מסך מלא. לחץ הענק.',
    whyEn: 'Without this, the alarm appears only as a banner.',
    whyHe: 'ללא הרשאה, ההתראה תוצג רק כבאנר.',
  ),
];

// ─────────────────────────────────────────────
// Constants
// ─────────────────────────────────────────────
const _gold = Color(0xFFE8B923);
const _dark = Color(0xFF1A1A1A);

// ─────────────────────────────────────────────
// Widget
// ─────────────────────────────────────────────

class PermissionWizardScreen extends StatefulWidget {
  final String locale;
  final Function(String) onLocaleChanged;

  const PermissionWizardScreen({
    super.key,
    required this.locale,
    required this.onLocaleChanged,
  });

  @override
  State<PermissionWizardScreen> createState() => _PermissionWizardScreenState();
}

class _PermissionWizardScreenState extends State<PermissionWizardScreen>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  // ── Business state ──────────────────────────
  late List<PermissionStep> _steps;
  int _currentIndex = 0;
  bool _isGranting = false;
  bool _isCurrentGranted = false;
  bool _isDenied = false;
  bool _isPermanentlyDenied = false;
  bool _waitingForResume = false;

  // ── Animation controllers ───────────────────
  late AnimationController _pulseController;   // outer ring breathe
  late AnimationController _entranceController; // content slide-in on step change
  late AnimationController _successController;  // checkmark scale bounce
  late AnimationController _dotsController;     // waiting dots

  late Animation<double> _pulseAnim;
  late Animation<double> _entranceFade;
  late Animation<Offset> _entranceSlide;
  late Animation<double> _successScale;

  bool get _isHebrew => widget.locale == 'he';

  // ── Lifecycle ───────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _steps = _buildSteps();
    _initAnimations();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _skipGrantedSteps();
      _entranceController.forward();
    });
  }

  void _initAnimations() {
    // Pulsing outer ring (repeats)
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _pulseAnim = CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut);

    // Content entrance per step
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _entranceFade = CurvedAnimation(parent: _entranceController, curve: Curves.easeOut);
    _entranceSlide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entranceController, curve: Curves.easeOut));

    // Success bounce
    _successController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _successScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.3), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 0.9), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 0.9, end: 1.0), weight: 25),
    ]).animate(CurvedAnimation(parent: _successController, curve: Curves.easeOut));

    // Waiting dots loop
    _dotsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pulseController.dispose();
    _entranceController.dispose();
    _successController.dispose();
    _dotsController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed &&
        _currentIndex < _steps.length &&
        _steps[_currentIndex].type == PermissionStepType.batteryOptimization &&
        !_isGranting &&
        !_isCurrentGranted) {
      // Battery optimization changes can apply with delay on some OEMs.
      // Re-check automatically on resume so users don't need to tap Try Again.
      final granted = await _checkCurrentPermission();
      if (!mounted || !granted) return;
      setState(() {
        _isGranting = false;
        _isCurrentGranted = true;
        _isDenied = false;
        _isPermanentlyDenied = false;
      });
      _successController.forward(from: 0);
      await Future.delayed(const Duration(milliseconds: 700));
      if (mounted) _advanceToNext();
      return;
    }

    if (state == AppLifecycleState.resumed && _waitingForResume) {
      _waitingForResume = false;
      final granted = await _checkCurrentPermission();
      if (!mounted) return;
      setState(() {
        _isGranting = false;
        _isCurrentGranted = granted;
        _isDenied = !granted;
        _isPermanentlyDenied = false;
      });
      if (granted) {
        _successController.forward(from: 0);
        await Future.delayed(const Duration(milliseconds: 700));
        if (mounted) _advanceToNext();
      }
    }
  }

  // ── Business logic (unchanged) ──────────────

  List<PermissionStep> _buildSteps() {
    if (Platform.isAndroid) {
      PermissionStep step(PermissionStepType type) =>
          _allSteps.firstWhere((s) => s.type == type);

      return [
        step(PermissionStepType.notifications),
        step(PermissionStepType.location),
        step(PermissionStepType.batteryOptimization),
        step(PermissionStepType.exactAlarms),
        step(PermissionStepType.overlay),
        step(PermissionStepType.fullScreenIntent),
      ];
    }
    return _allSteps
        .where((s) =>
            s.type == PermissionStepType.notifications ||
            s.type == PermissionStepType.location)
        .toList();
  }

  Future<bool> _checkCurrentPermission() async {
    if (_currentIndex >= _steps.length) return true;
    final step = _steps[_currentIndex];
    switch (step.type) {
      case PermissionStepType.notifications:
        final status = await Permission.notification.status;
        return status.isGranted;
      case PermissionStepType.location:
        final status = await Permission.locationWhenInUse.status;
        return status.isGranted || status.isLimited;
      case PermissionStepType.exactAlarms:
        return NativeAlarmService.canScheduleExactAlarms();
      case PermissionStepType.batteryOptimization:
        return NativeAlarmService.isIgnoringBatteryOptimizations();
      case PermissionStepType.overlay:
        final overlayGranted = await NativeAlarmService.canDrawOverlays();
        if (!overlayGranted) {
          final available =
              await NativeAlarmService.isOverlaySettingsAvailable();
          if (!available) return true; // Auto-skip on restricted devices
        }
        return overlayGranted;
      case PermissionStepType.fullScreenIntent:
        return NativeAlarmService.canUseFullScreenIntent();
    }
  }

  Future<void> _skipGrantedSteps() async {
    while (_currentIndex < _steps.length) {
      final granted = await _checkCurrentPermission();
      if (!granted) break;
      _currentIndex++;
    }
    if (!mounted) return;
    if (_currentIndex >= _steps.length) {
      _finishWizard();
      return;
    }
    setState(() {});
  }

  Future<void> _onGrantPressed() async {
    setState(() {
      _isGranting = true;
      _isDenied = false;
      _isPermanentlyDenied = false;
      _isCurrentGranted = false;
    });

    final step = _steps[_currentIndex];

    if (step.grantMode == PermissionGrantMode.opensSettings) {
      setState(() => _waitingForResume = true);
      await _invokeSettingsRequest(step.type);
      return;
    }

    bool granted = false;
    bool permanentlyDenied = false;

    switch (step.type) {
      case PermissionStepType.notifications:
        if (Platform.isAndroid) {
          final status = await Permission.notification.request();
          granted = status.isGranted;
          permanentlyDenied = status.isPermanentlyDenied;
        } else {
          granted = await NotificationService().requestPermissions();
        }
        break;
      case PermissionStepType.location:
        final status = await Permission.locationWhenInUse.request();
        granted = status.isGranted || status.isLimited;
        permanentlyDenied = status.isPermanentlyDenied;
        break;
      case PermissionStepType.batteryOptimization:
        await NativeAlarmService.requestDisableBatteryOptimization();
        granted = await _waitForBatteryOptimizationGrant();
        break;
      default:
        break;
    }

    if (!mounted) return;
    setState(() {
      _isGranting = false;
      _isCurrentGranted = granted;
      _isDenied = !granted;
      _isPermanentlyDenied = permanentlyDenied;
    });

    if (granted) {
      _successController.forward(from: 0);
      await Future.delayed(const Duration(milliseconds: 700));
      if (mounted) _advanceToNext();
    }
  }

  Future<void> _invokeSettingsRequest(PermissionStepType type) async {
    switch (type) {
      case PermissionStepType.exactAlarms:
        await NativeAlarmService.requestExactAlarmPermission();
        break;
      case PermissionStepType.overlay:
        await NativeAlarmService.requestOverlayPermission();
        break;
      case PermissionStepType.fullScreenIntent:
        await NativeAlarmService.requestFullScreenIntentPermission();
        break;
      default:
        break;
    }
  }

  Future<bool> _waitForBatteryOptimizationGrant() async {
    // On some devices this state updates asynchronously after returning
    // from system UI, so poll briefly before showing "Try Again".
    for (int i = 0; i < 10; i++) {
      final granted = await NativeAlarmService.isIgnoringBatteryOptimizations();
      if (granted) return true;
      await Future.delayed(const Duration(milliseconds: 500));
    }
    return false;
  }

  bool _isOptionalStep(PermissionStep step) => step.isOptional;

  List<int> _requiredStepIndexes() {
    final indexes = <int>[];
    for (int i = 0; i < _steps.length; i++) {
      if (!_steps[i].isOptional) {
        indexes.add(i);
      }
    }
    return indexes;
  }

  int _currentRequiredStepPosition() {
    if (_currentIndex >= _steps.length) {
      return _requiredStepIndexes().length;
    }

    int position = 0;
    for (int i = 0; i <= _currentIndex && i < _steps.length; i++) {
      if (!_steps[i].isOptional) {
        position++;
      }
    }
    return position;
  }

  bool _isOptionalSectionStart() {
    if (_currentIndex >= _steps.length) return false;
    if (!_steps[_currentIndex].isOptional) return false;
    if (_currentIndex == 0) return true;
    return !_steps[_currentIndex - 1].isOptional;
  }

  void _skipOptionalStep() {
    if (_currentIndex >= _steps.length) return;
    final step = _steps[_currentIndex];
    if (!step.isOptional) return;
    _advanceToNext();
  }

  void _advanceToNext() {
    setState(() {
      _currentIndex++;
      _isCurrentGranted = false;
      _isDenied = false;
      _isPermanentlyDenied = false;
      _isGranting = false;
      _waitingForResume = false;
    });
    _successController.reset();
    _entranceController.forward(from: 0);
    _skipGrantedSteps();
  }

  Future<void> _finishWizard() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('permissions_wizard_complete', true);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => MainShell(
          locale: widget.locale,
          onLocaleChanged: widget.onLocaleChanged,
        ),
        transitionDuration: const Duration(milliseconds: 900),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeInOut),
          child: child,
        ),
      ),
    );
  }

  Future<void> _openAppSettingsForDenied() async {
    setState(() => _waitingForResume = true);
    await openAppSettings();
  }

  // ── Build ───────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: _isHebrew ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFFFDF5), Colors.white],
              stops: [0.0, 0.6],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                _buildBSDHeader(),
                _buildStepper(),
                _buildStepCounter(),
                Expanded(child: _buildContent()),
                _buildBottomActions(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Header ──────────────────────────────────

  Widget _buildBSDHeader() {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 6),
      child: Center(
        child: const Text(
          'בס״ד',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: _gold,
            letterSpacing: 2,
          ),
        ),
      ),
    );
  }

  // ── Step stepper ─────────────────────────────

  Widget _buildStepper() {
    if (_currentIndex >= _steps.length) return const SizedBox.shrink();

    final requiredIndexes = _requiredStepIndexes();
    if (requiredIndexes.isEmpty) return const SizedBox.shrink();

    final currentRequiredPosition = _currentRequiredStepPosition();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
      child: Row(
        children: List.generate(requiredIndexes.length * 2 - 1, (i) {
          if (i.isOdd) {
            // Connecting line
            final stepIdx = i ~/ 2;
            final isDone = stepIdx < currentRequiredPosition;
            return Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 400),
                height: 2,
                color: isDone ? _gold : const Color(0xFFE8E8E8),
              ),
            );
          }
          // Step dot
          final stepIdx = i ~/ 2;
          final step = _steps[requiredIndexes[stepIdx]];
          final isDone = stepIdx < currentRequiredPosition - 1;
          final isCurrent =
              !_steps[_currentIndex].isOptional &&
              stepIdx == currentRequiredPosition - 1;

          return AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            width: isCurrent ? 36 : 28,
            height: isCurrent ? 36 : 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDone
                  ? _dark
                  : isCurrent
                      ? _gold
                      : const Color(0xFFF0F0F0),
              boxShadow: isCurrent
                  ? [
                      BoxShadow(
                        color: _gold.withValues(alpha: 0.4),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: Icon(
                isDone ? Icons.check : step.icon,
                size: isCurrent ? 18 : 14,
                color: isDone
                    ? Colors.white
                    : isCurrent
                        ? _dark
                        : Colors.grey[400],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildStepCounter() {
    if (_currentIndex >= _steps.length) return const SizedBox.shrink();

    final step = _steps[_currentIndex];
    final requiredTotal = _requiredStepIndexes().length;
    final isOptional = step.isOptional;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: _gold.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            isOptional
                ? (_isHebrew ? 'שלב אופציונלי' : 'Optional step')
                : '${_currentRequiredStepPosition()} / $requiredTotal',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: _dark,
            ),
          ),
        ),
      ),
    );
  }

  // ── Content ──────────────────────────────────

  Widget _buildContent() {
    if (_currentIndex >= _steps.length) {
      return _buildAllDoneView();
    }

    final step = _steps[_currentIndex];
    final title = _isHebrew ? step.titleHe : step.titleEn;
    final desc = _isHebrew ? step.descriptionHe : step.descriptionEn;
    final why = _isHebrew ? step.whyHe : step.whyEn;
    final isOptional = _isOptionalStep(step);

    return FadeTransition(
      opacity: _entranceFade,
      child: SlideTransition(
        position: _entranceSlide,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Column(
            children: [
              if (_isOptionalSectionStart()) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F4F4),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _isHebrew
                        ? 'שלב אופציונלי לאמינות נוספת'
                        : 'Optional extra reliability',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _dark,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _isHebrew
                      ? 'אפשר לדלג כעת ולסיים את ההגדרה, או להוסיף שכבת אמינות נוספת.'
                      : 'You can finish setup now, or add one more layer of reliability.',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF666666),
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
              ],
              _buildAnimatedIcon(step),
              const SizedBox(height: 24),
              // Content card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 24,
                      offset: const Offset(0, 6),
                    ),
                    BoxShadow(
                      color: _gold.withValues(alpha: 0.04),
                      blurRadius: 40,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    if (isOptional) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: _gold.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _isHebrew ? 'אופציונלי' : 'Optional',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _dark,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: _dark,
                        height: 1.2,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      desc,
                      style: const TextStyle(
                        fontSize: 15,
                        color: Color(0xFF555555),
                        height: 1.6,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (step.instructionImageAssets.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildInstructionImages(step.instructionImageAssets),
                    ],
                    const SizedBox(height: 16),
                    _buildWhyCard(why),
                    const SizedBox(height: 14),
                    _buildTrustBadges(),
                  ],
                ),
              ),
              if (_isCurrentGranted) ...[
                const SizedBox(height: 16),
                _buildGrantedBadge(),
              ],
              if (_isDenied) ...[
                const SizedBox(height: 16),
                _buildDeniedFeedback(step),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── Animated icon ────────────────────────────

  Widget _buildAnimatedIcon(PermissionStep step) {
    return SizedBox(
      width: 160,
      height: 160,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer pulsing ring
          if (!_isCurrentGranted)
            AnimatedBuilder(
              animation: _pulseAnim,
              builder: (_, __) {
                final scale = 1.0 + 0.12 * _pulseAnim.value;
                final opacity = 0.18 - 0.12 * _pulseAnim.value;
                return Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _gold.withValues(alpha: opacity),
                        width: 2,
                      ),
                    ),
                  ),
                );
              },
            ),
          // Second ring (static)
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            width: 126,
            height: 126,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: (_isCurrentGranted ? Colors.green : _gold)
                  .withValues(alpha: 0.07),
              border: Border.all(
                color: (_isCurrentGranted ? Colors.green : _gold)
                    .withValues(alpha: 0.2),
                width: 1.5,
              ),
            ),
          ),
          // Inner icon circle with success scale bounce
          ScaleTransition(
            scale: _isCurrentGranted ? _successScale : const AlwaysStoppedAnimation(1.0),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (_isCurrentGranted ? Colors.green : _gold)
                    .withValues(alpha: 0.14),
                border: Border.all(
                  color: _isCurrentGranted ? Colors.green : _gold,
                  width: 2.5,
                ),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, anim) => ScaleTransition(
                  scale: anim,
                  child: FadeTransition(opacity: anim, child: child),
                ),
                child: Icon(
                  _isCurrentGranted
                      ? Icons.check_rounded
                      : step.icon,
                  key: ValueKey(_isCurrentGranted),
                  size: 44,
                  color: _isCurrentGranted ? Colors.green : _dark,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Why card ─────────────────────────────────

  Widget _buildInstructionImages(List<String> assets) {
    final caption = _isHebrew ? 'מה תראה' : 'What you\'ll see';
    final imageBorder = Border.all(color: const Color(0xFFE6E6E6));

    Widget buildCard(String asset) {
      return Container(
        width: 150,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(12),
          border: imageBorder,
        ),
        clipBehavior: Clip.antiAlias,
        child: Image.asset(asset, fit: BoxFit.cover),
      );
    }

    final single = assets.length == 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.visibility_outlined,
              size: 14,
              color: Color(0xFF888888),
            ),
            const SizedBox(width: 6),
            Text(
              caption,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF888888),
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (single)
          SizedBox(
            height: 260,
            child: Center(
              child: AspectRatio(
                aspectRatio: 9 / 16,
                child: buildCard(assets.first),
              ),
            ),
          )
        else
          SizedBox(
            height: 260,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              itemCount: assets.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) => buildCard(assets[i]),
            ),
          ),
      ],
    );
  }

  Widget _buildWhyCard(String why) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: _gold.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _gold.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb_outline_rounded, size: 16, color: _gold),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              why,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF555555),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Trust badges ─────────────────────────────

  Widget _buildTrustBadges() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _trustPill(Icons.lock_outline_rounded,
            _isHebrew ? 'פרטי לחלוטין' : 'Local only'),
        const SizedBox(width: 8),
        _trustPill(Icons.shield_outlined,
            _isHebrew ? 'לא משותף' : 'Never shared'),
      ],
    );
  }

  Widget _trustPill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F4F4),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.grey[500]),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[500],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ── Granted badge ────────────────────────────

  Widget _buildGrantedBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.green.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_rounded, color: Colors.green, size: 20),
          const SizedBox(width: 8),
          Text(
            _isHebrew ? 'ההרשאה אושרה!' : 'Permission granted!',
            style: const TextStyle(
              fontSize: 14,
              color: Colors.green,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // ── Denied feedback ──────────────────────────

  Widget _buildDeniedFeedback(PermissionStep step) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.orange.withValues(alpha: 0.25)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.warning_amber_rounded,
                  color: Colors.orange, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _isHebrew
                      ? 'ההרשאה נדחתה. ניתן לנסות שוב או לאפשר בהגדרות.'
                      : 'Permission denied. You can try again or enable it in Settings.',
                  style: const TextStyle(fontSize: 13, height: 1.4),
                ),
              ),
            ],
          ),
        ),
        if (_isPermanentlyDenied) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _openAppSettingsForDenied,
            icon: const Icon(Icons.settings_outlined, size: 15),
            label: Text(
              _isHebrew ? 'פתח הגדרות' : 'Open Settings',
              style: const TextStyle(fontSize: 13),
            ),
            style: TextButton.styleFrom(foregroundColor: _dark),
          ),
        ],
      ],
    );
  }

  // ── All done view ────────────────────────────

  Widget _buildAllDoneView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.green.withValues(alpha: 0.1),
                border: Border.all(color: Colors.green.withValues(alpha: 0.3), width: 2),
              ),
              child: const Icon(
                Icons.check_rounded,
                size: 60,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              _isHebrew ? 'ההגדרה הושלמה!' : 'Setup complete!',
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: _dark,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _isHebrew
                  ? 'ההרשאות החשובות מוכנות, ותוכל לקבל תזכורות להדלקת נרות.'
                  : 'Your key permissions are ready, so candle lighting reminders can work properly.',
              style: const TextStyle(
                fontSize: 15,
                color: Color(0xFF666666),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ── Bottom actions ───────────────────────────

  Widget _buildBottomActions() {
    if (_waitingForResume) return _buildWaitingState();

    final step =
        _currentIndex < _steps.length ? _steps[_currentIndex] : null;
    final showSkipOptional =
        step != null &&
        step.isOptional &&
        !_isCurrentGranted &&
        !_isGranting;
    final String label;
    final VoidCallback? onPressed;

    if (_isCurrentGranted) {
      label = _isHebrew ? 'הבא ←' : 'Next →';
      onPressed = _advanceToNext;
    } else if (_isDenied) {
      label = _isHebrew ? 'נסה שוב' : 'Try Again';
      onPressed = _onGrantPressed;
    } else if (_isGranting) {
      label = '';
      onPressed = null;
    } else {
      label = _isHebrew ? '← הענק' : 'Grant →';
      onPressed = _onGrantPressed;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            height: 56,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  colors: _isCurrentGranted
                      ? [Colors.green.shade700, Colors.green.shade500]
                      : [const Color(0xFF1A1A1A), const Color(0xFF333333)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: (_isCurrentGranted ? Colors.green : _dark)
                        .withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: onPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shadowColor: Colors.transparent,
                  disabledBackgroundColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isGranting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Text(
                        label,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
              ),
            ),
          ),
          if (showSkipOptional) ...[
            const SizedBox(height: 10),
            TextButton(
              onPressed: _skipOptionalStep,
              child: Text(
                _isHebrew ? 'דלג לעת עתה' : 'Do this later',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _dark,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWaitingState() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Animated bouncing dots
          AnimatedBuilder(
            animation: _dotsController,
            builder: (_, __) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (i) {
                  final offset = math.sin(
                    (_dotsController.value * 2 * math.pi) - (i * math.pi / 3),
                  );
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: Transform.translate(
                      offset: Offset(0, -6 * offset.clamp(0.0, 1.0)),
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _gold.withValues(
                            alpha: 0.4 + 0.6 * offset.clamp(0.0, 1.0),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              );
            },
          ),
          const SizedBox(height: 12),
          Text(
            _isHebrew
                ? 'אנא אפשר בהגדרות, ואז חזור לכאן'
                : 'Please grant in Settings, then return here',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF888888),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
