import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0A0A0A),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  runApp(const ShabbosApp());
}

class ShabbosApp extends StatefulWidget {
  const ShabbosApp({super.key});

  @override
  State<ShabbosApp> createState() => _ShabbosAppState();
}

class _ShabbosAppState extends State<ShabbosApp> {
  String _locale = 'en';
  bool _ready = false;

  // Key to force rebuild of entire widget tree when locale changes
  Key _appKey = UniqueKey();

  String get locale => _locale;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _locale = prefs.getString('app_language') ?? 'en';
      _ready = true;
    });
  }

  void setLocale(String locale) async {
    if (_locale == locale) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_language', locale);

    setState(() {
      _locale = locale;
      // Generate new key to force complete rebuild
      _appKey = UniqueKey();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const MaterialApp(
        home: Scaffold(
          backgroundColor: Color(0xFF0A0A0A),
          body: Center(
            child: CircularProgressIndicator(color: Color(0xFFE8B923)),
          ),
        ),
      );
    }

    return KeyedSubtree(
      key: _appKey,
      child: MaterialApp(
        title: 'Shabbos!!',
        debugShowCheckedModeBanner: false,
        locale: Locale(_locale),
        supportedLocales: const [Locale('en'), Locale('he')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.light,
          scaffoldBackgroundColor: Colors.white,
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF1A1A1A),
            secondary: Color(0xFFE8B923),
            surface: Colors.white,
            onPrimary: Colors.white,
            onSecondary: Color(0xFF1A1A1A),
            onSurface: Color(0xFF1A1A1A),
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.white,
            foregroundColor: Color(0xFF1A1A1A),
            elevation: 0,
            centerTitle: false,
          ),
          textTheme: const TextTheme(
            headlineLarge: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A1A),
              letterSpacing: -0.5,
            ),
            headlineMedium: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A1A),
            ),
            titleLarge: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A1A),
            ),
            bodyLarge: TextStyle(fontSize: 16, color: Color(0xFF1A1A1A)),
            bodyMedium: TextStyle(fontSize: 14, color: Color(0xFF666666)),
          ),
        ),
        builder: (context, child) {
          return Directionality(
            textDirection: _locale == 'he'
                ? TextDirection.rtl
                : TextDirection.ltr,
            child: child!,
          );
        },
        home: SplashScreen(locale: _locale, onLocaleChanged: setLocale),
      ),
    );
  }
}
