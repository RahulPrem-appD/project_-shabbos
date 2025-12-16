import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/candle_lighting.dart';
import '../models/city.dart';

class LocationService {
  static const String _locationKey = 'saved_location';
  static const String _useGpsKey = 'use_gps';

  /// Get current GPS location
  Future<LocationInfo?> getCurrentLocation() async {
    try {
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return null;
      }

      // Check permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return null;
      }

      // Get position
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 10),
        ),
      );

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
        }
      } catch (e) {
        // Geocoding might fail, but we still have coordinates
      }

      return LocationInfo(
        latitude: position.latitude,
        longitude: position.longitude,
        cityName: cityName,
        country: country,
      );
    } catch (e) {
      return null;
    }
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
  }

  /// Get saved location
  Future<LocationInfo?> getSavedLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final locationStr = prefs.getString(_locationKey);
    if (locationStr != null) {
      try {
        return LocationInfo.fromJson(json.decode(locationStr));
      } catch (e) {
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

