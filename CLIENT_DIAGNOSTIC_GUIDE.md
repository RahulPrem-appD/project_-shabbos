# Client Diagnostic Guide - Notification and Audio Issues

## Quick Overview
Your app should work reliably, but if you're experiencing issues where "notification didn't pop up and song didn't play at time", follow this guide to diagnose and fix the problem.

---

## Step 1: Generate Diagnostic Report

**What it does:** Creates a detailed report of all scheduled alarms, permissions, and system status

**How to use:**
1. Open the Shabbos!! app
2. Go to Settings
3. Look for "Diagnostic Report" or "Troubleshooting" option
4. Tap it to generate a report
5. Share/Export the report (this will help identify issues)

**What to look for in the report:**
- Check "Pending Notifications" section - should show upcoming alarms
- Check "Android Permissions" section - all should be true
- Check "Native Android Alarms" section - should list scheduled alarms
- Check "Health Check Status" - should show recent health checks

---

## Step 2: Test with Immediate Notification

**What it does:** Verifies basic notification and sound functionality

**How to use:**
1. Open Settings
2. Look for "Send Test Notification" button
3. Tap it
4. Check if notification appears
5. Check if sound plays

**If this fails:**
- **No notification:** Check notification permissions (see Step 3)
- **Notification but no sound:** Check device volume (see Step 4)

---

## Step 3: Verify Permissions (Android)

### Android 12+ Users

**Check Exact Alarm Permission:**
1. Go to Settings > Apps > Shabbos!! > Special App Access
2. Tap "Alarms & Reminders"
3. Make sure "Alarms & Reminders" is enabled

**Check Notification Permission:**
1. Go to Settings > Apps > Shabbos!! > Notifications
2. Make sure "Notifications" is ON
3. Tap "Shabbos Alerts" channel
4. Make sure it's enabled and set to "Important" or "Urgent"

**Check Battery Optimization:**
1. Go to Settings > Apps > Shabbos!! > Battery
2. Tap "Battery Optimization" or "Unrestricted"
3. Select "Unrestricted" or "Allow background activity"
4. This is CRITICAL - battery optimization can kill the app in background

### Android 13+ Users

**Additional Steps:**
1. Go to Settings > Apps > Shabbos!! > Permissions
2. Check "Notifications" - should be "Allow"
3. Check all other permissions are granted

---

## Step 4: Check Device Volume

**Common Issue:** Alarm volume is separate from media volume!

**How to fix:**
1. Go to Settings > Sound & Vibration
2. Find "Alarm Volume" slider
3. Make sure it's turned up (not zero)
4. Also check "Media Volume" and "Ringtone Volume"

**Do Not Disturb (DND) Mode:**
1. Go to Settings > Sound & Vibration > Do Not Disturb
2. Either turn it OFF
3. Or tap "Exceptions" and ensure "Alarms" are allowed

**Silent/Vibrate Mode:**
1. Check phone is not in Silent mode (physical switch on iPhone)
2. Check phone is not in Vibrate-only mode
3. Try turning volume up with physical buttons

---

## Step 5: Test Scheduled Notifications

**What it does:** Schedules test alarms for tomorrow to verify full notification flow

**How to use:**
1. Open Settings
2. Look for "Schedule Daily Test Notifications"
3. Tap it
4. You'll see confirmation with scheduled times
5. Wait for the scheduled time tomorrow
6. Check if notification appears and sound plays

**If this works:**
- Your setup is correct!
- The issue was likely with specific candle lighting times
- Regular alarms should work now

**If this fails:**
- Check all permissions again (Step 3)
- Generate diagnostic report (Step 1)
- Contact support with the report

---

## Step 6: Test Sound Playback Directly

**What it does:** Tests if sound files can be played

**How to use:**
1. Open Settings
2. Look for "Test Sound Playback" button
3. Tap it
4. You should hear the Shofar sound

**If you don't hear sound:**
- Check device volume (Step 4)
- Check device is not on silent/vibrate
- Check sound files are working in the app
- Try playing music from another app to verify audio works

---

## Step 7: Test After Device Restart

**What it does:** Verifies alarms survive device restart

