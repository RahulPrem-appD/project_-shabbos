# Android Notification Sound Debugging

## Current Status

The Android notification system uses:
1. **Native Alarm Scheduler** (`AlarmScheduler.kt`) - schedules exact alarms
2. **Alarm Receiver** (`AlarmReceiver.kt`) - receives alarm broadcasts  
3. **Alarm Audio Service** (`AlarmAudioService.kt`) - foreground service that plays sound
4. **MediaPlayer** - plays `.mp3` files from assets

## Common Issues

### Issue 1: Notification Appears But No Sound

**Possible Causes:**

1. **Battery Optimization Killing Service**
   - Android may kill the foreground service
   - Solution: Disable battery optimization for the app

2. **Do Not Disturb Mode**
   - Android blocks notification sounds in DND mode
   - Solution: Configure notification category as ALARM

3. **Audio Focus Not Granted**
   - Other apps may have audio focus
   - Check logs for "Audio focus denied"

4. **Service Not Starting**
   - AlarmReceiver may not start AlarmAudioService
   - Check logs for "Started AlarmAudioService"

### Issue 2: No Notification At All

**Possible Causes:**

1. **Exact Alarm Permission Not Granted (Android 12+)**
   - Check: Settings → Apps → ShabbosApp → Alarms & reminders
   - Enable "Alarms & reminders" permission

2. **Notification Permission Not Granted (Android 13+)**
   - Check: Settings → Apps → ShabbosApp → Notifications
   - Enable notifications

3. **Alarm Not Scheduled**
   - Check logs for "Native alarm scheduled"
   - Verify `AlarmScheduler.setAlarm()` is called

## Debugging Steps

### Step 1: Enable Logging

Run the app and check logcat:

```bash
# Clear logs first
adb logcat -c

# Monitor logs
adb logcat | grep -E "ShabbosAlarm|ShabbosApp"
```

### Step 2: Test Scheduled Notification

1. Open the app
2. Go to Settings tab
3. Tap "Test Scheduled Notification"
4. Close the app COMPLETELY (swipe away from recents)
5. Wait 10 seconds
6. Check if notification appears AND sound plays

### Step 3: Check Expected Log Sequence

When the alarm fires, you should see:

```
ShabbosAlarmReceiver: ========================================
ShabbosAlarmReceiver: onReceive() called!
ShabbosAlarmReceiver: Intent action: ...
ShabbosAlarmReceiver: WakeLock acquired
ShabbosAlarmReceiver: Started AlarmAudioService
ShabbosAlarmAudioService: ========================================
ShabbosAlarmAudioService: onStartCommand called
ShabbosAlarmAudioService: Sound ID: rav_shalom_shofar
ShabbosAlarmAudioService: Wake lock acquired: true
ShabbosAlarmAudioService: Started foreground service
ShabbosAlarmAudioService: Playing sound: rav_shalom_shofar
ShabbosAlarmAudioService: Asset path: flutter_assets/assets/sounds/RavShalomShofarDefaultlouder.mp3
ShabbosAlarmAudioService: Audio focus granted
ShabbosAlarmAudioService: Asset file found and opened
ShabbosAlarmAudioService: MediaPlayer PREPARED
ShabbosAlarmAudioService: MediaPlayer.start() called
ShabbosAlarmAudioService: MediaPlayer.isPlaying: true
ShabbosAlarmAudioService: ✓ Audio playback confirmed
```

### Step 4: Check for Missing Steps

If you see logs up to a certain point, that tells you where it fails:

**If you don't see "onReceive() called!":**
- Alarm not scheduled OR permission denied
- Check: Settings → Apps → ShabbosApp → Alarms & reminders
- Grant "Alarms & reminders" permission

**If you see "onReceive()" but not "onStartCommand":**
- Service failed to start
- Check: Battery optimization might be killing it
- Disable battery optimization: Settings → Apps → ShabbosApp → Battery → Unrestricted

**If you see "onStartCommand" but not "MediaPlayer PREPARED":**
- Asset file not found OR MediaPlayer error
- Check: `flutter clean && flutter pub get`
- Verify sound files in `assets/sounds/`

**If you see "MediaPlayer PREPARED" but not "isPlaying: true":**
- Audio focus denied OR MediaPlayer error
- Check: Close other audio apps
- Check: Volume is not muted

## Quick Fixes

### Fix 1: Disable Battery Optimization

```bash
# Open battery optimization settings
adb shell am start -a android.settings.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS -d package:com.shabbos.shabbos_app
```

Then manually disable battery optimization.

### Fix 2: Grant Exact Alarm Permission (Android 12+)

```bash
# Open exact alarm settings
adb shell am start -a android.settings.REQUEST_SCHEDULE_EXACT_ALARM
```

Then manually enable for ShabbosApp.

### Fix 3: Test Audio Playback Directly

```bash
# Check if sound files exist in APK
unzip -l build/app/outputs/flutter-apk/app-release.apk | grep -i "sounds.*mp3"
```

Should show:
```
assets/flutter_assets/assets/sounds/RavShalomShofarDefaultlouder.mp3
assets/flutter_assets/assets/sounds/RYomTovShabbatShalomSong.mp3
...
```

### Fix 4: Verify Notification Channel

The app creates a notification channel:
- **Channel ID:** `shabbos_alerts`
- **Name:** "Shabbos Alerts"
- **Importance:** HIGH
- **Category:** ALARM

Check channel settings:
```
Settings → Apps → ShabbosApp → Notifications → Shabbos Alerts
```

Ensure:
- ✅ Show notifications
- ✅ Sound: Enabled
- ✅ Override Do Not Disturb: Enabled (if available)

## Testing Checklist

- [ ] Exact alarm permission granted (Android 12+)
- [ ] Notification permission granted (Android 13+)
- [ ] Battery optimization disabled
- [ ] Do Not Disturb mode: OFF (or app excluded)
- [ ] Device volume: UP
- [ ] Sound files exist in `assets/sounds/`
- [ ] Notification channel "Shabbos Alerts" enabled
- [ ] Alarm scheduled successfully (check logs)

## Common Device-Specific Issues

### Samsung Devices
- **Issue:** Aggressive battery optimization
- **Fix:** Settings → Apps → ShabbosApp → Battery → Optimize battery usage → All → ShabbosApp → Don't optimize

### Xiaomi/MIUI Devices
- **Issue:** Autostart disabled
- **Fix:** Security → Autostart → Enable ShabbosApp

### Huawei/EMUI Devices
- **Issue:** App launch management
- **Fix:** Settings → Battery → App launch → ShabbosApp → Manage manually → Enable all

### OnePlus/OxygenOS Devices
- **Issue:** Advanced optimization
- **Fix:** Settings → Battery → Battery optimization → ShabbosApp → Don't optimize

## Still Not Working?

If after all checks sound still doesn't play:

1. **Capture full logs:**
   ```bash
   adb logcat -d > shabbos_logs.txt
   ```

2. **Check for errors:**
   ```bash
   grep -i "error\|exception\|failed" shabbos_logs.txt
   ```

3. **Check debug logs from app:**
   ```bash
   adb shell run-as com.shabbos.shabbos_app cat files/debug_logs.txt
   ```

4. **Test on different device:**
   - Try on another Android device
   - Helps identify device-specific issues
