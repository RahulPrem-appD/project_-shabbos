// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Shabbos!!';

  @override
  String get appSubtitle => 'Candle Lighting Alert for Shabbat and Yom Tov';

  @override
  String get bsd => 'בס\"ד';

  @override
  String get home => 'Home';

  @override
  String get settings => 'Settings';

  @override
  String get about => 'About';

  @override
  String get candleLighting => 'Candle Lighting';

  @override
  String get shabbat => 'Shabbat';

  @override
  String get yomTov => 'Yom Tov';

  @override
  String get today => 'Today';

  @override
  String get thisWeek => 'This Week';

  @override
  String get upcoming => 'Upcoming';

  @override
  String get noUpcoming => 'No upcoming candle lighting times';

  @override
  String get location => 'Location';

  @override
  String get currentLocation => 'Current Location';

  @override
  String get selectCity => 'Select City';

  @override
  String get useGPS => 'Use GPS Location';

  @override
  String get manualLocation => 'Manual Location';

  @override
  String get notifications => 'Notifications';

  @override
  String get enableNotifications => 'Enable Notifications';

  @override
  String get notificationTime => 'Notification Time';

  @override
  String minutesBefore(int minutes) {
    return '$minutes minutes before';
  }

  @override
  String get atCandleLighting => 'At candle lighting time';

  @override
  String get sound => 'Sound';

  @override
  String get selectSound => 'Select Sound';

  @override
  String get defaultSound => 'Default';

  @override
  String get customSound => 'Custom Sound';

  @override
  String get uploadSound => 'Upload Sound';

  @override
  String get chooseFile => 'Choose File';

  @override
  String get language => 'Language';

  @override
  String get english => 'English';

  @override
  String get hebrew => 'עברית';

  @override
  String get aboutApp => 'About This App';

  @override
  String get aboutDescription =>
      'Shabbos!! is a simple app designed to help you prepare for Shabbat and Yom Tov with peaceful audio reminders before candle lighting time.';

  @override
  String get dedication => 'Dedication';

  @override
  String get dedicationText =>
      'This app is dedicated in loving memory of my parents and my wife\'s father, of blessed memory. May their neshamot have an aliyah.';

  @override
  String get version => 'Version';

  @override
  String get friday => 'Friday';

  @override
  String get saturday => 'Saturday';

  @override
  String get candleLightingTime => 'Candle Lighting Time';

  @override
  String get havdalah => 'Havdalah';

  @override
  String get loading => 'Loading...';

  @override
  String get error => 'Error';

  @override
  String get retry => 'Retry';

  @override
  String get locationPermissionDenied => 'Location permission denied';

  @override
  String get locationPermissionRequired =>
      'Location permission is required to calculate accurate candle lighting times for your area.';

  @override
  String get grantPermission => 'Grant Permission';

  @override
  String get testNotification => 'Test Notification';

  @override
  String get testSound => 'Test Sound';

  @override
  String get soundSettings => 'Sound Settings';

  @override
  String get notificationSettings => 'Notification Settings';

  @override
  String get locationSettings => 'Location Settings';

  @override
  String get preCandle => 'Pre-Candle Lighting';

  @override
  String get preNotificationDesc => 'Notification before candle lighting';

  @override
  String get candleNotificationDesc => 'Notification at candle lighting time';

  @override
  String get goodShabbos => 'Good Shabbos!';

  @override
  String get shabbosComing => 'Shabbos is coming!';

  @override
  String get yomTovComing => 'Yom Tov is coming!';

  @override
  String get timeToLight => 'Time to light candles';

  @override
  String get prepareForShabbos => 'Prepare for Shabbos';

  @override
  String get prepareForYomTov => 'Prepare for Yom Tov';
}
