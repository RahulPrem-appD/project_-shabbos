# iOS Notification Sound Fix

## Problem
Scheduled notifications on iOS are not playing sounds.

## Root Cause
**iOS does NOT support .mp3 files for notification sounds!**

iOS notification sounds must be in one of these formats:
- `.caf` (Core Audio Format) - **Recommended**
- `.wav` (Waveform Audio)
- `.aiff` (Audio Interchange File Format)

The app currently has `.mp3` files, which work fine for Android but **will not work** for iOS notifications.

## Solution

### Step 1: Convert MP3 files to CAF format

Run the conversion script:

```bash
cd /Users/rahulprem/Development/project_-shabbos
./convert_ios_sounds.sh
```

This will convert all `.mp3` files in `ios/Runner/Sounds/` to `.caf` format.

**Manual conversion (if script doesn't work):**

```bash
cd ios/Runner/Sounds

# Convert each file individually
afconvert RavShalomShofarDefaultlouder.mp3 RavShalomShofarDefaultlouder.caf -d ima4 -f caff -v
afconvert RYomTovShabbatShalomSong.mp3 RYomTovShabbatShalomSong.caf -d ima4 -f caff -v
afconvert YomTov-Default.mp3 YomTov-Default.caf -d ima4 -f caff -v
afconvert "Ata Bechartanu-YomTov.mp3" "Ata Bechartanu-YomTov.caf" -d ima4 -f caff -v
afconvert "Ata Bechartanu2-YomTov.mp3" "Ata Bechartanu2-YomTov.caf" -d ima4 -f caff -v
afconvert HoduLaHashem-YomTov.mp3 HoduLaHashem-YomTov.caf -d ima4 -f caff -v
```

### Step 2: Add CAF files to Xcode project

1. Open the project in Xcode:
   ```bash
   open ios/Runner.xcworkspace
   ```

2. In Xcode:
   - Right-click on the `Runner` folder (or `Sounds` folder if it exists)
   - Select "Add Files to Runner..."
   - Navigate to `ios/Runner/Sounds/`
   - Select all the `.caf` files
   - **IMPORTANT**: Check these options:
     - ✅ "Copy items if needed"
     - ✅ "Create groups" (not folder references)
     - ✅ Check "Runner" in "Add to targets"
   - Click "Add"

3. Verify the files are in the bundle:
   - Select a `.caf` file in Xcode
   - Check the "Target Membership" in the right panel
   - Ensure "Runner" is checked

### Step 3: Verify file format

The sound files must also meet these requirements:
- ✅ Format: `.caf`, `.wav`, or `.aiff` (NOT `.mp3`)
- ✅ Duration: Less than 30 seconds
- ✅ Location: In app bundle (not just in folder)
- ✅ Target: Included in Runner target

### Step 4: Rebuild the app

```bash
flutter clean
flutter pub get
flutter build ios
# Or run directly:
flutter run
```

## Testing

After converting and adding the files:

1. **Test immediate notification:**
   - Open app → Settings → "Test Notification"
   - Should hear sound immediately

2. **Test scheduled notification:**
   - Open app → Settings → "Test Scheduled Notification"
   - Lock device or minimize app
   - Wait 10 seconds
   - Should hear sound when notification appears

## Verification

Check the console logs when scheduling notifications. You should see:

```
NotificationService: iOS sound file for rav_shalom_shofar: RavShalomShofarDefaultlouder.caf
NotificationService: ✓ iOS notification scheduled successfully
```

If you see warnings about `.mp3` files, the conversion didn't work or files weren't added correctly.

## Troubleshooting

### Sound still doesn't play:

1. **Check file format:**
   ```bash
   file ios/Runner/Sounds/*.caf
   ```
   Should show "Core Audio" format

2. **Check file duration:**
   ```bash
   afinfo ios/Runner/Sounds/*.caf | grep duration
   ```
   Should be less than 30 seconds

3. **Check Xcode bundle:**
   - Open Xcode → Runner target → Build Phases → Copy Bundle Resources
   - Verify `.caf` files are listed

4. **Check notification permissions:**
   - Settings → Shabbos!! → Notifications
   - Ensure "Allow Notifications" is ON
   - Ensure "Sounds" is ON

5. **Check device settings:**
   - Settings → Sounds & Haptics
   - Ensure volume is up
   - Ensure device is not in silent mode

## Additional Notes

- The `.mp3` files are still needed for Android (they work fine there)
- The `.caf` files are only needed for iOS
- Both formats can coexist in the project
- The code automatically uses `.caf` for iOS and `.mp3` for Android

## References

- [Apple Documentation: Custom Notification Sounds](https://developer.apple.com/documentation/usernotifications/unnotificationsound)
- [flutter_local_notifications iOS Setup](https://pub.dev/packages/flutter_local_notifications#ios-setup)
