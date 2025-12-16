import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/candle_lighting.dart';

class HebcalService {
  static const String _baseUrl = 'https://www.hebcal.com/shabbat';

  /// Fetches candle lighting times for a given location
  /// Returns a list of upcoming candle lighting events
  Future<List<CandleLighting>> getCandleLightingTimes({
    required double latitude,
    required double longitude,
    int weeks = 4,
  }) async {
    try {
      final uri = Uri.parse(_baseUrl).replace(queryParameters: {
        'cfg': 'json',
        'geo': 'pos',
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
        'M': 'on', // Include Havdalah
        'b': '18', // Candle lighting minutes before sunset (standard 18)
      });

      final response = await http.get(uri);

      if (response.statusCode != 200) {
        throw Exception('Failed to fetch candle lighting times: ${response.statusCode}');
      }

      final data = json.decode(response.body);
      return _parseHebcalResponse(data);
    } catch (e) {
      throw Exception('Error fetching candle lighting times: $e');
    }
  }

  /// Fetches candle lighting times for multiple weeks ahead
  Future<List<CandleLighting>> getExtendedCandleLightingTimes({
    required double latitude,
    required double longitude,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final uri = Uri.parse('https://www.hebcal.com/hebcal').replace(queryParameters: {
        'cfg': 'json',
        'v': '1',
        'geo': 'pos',
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
        'start': _formatDate(startDate),
        'end': _formatDate(endDate),
        'c': 'on', // Candle lighting
        'M': 'on', // Havdalah
        'b': '18', // Minutes before sunset
        'maj': 'on', // Major holidays
        'min': 'off', // Minor holidays
        'mod': 'off', // Modern holidays
        'nx': 'off', // Rosh Chodesh
        's': 'off', // Parasha
      });

      final response = await http.get(uri);

      if (response.statusCode != 200) {
        throw Exception('Failed to fetch extended times: ${response.statusCode}');
      }

      final data = json.decode(response.body);
      return _parseExtendedResponse(data);
    } catch (e) {
      throw Exception('Error fetching extended times: $e');
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  List<CandleLighting> _parseHebcalResponse(Map<String, dynamic> data) {
    final List<CandleLighting> results = [];
    final items = data['items'] as List<dynamic>? ?? [];

    DateTime? currentCandleLighting;
    DateTime? currentHavdalah;
    String? currentHoliday;
    String? currentHebrewHoliday;
    DateTime? eventDate;
    bool isYomTov = false;

    for (final item in items) {
      final category = item['category'] as String?;
      final dateStr = item['date'] as String?;
      
      if (dateStr == null) continue;

      final date = DateTime.parse(dateStr);

      if (category == 'candles') {
        // If we have a previous candle lighting, save it
        if (currentCandleLighting != null) {
          results.add(CandleLighting(
            date: eventDate ?? currentCandleLighting,
            candleLightingTime: currentCandleLighting,
            havdalahTime: currentHavdalah,
            holidayName: currentHoliday,
            hebrewHolidayName: currentHebrewHoliday,
            isShabbat: currentHoliday == null || currentHoliday.isEmpty,
            isYomTov: isYomTov,
          ));
        }
        
        currentCandleLighting = date;
        eventDate = date;
        currentHavdalah = null;
        currentHoliday = item['memo'] as String?;
        currentHebrewHoliday = item['hebrew'] as String?;
        isYomTov = item['yomtov'] == true;
      } else if (category == 'havdalah') {
        currentHavdalah = date;
      } else if (category == 'holiday') {
        final yomtov = item['yomtov'] as bool? ?? false;
        if (yomtov) {
          currentHoliday = item['title'] as String?;
          currentHebrewHoliday = item['hebrew'] as String?;
          isYomTov = true;
        }
      }
    }

    // Don't forget the last one
    if (currentCandleLighting != null) {
      results.add(CandleLighting(
        date: eventDate ?? currentCandleLighting,
        candleLightingTime: currentCandleLighting,
        havdalahTime: currentHavdalah,
        holidayName: currentHoliday,
        hebrewHolidayName: currentHebrewHoliday,
        isShabbat: currentHoliday == null || currentHoliday.isEmpty,
        isYomTov: isYomTov,
      ));
    }

    return results;
  }

  List<CandleLighting> _parseExtendedResponse(Map<String, dynamic> data) {
    final List<CandleLighting> results = [];
    final items = data['items'] as List<dynamic>? ?? [];

    // Group items by date to pair candle lighting with havdalah
    final Map<String, Map<String, dynamic>> eventsByDate = {};

    for (final item in items) {
      final category = item['category'] as String?;
      final dateStr = item['date'] as String?;
      
      if (dateStr == null) continue;

      final dateKey = dateStr.substring(0, 10); // YYYY-MM-DD

      eventsByDate[dateKey] ??= {};

      if (category == 'candles') {
        eventsByDate[dateKey]!['candles'] = item;
      } else if (category == 'havdalah') {
        // Havdalah is typically the next day, find the previous candle lighting
        final havdalahDate = DateTime.parse(dateStr);
        final candleDate = havdalahDate.subtract(const Duration(days: 1));
        final candleDateKey = _formatDate(candleDate);
        if (eventsByDate.containsKey(candleDateKey)) {
          eventsByDate[candleDateKey]!['havdalah'] = item;
        }
      } else if (category == 'holiday') {
        eventsByDate[dateKey]!['holiday'] = item;
      }
    }

    for (final entry in eventsByDate.entries) {
      final events = entry.value;
      if (events.containsKey('candles')) {
        final candleItem = events['candles'];
        final havdalahItem = events['havdalah'];
        final holidayItem = events['holiday'];

        final candleDate = DateTime.parse(candleItem['date'] as String);
        final havdalahDate = havdalahItem != null 
            ? DateTime.parse(havdalahItem['date'] as String) 
            : null;

        final isYomTov = holidayItem?['yomtov'] == true || candleItem['yomtov'] == true;

        results.add(CandleLighting(
          date: candleDate,
          candleLightingTime: candleDate,
          havdalahTime: havdalahDate,
          holidayName: holidayItem?['title'] as String? ?? candleItem['memo'] as String?,
          hebrewHolidayName: holidayItem?['hebrew'] as String? ?? candleItem['hebrew'] as String?,
          isShabbat: !isYomTov,
          isYomTov: isYomTov,
        ));
      }
    }

    // Sort by date
    results.sort((a, b) => a.candleLightingTime.compareTo(b.candleLightingTime));

    return results;
  }
}

