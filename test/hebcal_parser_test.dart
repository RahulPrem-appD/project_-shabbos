// Parser tests fed by real Hebcal JSON responses captured under
// `test/fixtures/`. They lock in the rules:
//   1. A candle lighting is Yom Tov iff the NEXT calendar day is a Yom Tov
//      holiday — same-day match is not enough (otherwise a Yom-Tov-into-
//      Shabbat Friday candle gets misclassified as a 2nd day of Yom Tov).
//   2. A Yom Tov candle is Day 2 iff the immediately preceding entry is also
//      a Yom Tov candle exactly 1 calendar day before. Applied uniformly in
//      Israel and Diaspora — Rosh Hashanah is 2-day even in Israel.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shabbos_app/models/candle_lighting.dart';
import 'package:shabbos_app/services/hebcal_service.dart';

Map<String, dynamic> _loadFixture(String name) {
  final file = File('test/fixtures/$name');
  return json.decode(file.readAsStringSync()) as Map<String, dynamic>;
}

List<CandleLighting> _parse(String fixtureName, {required bool isInIsrael}) {
  final data = _loadFixture(fixtureName);
  return HebcalService().parseExtendedResponseForTest(
    data,
    locale: 'en',
    isInIsrael: isInIsrael,
  );
}

CandleLighting _candleOnDate(List<CandleLighting> events, String yyyymmdd) {
  return events.firstWhere(
    (e) =>
        '${e.candleLightingTime.year.toString().padLeft(4, '0')}-'
            '${e.candleLightingTime.month.toString().padLeft(2, '0')}-'
            '${e.candleLightingTime.day.toString().padLeft(2, '0')}' ==
        yyyymmdd,
    orElse: () => throw StateError(
      'No candle lighting on $yyyymmdd. Got: ${events.map((e) => e.candleLightingTime.toIso8601String()).toList()}',
    ),
  );
}

