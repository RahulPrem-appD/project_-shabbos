# Alarm & Notification System - Edge Cases Analysis

## Critical Edge Cases to Consider

### 1. **Exact Boundary: 5 Minutes Threshold**
**Scenario**: User changes from 40→20 minutes when exactly 5 minutes before the old alarm would fire
- **Current behavior**: Protection threshold is exactly 5 minutes
- **Risk**: Alarm at exactly 5:00.000 might be cancelled if timing is off by milliseconds
- **Solution**: Use `>=` instead of `>` for threshold check, or add small buffer (5 minutes + 1 second)

### 2. **Backward Timing Change (20→40 minutes)**
**Scenario**: User changes from 20→40 minutes (making alarm earlier)
- **Current behavior**: New alarm time is further in future, so protection might not trigger
- **Risk**: Old alarm (20 min) might be cancelled even if it's imminent
- **Solution**: Check BOTH old and new alarm times - protect if EITHER is imminent

### 3. **Multiple Rapid Setting Changes**
**Scenario**: User changes 40→20→60→20 minutes in quick succession
- **Current behavior**: Each change triggers reschedule
- **Risk**: Race conditions, alarms might be cancelled/rescheduled multiple times
- **Solution**: Debounce rescheduling, or queue changes and process sequentially

### 4. **Device Timezone Change**
**Scenario**: User travels across timezone or device auto-adjusts for DST
- **Current behavior**: Alarms scheduled in local time might fire at wrong time
- **Risk**: Alarm fires at wrong absolute time
- **Solution**: Store alarms in UTC, convert to local time when displaying, reschedule on timezone change

### 5. **Daylight Saving Time Transition**
**Scenario**: DST starts/ends while alarms are scheduled
- **Current behavior**: Alarm times might shift by 1 hour unexpectedly
- **Risk**: Alarm fires 1 hour early/late
- **Solution**: Detect DST changes and reschedule all alarms, or use UTC timestamps

### 6. **User Disables Notifications Right Before Alarm**
**Scenario**: User turns off notifications 1 minute before alarm fires
- **Current behavior**: `setNotificationsEnabled(false)` cancels all alarms
- **Risk**: Alarm is cancelled even though it's about to fire
- **Solution**: Protect imminent alarms even when disabling notifications

### 7. **Sound Change While Alarm is Imminent**
**Scenario**: User changes sound selection 2 minutes before alarm
- **Current behavior**: Sound ID is locked in at scheduling, but reschedule might cancel alarm
- **Risk**: Alarm might be cancelled, or might fire with old sound (which is actually correct)
- **Solution**: If alarm is imminent, skip rescheduling entirely, just update future alarms

### 8. **App Force-Closed/Killed**
**Scenario**: User force-closes app or system kills it for memory
- **Current behavior**: Android native alarms should still fire
- **Risk**: iOS notifications might not fire if app is killed
- **Solution**: Ensure critical alarms use native Android alarms, iOS critical notifications

### 9. **Device Restart**
**Scenario**: Device reboots while alarms are scheduled
- **Current behavior**: Android alarms are saved to SharedPreferences and rescheduled on boot
- **Risk**: If reschedule fails, alarms are lost
- **Solution**: Verify boot receiver reschedules correctly, add retry logic

### 10. **Battery Dies and Device Restarts**
**Scenario**: Device battery dies, user charges and restarts
- **Current behavior**: Same as device restart
- **Risk**: Alarms might be lost if device was off during scheduled time
- **Solution**: Check for missed alarms on boot and notify user

### 11. **Location/Timezone Change**
**Scenario**: User changes location or manually changes timezone
- **Current behavior**: Candle lighting times change, alarms need rescheduling
- **Risk**: Old alarms fire at wrong time for new location
- **Solution**: Detect location/timezone change and reschedule immediately

### 12. **Candle Lighting Time Updates**
**Scenario**: API updates candle lighting time (rare but possible)
- **Current behavior**: App fetches new times, reschedules
- **Risk**: If update happens right before alarm, old alarm might fire at wrong time
- **Solution**: If new time differs significantly from old, cancel and reschedule even if imminent

