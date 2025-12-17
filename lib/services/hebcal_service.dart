import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/candle_lighting.dart';

class HebcalService {
  static const String _baseUrl = 'https://www.hebcal.com/shabbat';

  /// Fetches candle lighting times for a given location
  /// Returns a list of upcoming candle lighting events
  /// 
  /// [timezone] is REQUIRED for correct local times (e.g., 'America/New_York', 'Asia/Jerusalem')
  Future<List<CandleLighting>> getCandleLightingTimes({
    required double latitude,
    required double longitude,
    String? timezone,
    int weeks = 4,
  }) async {
    try {
      // Determine timezone - use provided or detect from coordinates
      final tz = timezone ?? await _detectTimezone(latitude, longitude);
      
      final queryParams = {
        'cfg': 'json',
        'geo': 'pos',
        'latitude': latitude.toStringAsFixed(4),
        'longitude': longitude.toStringAsFixed(4),
        'M': 'on', // Include Havdalah
        'b': '18', // Candle lighting minutes before sunset (standard 18)
      };
      
      // Add timezone if available
      if (tz != null && tz.isNotEmpty) {
        queryParams['tzid'] = tz;
      }
      
      final uri = Uri.parse(_baseUrl).replace(queryParameters: queryParams);
      
      debugPrint('HebcalService: Fetching from $uri');

      final response = await http.get(uri);

      if (response.statusCode != 200) {
        throw Exception('Failed to fetch candle lighting times: ${response.statusCode}');
      }

      final data = json.decode(response.body);
      
      // Log the response for debugging
      debugPrint('HebcalService: Response location: ${data['location']}');
      debugPrint('HebcalService: Response timezone: ${data['location']?['tzid']}');
      
      return _parseHebcalResponse(data);
    } catch (e) {
      debugPrint('HebcalService: Error: $e');
      throw Exception('Error fetching candle lighting times: $e');
    }
  }

  /// Fetches candle lighting times for multiple weeks ahead
  Future<List<CandleLighting>> getExtendedCandleLightingTimes({
    required double latitude,
    required double longitude,
    required DateTime startDate,
    required DateTime endDate,
    String? timezone,
  }) async {
    try {
      // Determine timezone - use provided or detect from coordinates
      final tz = timezone ?? await _detectTimezone(latitude, longitude);
      
      final queryParams = {
        'cfg': 'json',
        'v': '1',
        'geo': 'pos',
        'latitude': latitude.toStringAsFixed(4),
        'longitude': longitude.toStringAsFixed(4),
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
      };
      
      // Add timezone if available
      if (tz != null && tz.isNotEmpty) {
        queryParams['tzid'] = tz;
      }

      final uri = Uri.parse('https://www.hebcal.com/hebcal').replace(queryParameters: queryParams);
      
      debugPrint('HebcalService: Fetching extended from $uri');

      final response = await http.get(uri);

      if (response.statusCode != 200) {
        throw Exception('Failed to fetch extended times: ${response.statusCode}');
      }

      final data = json.decode(response.body);
      return _parseExtendedResponse(data);
    } catch (e) {
      debugPrint('HebcalService: Extended error: $e');
      throw Exception('Error fetching extended times: $e');
    }
  }

