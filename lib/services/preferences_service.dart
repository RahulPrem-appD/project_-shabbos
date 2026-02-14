import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  static const String _languageKey = 'app_language';
  static const String _firstLaunchKey = 'first_launch';
  static const String _travelTipKey = 'has_seen_travel_tip';

  Future<String> getLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_languageKey) ?? 'en';
  }

  Future<void> setLanguage(String languageCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, languageCode);
  }

  Future<bool> isFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_firstLaunchKey) ?? true;
  }

  Future<void> setFirstLaunchComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_firstLaunchKey, false);
  }

  Future<bool> hasSeenTravelTip() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_travelTipKey) ?? false;
  }

  Future<void> setTravelTipSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_travelTipKey, true);
  }
}

