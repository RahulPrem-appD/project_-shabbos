# Inch-by-inch review (2026-01-24)

## Scope reviewed

- **Android native**: `AlarmScheduler.kt` → `AlarmReceiver.kt` → `AlarmAudioService.kt` and reboot rescheduling via `BootReceiver.kt`, plus `MainActivity.kt` MethodChannel glue.
- **Android manifest**: receiver/service declarations and required permissions.
- **Flutter**: `notification_service.dart` scheduling + diagnostics, and `native_alarm_service.dart` MethodChannel wrapper.

## Findings and fixes

### 1) Removed hardcoded desktop-path “agent log” file writes (Flutter)

**Problem**

`lib/services/notification_service.dart` contained “agent log” blocks that attempted to write JSON lines to:

- `/Users/rahul/Development/project_ shabbos/.cursor/debug.log`

This path is:

- **Not valid on Android/iOS devices** (would always throw),
- **User-specific** (wrong username/path),
- Adds avoidable noise and risk during scheduling.

**Fix**

- Removed those blocks entirely.
- Removed now-unused `dart:convert` import.

**Result**

- No more hardcoded file I/O from mobile codepaths.
- `flutter build apk --debug` still succeeds.

### 2) Confirmed native alarm/notification pipeline consistency

- **Channel IDs**: consistent use of `shabbos_alerts` across `MainActivity.kt`, `AlarmReceiver.kt`, `AlarmScheduler.kt`.
- **Foreground audio channel**: separate `shabbos_audio_service` in `AlarmAudioService.kt`.
- **PendingIntent flags**: `FLAG_IMMUTABLE | FLAG_UPDATE_CURRENT` used for modern Android; cancellation uses `FLAG_NO_CREATE` correctly.
- **WakeLocks**: all acquired with **timeouts** and released in `finally`/`onDestroy` paths.
- **Boot rescheduling**: `BootReceiver` registered with `BOOT_COMPLETED` and uses a WakeLock while rescheduling.
- **Scheduling validation**: performed in Flutter (pre-schedule) and native (pre-schedule + pre-execution checks) with logs.

## Build verification

- `flutter analyze`: only informational warnings in test files.
- `flutter build apk --debug`: **success**.

## Known platform limitations (unchanged)

Even with perfect code, Android OEM policies can still delay/prevent exact delivery in rare cases unless the user settings allow it:

- blocked notifications / blocked channel
- exact alarm permission not granted (Android 12+)
- aggressive battery optimization / OEM “sleeping apps”
- user DND settings (partially mitigated via channel bypass + alarm usage)

