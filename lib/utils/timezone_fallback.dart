/// Last-resort timezone guess when neither the city list nor the Hebcal
/// timezone lookup produced a real IANA zone.
///
/// Returns a FIXED-OFFSET zone (Etc/GMT±N) instead of a real region zone.
/// A region zone can observe DST the actual location doesn't: the old maps
/// returned 'Asia/Jerusalem' for every UTC+2 longitude, which made South
/// African times one hour late for the entire Israeli summer (proven with
/// Marloth Park: Hebcal 5:15 PM, app 6:13 PM). A fixed offset is at worst
/// off by a constant all year — never seasonally, never by surprise.
///
/// NOTE: Etc/GMT zone names invert the sign — UTC+2 is 'Etc/GMT-2'.
/// Hebcal accepts these (verified: tzid=Etc/GMT-2 returns +02:00 times).
String fixedOffsetZoneForLongitude(double longitude) {
  final offset = (longitude / 15).round().clamp(-12, 12);
  if (offset == 0) return 'Etc/GMT';
  return offset > 0 ? 'Etc/GMT-$offset' : 'Etc/GMT+${offset.abs()}';
}
