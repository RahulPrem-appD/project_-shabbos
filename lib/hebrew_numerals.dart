import 'package:flutter/foundation.dart';

/// Helper functions for Hebrew numerals (geresh/gershayim)

/// Convert number to Hebrew numerals (geresh/gershayim)
String toHebrewNumerals(int num) {
  // Hebrew numerals mapping (singles)
  final singles = {
    1: 'א',
    2: 'ב',
    3: 'ג',
    4: 'ד',
    5: 'ה',
    6: 'ו',
    7: 'ז',
    8: 'ח',
    9: 'ט',
  };

  // Tens
  final tens = {
    10: 'י',
    20: 'כ',
    30: 'ל',
    40: 'מ',
    50: 'נ',
    60: 'ס',
    70: 'ע',
    80: 'פ',
    90: 'צ',
  };

  // Hundreds
  final hundreds = {
    100: 'ק',
    200: 'ר',
    300: 'ש',
    400: 'ת',
  };

  // Special cases for years (thousands)
  final yearMap = {
    5784: 'תשפ"ד',
    5785: 'תשפ"ה',
    5786: 'תשפ"ו',
    5787: 'תשפ"ז',
    5788: 'תשפ"ח',
    5789: 'תשפ"ט',
    5790: 'תש"צ',
  };

  // Check if it's a known year
  if (num >= 5784 && num <= 5790) {
    return yearMap[num] ?? num.toString();
  }

  // For single digits (1-9)
  if (num >= 1 && num <= 9) {
    return '${singles[num]}׳';
  }

  // For exact tens (10, 20, ..., 90)
  if (num % 10 == 0 && num <= 90) {
    return '${tens[num]}׳';
  }

  // For exact hundreds (100, 200, 300, 400)
  if (num % 100 == 0 && num <= 400) {
    return '${hundreds[num]}׳';
  }

  // For teens (11-19)
  if (num >= 11 && num <= 19) {
    final units = singles[num - 10] ?? '';
    return 'י$units';
  }

  // For combinations like 29 = כ״ט
  final tensVal = (num ~/ 10) * 10;
  final units = num % 10;

  if (tensVal <= 90) {
    final tensChar = tens[tensVal] ?? '';
    final unitsChar = (units > 0) ? singles[units] ?? '' : '';
    if (units == 0) {
      return '$tensChar׳';
    }
    return '$tensChar״$unitsChar';
  }

  // For numbers like 100-999
  if (num >= 100 && num <= 999) {
    final hundredsVal = (num ~/ 100) * 100;
    final remainder = num % 100;

    final hundredsChar = hundreds[hundredsVal] ?? '';
    if (remainder == 0) {
      return '$hundredsChar׳';
    }
    // Recursively convert remainder
    return '$hundredsChar${toHebrewNumerals(remainder)}';
  }

  return num.toString();
}

/// Map of Hebrew month names (English to Hebrew)
const hebrewMonthNames = {
  'Nisan': 'ניסן',
  'Iyyar': 'אייר',
  'Sivan': 'סיוון',
  'Tamuz': 'תמוז',
  'Av': 'אב',
  'Elul': 'אלול',
  'Tishrei': 'תשרי',
  'Cheshvan': 'חשון',
  'Kislev': 'כסלו',
  'Tevet': 'טבת',
  'Shevat': 'שבט',
  'Adar': 'אדר',
  'Adar I': 'אדר א׳',
  'Adar II': 'אדר ב׳',
};

/// Convert English Hebrew date format to proper Hebrew format
/// Converts "29 Elul 5785" to "כ״ט אלול תשפ״ה"
String? formatHebrewDateProper(String? hebrewDate) {
  if (hebrewDate == null || hebrewDate.isEmpty) return null;

  try {
    // Parse date format: "29 Elul 5785" or "29 Elul 5785"
    final parts = hebrewDate.split(' ');
    if (parts.length < 2) return hebrewDate;

    final dayStr = parts[0]; // e.g., "29"
    final monthStr = parts[1]; // e.g., "Elul"
    
    // Convert day to Hebrew numerals
    final hebrewDay = toHebrewNumerals(int.tryParse(dayStr) ?? 1);
    
    // Get Hebrew year if available
    if (parts.length > 2) {
      // Full date with year: "29 Elul 5785"
      final yearStr = parts[2];
      final hebrewYear = toHebrewNumerals(int.tryParse(yearStr) ?? 5785);
      final hebrewMonth = hebrewMonthNames[monthStr] ?? monthStr;
      return '$hebrewDay $hebrewMonth $hebrewYear';
    }

    // Date without year: "29 Elul" (likely Shabbat candle lighting)
    final hebrewMonth = hebrewMonthNames[monthStr] ?? monthStr;
    return '$hebrewDay $hebrewMonth';
  } catch (e) {
    debugPrint('Error converting Hebrew date: $e');
    return hebrewDate;
  }
}
