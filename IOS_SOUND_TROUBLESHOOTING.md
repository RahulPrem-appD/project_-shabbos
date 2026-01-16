# iOS Notification Sound Troubleshooting

## Problem
Scheduled notifications are not playing sounds on iOS.

## Quick Diagnosis

After rebuilding the app, check the Xcode console for these messages:
- `ShabbosApp: Verifying sound files in bundle...`
- `ShabbosApp: ✓ Found [filename].caf` (should see 6 files)
- `ShabbosApp: ✗ NOT FOUND: [filename].caf` (indicates missing files)

## Step-by-Step Fix

### 1. Verify Files Are in Xcode Project

1. Open `ios/Runner.xcworkspace` in Xcode
2. In the Project Navigator (left sidebar), look for a "Sounds" folder
3. Verify all 6 `.caf` files are listed:
   - `RavShalomShofarDefaultlouder.caf`
   - `RYomTovShabbatShalomSong.caf`
   - `YomTov-Default.caf`
   - `Ata Bechartanu-YomTov.caf`
   - `Ata Bechartanu2-YomTov.caf`
   - `HoduLaHashem-YomTov.caf`

### 2. Verify Files Are in Build Resources

1. In Xcode, select the **Runner** target (top of left sidebar)
2. Click **Build Phases** tab
3. Expand **Copy Bundle Resources**
4. Scroll down and verify all 6 `.caf` files are listed
5. If any are missing:
   - Click the **+** button
   - Navigate to `ios/Runner/Sounds/`
   - Select the missing `.caf` files
   - Click **Add**

### 3. Clean and Rebuild

**CRITICAL:** You MUST do a clean build:

```bash
# Stop the app if running
# Then run:
flutter clean
cd ios
rm -rf Pods Podfile.lock
pod install
cd ..
flutter pub get
flutter build ios
```

Or in Xcode:
1. **Product** → **Clean Build Folder** (⇧⌘K)
2. **Product** → **Build** (⌘B)

### 4. Verify Files Are in Bundle

After rebuilding, check the console output when the app launches. You should see:
```
ShabbosApp: ✓ Found RavShalomShofarDefaultlouder.caf
ShabbosApp: ✓ Found RYomTovShabbatShalomSong.caf
...
ShabbosApp: Found 6/6 sound files in bundle
```

If you see `✗ NOT FOUND` messages, the files are NOT in the bundle.

### 5. Alternative: Move Files to Bundle Root

If files still aren't found, try moving them to the bundle root:

1. In Xcode, select all `.caf` files in the "Sounds" folder
2. Right-click → **Delete** → Choose **Remove Reference** (NOT Move to Trash)
3. Right-click on **Runner** folder → **Add Files to "Runner"...**
4. Navigate to `ios/Runner/Sounds/`
5. Select all `.caf` files
6. **IMPORTANT:** Check these options:
   - ✅ **Copy items if needed**
   - ✅ **Create groups** (NOT folder references)
   - ✅ **Runner** target is checked
7. Click **Add**
8. Verify they appear in **Copy Bundle Resources**
9. Clean and rebuild

### 6. Verify Sound File Format

Check that files are valid `.caf` format:

```bash
cd ios/Runner/Sounds
file *.caf
```

Should show: `Core Audio File`

Check duration (must be < 30 seconds):

```bash
afinfo *.caf | grep duration
```

### 7. Test Notification

1. Open the app
2. Go to Settings
3. Tap "Test Scheduled Notification"
4. Close the app completely (swipe up from app switcher)
5. Wait 10 seconds
6. Notification should appear WITH sound

## Common Issues

### Issue: Files Not in Bundle

**Symptoms:**
- Console shows `✗ NOT FOUND` for all files
- Notifications appear but no sound plays

**Fix:**
- Ensure files are in **Copy Bundle Resources**
- Clean build folder and rebuild
- Check file paths in Xcode project

### Issue: Wrong File Format

**Symptoms:**
- Files exist but iOS ignores them
- Console shows files found but no sound

**Fix:**
- Verify files are `.caf` format (not `.mp3`)
- Check file encoding: `afinfo file.caf`
- Re-convert if needed: `afconvert input.mp3 output.caf -d ima4 -f caff -v`

### Issue: File Name Mismatch

**Symptoms:**
- Files found but wrong sound plays (or default sound)

**Fix:**
- Verify exact filename match (case-sensitive!)
- Check code references: `DarwinNotificationDetails(sound: 'RavShalomShofarDefaultlouder.caf')`
- Must include `.caf` extension

### Issue: Files Too Long

**Symptoms:**
- Files found but iOS plays default sound instead

**Fix:**
- Check duration: `afinfo file.caf | grep duration`
- Must be < 30 seconds
- Trim if needed

## Still Not Working?

1. **Check Xcode Console:**
   - Window → Devices and Simulators
   - Select your device
   - Click "Open Console"
   - Filter by "ShabbosApp"
   - Look for sound-related errors

2. **Verify Notification Settings:**
   - iOS Settings → Notifications → ShabbosApp
   - Ensure "Allow Notifications" is ON
   - Check "Sounds" is enabled

3. **Test with Default Sound:**
   - Temporarily change code to use `sound: null` (default sound)
   - If default sound works, issue is with `.caf` files
   - If default sound doesn't work, issue is with notification setup

4. **Check Device Settings:**
   - Ensure device is not in Silent Mode
   - Check volume is up
   - Try on a different device/simulator

## Expected Console Output (Success)

```
ShabbosApp: Verifying sound files in bundle...
ShabbosApp: ✓ Found RavShalomShofarDefaultlouder.caf at: /path/to/bundle/RavShalomShofarDefaultlouder.caf
ShabbosApp: ✓ Found RYomTovShabbatShalomSong.caf at: /path/to/bundle/RYomTovShabbatShalomSong.caf
...
ShabbosApp: Found 6/6 sound files in bundle
```

If you see this, files are in the bundle and should work!
