# Test Scheduled Notifications - iOS

## Issue
Immediate notifications work, but 10-second scheduled notifications don't appear.

## What I Fixed

1. **Added comprehensive debug logging** to see exactly what's happening when scheduling
2. **Ensured proper timezone handling** for scheduled times
3. **Added notification cancellation** before scheduling new test notification
4. **Verified iOS permissions** are correctly requested

## Testing Steps

### Step 1: Run with Console Output

```bash
cd /Users/rahul/Development/project_\ shabbos
flutter run --verbose
```

### Step 2: Test Immediate Notification (Verify Permissions)

1. Open the app
2. Go to **Settings** tab
3. Tap **"Test Notification"**
4. You should see an immediate notification

✅ **If this works:** Permissions are granted correctly

### Step 3: Test Scheduled Notification (App Open)

1. Go to **Settings** tab
2. Tap **"Test Scheduled Notification"**
3. **Keep the app OPEN**
4. Watch the console for these debug messages:

```
==========================================
NotificationService: SCHEDULING TEST NOTIFICATION
==========================================
NotificationService: Delay: 10 seconds
NotificationService: Current time: ...
NotificationService: Scheduled for: ...
NotificationService: Setting up iOS notification...
NotificationService: Local timezone: ...
NotificationService: Difference: 10 seconds
NotificationService: ✓ iOS notification scheduled successfully!
NotificationService: Pending notifications: 1
  ✓ ID 998: שבת שלום! Good Shabbos!
==========================================
```

5. **Wait 10 seconds**
6. Notification should appear

### Step 4: What to Check in Console

#### ✅ **GOOD SIGNS:**
- `✓ iOS notification scheduled successfully!`
- `Pending notifications: 1` (or more)
- `Difference: 10 seconds` (correct time difference)

#### ❌ **BAD SIGNS:**
- `⚠️ WARNING: No pending notifications found!`
- `✗ ERROR scheduling notification:`
- `Pending notifications: 0`
- `Difference: -X seconds` (negative = scheduled in the past)

## Important iOS Behaviors

### 🔴 **iOS Foreground Notification Limitation**

**IMPORTANT:** On iOS, scheduled notifications **MAY NOT** appear when the app is in the foreground (on screen). This is iOS system behavior.

To properly test:

**Option A: Minimize the app**
1. Tap "Test Scheduled Notification"
2. Immediately press **Home button** (don't kill, just minimize)
3. Wait 10 seconds on home screen
4. Notification should appear

**Option B: Lock the device**
1. Tap "Test Scheduled Notification"
2. Immediately **lock the device** (power button)
3. Wait 10 seconds
4. Notification should appear on lock screen

**Option C: Switch to another app**
1. Tap "Test Scheduled Notification"
2. Immediately switch to another app (Safari, etc.)
3. Wait 10 seconds
4. Notification should appear

### Why Immediate Notification Works but Scheduled Doesn't

- **Immediate notification** uses `show()` which can display in foreground
- **Scheduled notification** uses `zonedSchedule()` which iOS may suppress in foreground

This is **expected iOS behavior**, not a bug!

## Troubleshooting

### If Console Shows "✓ Scheduled successfully" but No Notification:

1. **App is in foreground** - Try minimizing the app
2. **Do Not Disturb is ON** - Check control center
3. **Focus mode active** - Turn off Focus
4. **Notification settings** - Settings → Shabbos!! → Notifications → Ensure all ON

### If Console Shows "⚠️ No pending notifications":

This means the notification wasn't actually scheduled. Check for error messages in the console.

### If Console Shows Error:

Copy the full error message and investigate the specific issue.

## Final Test (Most Important)

**Test with app NOT in foreground:**

1. Open app → Settings
2. Tap "Test Scheduled Notification"
3. **Immediately press Home button** (or lock device)
4. Wait 10 seconds
5. Notification should appear

This mimics real-world usage where users schedule notifications and close the app.

## Expected Results

✅ **Working correctly if:**
- Console shows "✓ iOS notification scheduled successfully!"
- Console shows "Pending notifications: 1" (or more)
- Notification appears after 10 seconds **when app is NOT in foreground**

❌ **Issue exists if:**
- No notification after 10 seconds **when app is minimized/locked**
- Console shows errors
- Console shows 0 pending notifications

## Real-World Usage

For actual Shabbat notifications:
- Users schedule notifications
- Users close the app
- Notifications fire at the correct time
- **This works even when app is killed**

The 10-second test notification should work the same way when the app is minimized.

---

**Next Step:** Run the test with console output and share the logs!

