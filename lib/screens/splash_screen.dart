import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'home_screen.dart';

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

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _flameController;
  late AnimationController _glowController;
  late AnimationController _textController;
  late AnimationController _particleController;
  
  late Animation<double> _fadeIn;
  late Animation<double> _titleSlide;
  late Animation<double> _subtitleFade;
  late Animation<double> _glowPulse;

  @override
  void initState() {
    super.initState();
    
    // Main fade in
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    
    // Flame flicker
    _flameController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    
    // Glow pulse
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);
    
    // Text animations
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    
    // Particles
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4000),
    )..repeat();

    _fadeIn = CurvedAnimation(
      parent: _fadeController, 
      curve: Curves.easeOutCubic,
    );
    
    _titleSlide = Tween<double>(begin: 30, end: 0).animate(
      CurvedAnimation(
        parent: _textController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
      ),
    );
    
    _subtitleFade = CurvedAnimation(
      parent: _textController,
      curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
    );
    
    _glowPulse = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    // Start animations
    _fadeController.forward();
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _textController.forward();
    });

    _navigateToHome();
  }

  Future<void> _navigateToHome() async {
    await Future.delayed(const Duration(milliseconds: 3500));
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
        pageBuilder: (_, __, ___) => HomeScreen(
          locale: widget.locale,
          onLocaleChanged: widget.onLocaleChanged,
        ),
        transitionDuration: const Duration(milliseconds: 800),
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
    _fadeController.dispose();
    _flameController.dispose();
    _glowController.dispose();
    _textController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    
    return Scaffold(
      backgroundColor: const Color(0xFF050508),
      body: Stack(
        children: [
          // Background gradient
          AnimatedBuilder(
            animation: _glowController,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.3),
                    radius: 1.2,
                    colors: [
                      Color.lerp(
                        const Color(0xFF1A1008),
                        const Color(0xFF2A1810),
                        _glowPulse.value,
                      )!,
                      const Color(0xFF0A0808),
                      const Color(0xFF050508),
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              );
            },
          ),
          
          // Floating particles
          AnimatedBuilder(
            animation: _particleController,
            builder: (context, child) {
              return CustomPaint(
                size: size,
                painter: _ParticlePainter(
                  progress: _particleController.value,
                  opacity: _fadeIn.value * 0.6,
                ),
              );
            },
          ),
          
          // Main content
          Center(
            child: FadeTransition(
              opacity: _fadeIn,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(flex: 2),
                  
                  // בס״ד at top
                  AnimatedBuilder(
                    animation: _subtitleFade,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _subtitleFade.value * 0.5,
                        child: const Text(
                          'בס״ד',
                          style: TextStyle(
                            fontSize: 16,
                            color: Color(0xFFE8B923),
                            letterSpacing: 2,
                          ),
                        ),
                      );
                    },
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // Candles with glow
                  AnimatedBuilder(
                    animation: Listenable.merge([_flameController, _glowController]),
                    builder: (context, child) {
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          // Ambient glow behind candles
                          Container(
                            width: 200,
                            height: 200,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  const Color(0xFFE8B923).withValues(alpha: _glowPulse.value * 0.4),
                                  const Color(0xFFFF6B00).withValues(alpha: _glowPulse.value * 0.15),
                                  Colors.transparent,
                                ],
                                stops: const [0.0, 0.4, 1.0],
                              ),
                            ),
                          ),
                          // Candles
                          SizedBox(
                            height: 200,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                _buildCandle(
                                  flicker: _flameController.value,
                                  glowIntensity: _glowPulse.value,
                                  height: 95,
                                ),
                                const SizedBox(width: 32),
                                _buildCandle(
                                  flicker: 1 - _flameController.value,
                                  glowIntensity: _glowPulse.value,
                                  height: 90,
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  
                  const SizedBox(height: 50),
                  
                  // App name with animation
                  AnimatedBuilder(
                    animation: _textController,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(0, _titleSlide.value),
                        child: Opacity(
                          opacity: _textController.value.clamp(0.0, 1.0),
                          child: Column(
                            children: [
                              // English name
                              ShaderMask(
                                shaderCallback: (bounds) => const LinearGradient(
                                  colors: [
                                    Colors.white,
                                    Color(0xFFFFF8E1),
                                    Colors.white,
                                  ],
                                ).createShader(bounds),
                                child: const Text(
                                  'Shabbos!!',
                                  style: TextStyle(
                                    fontSize: 48,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: 2,
                                    height: 1.1,
                                  ),
                                ),
                              ),
                              
                              const SizedBox(height: 8),
                              
                              // Hebrew name with golden glow
                              Text(
                                'שבת!!',
                                style: TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFFE8B923),
                                  shadows: [
                                    Shadow(
                                      color: const Color(0xFFE8B923).withValues(alpha: 0.5),
                                      blurRadius: 20,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Subtitle
                  AnimatedBuilder(
                    animation: _subtitleFade,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _subtitleFade.value,
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                              decoration: BoxDecoration(
                                border: Border(
                                  top: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.1),
                                    width: 1,
                                  ),
                                  bottom: BorderSide(
                                    color: Colors.white.withValues(alpha: 0.1),
                                    width: 1,
                                  ),
                                ),
                              ),
                              child: Text(
                                'CANDLE LIGHTING TIMES',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withValues(alpha: 0.6),
                                  letterSpacing: 4,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'הדלקת נרות שבת ויום טוב',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withValues(alpha: 0.4),
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  
                  const Spacer(flex: 3),
                  
                  // Loading indicator
                  AnimatedBuilder(
                    animation: _subtitleFade,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _subtitleFade.value * 0.6,
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              const Color(0xFFE8B923).withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  
                  const SizedBox(height: 60),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCandle({
    required double flicker,
    required double glowIntensity,
    required double height,
  }) {
    // Add some randomness to make flames more natural
    final flickerOffset = math.sin(flicker * math.pi) * 0.5 + 0.5;
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Flame with multiple layers
        Stack(
          alignment: Alignment.bottomCenter,
          children: [
            // Outer glow
            Container(
              width: 40 + (flickerOffset * 8),
              height: 70 + (flickerOffset * 15),
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, 0.3),
                  colors: [
                    const Color(0xFFFF6B00).withValues(alpha: glowIntensity * 0.3),
                    Colors.transparent,
                  ],
                ),
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            // Middle flame
            Container(
              width: 22 + (flickerOffset * 5),
              height: 55 + (flickerOffset * 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    const Color(0xFFFF6B00).withValues(alpha: 0.6),
                    const Color(0xFFFFAB00),
                    const Color(0xFFFFE082),
                  ],
                  stops: const [0.0, 0.3, 0.6, 1.0],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                  bottomLeft: Radius.circular(8),
                  bottomRight: Radius.circular(8),
                ),
              ),
            ),
            // Inner bright core
            Positioned(
              bottom: 5,
              child: Container(
                width: 10 + (flickerOffset * 2),
                height: 30 + (flickerOffset * 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.white.withValues(alpha: 0.9),
                      const Color(0xFFFFF8E1),
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
        
        // Wick
        Container(
          width: 3,
          height: 6,
          decoration: BoxDecoration(
            color: const Color(0xFF2D2D2D),
            borderRadius: BorderRadius.circular(1),
          ),
        ),
        
        // Candle body with gradient
        Container(
          width: 18,
          height: height,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Color(0xFFE8E0D0),
                Color(0xFFFFFBF5),
                Color(0xFFFFF8E1),
                Color(0xFFE8E0D0),
              ],
              stops: [0.0, 0.3, 0.7, 1.0],
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(3),
              bottomRight: Radius.circular(3),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFE8B923).withValues(alpha: glowIntensity * 0.4),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
        ),
        
        // Candle holder
        Container(
          width: 28,
          height: 8,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFD4AF37),
                Color(0xFFAA8C2C),
                Color(0xFF8B7226),
              ],
            ),
            borderRadius: BorderRadius.circular(2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// Particle painter for floating embers effect
class _ParticlePainter extends CustomPainter {
  final double progress;
  final double opacity;
  
  _ParticlePainter({required this.progress, required this.opacity});
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final random = math.Random(42); // Fixed seed for consistent particles
    
    for (int i = 0; i < 20; i++) {
      final baseX = random.nextDouble() * size.width;
      final baseY = size.height * 0.3 + random.nextDouble() * size.height * 0.4;
      final speed = 0.3 + random.nextDouble() * 0.7;
      final particleProgress = (progress * speed + i * 0.05) % 1.0;
      
      final x = baseX + math.sin(particleProgress * math.pi * 2 + i) * 20;
      final y = baseY - particleProgress * size.height * 0.3;
      final particleOpacity = opacity * (1 - particleProgress) * (0.3 + random.nextDouble() * 0.4);
      final particleSize = 1.5 + random.nextDouble() * 2;
      
      paint.color = Color.lerp(
        const Color(0xFFE8B923),
        const Color(0xFFFF6B00),
        random.nextDouble(),
      )!.withValues(alpha: particleOpacity);
      
      canvas.drawCircle(Offset(x, y), particleSize, paint);
    }
  }
  
  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.opacity != opacity;
  }
}
