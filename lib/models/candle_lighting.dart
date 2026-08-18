class CandleLighting {
  final DateTime date;
  final DateTime candleLightingTime;
  final DateTime? havdalahTime;
  final String? holidayName;
  final String? hebrewHolidayName;
  final bool isShabbat;
  final bool isYomTov;
  // True only for Day 2 of a 2-day (Diaspora) Yom Tov. Always false in Israel.
  // Drives alarm suppression: Day 1 alarms allowed, Day 2 alarms blocked.
  final bool isSecondDayYomTov;
  final String? hebrewDate; // Hebrew date string (e.g., "כ״ב כסלו תשפ״ה")
  final String? parasha; // Torah portion name (e.g., "Bereshit")
  final String? hebrewParasha; // Torah portion name in Hebrew (e.g., "בראשית")

  CandleLighting({
    required this.date,
    required this.candleLightingTime,
    this.havdalahTime,
    this.holidayName,
    this.hebrewHolidayName,
    this.isShabbat = false,
    this.isYomTov = false,
    this.isSecondDayYomTov = false,
    this.hebrewDate,
    this.parasha,
    this.hebrewParasha,
  });

  String get displayName {
    // If it's Yom Tov, show holiday name
    if (isYomTov && holidayName != null && holidayName!.isNotEmpty) {
      return holidayName!;
    }
    // If it's Shabbat with a parasha, show the parasha name
    if (isShabbat && parasha != null && parasha!.isNotEmpty) {
      return parasha!;
    }
    // Default
    return isShabbat ? 'Shabbat' : 'Yom Tov';
  }

  String get hebrewDisplayName {
    // If it's Yom Tov, show Hebrew holiday name
    if (isYomTov && hebrewHolidayName != null && hebrewHolidayName!.isNotEmpty) {
      return hebrewHolidayName!;
    }
    // If it's Shabbat with a parasha, show the Hebrew parasha name
    if (isShabbat && hebrewParasha != null && hebrewParasha!.isNotEmpty) {
      return hebrewParasha!;
    }
    // Default
    return isShabbat ? 'שבת' : 'יום טוב';
  }

  @override
  String toString() {
    return 'CandleLighting(date: $date, candleLighting: $candleLightingTime, holiday: $holidayName)';
  }
}

class LocationInfo {
  final double latitude;
  final double longitude;
  final String? cityName;
  final String? country;
  final String? timezone;
  // True when [timezone] came from a trusted source (the city list or the
  // Hebcal tzid lookup). False when it was estimated from longitude — an
  // estimate can be a DST-observing zone the location doesn't follow, so
  // unvalidated timezones are re-checked against Hebcal on load and healed.
  // Absent in previously-saved locations → false → they heal on next load.
  final bool tzValidated;

  LocationInfo({
    required this.latitude,
    required this.longitude,
    this.cityName,
    this.country,
    this.timezone,
    this.tzValidated = false,
  });

  LocationInfo copyWith({String? timezone, bool? tzValidated}) => LocationInfo(
    latitude: latitude,
    longitude: longitude,
    cityName: cityName,
    country: country,
    timezone: timezone ?? this.timezone,
    tzValidated: tzValidated ?? this.tzValidated,
  );

  Map<String, dynamic> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
    'cityName': cityName,
    'country': country,
    'timezone': timezone,
    'tzValidated': tzValidated,
  };

  factory LocationInfo.fromJson(Map<String, dynamic> json) => LocationInfo(
    latitude: json['latitude'] as double,
    longitude: json['longitude'] as double,
    cityName: json['cityName'] as String?,
    country: json['country'] as String?,
    timezone: json['timezone'] as String?,
    tzValidated: json['tzValidated'] as bool? ?? false,
  );

  String get displayName {
    if (cityName != null && country != null) {
      return '$cityName, $country';
    }
    return cityName ?? 'Unknown Location';
  }
}

