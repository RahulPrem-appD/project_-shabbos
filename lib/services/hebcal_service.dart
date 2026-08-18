import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/candle_lighting.dart';
import '../hebrew_numerals.dart';
import '../utils/timezone_fallback.dart';

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
    String? country,
    String locale = 'en', // 'he' for Hebrew, 'en' for English
  }) async {
    try {
      // Determine timezone - use provided or detect from coordinates
      final tz = timezone ?? await _detectTimezone(latitude, longitude);

      // Set language parameter based on locale
      // From Hebcal API: use 'h' for Hebrew, 's' for Sephardic transliteration (English)
      final language = locale == 'he' ? 'h' : 's';
      // Israel detection drives 1-day vs 2-day Yom Tov. Three independent
      // signals — any one suffices, since each can fail in real-world cases:
      //   - country: may be localized ("ישראל") or null when geocoding fails
      //   - timezone: may be set to a non-Jerusalem zone if GPS lookup fails
      //   - lat/long bounding box: foolproof when the device is physically
      //     in Israel/Judea/Samaria, regardless of geocoder/timezone state
      final countryLc = country?.toLowerCase();
      final isIsraelByCountry = countryLc != null &&
          (countryLc == 'israel' ||
              countryLc == 'state of israel' ||
              country == 'ישראל' ||
              country == 'إسرائيل');
      final isIsraelByTimezone = tz != null &&
          (tz.toLowerCase() == 'asia/jerusalem' ||
              tz.toLowerCase() == 'asia/tel_aviv' ||
              tz == 'Israel');
      // Bounding box covering Israel + Judea/Samaria. Approximate but tight
      // enough that no diaspora city falls inside it.
      final isIsraelByCoordinates = latitude >= 29.0 &&
          latitude <= 33.5 &&
          longitude >= 34.0 &&
          longitude <= 36.0;
      final isInIsrael =
          isIsraelByCountry || isIsraelByTimezone || isIsraelByCoordinates;
      debugPrint(
        'HebcalService: isInIsrael=$isInIsrael '
        '(country=$country/$isIsraelByCountry, tz=$tz/$isIsraelByTimezone, '
        'coords=($latitude,$longitude)/$isIsraelByCoordinates)',
      );

      final queryParams = {
        'cfg': 'json',
        'v': '1',
        'geo': 'pos',
        'latitude': latitude.toStringAsFixed(4),
        'longitude': longitude.toStringAsFixed(4),
        'start': _formatDate(startDate),
        'end': _formatDate(endDate),
        'yt': 'H', // Yom Tov type
        'maj': 'on', // Major holidays
        's': 'on', // Parasha (Torah portion)
        'ss': 'on', // Special Shabbatot
        'mm': '2', // Month mode
        'lg': language, // Language: h for Hebrew, s for Sephardic (English)
        'c': 'on', // Candle lighting
        'b': '18', // Minutes before sunset
        'M': 'on', // Havdalah
        'ue': 'off', // User events off
        'd': 'on', // Include Gregorian dates with Hebrew dates
      };

      if (isInIsrael) {
        queryParams['i'] = 'on'; // Israel holiday schedule
      }

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
      return _parseExtendedResponse(data, locale: locale, isInIsrael: isInIsrael);
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

      final response =
          await http.get(uri).timeout(const Duration(seconds: 6));
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

    // Last resort: fixed-offset estimate from longitude. Must never be a
    // DST-observing region zone — the old map returned Asia/Jerusalem for
    // every UTC+2 longitude, which made South African requests come back an
    // hour late (tzid drives the wall-clock Hebcal responds with).
    return fixedOffsetZoneForLongitude(longitude);
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Parse the date string from HebCal API
  /// HebCal returns dates in ISO 8601 format with timezone offset
  /// e.g., "2024-12-20T16:23:00-05:00" or "2024-12-20T16:23:00+02:00"
  ///
  /// IMPORTANT: We extract just the datetime portion and ignore timezone
  /// to preserve the event's local time in its location timezone.
  /// This ensures date matching works correctly even when device timezone differs.
  DateTime _parseHebcalDate(String dateStr) {
    try {
      // Extract just the datetime portion (YYYY-MM-DDTHH:MM:SS)
      // Ignore the timezone offset to preserve the event's local time
      final match = RegExp(r'^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2})').firstMatch(dateStr);

      if (match != null) {
        final dateTimePart = match.group(1)!;
        final parsed = DateTime.parse(dateTimePart);
        debugPrint('HebcalService: Parsed "$dateStr" -> $parsed (event local time)');
        return parsed;
      }

      // Fallback for dates without time (gregdate items)
      final dateOnly = dateStr.substring(0, 10);
      final parsed = DateTime.parse(dateOnly);
      debugPrint('HebcalService: Parsed date "$dateStr" -> $parsed');
      return parsed;
    } catch (e) {
      debugPrint('HebcalService: Date parse error for "$dateStr": $e');
      return DateTime.now();
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

  /// Test-only wrapper around the private parser. Lets unit tests feed in
  /// captured Hebcal JSON fixtures and assert against the parser's output
  /// without making any network calls. Do not call from production code.
  @visibleForTesting
  List<CandleLighting> parseExtendedResponseForTest(
    Map<String, dynamic> data, {
    required String locale,
    required bool isInIsrael,
  }) {
    return _parseExtendedResponse(data, locale: locale, isInIsrael: isInIsrael);
  }

  List<CandleLighting> _parseExtendedResponse(
    Map<String, dynamic> data, {
    required String locale,
    required bool isInIsrael,
  }) {
    final List<CandleLighting> results = [];
    final items = data['items'] as List<dynamic>? ?? [];

    // Collect all events by type
    final List<Map<String, dynamic>> candleEvents = [];
    final List<Map<String, dynamic>> havdalahEvents = [];
    final List<Map<String, dynamic>> holidayEvents = [];
    final List<Map<String, dynamic>> parashaEvents = [];
    // Map to store Hebrew dates by Gregorian date (YYYY-MM-DD format)
    final Map<String, String> hebrewDatesByDate = {};

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
      } else if (category == 'gregdate') {
        // Store Hebrew date from gregdate items
        final dateStr = item['date'] as String?;
        final hdate = item['hdate'] as String?;
        if (dateStr != null && hdate != null) {
          hebrewDatesByDate[dateStr] = hdate;
        }
      }
    }

    // Process each candle lighting event
    for (final candleItem in candleEvents) {
      final candleDateStr = candleItem['date'] as String?;
      if (candleDateStr == null) continue;

      final candleDate = _parseHebcalDate(candleDateStr);
      final candleDay =
          DateTime(candleDate.year, candleDate.month, candleDate.day);

      // Find the corresponding Havdalah
      DateTime? havdalahDate;
      for (final havdalahItem in havdalahEvents) {
        final havdalahDateStr = havdalahItem['date'] as String?;
        if (havdalahDateStr == null) continue;

        final hDate = _parseHebcalDate(havdalahDateStr);
        final havdalahDay = DateTime(hDate.year, hDate.month, hDate.day);
        final daysDiff = havdalahDay.difference(candleDay).inDays;

        // Havdalah should be 1-3 days after candle lighting
        if (daysDiff >= 1 && daysDiff <= 3) {
          // Check if there's no candle lighting between them
          bool hasIntermediateCandles = false;
          for (final otherCandle in candleEvents) {
            if (otherCandle == candleItem) continue;
            final otherCandleDateStr = otherCandle['date'] as String?;
            if (otherCandleDateStr == null) continue;
            final otherCandleDate = _parseHebcalDate(otherCandleDateStr);
            final otherDay = DateTime(
              otherCandleDate.year,
              otherCandleDate.month,
              otherCandleDate.day,
            );
            if (otherDay.isAfter(candleDay) && otherDay.isBefore(havdalahDay)) {
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

      // Get holiday/parasha info associated with this candle lighting.
      //
      // RULE: a candle lighting is a Yom Tov candle lighting iff the NEXT
      // calendar day is a Yom Tov holiday (i.e. lighting these candles takes
      // you INTO a Yom Tov day). A same-day-only match would incorrectly
      // flag the Friday candle as Yom Tov in cases where Yom Tov ends Friday
      // and immediately rolls into Shabbat (e.g. Shavuot 5786 in Israel) —
      // that candle is for the SHABBAT that follows, not the ending Yom Tov.
      String? holidayName;
      String? hebrewHolidayName;
      bool isYomTov = false;

      final candleDateKey = _formatDate(candleDate);
      final candleDateTime = DateTime(candleDate.year, candleDate.month, candleDate.day);
      for (final holidayItem in holidayEvents) {
        if (holidayItem['yomtov'] != true) continue;
        final holidayDateStr = holidayItem['date'] as String?;
        if (holidayDateStr == null) continue;

        final holidayDate = _parseHebcalDate(holidayDateStr);
        final holidayDateTime = DateTime(holidayDate.year, holidayDate.month, holidayDate.day);
        final daysDiff = holidayDateTime.difference(candleDateTime).inDays;

        if (daysDiff == 1) {
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

      // If no holiday found, check if memo has event info
      // But only use it if we don't have a parasha (parasha takes precedence)
      if (holidayName == null) {
        // Don't use memo here - we'll populate parasha separately below
        // This prevents "Parashat Vaera" from being used as holidayName when
        // it should be used as the parasha field for proper display
        debugPrint('HebcalService: No Yom Tov holiday found for $candleDateKey, will use parasha if available');
      }

      // Get Hebrew date from the gregdate map
      String? hebrewDate;
      // Extract date part from the datetime string (YYYY-MM-DD)
      final candleDateOnly = candleDateStr.substring(0, 10);
      if (hebrewDatesByDate.containsKey(candleDateOnly)) {
        final hdate = hebrewDatesByDate[candleDateOnly]!;
        hebrewDate = formatHebrewDateProper(hdate);
        debugPrint('HebcalService: Found Hebrew date for $candleDateOnly: $hebrewDate');
      } else {
        debugPrint('HebcalService: No Hebrew date found for $candleDateOnly');
      }

      // Find associated parasha (Torah portion)
      String? parasha;
      String? hebrewParasha;
      for (final parashaItem in parashaEvents) {
        final parashaDateStr = parashaItem['date'] as String?;
        if (parashaDateStr == null) continue;

        final parashaDate = _parseHebcalDate(parashaDateStr);
        final parashaDateKey = _formatDate(parashaDate);

        // Parasha is typically on Saturday (day after candle lighting on Friday)
        // Check if parasha date matches candle date OR is the next calendar day
        final parashaDateTime = DateTime(parashaDate.year, parashaDate.month, parashaDate.day);
        final daysDiff = parashaDateTime.difference(candleDateTime).inDays;

        if (parashaDateKey == candleDateKey || daysDiff == 1) {
          // For parasha items:
          // Hebrew locale (lg=h): title has Hebrew with nikud, hebrew has plain Hebrew
          // English locale (lg=s): title has English name, hebrew has Hebrew without nikud
          if (locale == 'he') {
            // For Hebrew UI, use plain Hebrew without nikud for better display
            parasha = parashaItem['hebrew'] as String? ?? parashaItem['title'] as String?;
            hebrewParasha = parashaItem['hebrew'] as String? ?? parashaItem['title'] as String?;
          } else {
            // For English UI
            parasha = parashaItem['title'] as String?;
            hebrewParasha = parashaItem['hebrew'] as String? ?? parashaItem['title'] as String?;
          }
          debugPrint('HebcalService: Found parasha for $candleDateKey: $parasha ($hebrewParasha)');
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

    // Mark Day 2 of multi-day Yom Tov.
    // A Yom Tov entry is Day 2 when the immediately preceding entry is also
    // a Yom Tov candle lighting on the calendar day right before this one.
    //
    // We do NOT gate this on `!isInIsrael`: Rosh Hashanah is 2-day even in
    // Israel, and the user requirement is that Day 2 alarms must be blocked
    // wherever a Day 2 exists. In Israel, the new isYomTov rule (next-day
    // holiday) prevents a Yom-Tov-into-Shabbat candle from being flagged
    // Yom Tov, so this loop won't accidentally mark the Shabbat candle as
    // Day 2 of a 1-day Israeli Yom Tov.
    for (int i = 1; i < results.length; i++) {
      final current = results[i];
      if (!current.isYomTov) continue;
      final previous = results[i - 1];
      if (!previous.isYomTov) continue;

      final currentDay = DateTime(
        current.candleLightingTime.year,
        current.candleLightingTime.month,
        current.candleLightingTime.day,
      );
      final previousDay = DateTime(
        previous.candleLightingTime.year,
        previous.candleLightingTime.month,
        previous.candleLightingTime.day,
      );

      if (currentDay.difference(previousDay).inDays == 1) {
        results[i] = CandleLighting(
          date: current.date,
          candleLightingTime: current.candleLightingTime,
          havdalahTime: current.havdalahTime,
          holidayName: current.holidayName,
          hebrewHolidayName: current.hebrewHolidayName,
          isShabbat: current.isShabbat,
          isYomTov: current.isYomTov,
          isSecondDayYomTov: true,
          hebrewDate: current.hebrewDate,
          parasha: current.parasha,
          hebrewParasha: current.hebrewParasha,
        );
      }
    }

    debugPrint(
      'HebcalService: Parsed ${results.length} extended candle lighting events (isInIsrael=$isInIsrael)',
    );
    for (final r in results) {
      debugPrint('  - ${r.displayName}: ${r.candleLightingTime} (parasha: ${r.parasha}, hebrewParasha: ${r.hebrewParasha}, day2=${r.isSecondDayYomTov})');
    }

    return results;
  }
}
