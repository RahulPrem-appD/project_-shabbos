class CandleLighting {
  final DateTime date;
  final DateTime candleLightingTime;
  final DateTime? havdalahTime;
  final String? holidayName;
  final String? hebrewHolidayName;
  final bool isShabbat;
  final bool isYomTov;
  final String? hebrewDate; // Hebrew date string (e.g., "כ״ב כסלו תשפ״ה")

  CandleLighting({
    required this.date,
    required this.candleLightingTime,
    this.havdalahTime,
    this.holidayName,
    this.hebrewHolidayName,
    this.isShabbat = false,
    this.isYomTov = false,
    this.hebrewDate,
  });

  String get displayName {
    if (holidayName != null && holidayName!.isNotEmpty) {
      return holidayName!;
    }
    return isShabbat ? 'Shabbat' : 'Yom Tov';
  }

  String get hebrewDisplayName {
    if (hebrewHolidayName != null && hebrewHolidayName!.isNotEmpty) {
      return hebrewHolidayName!;
    }
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

  LocationInfo({
    required this.latitude,
    required this.longitude,
    this.cityName,
    this.country,
    this.timezone,
  });

  Map<String, dynamic> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
    'cityName': cityName,
    'country': country,
    'timezone': timezone,
  };

  factory LocationInfo.fromJson(Map<String, dynamic> json) => LocationInfo(
    latitude: json['latitude'] as double,
    longitude: json['longitude'] as double,
    cityName: json['cityName'] as String?,
    country: json['country'] as String?,
    timezone: json['timezone'] as String?,
  );

  String get displayName {
    if (cityName != null && country != null) {
      return '$cityName, $country';
    }
    return cityName ?? 'Unknown Location';
  }
}

