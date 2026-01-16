# Verify iOS Sound Files Are in Bundle

## Quick Verification

The `.caf` files have been:
1. ✅ Created in `ios/Runner/Sounds/`
2. ✅ Added to Xcode project (`project.pbxproj`)
3. ✅ Added to build resources

## ⚠️ CRITICAL: Rebuild Required

**You MUST rebuild the app** for the `.caf` files to be included in the app bundle:

```bash
flutter clean
flutter pub get
flutter build ios
# Or run directly:
flutter run
```

## Verify Files Are in Bundle (After Rebuild)

After rebuilding, you can verify the files are in the bundle:

### Option 1: Check Built App Bundle

```bash
# Find the built app
find ~/Library/Developer/Xcode/DerivedData -name "Runner.app" -type d | head -1

# List sounds in bundle
ls -la "/path/to/Runner.app/Sounds/"*.caf
```

### Option 2: Check via Xcode

1. Open `ios/Runner.xcworkspace` in Xcode
2. Select the Runner target
3. Go to "Build Phases" → "Copy Bundle Resources"
4. Verify all `.caf` files are listed
5. Build the app (⌘+B)
6. Check the build log for any errors

## Testing After Rebuild

1. **Test immediate notification:**
   - Settings → "Test Notification"
   - Should hear sound

2. **Test scheduled notification:**
   - Settings → "Test Scheduled Notification"
   - Close app completely
   - Wait 10 seconds
   - Notification should appear WITH sound

## If Sounds Still Don't Play

### Check iOS Console Logs

In Xcode:
1. Window → Devices and Simulators
2. Select your device
3. Click "Open Console"
4. Filter by "ShabbosApp" or "notification"
5. Look for errors about sound files

### Common Issues

1. **Files not in bundle:**
   - Rebuild required
   - Check "Copy Bundle Resources" in Xcode

2. **File name mismatch:**
   - iOS is case-sensitive
   - Must match exactly: `RavShalomShofarDefaultlouder.caf`

3. **File too long:**
   - Must be < 30 seconds
   - Check: `afinfo ios/Runner/Sounds/*.caf | grep duration`

4. **Wrong format:**
   - Must be `.caf`, `.wav`, or `.aiff`
   - Check: `file ios/Runner/Sounds/*.caf`

## Expected Behavior

After rebuilding:
- ✅ Immediate notifications play sound
- ✅ Scheduled notifications play sound when they fire
- ✅ Sounds work even when app is closed

If this doesn't work after rebuilding, check Xcode console for specific error messages.
