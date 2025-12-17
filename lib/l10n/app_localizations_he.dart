// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hebrew (`he`).
class AppLocalizationsHe extends AppLocalizations {
  AppLocalizationsHe([String locale = 'he']) : super(locale);

  @override
  String get appTitle => '!!שבת';

  @override
  String get appSubtitle => 'התראת הדלקת נרות לשבת וליום טוב';

  @override
  String get bsd => 'בס\"ד';

  @override
  String get home => 'בית';

  @override
  String get settings => 'הגדרות';

  @override
  String get about => 'אודות';

  @override
  String get candleLighting => 'הדלקת נרות';

  @override
  String get shabbat => 'שבת';

  @override
  String get yomTov => 'יום טוב';

  @override
  String get today => 'היום';

  @override
  String get thisWeek => 'השבוע';

  @override
  String get upcoming => 'קרוב';

  @override
  String get noUpcoming => 'אין זמני הדלקת נרות קרובים';

  @override
  String get location => 'מיקום';

  @override
  String get currentLocation => 'מיקום נוכחי';

  @override
  String get selectCity => 'בחר עיר';

  @override
  String get useGPS => 'השתמש במיקום GPS';

  @override
  String get manualLocation => 'מיקום ידני';

  @override
  String get notifications => 'התראות';

  @override
  String get enableNotifications => 'הפעל התראות';

  @override
  String get notificationTime => 'זמן התראה';

  @override
  String minutesBefore(int minutes) {
    return '$minutes דקות לפני';
  }

  @override
  String get atCandleLighting => 'בזמן הדלקת נרות';

  @override
  String get sound => 'צליל';

  @override
  String get selectSound => 'בחר צליל';

  @override
  String get defaultSound => 'ברירת מחדל';

  @override
  String get customSound => 'צליל מותאם';

  @override
  String get uploadSound => 'העלה צליל';

  @override
  String get chooseFile => 'בחר קובץ';

  @override
  String get language => 'שפה';

  @override
  String get english => 'English';

  @override
  String get hebrew => 'עברית';

  @override
  String get aboutApp => 'אודות האפליקציה';

  @override
  String get aboutDescription =>
      '!!שבת היא אפליקציה פשוטה שנועדה לעזור לך להתכונן לשבת ויום טוב עם תזכורות שמע שקטות לפני הדלקת נרות.';

  @override
  String get dedication => 'הקדשה';

  @override
  String get dedicationText =>
      'אפליקציה זו מוקדשת לזכר הורי והורי אשתי, זכרונם לברכה. יהי זכרם ברוך.';

  @override
  String get version => 'גרסה';

  @override
  String get friday => 'יום שישי';

  @override
  String get saturday => 'שבת';

  @override
  String get candleLightingTime => 'זמן הדלקת נרות';

  @override
  String get havdalah => 'הבדלה';

  @override
  String get loading => 'טוען...';

  @override
  String get error => 'שגיאה';

  @override
  String get retry => 'נסה שוב';

  @override
  String get locationPermissionDenied => 'הרשאת מיקום נדחתה';

  @override
  String get locationPermissionRequired =>
      'נדרשת הרשאת מיקום לחישוב זמני הדלקת נרות מדויקים לאזור שלך.';

  @override
  String get grantPermission => 'הענק הרשאה';

  @override
  String get testNotification => 'בדוק התראה';

  @override
  String get testSound => 'בדוק צליל';

  @override
  String get soundSettings => 'הגדרות צליל';

  @override
  String get notificationSettings => 'הגדרות התראות';

  @override
  String get locationSettings => 'הגדרות מיקום';

  @override
  String get preCandle => 'לפני הדלקת נרות';

  @override
  String get preNotificationDesc => 'התראה לפני הדלקת נרות';

  @override
  String get candleNotificationDesc => 'התראה בזמן הדלקת נרות';

  @override
  String get goodShabbos => '!שבת שלום';

  @override
  String get shabbosComing => '!שבת מגיעה';

  @override
  String get yomTovComing => '!יום טוב מגיע';

  @override
  String get timeToLight => 'זמן להדליק נרות';

  @override
  String get prepareForShabbos => 'התכוננו לשבת';

  @override
  String get prepareForYomTov => 'התכוננו ליום טוב';
}
