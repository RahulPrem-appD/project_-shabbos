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
  late Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    
    _flameController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _fadeIn = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _fadeController.forward();

    _navigateToHome();
  }

  Future<void> _navigateToHome() async {
    await Future.delayed(const Duration(milliseconds: 2800));
    if (!mounted) return;
    
    // Update status bar for light theme
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
        transitionDuration: const Duration(milliseconds: 600),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _flameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Center(
        child: FadeTransition(
          opacity: _fadeIn,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Candles
              AnimatedBuilder(
                animation: _flameController,
                builder: (context, child) {
                  return SizedBox(
                    height: 180,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildCandle(_flameController.value),
                        const SizedBox(width: 24),
                        _buildCandle(1 - _flameController.value),
                      ],
                    ),
                  );
                },
              ),
              
              const SizedBox(height: 48),
              
              // App name
              const Text(
                'Shabbos!!',
                style: TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: 1,
                ),
              ),
              
              const SizedBox(height: 8),
              
              const Text(
                'שבת!!',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFE8B923),
                ),
              ),
              
              const SizedBox(height: 24),
              
              Text(
                'Candle Lighting Times',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.6),
                  letterSpacing: 2,
                ),
              ),
              
              const SizedBox(height: 80),
              
              Text(
                'בס״ד',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCandle(double flicker) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Flame
        Container(
          width: 20 + (flicker * 4),
          height: 50 + (flicker * 8),
          decoration: BoxDecoration(
            gradient: RadialGradient(
              colors: [
                Colors.white,
                const Color(0xFFFFE082),
                const Color(0xFFE8B923),
                const Color(0xFFFF8F00).withValues(alpha: 0.8),
                Colors.transparent,
              ],
              stops: const [0.0, 0.2, 0.4, 0.7, 1.0],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        // Candle body
        Container(
          width: 16,
          height: 80,
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8E1),
            borderRadius: BorderRadius.circular(2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFE8B923).withValues(alpha: 0.3),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
