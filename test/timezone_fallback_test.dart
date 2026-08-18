import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:shabbos_app/utils/timezone_fallback.dart';

void main() {
  setUpAll(() {
    tzdata.initializeTimeZones();
  });

  group('fixedOffsetZoneForLongitude', () {
    test('South Africa (lon 31.77) gets fixed UTC+2, never a DST zone', () {
      expect(fixedOffsetZoneForLongitude(31.77), 'Etc/GMT-2');
    });

    test('representative longitudes map to the expected fixed offsets', () {
      expect(fixedOffsetZoneForLongitude(-74.0), 'Etc/GMT+5'); // New York
      expect(fixedOffsetZoneForLongitude(-118.2), 'Etc/GMT+8'); // Los Angeles
      expect(fixedOffsetZoneForLongitude(35.2), 'Etc/GMT-2'); // Jerusalem
      expect(fixedOffsetZoneForLongitude(0.1), 'Etc/GMT'); // London
      expect(fixedOffsetZoneForLongitude(-157.8), 'Etc/GMT+11'); // Honolulu
      expect(fixedOffsetZoneForLongitude(174.8), 'Etc/GMT-12'); // Auckland
    });

    test('extreme longitudes stay within valid Etc range', () {
      expect(fixedOffsetZoneForLongitude(180.0), 'Etc/GMT-12');
      expect(fixedOffsetZoneForLongitude(-180.0), 'Etc/GMT+12');
    });

    test('every returned zone resolves in the tz database', () {
      for (double lon = -180; lon <= 180; lon += 7.5) {
        final zone = fixedOffsetZoneForLongitude(lon);
        expect(() => tz.getLocation(zone), returnsNormally,
            reason: '$zone (lon $lon) must exist in tzdata');
      }
    });
  });

  group('fire-instant anchoring (Marloth Park regression)', () {
    // Hebcal for Marloth Park (correct tzid Africa/Johannesburg) returns
    // candles 2026-08-14T17:15:00+02:00. The parser strips the offset and
    // keeps the naive wall clock 17:15. The scheduler must anchor that wall
    // clock in the LOCATION's zone.
    final naive = DateTime(2026, 8, 14, 17, 15);

    tz.TZDateTime anchor(String zone) => tz.TZDateTime(
          tz.getLocation(zone),
          naive.year,
          naive.month,
          naive.day,
          naive.hour,
          naive.minute,
        );

    test('Africa/Johannesburg and Etc/GMT-2 give the same true instant', () {
      final real = anchor('Africa/Johannesburg');
      final fixed = anchor('Etc/GMT-2');
      expect(real.toUtc(), DateTime.utc(2026, 8, 14, 15, 15));
      expect(fixed.toUtc(), real.toUtc(),
          reason: 'fixed-offset fallback must agree with the real zone');
    });

    test('the old Asia/Jerusalem guess was one hour late in August', () {
      final wrong = anchor('Asia/Jerusalem'); // IDT, UTC+3 in August
      final right = anchor('Africa/Johannesburg'); // SAST, UTC+2 year-round
      expect(wrong.toUtc().difference(right.toUtc()),
          const Duration(hours: -1),
          reason: 'same wall clock, +3 zone → instant is 1h EARLIER in UTC, '
              'so the alarm fires an hour late by local truth');
    });

    test('Etc sign inversion sanity: Etc/GMT-2 means UTC+2', () {
      final t = tz.TZDateTime(tz.getLocation('Etc/GMT-2'), 2026, 1, 1, 12);
      expect(t.toUtc(), DateTime.utc(2026, 1, 1, 10));
    });
  });
}
