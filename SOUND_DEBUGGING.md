# Sound Playback Debugging Guide

## Quick Test Steps

### Step 1: Test Direct Sound Playback
1. Open the app
2. Go to **Settings** tab
3. Tap **"Test Notification"**
4. **Listen for sound immediately**

**Expected Result:**
- ✅ **If you HEAR sound**: AudioService is working! The issue is with notification sounds.
- ❌ **If you DON'T hear sound**: The problem is with sound files or AudioService.

### Step 2: Check Console Logs

Look for these debug messages:

**For Android:**
```
AudioService: Attempting to play sound: rav_shalom_shofar
AudioService: Playing asset: sounds/RavShalomShofarDefaultlouder.mp3
AudioService: Successfully started playing rav_shalom_shofar
```

**For iOS:**
```
AudioService: Attempting to play sound: rav_shalom_shofar
AudioService: Playing asset: sounds/RavShalomShofarDefaultlouder.mp3
AudioService: Successfully started playing rav_shalom_shofar
```

### Step 3: Test Scheduled Notification

1. Go to **Settings** tab
2. Tap **"Test Scheduled Notification"**
3. **Close the app completely** (swipe away)
4. Wait 10 seconds
5. Check if notification appears AND sound plays

## Common Issues & Solutions

### Issue 1: No Sound on Immediate Test

**Symptoms:**
- Notification appears
- No sound plays
- Console shows "AudioService: Successfully started playing"

**Possible Causes:**
1. **Device volume is muted**
   - Check device volume buttons
   - Check silent mode switch (iOS)
   - Check Do Not Disturb mode

2. **Sound file missing**
   - Check `pubspec.yaml` includes: `assets/sounds/`
   - Verify files exist in `assets/sounds/` directory
   - Run `flutter clean && flutter pub get`

3. **AudioService not working**
   - Check console for errors
   - Try restarting the app

### Issue 2: No Sound on Scheduled Notifications (Android)

**Symptoms:**
- Notification appears
- No sound plays
- App is closed when notification fires

**Possible Causes:**
1. **AlarmAudioService not starting**
   - Check logcat for: `ShabbosAlarmReceiver: Started AlarmAudioService`
   - Check logcat for: `ShabbosAlarmAudioService: onStartCommand called`
   - Check logcat for: `ShabbosAlarmAudioService: MediaPlayer started`

2. **Audio focus denied**
   - Check logcat for: `Audio focus denied`
   - Some devices require special permissions

3. **MediaPlayer not playing**
   - Check logcat for: `MediaPlayer error`
   - Check logcat for: `isPlaying: false`

**Debug Steps:**
```bash
# Check Android logs
adb logcat | grep -i "ShabbosAlarm"
```

Look for:
- `AlarmReceiver: onReceive() called!` - Alarm fired
- `AlarmAudioService: onStartCommand called` - Service started
- `AlarmAudioService: MediaPlayer PREPARED` - Player ready
- `AlarmAudioService: MediaPlayer.start() called` - Playback started
- `AlarmAudioService: ✓ Audio playback confirmed` - Success!

### Issue 3: No Sound on Scheduled Notifications (iOS)

**Symptoms:**
- Notification appears
- No sound plays
- App is closed when notification fires

**Possible Causes:**
1. **Sound file format wrong**
   - iOS requires `.caf`, `.wav`, or `.aiff` (NOT `.mp3`)
   - Check console for: `⚠️ WARNING: iOS does not support .mp3`
   - Convert files using: `./convert_ios_sounds.sh`

2. **Sound file not in bundle**
   - Files must be added to Xcode project
   - Must be included in Target Membership
   - Check: Xcode → Runner target → Build Phases → Copy Bundle Resources

3. **Sound file name mismatch**
   - Name in code must match filename exactly
   - Case-sensitive on iOS
   - Check: `_getIosSoundFile()` returns correct name

**Debug Steps:**
1. Check Xcode console for:
   ```
   NotificationService: iOS sound file for rav_shalom_shofar: RavShalomShofarDefaultlouder.caf
   NotificationService: ⚠️ Make sure .caf file exists in ios/Runner/Sounds/
   ```

2. Verify files in Xcode:
   - Open `ios/Runner.xcworkspace`
   - Check `Runner/Sounds/` folder
   - Verify `.caf` files are listed
   - Check Target Membership includes "Runner"

3. Test sound file:
   ```bash
   # Check if file exists
   ls -la ios/Runner/Sounds/*.caf
   
   # Check file format
   file ios/Runner/Sounds/RavShalomShofarDefaultlouder.caf
   # Should show: "Core Audio"
   ```

## Platform-Specific Debugging

### Android Debugging

**Check AlarmReceiver logs:**
```bash
adb logcat | grep "ShabbosAlarmReceiver"
```

**Check AlarmAudioService logs:**
```bash
adb logcat | grep "ShabbosAlarmAudioService"
```

**Check if service is running:**
```bash
adb shell dumpsys activity services | grep AlarmAudioService
```

**Common Android Issues:**
- Battery optimization killing the service
- Audio focus denied by another app
- MediaPlayer initialization failure
- Asset file path incorrect

### iOS Debugging

**Check Xcode console:**
- Look for `NotificationService:` messages
- Look for `ShabbosApp:` messages (from AppDelegate)

**Check notification settings:**
- Settings → Shabbos!! → Notifications
- Ensure "Allow Notifications" is ON
- Ensure "Sounds" is ON

**Common iOS Issues:**
- Sound files are `.mp3` instead of `.caf`
- Files not added to Xcode bundle
- Sound file name doesn't match
- Sound file longer than 30 seconds

## Verification Checklist

### For Android:
- [ ] Sound files exist in `assets/sounds/`
- [ ] `pubspec.yaml` includes `assets/sounds/`
- [ ] AlarmReceiver is registered in AndroidManifest.xml
- [ ] AlarmAudioService is registered in AndroidManifest.xml
- [ ] Battery optimization is disabled
- [ ] Audio focus is granted (check logs)
- [ ] MediaPlayer starts successfully (check logs)

### For iOS:
- [ ] Sound files are `.caf`, `.wav`, or `.aiff` (NOT `.mp3`)
- [ ] Files are in `ios/Runner/Sounds/` directory
- [ ] Files are added to Xcode project
- [ ] Files are included in Target Membership (Runner)
- [ ] Files are listed in "Copy Bundle Resources"
- [ ] Sound file names match exactly (case-sensitive)
- [ ] Sound files are less than 30 seconds
- [ ] Notification permissions granted
- [ ] Sounds enabled in notification settings

## Next Steps

1. **Run the test notification** and check console logs
2. **Identify which step fails** (AudioService, AlarmReceiver, AlarmAudioService, etc.)
3. **Check the specific error messages** in logs
4. **Follow the platform-specific debugging steps** above

## Getting Help

If sounds still don't play after following this guide:

1. **Collect logs:**
   - Android: `adb logcat > sound_debug.log`
   - iOS: Copy Xcode console output

2. **Note the platform:** Android or iOS?

3. **Note when it fails:**
   - Immediate test notification?
   - Scheduled notification?
   - Both?

4. **Check the diagnostic report:**
   - The app has a diagnostic report feature
   - Use it to gather system information