  /// Detect timezone from coordinates using a simple lookup
  /// This is a fallback when timezone is not provided
  Future<String?> _detectTimezone(double latitude, double longitude) async {
    // Use a simple heuristic based on longitude for rough timezone detection
    // This is a fallback - ideally the timezone should be provided from City data
    
    // Try to use a timezone API as fallback
    try {
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
          debugPrint('HebcalService: Detected timezone from API: $tzid');
          return tzid;
        }
      }
    } catch (e) {
      debugPrint('HebcalService: Timezone detection failed: $e');
    }
    
    // Fallback: rough estimate based on longitude
    // Each timezone is approximately 15 degrees of longitude
    final offset = (longitude / 15).round();
    
    // Map common offsets to IANA timezone names
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
    
    return timezoneMap[offset];
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Parse the date string from HebCal API
  /// HebCal returns dates in ISO 8601 format with timezone offset
  /// e.g., "2024-12-20T16:23:00-05:00"
  DateTime _parseHebcalDate(String dateStr) {
    try {
      // HebCal returns ISO 8601 with timezone offset
      // DateTime.parse handles this correctly and converts to local time
      final parsed = DateTime.parse(dateStr);
      
      // Convert to local time if it's in UTC
      if (parsed.isUtc) {
        return parsed.toLocal();
      }
      
      return parsed;
    } catch (e) {
      debugPrint('HebcalService: Date parse error for "$dateStr": $e');
      // Fallback: try to parse without timezone
      try {
        // Remove timezone info and parse as local
        final cleanDate = dateStr.replaceAll(RegExp(r'[+-]\d{2}:\d{2}$'), '');
        return DateTime.parse(cleanDate);
      } catch (e2) {
        debugPrint('HebcalService: Fallback date parse also failed: $e2');
        return DateTime.now();
      }
    }
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

      final date = _parseHebcalDate(dateStr);
      
      debugPrint('HebcalService: Parsing item - category: $category, date: $dateStr -> $date');

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

    debugPrint('HebcalService: Parsed ${results.length} candle lighting events');
    for (final r in results) {
      debugPrint('  - ${r.displayName}: ${r.candleLightingTime}');
    }

    return results;
  }

  List<CandleLighting> _parseExtendedResponse(Map<String, dynamic> data) {
    final List<CandleLighting> results = [];
    final items = data['items'] as List<dynamic>? ?? [];

    // Collect all events by type
    final List<Map<String, dynamic>> candleEvents = [];
    final List<Map<String, dynamic>> havdalahEvents = [];
    final List<Map<String, dynamic>> holidayEvents = [];

    for (final item in items) {
      final category = item['category'] as String?;
      if (category == 'candles') {
        candleEvents.add(item);
      } else if (category == 'havdalah') {
        havdalahEvents.add(item);
      } else if (category == 'holiday') {
        holidayEvents.add(item);
      }
    }

    // Process each candle lighting event
    for (final candleItem in candleEvents) {
      final candleDateStr = candleItem['date'] as String?;
      if (candleDateStr == null) continue;

      final candleDate = _parseHebcalDate(candleDateStr);
      
      // Find the corresponding Havdalah
      // Havdalah is typically 1-2 days after candle lighting (1 for regular Shabbat, 2+ for holidays)
      DateTime? havdalahDate;
      for (final havdalahItem in havdalahEvents) {
        final havdalahDateStr = havdalahItem['date'] as String?;
        if (havdalahDateStr == null) continue;
        
        final hDate = _parseHebcalDate(havdalahDateStr);
        final daysDiff = hDate.difference(candleDate).inDays;
        
        // Havdalah should be 1-3 days after candle lighting
        if (daysDiff >= 1 && daysDiff <= 3) {
          // Check if there's no candle lighting between them
          bool hasIntermediateCandles = false;
          for (final otherCandle in candleEvents) {
            if (otherCandle == candleItem) continue;
            final otherDateStr = otherCandle['date'] as String?;
            if (otherDateStr == null) continue;
            final otherDate = _parseHebcalDate(otherDateStr);
            if (otherDate.isAfter(candleDate) && otherDate.isBefore(hDate)) {
              hasIntermediateCandles = true;
              break;
            }
          }
          
          if (!hasIntermediateCandles) {
            havdalahDate = hDate;
            break;
          }
        }
      }

      // Find associated holiday
      String? holidayName = candleItem['memo'] as String?;
      String? hebrewHolidayName = candleItem['hebrew'] as String?;
      bool isYomTov = candleItem['yomtov'] == true;

      // Check if there's a holiday on the same date
      final candleDateKey = _formatDate(candleDate);
      for (final holidayItem in holidayEvents) {
        final holidayDateStr = holidayItem['date'] as String?;
        if (holidayDateStr == null) continue;
        
        final holidayDate = _parseHebcalDate(holidayDateStr);
        final holidayDateKey = _formatDate(holidayDate);
        
        // Holiday can be on the same day or the next day (since Shabbat starts Friday evening)
        if (holidayDateKey == candleDateKey || 
            holidayDate.difference(candleDate).inDays == 1) {
          if (holidayItem['yomtov'] == true) {
            holidayName = holidayItem['title'] as String?;
            hebrewHolidayName = holidayItem['hebrew'] as String?;
            isYomTov = true;
            break;
          }
        }
      }

      results.add(CandleLighting(
        date: candleDate,
        candleLightingTime: candleDate,
        havdalahTime: havdalahDate,
        holidayName: holidayName,
        hebrewHolidayName: hebrewHolidayName,
        isShabbat: !isYomTov,
        isYomTov: isYomTov,
      ));
    }

    // Sort by date
    results.sort((a, b) => a.candleLightingTime.compareTo(b.candleLightingTime));

    debugPrint('HebcalService: Parsed ${results.length} extended candle lighting events');

    return results;
  }
}
