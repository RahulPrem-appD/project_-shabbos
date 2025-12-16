class City {
  final String name;
  final String hebrewName;
  final String country;
  final double latitude;
  final double longitude;
  final String timezone;

  const City({
    required this.name,
    required this.hebrewName,
    required this.country,
    required this.latitude,
    required this.longitude,
    required this.timezone,
  });

  static const List<City> majorCities = [
    // Israel
    City(name: 'Jerusalem', hebrewName: 'ירושלים', country: 'Israel', latitude: 31.7683, longitude: 35.2137, timezone: 'Asia/Jerusalem'),
    City(name: 'Tel Aviv', hebrewName: 'תל אביב', country: 'Israel', latitude: 32.0853, longitude: 34.7818, timezone: 'Asia/Jerusalem'),
    City(name: 'Haifa', hebrewName: 'חיפה', country: 'Israel', latitude: 32.7940, longitude: 34.9896, timezone: 'Asia/Jerusalem'),
    City(name: 'Bnei Brak', hebrewName: 'בני ברק', country: 'Israel', latitude: 32.0833, longitude: 34.8333, timezone: 'Asia/Jerusalem'),
    City(name: 'Petah Tikva', hebrewName: 'פתח תקווה', country: 'Israel', latitude: 32.0889, longitude: 34.8864, timezone: 'Asia/Jerusalem'),
    City(name: 'Ashdod', hebrewName: 'אשדוד', country: 'Israel', latitude: 31.8044, longitude: 34.6553, timezone: 'Asia/Jerusalem'),
    City(name: 'Netanya', hebrewName: 'נתניה', country: 'Israel', latitude: 32.3286, longitude: 34.8567, timezone: 'Asia/Jerusalem'),
    City(name: 'Beersheba', hebrewName: 'באר שבע', country: 'Israel', latitude: 31.2518, longitude: 34.7913, timezone: 'Asia/Jerusalem'),
    City(name: 'Tzfat (Safed)', hebrewName: 'צפת', country: 'Israel', latitude: 32.9658, longitude: 35.4983, timezone: 'Asia/Jerusalem'),
    
    // United States
    City(name: 'New York', hebrewName: 'ניו יורק', country: 'USA', latitude: 40.7128, longitude: -74.0060, timezone: 'America/New_York'),
    City(name: 'Los Angeles', hebrewName: 'לוס אנג\'לס', country: 'USA', latitude: 34.0522, longitude: -118.2437, timezone: 'America/Los_Angeles'),
    City(name: 'Chicago', hebrewName: 'שיקגו', country: 'USA', latitude: 41.8781, longitude: -87.6298, timezone: 'America/Chicago'),
    City(name: 'Miami', hebrewName: 'מיאמי', country: 'USA', latitude: 25.7617, longitude: -80.1918, timezone: 'America/New_York'),
    City(name: 'Baltimore', hebrewName: 'בולטימור', country: 'USA', latitude: 39.2904, longitude: -76.6122, timezone: 'America/New_York'),
    City(name: 'Philadelphia', hebrewName: 'פילדלפיה', country: 'USA', latitude: 39.9526, longitude: -75.1652, timezone: 'America/New_York'),
    City(name: 'Boston', hebrewName: 'בוסטון', country: 'USA', latitude: 42.3601, longitude: -71.0589, timezone: 'America/New_York'),
    City(name: 'Cleveland', hebrewName: 'קליבלנד', country: 'USA', latitude: 41.4993, longitude: -81.6944, timezone: 'America/New_York'),
    City(name: 'Detroit', hebrewName: 'דטרויט', country: 'USA', latitude: 42.3314, longitude: -83.0458, timezone: 'America/Detroit'),
    City(name: 'Houston', hebrewName: 'יוסטון', country: 'USA', latitude: 29.7604, longitude: -95.3698, timezone: 'America/Chicago'),
    City(name: 'Dallas', hebrewName: 'דאלאס', country: 'USA', latitude: 32.7767, longitude: -96.7970, timezone: 'America/Chicago'),
    City(name: 'Denver', hebrewName: 'דנבר', country: 'USA', latitude: 39.7392, longitude: -104.9903, timezone: 'America/Denver'),
    City(name: 'Phoenix', hebrewName: 'פניקס', country: 'USA', latitude: 33.4484, longitude: -112.0740, timezone: 'America/Phoenix'),
    City(name: 'San Francisco', hebrewName: 'סן פרנסיסקו', country: 'USA', latitude: 37.7749, longitude: -122.4194, timezone: 'America/Los_Angeles'),
    City(name: 'Seattle', hebrewName: 'סיאטל', country: 'USA', latitude: 47.6062, longitude: -122.3321, timezone: 'America/Los_Angeles'),
    City(name: 'Atlanta', hebrewName: 'אטלנטה', country: 'USA', latitude: 33.7490, longitude: -84.3880, timezone: 'America/New_York'),
    City(name: 'Lakewood, NJ', hebrewName: 'לייקווד', country: 'USA', latitude: 40.0968, longitude: -74.2179, timezone: 'America/New_York'),
    City(name: 'Monsey, NY', hebrewName: 'מונסי', country: 'USA', latitude: 41.1112, longitude: -74.0687, timezone: 'America/New_York'),
    
    // Canada
    City(name: 'Toronto', hebrewName: 'טורונטו', country: 'Canada', latitude: 43.6532, longitude: -79.3832, timezone: 'America/Toronto'),
    City(name: 'Montreal', hebrewName: 'מונטריאול', country: 'Canada', latitude: 45.5017, longitude: -73.5673, timezone: 'America/Montreal'),
    City(name: 'Vancouver', hebrewName: 'ונקובר', country: 'Canada', latitude: 49.2827, longitude: -123.1207, timezone: 'America/Vancouver'),
    
    // Europe
    City(name: 'London', hebrewName: 'לונדון', country: 'UK', latitude: 51.5074, longitude: -0.1278, timezone: 'Europe/London'),
    City(name: 'Manchester', hebrewName: 'מנצ\'סטר', country: 'UK', latitude: 53.4808, longitude: -2.2426, timezone: 'Europe/London'),
    City(name: 'Paris', hebrewName: 'פריז', country: 'France', latitude: 48.8566, longitude: 2.3522, timezone: 'Europe/Paris'),
    City(name: 'Berlin', hebrewName: 'ברלין', country: 'Germany', latitude: 52.5200, longitude: 13.4050, timezone: 'Europe/Berlin'),
    City(name: 'Amsterdam', hebrewName: 'אמסטרדם', country: 'Netherlands', latitude: 52.3676, longitude: 4.9041, timezone: 'Europe/Amsterdam'),
    City(name: 'Antwerp', hebrewName: 'אנטוורפן', country: 'Belgium', latitude: 51.2194, longitude: 4.4025, timezone: 'Europe/Brussels'),
    City(name: 'Vienna', hebrewName: 'וינה', country: 'Austria', latitude: 48.2082, longitude: 16.3738, timezone: 'Europe/Vienna'),
    City(name: 'Zurich', hebrewName: 'ציריך', country: 'Switzerland', latitude: 47.3769, longitude: 8.5417, timezone: 'Europe/Zurich'),
    
    // Australia
    City(name: 'Melbourne', hebrewName: 'מלבורן', country: 'Australia', latitude: -37.8136, longitude: 144.9631, timezone: 'Australia/Melbourne'),
    City(name: 'Sydney', hebrewName: 'סידני', country: 'Australia', latitude: -33.8688, longitude: 151.2093, timezone: 'Australia/Sydney'),
    
    // South America
    City(name: 'Buenos Aires', hebrewName: 'בואנוס איירס', country: 'Argentina', latitude: -34.6037, longitude: -58.3816, timezone: 'America/Argentina/Buenos_Aires'),
    City(name: 'São Paulo', hebrewName: 'סאו פאולו', country: 'Brazil', latitude: -23.5505, longitude: -46.6333, timezone: 'America/Sao_Paulo'),
    
    // South Africa
    City(name: 'Johannesburg', hebrewName: 'יוהנסבורג', country: 'South Africa', latitude: -26.2041, longitude: 28.0473, timezone: 'Africa/Johannesburg'),
    City(name: 'Cape Town', hebrewName: 'קייפטאון', country: 'South Africa', latitude: -33.9249, longitude: 18.4241, timezone: 'Africa/Johannesburg'),
  ];
}

