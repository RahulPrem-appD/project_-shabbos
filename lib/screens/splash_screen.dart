import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'main_shell.dart';

class SplashScreen extends StatefulWidget {
  final String locale;
  final Function(String) onLocaleChanged;

  const SplashScreen({
    super.key,
    required this.locale,
    required this.onLocaleChanged,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // Animation Controllers
  late AnimationController _masterController;
  late AnimationController _flameController1;
  late AnimationController _flameController2;
  late AnimationController _glowPulseController;
  late AnimationController _particleController;
  late AnimationController _shimmerController;
  late AnimationController _breatheController;
  late AnimationController _flickerController;

  // Animations
  late Animation<double> _candleSlide;
  late Animation<double> _candleOpacity;
  late Animation<double> _titleOpacity;
  late Animation<double> _titleSlide;
  late Animation<double> _hebrewOpacity;
  late Animation<double> _subtitleOpacity;
  late Animation<double> _bsdOpacity;
  late Animation<double> _ringExpand;
  late Animation<double> _ringOpacity;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _startAnimationSequence();
  }

  void _initAnimations() {
    _masterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    );

    // Two separate flame controllers for independent movement
    _flameController1 = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _flameController2 = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);

    // Random flicker effect
    _flickerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    )..repeat(reverse: true);

    _glowPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);

    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 8000),
    )..repeat();

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat();

    _breatheController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5000),
    )..repeat(reverse: true);

    // Sequenced animations
    _candleSlide = Tween<double>(begin: 40.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _masterController,
        curve: const Interval(0.1, 0.4, curve: Curves.easeOutCubic),
      ),
    );

    _candleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _masterController,
        curve: const Interval(0.1, 0.35, curve: Curves.easeOut),
      ),
    );

    _titleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _masterController,
        curve: const Interval(0.35, 0.55, curve: Curves.easeOut),
      ),
    );

    _titleSlide = Tween<double>(begin: 25.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _masterController,
        curve: const Interval(0.35, 0.6, curve: Curves.easeOutCubic),
      ),
    );

    _hebrewOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _masterController,
        curve: const Interval(0.45, 0.65, curve: Curves.easeOut),
      ),
    );

    _subtitleOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _masterController,
        curve: const Interval(0.6, 0.8, curve: Curves.easeOut),
      ),
    );

    _bsdOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _masterController,
        curve: const Interval(0.7, 0.9, curve: Curves.easeOut),
      ),
    );

    _ringExpand = Tween<double>(begin: 0.6, end: 1.4).animate(
      CurvedAnimation(
        parent: _masterController,
        curve: const Interval(0.15, 0.5, curve: Curves.easeOut),
      ),
    );

    _ringOpacity = Tween<double>(begin: 0.6, end: 0.0).animate(
      CurvedAnimation(
        parent: _masterController,
        curve: const Interval(0.15, 0.5, curve: Curves.easeOut),
      ),
    );
  }

  void _startAnimationSequence() {
    _masterController.forward();
    _navigateToHome();
  }

  Future<void> _navigateToHome() async {
    await Future.delayed(const Duration(milliseconds: 4500));
    if (!mounted) return;

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => MainShell(
          locale: widget.locale,
          onLocaleChanged: widget.onLocaleChanged,
        ),
        transitionDuration: const Duration(milliseconds: 900),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeInOut,
            ),
            child: child,
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _masterController.dispose();
    _flameController1.dispose();
    _flameController2.dispose();
    _flickerController.dispose();
    _glowPulseController.dispose();
    _particleController.dispose();
    _shimmerController.dispose();
    _breatheController.dispose();
    super.dispose();
  }

  bool get isHebrew => widget.locale == 'he';

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF020204),
      body: Stack(
        children: [
          _buildAnimatedBackground(size),
          _buildParticles(size),
          _buildMainContent(size),
          _buildVignette(size),
        ],
      ),
    );
  }

  Widget _buildAnimatedBackground(Size size) {
    return AnimatedBuilder(
      animation: Listenable.merge([_breatheController, _glowPulseController]),
      builder: (context, child) {
        final breathe = Curves.easeInOut.transform(_breatheController.value);
        final glow = _glowPulseController.value;

        return Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0, -0.25 + breathe * 0.05),
              radius: 1.3,
              colors: [
                Color.lerp(
                  const Color(0xFF1A0D02),
                  const Color(0xFF251205),
                  glow,
                )!,
                const Color(0xFF0A0505),
                const Color(0xFF020204),
              ],
              stops: const [0.0, 0.4, 1.0],
            ),
          ),
        );
      },
    );
  }

  Widget _buildParticles(Size size) {
    return AnimatedBuilder(
      animation: Listenable.merge([_particleController, _masterController]),
      builder: (context, child) {
        return CustomPaint(
          size: size,
          painter: _SmokeParticlePainter(
            progress: _particleController.value,
            opacity: _candleOpacity.value,
          ),
        );
      },
    );
  }

  Widget _buildMainContent(Size size) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _masterController,
        _flameController1,
        _flameController2,
        _glowPulseController,
        _shimmerController,
        _flickerController,
      ]),
      builder: (context, child) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),

              // בס״ד
              Opacity(opacity: _bsdOpacity.value, child: _buildBSD()),

              SizedBox(height: size.height * 0.03),

              // Realistic Candles
              Transform.translate(
                offset: Offset(0, _candleSlide.value),
                child: Opacity(
                  opacity: _candleOpacity.value,
                  child: _buildRealisticCandles(size),
                ),
              ),

              SizedBox(height: size.height * 0.04),

              // Primary title (bigger and first) - Hebrew for Hebrew locale, English for English locale
              Transform.translate(
                offset: Offset(0, _titleSlide.value),
                child: Opacity(
                  opacity: _titleOpacity.value,
                  child: isHebrew ? _buildHebrewTitle() : _buildEnglishTitlePrimary(),
                ),
              ),

              const SizedBox(height: 6),

              // Secondary title (smaller)
              Opacity(
                opacity: _hebrewOpacity.value,
                child: isHebrew ? _buildEnglishTitle() : _buildHebrewTitleSecondary(),
              ),

              SizedBox(height: size.height * 0.022),

              // Divider
              Opacity(
                opacity: _subtitleOpacity.value,
                child: _buildElegantDivider(),
              ),

              const SizedBox(height: 14),

              // Subtitles
              Opacity(
                opacity: _subtitleOpacity.value,
                child: _buildSubtitles(),
              ),

              const Spacer(flex: 2),

              // Loading
              Opacity(
                opacity: _subtitleOpacity.value,
                child: _buildLoadingIndicator(),
              ),

              SizedBox(height: size.height * 0.06),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBSD() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(
          color: const Color(0xFFD4A84B).withValues(alpha: 0.4),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Text(
        'בס״ד',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Color(0xFFD4A84B),
          letterSpacing: 3,
        ),
      ),
    );
  }

  Widget _buildRealisticCandles(Size size) {
    final flame1 = _flameController1.value;
    final flame2 = _flameController2.value;
    final glow = _glowPulseController.value;
    final flicker = _flickerController.value;

    return SizedBox(
      height: 300,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Soft ambient light on surface
          Positioned(
            bottom: 0,
            child: Container(
              width: 250,
              height: 40,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    const Color(
                      0xFFFF9500,
                    ).withValues(alpha: 0.15 + glow * 0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Expanding ring
          Transform.scale(
            scale: _ringExpand.value,
            child: Opacity(
              opacity: _ringOpacity.value * 0.4,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFFFFAA33),
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),

          // Main glow
          Container(
            width: 200 + glow * 30,
            height: 200 + glow * 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFFFFAA33).withValues(alpha: 0.12 + glow * 0.06),
                  const Color(0xFFFF6600).withValues(alpha: 0.05),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),

          // Two candles
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildSingleCandle(
                flamePhase: flame1,
                flickerPhase: flicker,
                glowIntensity: glow,
                candleHeight: 105,
                seed: 1,
              ),
              const SizedBox(width: 55),
              _buildSingleCandle(
                flamePhase: flame2,
                flickerPhase: 1 - flicker,
                glowIntensity: glow,
                candleHeight: 100,
                seed: 2,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSingleCandle({
    required double flamePhase,
    required double flickerPhase,
    required double glowIntensity,
    required double candleHeight,
    required int seed,
  }) {
    // Natural flame movement with multiple frequencies
    final primaryWave = math.sin(flamePhase * math.pi);
    final secondaryWave = math.sin(flamePhase * math.pi * 2.3 + seed) * 0.3;
    final microFlicker = math.sin(flickerPhase * math.pi * 4) * 0.15;
    final combinedFlame = (primaryWave + secondaryWave + microFlicker).clamp(
      0.0,
      1.0,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Flame assembly
        SizedBox(
          width: 50,
          height: 90,
          child: CustomPaint(
            painter: _RealisticFlamePainter(
              phase: combinedFlame,
              intensity: glowIntensity,
              seed: seed,
            ),
          ),
        ),

        // Wick
        Container(
          width: 2.5,
          height: 7,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF1A1A1A),
                const Color(0xFF2D2518),
                const Color(0xFF3D3025),
              ],
            ),
            borderRadius: BorderRadius.circular(1),
          ),
        ),

        // Melted wax pool at top
        Container(
          width: 22,
          height: 4,
          decoration: BoxDecoration(
            gradient: RadialGradient(
              colors: [const Color(0xFFFFF8E8), const Color(0xFFF5ECD8)],
            ),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(10),
              bottom: Radius.circular(2),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(
                  0xFFFFAA33,
                ).withValues(alpha: 0.3 + glowIntensity * 0.2),
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ],
          ),
        ),

        // Candle body with realistic wax texture
        Container(
          width: 20,
          height: candleHeight,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: const [
                Color(0xFFD8CDB8),
                Color(0xFFF0E8D8),
                Color(0xFFFFFBF2),
                Color(0xFFFFF8E8),
                Color(0xFFF5ECD8),
                Color(0xFFE8DCC8),
              ],
              stops: const [0.0, 0.15, 0.35, 0.65, 0.85, 1.0],
            ),
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(3),
            ),
            boxShadow: [
              // Warm glow from flame
              BoxShadow(
                color: const Color(
                  0xFFFF8800,
                ).withValues(alpha: 0.25 + glowIntensity * 0.15),
                blurRadius: 30,
                spreadRadius: 8,
              ),
              // Subtle shadow
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 4,
                offset: const Offset(2, 0),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Wax drips
              Positioned(
                top: 0,
                left: 1,
                child: _buildWaxDrip(
                  height: 18 + combinedFlame * 4,
                  width: 5,
                  opacity: 0.7,
                ),
              ),
              Positioned(
                top: 8,
                right: 2,
                child: _buildWaxDrip(
                  height: 12 + combinedFlame * 3,
                  width: 4,
                  opacity: 0.5,
                ),
              ),
              Positioned(
                top: 25,
                left: 3,
                child: _buildWaxDrip(height: 8, width: 3.5, opacity: 0.4),
              ),
              // Subtle vertical texture lines
              ...List.generate(3, (i) {
                return Positioned(
                  top: 10,
                  left: 5.0 + i * 4,
                  child: Container(
                    width: 0.5,
                    height: candleHeight - 20,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withValues(alpha: 0.1),
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.03),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),

        // Simple brass holder
        _buildBrassHolder(glowIntensity),
      ],
    );
  }

  Widget _buildWaxDrip({
    required double height,
    required double width,
    required double opacity,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFFFFFDF5).withValues(alpha: opacity),
            const Color(0xFFF8F0E0).withValues(alpha: opacity * 0.8),
          ],
        ),
        borderRadius: BorderRadius.vertical(
          top: const Radius.circular(1),
          bottom: Radius.circular(width / 2),
        ),
      ),
    );
  }

  Widget _buildBrassHolder(double glow) {
    return Column(
      children: [
        // Lip
        Container(
          width: 30,
          height: 5,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFD4A84B), Color(0xFFB8923D)],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
            boxShadow: [
              BoxShadow(
                color: const Color(
                  0xFFD4A84B,
                ).withValues(alpha: 0.2 + glow * 0.1),
                blurRadius: 6,
              ),
            ],
          ),
        ),
        // Cup
        Container(
          width: 26,
          height: 10,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Color(0xFF8B6914),
                Color(0xFFB8923D),
                Color(0xFFD4A84B),
                Color(0xFFB8923D),
                Color(0xFF8B6914),
              ],
              stops: [0.0, 0.25, 0.5, 0.75, 1.0],
            ),
          ),
        ),
        // Base
        Container(
          width: 36,
          height: 8,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFB8923D), Color(0xFF8B6914), Color(0xFF6B5210)],
            ),
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(3),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHebrewTitle() {
    final glow = _glowPulseController.value;
    return ShaderMask(
      shaderCallback: (bounds) {
        final shimmer = _shimmerController.value;
        return LinearGradient(
          begin: Alignment(-1.5 + shimmer * 3, 0),
          end: Alignment(-0.5 + shimmer * 3, 0),
          colors: const [
            Color(0xFFD4A84B),
            Color(0xFFFFE082),
            Color(0xFFD4A84B),
          ],
        ).createShader(bounds);
      },
      blendMode: BlendMode.srcIn,
      child: Text(
        'שבת!!',
        textDirection: TextDirection.ltr,
        style: TextStyle(
          fontSize: 62,
          fontWeight: FontWeight.w800,
          letterSpacing: 10,
          height: 1.1,
          shadows: [
            Shadow(
              color: const Color(
                0xFFD4A84B,
              ).withValues(alpha: 0.6 + glow * 0.25),
              blurRadius: 30 + glow * 15,
            ),
            Shadow(
              color: const Color(0xFFFFAA33).withValues(alpha: 0.3),
              blurRadius: 50,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnglishTitle() {
    return Text(
      'Shabbos!!',
      textDirection: TextDirection.ltr,
      style: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        color: Colors.white.withValues(alpha: 0.85),
        letterSpacing: 4,
        shadows: [
          Shadow(
            color: const Color(0xFFD4A84B).withValues(alpha: 0.3),
            blurRadius: 15,
          ),
        ],
      ),
    );
  }

  // Primary English title (for English locale)
  Widget _buildEnglishTitlePrimary() {
    final glow = _glowPulseController.value;
    return ShaderMask(
      shaderCallback: (bounds) {
        final shimmer = _shimmerController.value;
        return LinearGradient(
          begin: Alignment(-1.5 + shimmer * 3, 0),
          end: Alignment(-0.5 + shimmer * 3, 0),
          colors: const [
            Color(0xFFD4A84B),
            Color(0xFFFFE082),
            Color(0xFFD4A84B),
          ],
        ).createShader(bounds);
      },
      blendMode: BlendMode.srcIn,
      child: Text(
        'Shabbos!!',
        textDirection: TextDirection.ltr,
        style: TextStyle(
          fontSize: 58,
          fontWeight: FontWeight.w800,
          letterSpacing: 6,
          height: 1.1,
          shadows: [
            Shadow(
              color: const Color(
                0xFFD4A84B,
              ).withValues(alpha: 0.6 + glow * 0.25),
              blurRadius: 30 + glow * 15,
            ),
            Shadow(
              color: const Color(0xFFFFAA33).withValues(alpha: 0.3),
              blurRadius: 50,
            ),
          ],
        ),
      ),
    );
  }

  // Secondary Hebrew title (for English locale)
  Widget _buildHebrewTitleSecondary() {
    return Text(
      'שבת!!',
      textDirection: TextDirection.ltr,
      style: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        color: Colors.white.withValues(alpha: 0.85),
        letterSpacing: 4,
        shadows: [
          Shadow(
            color: const Color(0xFFD4A84B).withValues(alpha: 0.3),
            blurRadius: 15,
          ),
        ],
      ),
    );
  }

  Widget _buildElegantDivider() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 50,
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.transparent,
                const Color(0xFFD4A84B).withValues(alpha: 0.6),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Transform.rotate(
          angle: math.pi / 4,
          child: Container(width: 6, height: 6, color: const Color(0xFFD4A84B)),
        ),
        const SizedBox(width: 12),
        Container(
          width: 50,
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFFD4A84B).withValues(alpha: 0.6),
                Colors.transparent,
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubtitles() {
    if (isHebrew) {
      // Hebrew locale: Hebrew first (primary), English second
      return Column(
        children: [
          Text(
            'התראת הדלקת נרות לשבת וליום טוב',
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.6),
              letterSpacing: 1,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'CANDLE LIGHTING ALERT\nFOR SHABBAT AND YOM TOV',
            textDirection: TextDirection.ltr,
            style: TextStyle(
              fontSize: 10,
              color: Colors.white.withValues(alpha: 0.45),
              letterSpacing: 3,
              fontWeight: FontWeight.w400,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      );
    } else {
      // English locale: English first (primary), Hebrew second
      return Column(
        children: [
          Text(
            'CANDLE LIGHTING ALERT\nFOR SHABBAT AND YOM TOV',
            textDirection: TextDirection.ltr,
            style: TextStyle(
              fontSize: 10,
              color: Colors.white.withValues(alpha: 0.6),
              letterSpacing: 3,
              fontWeight: FontWeight.w400,
              height: 1.6,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'התראת הדלקת נרות לשבת וליום טוב',
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.45),
              letterSpacing: 1,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      );
    }
  }

  Widget _buildLoadingIndicator() {
    return SizedBox(
      width: 28,
      height: 28,
      child: CircularProgressIndicator(
        strokeWidth: 1.5,
        valueColor: AlwaysStoppedAnimation<Color>(
          const Color(0xFFD4A84B).withValues(alpha: 0.6),
        ),
      ),
    );
  }

  Widget _buildVignette(Size size) {
    return IgnorePointer(
      child: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.1,
            colors: [
              Colors.transparent,
              Colors.black.withValues(alpha: 0.4),
              Colors.black.withValues(alpha: 0.8),
            ],
            stops: const [0.3, 0.75, 1.0],
          ),
        ),
      ),
    );
  }
}

// Realistic flame painter with natural movement
class _RealisticFlamePainter extends CustomPainter {
  final double phase;
  final double intensity;
  final int seed;

  _RealisticFlamePainter({
    required this.phase,
    required this.intensity,
    required this.seed,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final baseY = size.height;

    // Flame sway
    final sway = math.sin(phase * math.pi + seed) * 2;

    // Outer glow (very soft)
    final glowPaint = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15);

    glowPaint.shader = RadialGradient(
      center: Alignment(sway * 0.02, 0.3),
      radius: 0.8,
      colors: [
        const Color(0xFFFF6600).withValues(alpha: 0.3 * intensity),
        const Color(0xFFFF4400).withValues(alpha: 0.1 * intensity),
        Colors.transparent,
      ],
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(centerX + sway, baseY * 0.5),
        width: size.width * 0.9,
        height: size.height * 0.8,
      ),
      glowPaint,
    );

    // Outer flame (orange/red)
    final outerPath = Path();
    final outerWidth = 12 + phase * 3;
    final outerHeight = 55 + phase * 12;

    outerPath.moveTo(centerX, baseY);
    outerPath.quadraticBezierTo(
      centerX - outerWidth - sway,
      baseY - outerHeight * 0.4,
      centerX - outerWidth * 0.3 + sway,
      baseY - outerHeight * 0.75,
    );
    outerPath.quadraticBezierTo(
      centerX + sway * 0.5,
      baseY - outerHeight - phase * 5,
      centerX + outerWidth * 0.3 + sway,
      baseY - outerHeight * 0.75,
    );
    outerPath.quadraticBezierTo(
      centerX + outerWidth - sway,
      baseY - outerHeight * 0.4,
      centerX,
      baseY,
    );

    final outerPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          const Color(0xFFFFAA33),
          const Color(0xFFFF7700),
          const Color(0xFFFF4400).withValues(alpha: 0.8),
          const Color(0xFFCC2200).withValues(alpha: 0.3),
          Colors.transparent,
        ],
        stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(outerPath, outerPaint);

    // Middle flame (yellow/orange)
    final middlePath = Path();
    final middleWidth = 8 + phase * 2;
    final middleHeight = 42 + phase * 8;

    middlePath.moveTo(centerX, baseY - 2);
    middlePath.quadraticBezierTo(
      centerX - middleWidth - sway * 0.7,
      baseY - middleHeight * 0.45,
      centerX + sway * 0.3,
      baseY - middleHeight,
    );
    middlePath.quadraticBezierTo(
      centerX + middleWidth - sway * 0.7,
      baseY - middleHeight * 0.45,
      centerX,
      baseY - 2,
    );

    final middlePaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          const Color(0xFFFFDD66),
          const Color(0xFFFFBB33),
          const Color(0xFFFF8800).withValues(alpha: 0.6),
          Colors.transparent,
        ],
        stops: const [0.0, 0.35, 0.7, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(middlePath, middlePaint);

    // Inner flame (white/yellow core)
    final innerPath = Path();
    final innerWidth = 4 + phase * 1.5;
    final innerHeight = 25 + phase * 6;

    innerPath.moveTo(centerX, baseY - 3);
    innerPath.quadraticBezierTo(
      centerX - innerWidth,
      baseY - innerHeight * 0.5,
      centerX + sway * 0.2,
      baseY - innerHeight,
    );
    innerPath.quadraticBezierTo(
      centerX + innerWidth,
      baseY - innerHeight * 0.5,
      centerX,
      baseY - 3,
    );

    final innerPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          const Color(0xFFFFFFF8),
          const Color(0xFFFFFFE0),
          const Color(0xFFFFEEAA).withValues(alpha: 0.8),
          Colors.transparent,
        ],
        stops: const [0.0, 0.3, 0.6, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(innerPath, innerPaint);

    // Bright core spot
    final corePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    canvas.drawOval(
      Rect.fromCenter(center: Offset(centerX, baseY - 8), width: 6, height: 10),
      corePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RealisticFlamePainter oldDelegate) {
    return oldDelegate.phase != phase || oldDelegate.intensity != intensity;
  }
}

// Smoke/heat particle painter
class _SmokeParticlePainter extends CustomPainter {
  final double progress;
  final double opacity;

  _SmokeParticlePainter({required this.progress, required this.opacity});

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(42);
    final paint = Paint();

    // Smoke wisps rising from flames
    for (int i = 0; i < 15; i++) {
      final baseX = size.width * 0.4 + random.nextDouble() * size.width * 0.2;
      final baseY = size.height * 0.32;
      final speed = 0.15 + random.nextDouble() * 0.25;
      final particleProgress = (progress * speed + i * 0.06) % 1.0;

      final drift = math.sin(particleProgress * math.pi * 3 + i * 0.5) * 25;
      final x = baseX + drift;
      final y = baseY - particleProgress * size.height * 0.25;

      final fadeIn = particleProgress < 0.15 ? particleProgress / 0.15 : 1.0;
      final fadeOut = particleProgress > 0.6
          ? (1.0 - particleProgress) / 0.4
          : 1.0;
      final particleOpacity = opacity * fadeIn * fadeOut * 0.15;

      paint.color = Colors.white.withValues(alpha: particleOpacity);
      paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

      canvas.drawCircle(
        Offset(x, y),
        3 + random.nextDouble() * 4 + particleProgress * 6,
        paint,
      );
    }

    // Tiny ember sparks
    paint.maskFilter = null;
    for (int i = 0; i < 20; i++) {
      final baseX = size.width * 0.35 + random.nextDouble() * size.width * 0.3;
      final baseY = size.height * 0.35;
      final speed = 0.3 + random.nextDouble() * 0.5;
      final particleProgress = (progress * speed + i * 0.04) % 1.0;

      final wobble = math.sin(particleProgress * math.pi * 5 + i) * 12;
      final x = baseX + wobble;
      final y = baseY - particleProgress * size.height * 0.2;

      final fadeIn = particleProgress < 0.1 ? particleProgress / 0.1 : 1.0;
      final fadeOut = particleProgress > 0.7
          ? (1.0 - particleProgress) / 0.3
          : 1.0;
      final particleOpacity =
          opacity * fadeIn * fadeOut * (0.3 + random.nextDouble() * 0.4);

      paint.color = Color.lerp(
        const Color(0xFFFFAA33),
        const Color(0xFFFFDD88),
        random.nextDouble(),
      )!.withValues(alpha: particleOpacity);

      canvas.drawCircle(Offset(x, y), 0.8 + random.nextDouble() * 1.2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SmokeParticlePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.opacity != opacity;
  }
}
