#!/usr/bin/env dart

/// Test script to verify Shabbat time parsing with multiple locations
/// This demonstrates the timezone handling bug

void main() {
  print('=== Shabbat Time Parsing Test ===\n');

  // Simulate what the API returns for different locations
  // All times are for the same Shabbat (December 20, 2024)
  final testCases = [
    {
      'location': 'Jerusalem, Israel',
      'timezone': 'Asia/Jerusalem',
      'api_response': '2024-12-20T16:15:00+02:00', // 4:15pm Israel time
      'device_timezone': 'America/New_York', // User viewing from New York
      'expected_display': '09:15', // 9:15am Eastern (4:15pm Israel = 9:15am NY)
    },
    {
      'location': 'New York, NY',
      'timezone': 'America/New_York',
      'api_response': '2024-12-20T15:58:00-05:00', // 3:58pm Eastern time
      'device_timezone': 'America/New_York', // User viewing from New York
      'expected_display': '15:58', // 3:58pm Eastern
    },
    {
      'location': 'Los Angeles, CA',
      'timezone': 'America/Los_Angeles',
      'api_response': '2024-12-20T16:02:00-08:00', // 4:02pm Pacific time
      'device_timezone': 'America/New_York', // User viewing from New York
      'expected_display': '19:02', // 7:02pm Eastern (4:02pm Pacific = 7:02pm NY)
    },
    {
      'location': 'London, UK',
      'timezone': 'Europe/London',
      'api_response': '2024-12-20T15:47:00+00:00', // 3:47pm GMT
      'device_timezone': 'America/New_York', // User viewing from New York
      'expected_display': '10:47', // 10:47am Eastern (3:47pm GMT = 10:47am NY)
    },
    {
      'location': 'Tokyo, Japan',
      'timezone': 'Asia/Tokyo',
      'api_response': '2024-12-20T16:25:00+09:00', // 4:25pm Japan time
      'device_timezone': 'America/New_York', // User viewing from New York
      'expected_display': '02:25', // 2:25am Eastern (next day) (4:25pm Japan = 2:25am NY)
    },
  ];

  print('Current buggy behavior:\n');
  print('The app strips timezone info and treats API time as device local time.');
  print('This causes incorrect display when device timezone ≠ location timezone.\n');

  for (final testCase in testCases) {
    final location = testCase['location'] as String;
    final apiResponse = testCase['api_response'] as String;
    final expected = testCase['expected_display'] as String;

    // Simulate the buggy parsing
    final buggyResult = _parseBuggy(apiResponse);
    final correctResult = _parseCorrect(apiResponse);

    print('📍 $location');
    print('   API returns: $apiResponse');
    print('   ❌ Buggy code displays: $buggyResult (wrong!)');
    print('   ✅ Should display: $correctResult (expected: $expected)');
    print('   ⚠️  Error: ${calculateTimeDifference(buggyResult, correctResult)}\n');
  }

  print('\n=== Summary ===');
  print('The bug causes times to be off by several hours when the device');
  print('timezone differs from the Shabbat location timezone.');
  print('\nFix: Parse the full ISO 8601 string with timezone offset, then');
  print('convert to local device time for display.');
}

/// Simulates the buggy parsing in the current code
String _parseBuggy(String dateStr) {
  // This is what the current buggy code does:
  // 1. Strip the timezone offset
  // 2. Parse as if it's local time
  final cleanDate = dateStr.replaceAll(RegExp(r'[+-]\d{2}:\d{2}$'), '');
  final dateTime = DateTime.parse(cleanDate);

  // Format as HH:mm
  final hour = dateTime.hour.toString().padLeft(2, '0');
  final minute = dateTime.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

/// Simulates the correct parsing
String _parseCorrect(String dateStr) {
  // This is what the code SHOULD do:
  // 1. Parse the full ISO 8601 string with timezone
  // 2. The DateTime will be in UTC
  // 3. Convert to local time for display
  final dateTime = DateTime.parse(dateStr); // This parses to UTC

  // Convert to local time (simulated)
  final localTime = dateTime.toLocal();

  // Format as HH:mm
  final hour = localTime.hour.toString().padLeft(2, '0');
  final minute = localTime.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String calculateTimeDifference(String buggy, String correct) {
  final buggyParts = buggy.split(':');
  final correctParts = correct.split(':');

  final buggyMinutes = int.parse(buggyParts[0]) * 60 + int.parse(buggyParts[1]);
  final correctMinutes = int.parse(correctParts[0]) * 60 + int.parse(correctParts[1]);

  final diff = (buggyMinutes - correctMinutes).abs();
  final hours = diff ~/ 60;
  final minutes = diff % 60;

  if (hours > 0) {
    return '$hours hours ${minutes} minutes off';
  }
  return '$minutes minutes off';
}