void main() {
  group('Israel — single-day Yom Tov, no Shabbat overlap', () {
    test('Shavuot 5784 (Wed Yom Tov, normal year)', () {
      final events = _parse(
        'tlv_shavuot_5784_normal_year.json',
        isInIsrael: true,
      );
      final shavuotEve = _candleOnDate(events, '2024-06-11');
      expect(shavuotEve.isYomTov, isTrue);
      expect(shavuotEve.isSecondDayYomTov, isFalse);

      // Surrounding Shabbatot are NOT Yom Tov.
      expect(_candleOnDate(events, '2024-06-07').isYomTov, isFalse);
      expect(_candleOnDate(events, '2024-06-14').isYomTov, isFalse);
    });

    test('Sukkot 5787 — 1 day each, spaced apart by chol hamoed', () {
      final events = _parse('tlv_sukkot_5787.json', isInIsrael: true);

      final sukkotI = _candleOnDate(events, '2026-09-25');
      expect(sukkotI.isYomTov, isTrue);
      expect(sukkotI.isSecondDayYomTov, isFalse);

      final shminiAtzeret = _candleOnDate(events, '2026-10-02');
      expect(shminiAtzeret.isYomTov, isTrue);
      expect(shminiAtzeret.isSecondDayYomTov, isFalse);

      // Bereshit Shabbat after Sukkot — regular Shabbat.
      final bereshitShabbat = _candleOnDate(events, '2026-10-09');
      expect(bereshitShabbat.isYomTov, isFalse);
    });
  });

  group('Israel — bug case: Yom Tov rolling into Shabbat', () {
    test('Shavuot 5786 — Friday Yom Tov, Saturday Shabbat (THE bug)', () {
      final events = _parse(
        'tlv_shavuot_5786_into_shabbat.json',
        isInIsrael: true,
      );

      // Thursday: erev Shavuot — Yom Tov candle.
      final shavuotEve = _candleOnDate(events, '2026-05-21');
      expect(shavuotEve.isYomTov, isTrue);
      expect(shavuotEve.isSecondDayYomTov, isFalse);

      // Friday: candle lighting transitions Yom Tov→Shabbat. Must NOT be
      // marked Yom Tov (this is what fixed "still showing 2 days in Israel").
      final shabbat = _candleOnDate(events, '2026-05-22');
      expect(
        shabbat.isYomTov,
        isFalse,
        reason: 'Friday candle for Shabbat after 1-day Israeli Yom Tov '
            'must NOT be flagged as Day 2 of Yom Tov.',
      );
      expect(shabbat.isSecondDayYomTov, isFalse);
    });
  });

  group('Israel — Rosh Hashanah is 2-day even in Israel', () {
    test('RH 5787 — Day 2 flagged so alarms get suppressed', () {
      final events = _parse('tlv_rh_5787.json', isInIsrael: true);

      final day1 = _candleOnDate(events, '2026-09-11');
      expect(day1.isYomTov, isTrue);
      expect(day1.isSecondDayYomTov, isFalse);

      final day2 = _candleOnDate(events, '2026-09-12');
      expect(day2.isYomTov, isTrue);
      expect(
        day2.isSecondDayYomTov,
        isTrue,
        reason: 'Rosh Hashanah Day 2 must be flagged in Israel — '
            'alarms must be suppressed per spec.',
      );

      // Yom Kippur (single day) follows on 9/20.
      final yomKippurEve = _candleOnDate(events, '2026-09-20');
      expect(yomKippurEve.isYomTov, isTrue);
      expect(yomKippurEve.isSecondDayYomTov, isFalse);
    });
  });

  group('Diaspora — 2-day Yom Tov', () {
    test('NYC Sukkot 5787 — Day 2 flagged for both Sukkot and SA', () {
      final events = _parse('nyc_sukkot_5787.json', isInIsrael: false);

      // Sukkot Day 1 + Day 2.
      expect(_candleOnDate(events, '2026-09-25').isYomTov, isTrue);
      expect(_candleOnDate(events, '2026-09-25').isSecondDayYomTov, isFalse);
      expect(_candleOnDate(events, '2026-09-26').isYomTov, isTrue);
      expect(_candleOnDate(events, '2026-09-26').isSecondDayYomTov, isTrue);

      // Shemini Atzeret + Simchat Torah (separate in Diaspora).
      expect(_candleOnDate(events, '2026-10-02').isYomTov, isTrue);
      expect(_candleOnDate(events, '2026-10-02').isSecondDayYomTov, isFalse);
      expect(_candleOnDate(events, '2026-10-03').isYomTov, isTrue);
      expect(
        _candleOnDate(events, '2026-10-03').isSecondDayYomTov,
        isTrue,
        reason: 'Simchat Torah is Day 2 of Shemini Atzeret in Diaspora.',
      );
    });

    test('NYC Pesach 5786 — Day 1+2 and Day 7+8, Chol HaMoed Shabbat NOT YT', () {
      final events = _parse('nyc_pesach_5786.json', isInIsrael: false);

      // Day 1 / Day 2.
      expect(_candleOnDate(events, '2026-04-01').isYomTov, isTrue);
      expect(_candleOnDate(events, '2026-04-01').isSecondDayYomTov, isFalse);
      expect(_candleOnDate(events, '2026-04-02').isYomTov, isTrue);
      expect(_candleOnDate(events, '2026-04-02').isSecondDayYomTov, isTrue);

      // Shabbat Chol HaMoed — NOT Yom Tov.
      final cholHamoedShabbat = _candleOnDate(events, '2026-04-03');
      expect(
        cholHamoedShabbat.isYomTov,
        isFalse,
        reason: 'Shabbat Chol HaMoed candle has no Yom Tov holiday on '
            'next day, so must NOT be flagged Yom Tov.',
      );

      // Day 7 / Day 8.
      expect(_candleOnDate(events, '2026-04-07').isYomTov, isTrue);
      expect(_candleOnDate(events, '2026-04-07').isSecondDayYomTov, isFalse);
      expect(_candleOnDate(events, '2026-04-08').isYomTov, isTrue);
      expect(_candleOnDate(events, '2026-04-08').isSecondDayYomTov, isTrue);
    });

    test('NYC Shavuot 5786 — Day 2 = Shabbat, but Day-2-of-YT subsumes', () {
      final events = _parse('nyc_shavuot_5786.json', isInIsrael: false);

      expect(_candleOnDate(events, '2026-05-21').isYomTov, isTrue);
      expect(_candleOnDate(events, '2026-05-21').isSecondDayYomTov, isFalse);

      // The Friday candle leads into Saturday = Shavuot II = Yom Tov AND
      // Shabbat. Yom Tov classification wins.
      final day2 = _candleOnDate(events, '2026-05-22');
      expect(day2.isYomTov, isTrue);
      expect(day2.isSecondDayYomTov, isTrue);
    });

    test('NYC Rosh Hashanah 5787 — Day 2 flagged', () {
      final events = _parse('nyc_rh_5787.json', isInIsrael: false);

      expect(_candleOnDate(events, '2026-09-11').isYomTov, isTrue);
      expect(_candleOnDate(events, '2026-09-11').isSecondDayYomTov, isFalse);
      expect(_candleOnDate(events, '2026-09-12').isYomTov, isTrue);
      expect(_candleOnDate(events, '2026-09-12').isSecondDayYomTov, isTrue);
    });
  });

  group('Israel — Pesach 5786, 1-day at start and end', () {
    test('Day 1 only and Day 7 only, Chol HaMoed Shabbat NOT Yom Tov', () {
      final events = _parse('tlv_pesach_5786.json', isInIsrael: true);

      // Day 1.
      expect(_candleOnDate(events, '2026-04-01').isYomTov, isTrue);
      expect(_candleOnDate(events, '2026-04-01').isSecondDayYomTov, isFalse);

      // Shabbat Chol HaMoed.
      expect(_candleOnDate(events, '2026-04-03').isYomTov, isFalse);

      // Day 7 (= Pesach VII).
      expect(_candleOnDate(events, '2026-04-07').isYomTov, isTrue);
      expect(_candleOnDate(events, '2026-04-07').isSecondDayYomTov, isFalse);

      // Regular Shabbat after.
      expect(_candleOnDate(events, '2026-04-10').isYomTov, isFalse);

      // No Day 2 anywhere.
      expect(events.any((e) => e.isSecondDayYomTov), isFalse);
    });
  });
}