### 13. **Large Timing Change (20→60 minutes)**
**Scenario**: User changes from 20→60 minutes
- **Current behavior**: New alarm is much earlier, old alarm might be imminent
- **Risk**: Old alarm fires even though user wants new timing
- **Solution**: If new alarm time is valid and >5 min away, allow cancelling old imminent alarm

### 14. **Small Timing Change (20→40 minutes) When Old Alarm is Imminent**
**Scenario**: User changes 20→40 minutes when 20-min alarm is about to fire
- **Current behavior**: New alarm (40 min) is further in future, old alarm (20 min) is imminent
- **Risk**: Old alarm fires, but user wanted 40-minute warning
- **Solution**: If user explicitly changes timing, prioritize new setting unless new alarm is also imminent

### 15. **Alarm Scheduled During Shabbat**
**Scenario**: User opens app during Shabbat and somehow triggers scheduling
- **Current behavior**: `_canPlayAlarmAt()` should block this
- **Risk**: Alarm might be scheduled but shouldn't fire
- **Solution**: Double-check in scheduling logic, add explicit Shabbat check

### 16. **Multiple Candle Lightings Close Together**
**Scenario**: Two Shabbats/Yom Tovs scheduled within hours of each other
- **Current behavior**: Both get scheduled
- **Risk**: Alarms might conflict, or protection logic might protect wrong one
- **Risk**: If changing timing affects multiple events, protection might be too aggressive
- **Solution**: Check each event individually, protect only truly imminent alarms per event

### 17. **Network Failure During Reschedule**
**Scenario**: User changes settings, but network fails when fetching candle lighting times
- **Current behavior**: Reschedule might fail silently
- **Risk**: Alarms are cancelled but not rescheduled
- **Solution**: Only cancel after successful reschedule, or restore old alarms on failure

### 18. **Language/Locale Change**
**Scenario**: User changes app language right before alarm
- **Current behavior**: Notification text changes, but alarm time/sound stay same
- **Risk**: Low risk, but notification text might be in wrong language
- **Solution**: Reschedule notifications with new locale, but protect imminent alarms

### 19. **App Update While Alarms Scheduled**
**Scenario**: App updates while alarms are scheduled
- **Current behavior**: Alarms should persist if using native Android alarms
- **Risk**: If alarm IDs or structure changes, alarms might be lost
- **Solution**: Use stable alarm IDs, version migration logic if needed

### 20. **Clock Manipulation (User Changes Device Time)**
**Scenario**: User manually changes device clock forward/backward
- **Current behavior**: Alarms fire based on device time
- **Risk**: User could manipulate time to avoid alarms or cause them to fire early
- **Solution**: Detect significant clock changes, warn user, or use server time for critical alarms

### 21. **BONUS: Simultaneous Settings Changes**
**Scenario**: User changes timing AND sound AND location simultaneously
- **Current behavior**: Multiple reschedules might happen
- **Risk**: Race conditions, inconsistent state
- **Solution**: Batch changes, single reschedule operation

### 22. **BONUS: Very Short Pre-Notification (1-5 minutes)**
**Scenario**: User sets pre-notification to 1 minute (if allowed)
- **Current behavior**: Alarm might be scheduled but protection logic might interfere
- **Risk**: Alarm might be cancelled if it's always "imminent"
- **Solution**: Adjust protection threshold based on pre-notification setting, or minimum threshold

---

## Recommended Fixes

1. **Add buffer to protection threshold**: Use 5 minutes + 1 second to avoid exact boundary issues
2. **Check both old and new alarm times**: Protect if EITHER is imminent when changing timing
3. **Debounce rescheduling**: Prevent rapid successive changes
4. **Use UTC for alarm storage**: Avoid timezone/DST issues
5. **Protect alarms when disabling notifications**: Don't cancel imminent alarms even when disabling
6. **Batch setting changes**: Process multiple changes together
7. **Add retry logic**: Retry failed reschedules
8. **Detect clock manipulation**: Warn or prevent significant time changes
9. **Version migration**: Handle alarm structure changes across app updates
10. **Individual event protection**: Protect alarms per event, not globally
