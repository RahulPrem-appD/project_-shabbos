# iOS Notifications Test Guide

## Problem
iOS notifications not showing when app is killed

## Root Cause
iOS local notifications scheduled with `zonedSchedule` **SHOULD** work even when the app is killed - they're handled by the iOS system itself. If they're not working, it's usually due to:

1. **iOS system settings blocking notifications**
2. **Do Not Disturb / Focus mode enabled**
3. **Notification permissions not granted**
4. **Simulator issues** (notifications behave differently than on real devices)

---

## Testing Steps

### 1. Check Notification Permissions

After installing the app:

```bash
# Run the app
flutter run

# In the app:
1. Go to Settings tab
2. Enable Notifications
3. ALLOW notifications when prompted
4. Check that the permission dialog appeared
```

**On iOS device/simulator:**
- Settings → Shabbos!! → Notifications
- Ensure "Allow Notifications" is ON
- Ensure "Banners" is selected
- Ensure "Sounds" is ON

---

### 2. Test Immediate Notification

```bash
# In the app:
1. Go to Settings tab
2. Tap "Test Notification"
3. You should see a notification immediately
```

✅ **If this works:** Permission is granted correctly  
❌ **If this doesn't work:** Permission issue - reinstall the app and grant permission

---

### 3. Test Scheduled Notification (App Open)

```bash
# In the app:
1. Go to Settings tab
2. Tap "Test Scheduled Notification"
3. Keep the app OPEN
4. Wait 10 seconds
5. Notification should appear
```

✅ **If this works:** Scheduling mechanism works  
❌ **If this doesn't work:** Timezone or scheduling issue

---

### 4. Test Scheduled Notification (App Killed) - THE CRITICAL TEST

```bash
# In the app:
1. Go to Settings tab
2. Tap "Test Scheduled Notification"
3. IMMEDIATELY swipe up to kill the app (double-tap home, swipe up)
4. Wait 10 seconds
5. Notification should appear ON THE LOCK SCREEN
```

✅ **If this works:** Everything is working correctly!  
❌ **If this doesn't work:** See troubleshooting below

---

## Troubleshooting

### If notification doesn't show when app is killed:

#### Option 1: Check Focus/Do Not Disturb
- Swipe down from top-right → Check if Focus/DND is ON
- Turn it OFF

#### Option 2: Check Notification Settings
```
Settings → Shabbos!! → Notifications
✓ Allow Notifications: ON
✓ Lock Screen: ON
✓ Notification Center: ON
✓ Banners: ON
✓ Sounds: ON
✓ Badges: ON
```

#### Option 3: Check Time & Timezone
```
Settings → General → Date & Time
✓ Set Automatically: ON
✓ Time Zone: Correct
```

#### Option 4: Reset Simulator
```bash
# Stop the simulator
xcrun simctl shutdown all

# Erase all content
xcrun simctl erase all

# Run app again
flutter run
```

#### Option 5: Test on Real Device
**iOS Simulator has known issues with scheduled notifications**

Real device testing steps:
```bash
# Connect iPhone via USB
flutter run

# Or build and install manually:
flutter build ios
# Then install via Xcode
```

---

## Debug Logs

To see what's happening:

```bash
# Run with verbose logging
flutter run --verbose

# Look for these logs:
"NotificationService: Scheduling iOS notification"
"NotificationService: iOS notification scheduled successfully"
"NotificationService: Pending iOS notifications: X"

# Check pending notifications:
# If count is 0, notifications aren't being scheduled
# If count > 0, notifications ARE scheduled (iOS will show them)
```

---

## Expected Behavior

✅ **CORRECT:** Scheduled notifications fire even when app is:
- In background
- Killed/swiped away
- Device is locked
- After device restart

❌ **INCORRECT:** Notifications only work when app is:
- In foreground
- In background (but not killed)

---

## Key Insights

1. **iOS Local Notifications are system-level**
   - They don't need the app running
   - They don't need background modes
   - iOS handles them natively

2. **Simulator Limitations**
   - Simulator may not show notifications reliably
   - Always test on real device for accurate results

3. **Time-sensitive notifications**
   - Our notifications use `interruptionLevel: .timeSensitive`
   - This bypasses Focus mode (if configured)
   - Critical for religious timing notifications

4. **Permission is crucial**
   - Without notification permission, nothing works
   - Permission must be granted when first requested
   - Reinstalling the app resets permissions

---

## How to Debug: Step-by-Step

### Step 1: Check if notifications are being scheduled
```dart
// In notification_service.dart, after scheduling:
final pending = await _notifications.pendingNotificationRequests();
debugPrint('Pending: ${pending.length}');
for (final n in pending) {
  debugPrint('ID ${n.id}: ${n.title} at ${n.payload}');
}
```

**Expected:** Count > 0 after scheduling

### Step 2: Verify timezone
```dart
debugPrint('Local timezone: ${tz.local.name}');
debugPrint('Current time: ${DateTime.now()}');
debugPrint('Scheduled time: $scheduledTime');
```

**Expected:** Scheduled time is in the future

### Step 3: Check notification details
```dart
// Make sure interruptionLevel is set:
const iosDetails = DarwinNotificationDetails(
  presentAlert: true,
  presentBadge: true,
  presentSound: true,
  badgeNumber: 1,
  interruptionLevel: InterruptionLevel.timeSensitive, // ← Important!
);
```

---

## Final Checklist

Before reporting an issue, verify:

- [ ] Notification permission granted (Settings → Shabbos!! → Notifications)
- [ ] Focus/Do Not Disturb is OFF
- [ ] Time & timezone are correct
- [ ] Tested on REAL iOS device (not just simulator)
- [ ] App was completely killed (not just backgrounded)
- [ ] Waited full 10+ seconds after killing app
- [ ] Checked lock screen (not just notification center)
- [ ] Sound is not muted
- [ ] Volume is up

---

## Contact Info

If all the above fails on a **real iOS device**, the issue might be:
1. iOS version-specific bug
2. Device-specific restriction
3. Code bug (report with logs)

For testing: Always use a **real iPhone**, not simulator!