**How to use:**
1. Schedule daily test notifications (Step 5)
2. Restart your device (power off and on)
3. Wait for device to fully boot up
4. Generate diagnostic report (Step 1)
5. Check if alarms are still scheduled in the report
6. Wait for scheduled time
7. Check if notification appears and sound plays

**If alarms are lost after restart:**
- Check boot receiver is working
- Check battery optimization isn't killing the app immediately
- The app should automatically reschedule alarms on boot

---

## Common Issues and Solutions

### Issue 1: "I see the notification but no sound plays"

**Possible Causes:**
1. Alarm volume is zero
2. Device is on silent mode
3. Do Not Disturb is blocking sound

**Solutions:**
- Check Alarm Volume (Step 4)
- Turn off Do Not Disturb or allow alarms
- Take device off silent mode

### Issue 2: "No notification appears at all"

**Possible Causes:**
1. Notification permission denied
2. Notification channel blocked
3. Battery optimization killed the app

**Solutions:**
- Grant notification permission (Step 3)
- Enable "Shabbos Alerts" channel in settings
- Disable battery optimization (Step 3)

### Issue 3: "Notifications work sometimes but not always"

**Possible Causes:**
1. Battery optimization is inconsistent
2. Device manufacturer's aggressive background restrictions
3. App is being killed in background

**Solutions:**
- Set battery optimization to "Unrestricted" (Step 3)
- Add app to allowed background apps list
- Try using the app regularly to keep it in memory

### Issue 4: "Notifications stopped working after several days"

**Possible Causes:**
1. Alarms were cleared by system
2. App was updated or reinstalled
3. Permissions changed by system update

**Solutions:**
- Open the app to refresh alarms
- Generate diagnostic report to check alarm status
- Verify permissions are still granted
- Reschedule notifications by selecting city/time in app

---

## Platform-Specific Information

### Android Users

**Critical Permissions:**
- SCHEDULE_EXACT_ALARM (Android 12+)
- POST_NOTIFICATIONS (Android 13+)
- Battery optimization disabled

**Known Issues by Manufacturer:**
- **Samsung:** May need to add to "Protected Apps" in battery settings
- **Xiaomi:** May need to enable "Auto-start" in security settings
- **Oppo/Vivo:** May need to add to "Startup Manager"

### iOS Users

**Critical Settings:**
- Notifications must be allowed in Settings > Notifications > Shabbos!!
- Sound files must be in .caf format (they are!)
- Background app refresh should be enabled

**iOS-Specific Issues:**
- iOS manages notifications differently than Android
- Some sound types may not play in silent mode
- Check iOS notification settings carefully

---

## Getting Help

If you've tried all steps and still have issues:

1. **Generate Diagnostic Report** (Step 1)
2. **Share the Report** with support team
3. **Include:**
   - Your device model (e.g., iPhone 13, Samsung Galaxy S22)
   - Android/iOS version (e.g., Android 13, iOS 16)
   - What steps you've tried
   - What happens vs. what you expect to happen

---

## Quick Reference Checklist

- [ ] Generated diagnostic report
- [ ] Tested immediate notification
- [ ] Verified all permissions (Android 12/13+)
- [ ] Disabled battery optimization
- [ ] Checked alarm volume is up
- [ ] Turned off Do Not Disturb or allowed alarms
- [ ] Device not on silent mode
- [ ] Tested scheduled notifications
- [ ] Tested sound playback
- [ ] Tested after device restart

---

## Tips for Reliable Notifications

1. **Keep the app updated** - updates often include bug fixes
2. **Open the app regularly** - helps keep it in memory
3. **Check after major iOS/Android updates** - permissions may reset
4. **Don't force-close the app** - let it run normally
5. **Use the diagnostic report** - it shows exactly what's happening

---

## Technical Notes (For Developers)

The app uses:
- **Android:** AlarmManager with exact alarms + WakeLock + ForegroundService
- **iOS:** flutter_local_notifications with UNNotificationRequest
- **Audio:** Custom MediaPlayer service for reliable sound playback
- **Health Checks:** WorkManager checks alarm health every 12 hours

Diagnostic logs are stored in:
- Android: `/storage/emulated/0/Android/data/com.shabbos.shabbos_app/files/debug_logs.txt`
- Flutter: SharedPreferences (accessible via diagnostic report)

---

**Last Updated:** January 27, 2026
**App Version:** Current
