import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/candle_lighting.dart';
import '../models/city.dart';

class LocationService {
  static const String _locationKey = 'saved_location';
  static const String _useGpsKey = 'use_gps';

  /// Get current GPS location with timezone detection
  Future<LocationInfo?> getCurrentLocation() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('LocationService: Location services disabled');
        return null;
      }

      // Only check permissions, don't request (caller should handle permission requests)
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied || 
          permission == LocationPermission.deniedForever) {
        debugPrint('LocationService: Permission not granted: $permission');
        return null;
      }

      // Get position
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 10),
        ),
      );

      debugPrint('LocationService: Got position: ${position.latitude}, ${position.longitude}');

      // Get city name from coordinates
      String? cityName;
      String? country;
      try {
        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (placemarks.isNotEmpty) {
          cityName = placemarks.first.locality ?? placemarks.first.subAdministrativeArea;
          country = placemarks.first.country;
          debugPrint('LocationService: Geocoded to $cityName, $country');
        }
      } catch (e) {
        debugPrint('LocationService: Geocoding failed: $e');
      }

      // Detect timezone for the location
      String? timezone = await _detectTimezoneForLocation(
        position.latitude, 
        position.longitude,
      );
      
      debugPrint('LocationService: Detected timezone: $timezone');

      return LocationInfo(
        latitude: position.latitude,
        longitude: position.longitude,
        cityName: cityName,
        country: country,
        timezone: timezone,
      );
    } catch (e) {
      debugPrint('LocationService: Error getting location: $e');
      return null;
    }
  }

  /// Detect timezone for given coordinates
  /// Uses HebCal API to get the timezone for the location
  Future<String?> _detectTimezoneForLocation(double latitude, double longitude) async {
    try {
      // First, try to match with a known city
      final matchedCity = _findNearestCity(latitude, longitude);
      if (matchedCity != null) {
        debugPrint('LocationService: Matched to city ${matchedCity.name} with timezone ${matchedCity.timezone}');
        return matchedCity.timezone;
      }

      // If no city match, use HebCal to detect timezone
      final uri = Uri.parse('https://www.hebcal.com/shabbat').replace(queryParameters: {
        'cfg': 'json',
        'geo': 'pos',
        'latitude': latitude.toStringAsFixed(4),
        'longitude': longitude.toStringAsFixed(4),
      });

      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final tzid = data['location']?['tzid'] as String?;
        if (tzid != null && tzid.isNotEmpty) {
          debugPrint('LocationService: Got timezone from HebCal: $tzid');
          return tzid;
        }
      }
    } catch (e) {
      debugPrint('LocationService: Timezone detection failed: $e');
    }

    // Fallback: estimate from longitude
    return _estimateTimezoneFromLongitude(longitude);
  }

  /// Find the nearest city from the predefined list
  /// Returns null if no city is within 100km
  City? _findNearestCity(double latitude, double longitude) {
    City? nearestCity;
    double minDistance = double.infinity;

    for (final city in City.majorCities) {
      final distance = _calculateDistance(
        latitude, longitude,
        city.latitude, city.longitude,
      );
      
      if (distance < minDistance) {
        minDistance = distance;
        nearestCity = city;
      }
    }

    // Only return if within 100km
    if (minDistance <= 100) {
      return nearestCity;
    }
    return null;
  }

  /// Calculate distance between two points in km using Haversine formula
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // km
    
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    
    final a = 
      (sin(dLat / 2) * sin(dLat / 2)) +
      cos(_toRadians(lat1)) * cos(_toRadians(lat2)) *
      (sin(dLon / 2) * sin(dLon / 2));
    
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    
    return earthRadius * c;
  }

  double _toRadians(double degrees) => degrees * 3.14159265359 / 180;
  double sin(double x) => _sin(x);
  double cos(double x) => _cos(x);
  double sqrt(double x) => _sqrt(x);
  double atan2(double y, double x) => _atan2(y, x);

  // Simple math implementations to avoid dart:math import issues
  double _sin(double x) {
    // Normalize to [-pi, pi]
    while (x > 3.14159265359) {
      x -= 2 * 3.14159265359;
    }
    while (x < -3.14159265359) {
      x += 2 * 3.14159265359;
    }
    
    // Taylor series approximation
    double result = x;
    double term = x;
    for (int i = 1; i <= 10; i++) {
      term *= -x * x / ((2 * i) * (2 * i + 1));
      result += term;
    }
    return result;
  }

  double _cos(double x) {
    return _sin(x + 3.14159265359 / 2);
  }

  double _sqrt(double x) {
    if (x <= 0) return 0;
    double guess = x / 2;
    for (int i = 0; i < 20; i++) {
      guess = (guess + x / guess) / 2;
    }
    return guess;
  }

  double _atan2(double y, double x) {
    if (x > 0) return _atan(y / x);
    if (x < 0 && y >= 0) return _atan(y / x) + 3.14159265359;
    if (x < 0 && y < 0) return _atan(y / x) - 3.14159265359;
    if (x == 0 && y > 0) return 3.14159265359 / 2;
    if (x == 0 && y < 0) return -3.14159265359 / 2;
    return 0;
  }

  double _atan(double x) {
    // Use Taylor series for small x, identity for large x
    if (x.abs() > 1) {
      return (x > 0 ? 1 : -1) * (3.14159265359 / 2 - _atan(1 / x));
    }
    double result = x;
    double term = x;
    for (int i = 1; i <= 20; i++) {
      term *= -x * x;
      result += term / (2 * i + 1);
    }
    return result;
  }

  /// Estimate timezone from longitude (rough approximation)
  String _estimateTimezoneFromLongitude(double longitude) {
    final offset = (longitude / 15).round();
    
    final timezoneMap = {
      -12: 'Etc/GMT+12',
      -11: 'Pacific/Midway',
      -10: 'Pacific/Honolulu',
      -9: 'America/Anchorage',
      -8: 'America/Los_Angeles',
      -7: 'America/Denver',
      -6: 'America/Chicago',
      -5: 'America/New_York',
      -4: 'America/Halifax',
      -3: 'America/Sao_Paulo',
      -2: 'Atlantic/South_Georgia',
      -1: 'Atlantic/Azores',
      0: 'Europe/London',
      1: 'Europe/Paris',
      2: 'Asia/Jerusalem',
      3: 'Europe/Moscow',
      4: 'Asia/Dubai',
      5: 'Asia/Karachi',
      6: 'Asia/Dhaka',
      7: 'Asia/Bangkok',
      8: 'Asia/Shanghai',
      9: 'Asia/Tokyo',
      10: 'Australia/Sydney',
      11: 'Pacific/Noumea',
      12: 'Pacific/Auckland',
    };
    
    return timezoneMap[offset] ?? 'UTC';
  }

  /// Create LocationInfo from a City
  LocationInfo locationFromCity(City city) {
    return LocationInfo(
      latitude: city.latitude,
      longitude: city.longitude,
      cityName: city.name,
      country: city.country,
      timezone: city.timezone,
    );
  }

  /// Save location preference
  Future<void> saveLocation(LocationInfo location) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_locationKey, json.encode(location.toJson()));
    debugPrint('LocationService: Saved location: ${location.displayName} (${location.timezone})');
  }

  /// Get saved location
  Future<LocationInfo?> getSavedLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final locationStr = prefs.getString(_locationKey);
    if (locationStr != null) {
      try {
        final location = LocationInfo.fromJson(json.decode(locationStr));
        debugPrint('LocationService: Loaded saved location: ${location.displayName} (${location.timezone})');
        return location;
      } catch (e) {
        debugPrint('LocationService: Failed to parse saved location: $e');
        return null;
      }
    }
    return null;
  }

  /// Save GPS preference
  Future<void> setUseGps(bool useGps) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_useGpsKey, useGps);
  }

  /// Get GPS preference
  Future<bool> getUseGps() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_useGpsKey) ?? true;
  }

  /// Check if location permission is granted
  Future<bool> hasLocationPermission() async {
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.always || 
           permission == LocationPermission.whileInUse;
  }

  /// Request location permission
  Future<bool> requestLocationPermission() async {
    final permission = await Geolocator.requestPermission();
    return permission == LocationPermission.always || 
           permission == LocationPermission.whileInUse;
  }
}
