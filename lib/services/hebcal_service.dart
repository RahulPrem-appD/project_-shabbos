import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/candle_lighting.dart';
import '../hebrew_numerals.dart';

class HebcalService {
  static const String _baseUrl = 'https://www.hebcal.com/shabbat';

  /// Fetches candle lighting times for a given location
  /// Returns a list of upcoming candle lighting events
  ///
  /// [timezone] is REQUIRED for correct local times (e.g., 'America/New_York', 'Asia/Jerusalem')
  /// [locale] is locale for response: 'he' for Hebrew, 'en' for English
  Future<List<CandleLighting>> getCandleLightingTimes({
    required double latitude,
    required double longitude,
    String? timezone,
    int weeks = 4,
    String locale = 'en',
  }) async {
    try {
      // Determine timezone - use provided or detect from coordinates
      final tz = timezone ?? await _detectTimezone(latitude, longitude);

      // Set language parameter based on locale
      // From Hebcal API: use 'h' for Hebrew, 's' for Sephardic transliteration (English)
      final language = locale == 'he' ? 'h' : 's';

      final queryParams = {
        'cfg': 'json',
        'geo': 'pos',
        'latitude': latitude.toStringAsFixed(4),
        'longitude': longitude.toStringAsFixed(4),
        'M': 'on', // Include Havdalah
        'b': '18', // Candle lighting minutes before sunset (standard 18)
        'lg': language, // Language parameter
      };

      // Add timezone if available
      if (tz != null && tz.isNotEmpty) {
        queryParams['tzid'] = tz;
      }

      final uri = Uri.parse(_baseUrl).replace(queryParameters: queryParams);

      debugPrint('HebcalService: Fetching from $uri');

      final response = await http.get(uri);

      if (response.statusCode != 200) {
        throw Exception(
          'Failed to fetch candle lighting times: ${response.statusCode}',
        );
      }

      final data = json.decode(response.body);

      // Log response for debugging
      debugPrint('HebcalService: Response location: ${data['location']}');
      debugPrint(
        'HebcalService: Response timezone: ${data['location']?['tzid']}',
      );

      return _parseHebcalResponse(data, locale: locale);
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
    String locale = 'en', // 'he' for Hebrew, 'en' for English
  }) async {
    try {
      // Determine timezone - use provided or detect from coordinates
      final tz = timezone ?? await _detectTimezone(latitude, longitude);

      // Set language parameter based on locale
      // From Hebcal API: use 'h' for Hebrew, 's' for Sephardic transliteration (English)
      final language = locale == 'he' ? 'h' : 's';

      final queryParams = {
        'cfg': 'json',
        'v': '1',
        'geo': 'pos',
        'latitude': latitude.toStringAsFixed(4),
        'longitude': longitude.toStringAsFixed(4),
        'start': _formatDate(startDate),
        'end': _formatDate(endDate),
        'yt': 'H', // Yom Tov type
        'i': 'on', // Yom Tov info
        'maj': 'on', // Major holidays
        's': 'on', // Parasha (Torah portion)
        'ss': 'on', // Special Shabbatot
        'mm': '2', // Month mode
        'lg': language, // Language: h for Hebrew, s for Sephardic (English)
        'c': 'on', // Candle lighting
        'b': '18', // Minutes before sunset
        'M': 'on', // Havdalah
        'ue': 'off', // User events off
      };

      // Add timezone if available
      if (tz != null && tz.isNotEmpty) {
        queryParams['tzid'] = tz;
      }

      final uri = Uri.parse(
        'https://www.hebcal.com/hebcal',
      ).replace(queryParameters: queryParams);

      debugPrint('HebcalService: Fetching extended from $uri');

      final response = await http.get(uri);

      if (response.statusCode != 200) {
        throw Exception(
          'Failed to fetch extended times: ${response.statusCode}',
        );
      }

      final data = json.decode(response.body);
      return _parseExtendedResponse(data, locale: locale);
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
      final uri = Uri.parse('https://www.hebcal.com/shabbat').replace(
        queryParameters: {
          'cfg': 'json',
          'geo': 'pos',
          'latitude': latitude.toStringAsFixed(4),
          'longitude': longitude.toStringAsFixed(4),
        },
      );

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
      -3: 'Atlantic/South_Georgia',
      -2: 'Atlantic/Azores',
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
  /// e.g., "2024-12-20T16:23:00-05:00" or "2024-12-20T16:23:00+02:00"
  ///
  /// IMPORTANT: The time returned by HebCal is the LOCAL time at that location.
  /// We should display it as-is without any timezone conversion.
  DateTime _parseHebcalDate(String dateStr) {
    try {
      // HebCal returns times that are already in the correct local time for that location
      // e.g., "2025-12-19T16:15:00+02:00" means 4:15pm LOCAL time in Israel
      // We need to extract just the date/time portion and treat it as local time

      // Extract the datetime portion without timezone offset
      // Match pattern: YYYY-MM-DDTHH:MM:SS (ignore everything after)
      final match = RegExp(
        r'^(\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2})',
      ).firstMatch(dateStr);

      if (match != null) {
        final dateTimePart = match.group(1)!;
        // Parse as local time (no timezone conversion)
        final parsed = DateTime.parse(dateTimePart);
        debugPrint('HebcalService: Parsed "$dateStr" -> $parsed (local time)');
        return parsed;
      }

      // Fallback: try DateTime.parse but strip timezone
      final cleanDate = dateStr
          .replaceAll(RegExp(r'[+-]\\d{2}:\\d{2}$'), '')
          .replaceAll('Z', '');
      final parsed = DateTime.parse(cleanDate);
      debugPrint('HebcalService: Fallback parsed "$dateStr" -> $parsed');
      return parsed;
    } catch (e) {
      debugPrint('HebcalService: Date parse error for "$dateStr": $e');
      // Last resort fallback
      try {
        final cleanDate = dateStr
            .replaceAll(RegExp(r'[+-]\\d{2}:\\d{2}$'), '')
            .replaceAll('Z', '');
        return DateTime.parse(cleanDate);
      } catch (e2) {
        debugPrint('HebcalService: All date parsing failed: $e2');
        return DateTime.now();
      }
    }
  }

  List<CandleLighting> _parseHebcalResponse(Map<String, dynamic> data, {required String locale}) {
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

      debugPrint(
        'HebcalService: Parsing item - category: $category, date: $dateStr -> $date',
      );

      if (category == 'candles') {
        // If we have a previous candle lighting, save it
        if (currentCandleLighting != null) {
          results.add(
            CandleLighting(
              date: eventDate ?? currentCandleLighting,
              candleLightingTime: currentCandleLighting,
              havdalahTime: currentHavdalah,
              holidayName: currentHoliday,
              hebrewHolidayName: currentHebrewHoliday,
              isShabbat: currentHoliday == null || currentHoliday.isEmpty,
              isYomTov: isYomTov,
            ),
          );
        }

        currentCandleLighting = date;
        eventDate = date;
        currentHavdalah = null;

        // For candle lighting events:
        // Hebrew locale (lg=h): memo has Hebrew name, title_orig has transliteration
        // English locale (lg=s): memo has English name, hebrew has Hebrew
        if (locale == 'he') {
          currentHoliday = item['memo'] as String?;
          currentHebrewHoliday = item['memo'] as String?;
        } else {
          currentHoliday = item['memo'] as String?;
          currentHebrewHoliday = item['hebrew'] as String?;
        }
        isYomTov = item['yomtov'] == true;
      } else if (category == 'havdalah') {
        currentHavdalah = date;
      } else if (category == 'holiday') {
        final yomtov = item['yomtov'] as bool? ?? false;
        if (yomtov) {
          // For Yom Tov holidays:
          // Hebrew: title has Hebrew with nikud
          // English: title_orig has English name
          if (locale == 'he') {
            currentHoliday = item['title'] as String?;
            currentHebrewHoliday = item['title'] as String?;
          } else {
            currentHoliday = item['title_orig'] as String? ?? item['title'] as String?;
            currentHebrewHoliday = item['hebrew'] as String?;
          }
          isYomTov = true;
        }
      }
    }

    // Don't forget the last one
    if (currentCandleLighting != null) {
      results.add(
        CandleLighting(
          date: eventDate ?? currentCandleLighting,
          candleLightingTime: currentCandleLighting,
          havdalahTime: currentHavdalah,
          holidayName: currentHoliday,
          hebrewHolidayName: currentHebrewHoliday,
          isShabbat: currentHoliday == null || currentHoliday.isEmpty,
          isYomTov: isYomTov,
        ),
      );
    }

    debugPrint(
      'HebcalService: Parsed ${results.length} candle lighting events',
    );
    for (final r in results) {
      debugPrint('  - ${r.displayName}: ${r.candleLightingTime}');
    }

    return results;
  }

  List<CandleLighting> _parseExtendedResponse(Map<String, dynamic> data, {required String locale}) {
    final List<CandleLighting> results = [];
    final items = data['items'] as List<dynamic>? ?? [];

    // Collect all events by type
    final List<Map<String, dynamic>> candleEvents = [];
    final List<Map<String, dynamic>> havdalahEvents = [];
    final List<Map<String, dynamic>> holidayEvents = [];
    final List<Map<String, dynamic>> parashaEvents = [];

    for (final item in items) {
      final category = item['category'] as String?;
      if (category == 'candles') {
        candleEvents.add(item);
      } else if (category == 'havdalah') {
        havdalahEvents.add(item);
      } else if (category == 'holiday' && item['yomtov'] == true) {
        holidayEvents.add(item);
      } else if (category == 'parashat' || category == 'roshchodesh') {
        parashaEvents.add(item);
      }
    }

    // Process each candle lighting event
    for (final candleItem in candleEvents) {
      final candleDateStr = candleItem['date'] as String?;
      if (candleDateStr == null) continue;

      final candleDate = _parseHebcalDate(candleDateStr);

      // Find the corresponding Havdalah
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
            final otherCandleDateStr = otherCandle['date'] as String?;
            if (otherCandleDateStr == null) continue;
            final otherCandleDate = _parseHebcalDate(otherCandleDateStr);
            if (otherCandleDate.isAfter(candleDate) &&
                otherCandleDate.isBefore(hDate)) {
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

      // Get holiday/parasha info associated with this candle lighting
      String? holidayName;
      String? hebrewHolidayName;
      bool isYomTov = candleItem['yomtov'] == true;

      final candleDateKey = _formatDate(candleDate);

      // Check for holiday on same day or next day
      for (final holidayItem in holidayEvents) {
        final holidayDateStr = holidayItem['date'] as String?;
        if (holidayDateStr == null) continue;

        final holidayDate = _parseHebcalDate(holidayDateStr);
        final holidayDateKey = _formatDate(holidayDate);

        // Holiday can be on same day or next day (since Shabbat starts Friday evening)
        if (holidayDateKey == candleDateKey ||
            holidayDate.difference(candleDate).inDays == 1) {
          if (holidayItem['yomtov'] == true) {
            // For Yom Tov:
            // Hebrew: title has Hebrew with nikud
            // English: title_orig has English name
            if (locale == 'he') {
              holidayName = holidayItem['title'] as String?;
              hebrewHolidayName = holidayItem['title'] as String?;
            } else {
              holidayName = holidayItem['title_orig'] as String? ?? holidayItem['title'] as String?;
              hebrewHolidayName = holidayItem['hebrew'] as String?;
            }
            isYomTov = true;
            break;
          }
        }
      }

      // If no holiday found, use memo field from candle item
      if (holidayName == null) {
        // For candle items, memo contains the event name (Shabbat, parasha, or Yom Tov)
        if (locale == 'he') {
          holidayName = candleItem['memo'] as String?;
          hebrewHolidayName = candleItem['memo'] as String?;
        } else {
          holidayName = candleItem['memo'] as String?;
          hebrewHolidayName = null; // No Hebrew translation for English candles (just "Candle lighting")
        }
      }

      // Get Hebrew date
      final hebrewDate = candleItem['heDateParts'] != null
          ? _formatHebrewDate(candleItem['heDateParts'])
          : formatHebrewDateProper(candleItem['hdate'] as String?);

      // Find associated parasha (Torah portion)
      String? parasha;
      String? hebrewParasha;
      for (final parashaItem in parashaEvents) {
        final parashaDateStr = parashaItem['date'] as String?;
        if (parashaDateStr == null) continue;

        final parashaDate = _parseHebcalDate(parashaDateStr);
        final parashaDateKey = _formatDate(parashaDate);

        // Parasha is typically on the same day as candle lighting (Friday)
        if (parashaDateKey == candleDateKey) {
          // For parasha items:
          // Hebrew: title has Hebrew with nikud
          // English: title_orig has English transliteration
          if (locale == 'he') {
            parasha = parashaItem['title'] as String?;
            hebrewParasha = parashaItem['title'] as String?;
          } else {
            parasha = parashaItem['title_orig'] as String? ?? parashaItem['title'] as String?;
            hebrewParasha = parashaItem['hebrew'] as String?;
          }
          break;
        }
      }

      results.add(
        CandleLighting(
          date: candleDate,
          candleLightingTime: candleDate,
          havdalahTime: havdalahDate,
          holidayName: holidayName,
          hebrewHolidayName: hebrewHolidayName,
          isShabbat: !isYomTov,
          isYomTov: isYomTov,
          hebrewDate: hebrewDate,
          parasha: parasha,
          hebrewParasha: hebrewParasha,
        ),
      );
    }

    // Sort by date
    results.sort(
      (a, b) => a.candleLightingTime.compareTo(b.candleLightingTime),
    );

    debugPrint(
      'HebcalService: Parsed ${results.length} extended candle lighting events',
    );

    return results;
  }

  /// Format Hebrew date parts into a readable string
  String? _formatHebrewDate(dynamic heDateParts) {
    if (heDateParts == null) return null;
    try {
      final day = heDateParts['d'] as String?;
      final month = heDateParts['m'] as String?;
      final year = heDateParts['y'] as String?;
      if (day != null && month != null) {
        return year != null ? '$day $month $year' : '$day $month';
      }
    } catch (e) {
      debugPrint('HebcalService: Error formatting Hebrew date: $e');
    }
    return null;
  }
}
