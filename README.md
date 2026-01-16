# Shabbos!! שבת!!

בס״ד

**Shabbat & Yom Tov Candle Lighting**

הדלקת נרות שבת ויום טוב

---

A simple, clean Flutter app designed to help you prepare for Shabbat and Yom Tov with peaceful audio reminders.

## Features

- 🕯️ **Candle Lighting Times** - Accurate times calculated using HebCal (Hebrew Calendar)
- 📍 **Location Support** - Automatic GPS or manual city selection from 45+ major Jewish communities
- 🔔 **Two Notifications**:
  - 20 minutes before candle lighting (gentle reminder)
  - At candle lighting time (different sound)
- 🎵 **Custom Sounds** - Built-in sounds or upload your own audio file (offline-friendly, no streaming)
- 🌐 **Bilingual** - Full English and Hebrew (עברית) support with RTL
- 🔒 **Privacy First** - No accounts, no servers, no data collection

## The Name

**Shabbos!!** - The two exclamation points symbolize the two Shabbat candles.

## Yom Tov Logic

- Yom Tov reminders occur **only on the first day**
- No reminders on the second day of Yom Tov
- Same reminder structure as Shabbat

## Design

- Clean white background with black text
- Animated candle flames
- בס״ד in the upper right corner
- Simple, calm, respectful, uncluttered
- No ads

## Technical Details

### Platforms
- **iOS** 12.0+
- **Android** API 21+ (Android 5.0 Lollipop)

### Requirements
- Flutter 3.8.0 or higher

### Dependencies
- `flutter_local_notifications` - Local notification scheduling
- `geolocator` & `geocoding` - Location services
- `http` - HebCal API integration
- `audioplayers` - Sound playback
- `shared_preferences` - Local settings storage
- `timezone` - Timezone handling

### Building

```bash
# Get dependencies
flutter pub get

# Run on connected device
flutter run

# Build for release
flutter build apk --release  # Android
flutter build ios --release  # iOS
```

## Permissions

The app requests the following permissions:
- **Location** - To calculate accurate candle lighting times for your area
- **Notifications** - To send reminders before Shabbat/Yom Tov

## Data Source

Candle lighting times are calculated using [HebCal](https://www.hebcal.com/), a trusted Hebrew calendar service. Times are based on the Hebrew calendar and your location.

---

## Dedication

This app is dedicated to the loving and blessed memory of my father
**Shmuel Hirsh ben Mordechai Menachem Mendel ז״ל**,
my mother **Betty bas Yechiel ע״ה**,
and my wife's father **Levi ben Ephraim ז״ל**.

May their neshamos continue to rise higher and higher in Gan Eden,
and may they be meilitzei tov for their entire family
and for all of Klal Yisrael.

---

שבת שלום! Good Shabbos!
