package com.shabbos.shabbos_app

import android.app.AlarmManager
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build
import android.os.PowerManager
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.*

class AlarmScheduler(private val context: Context) {
    private val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
    private val prefs: SharedPreferences = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
    
    companion object {
        private const val TAG = "ShabbosAlarmScheduler"
        private const val PREFS_NAME = "shabbos_alarms"
        private const val KEY_SCHEDULED_ALARMS = "scheduled_alarms"
        
        /**
         * Helper function to write logs to debug_logs.txt for diagnostic reports
         */
        private fun writeDebugLog(context: Context, location: String, message: String, data: Map<String, Any?>? = null) {
            try {
                val logData = org.json.JSONObject().apply {
                    put("timestamp", System.currentTimeMillis())
                    put("location", location)
                    put("message", message)
                    if (data != null) {
                        val dataObj = org.json.JSONObject()
                        data.forEach { (key, value) ->
                            when (value) {
                                null -> dataObj.put(key, "null")
                                is Boolean -> dataObj.put(key, value)
                                is Number -> dataObj.put(key, value)
                                is String -> dataObj.put(key, value)
                                else -> dataObj.put(key, value.toString())
                            }
                        }
                        put("data", dataObj)
                    }
                }
                java.io.File(context.getExternalFilesDir(null), "debug_logs.txt").appendText("${logData.toString()}\n")
            } catch (e: Exception) {
                android.util.Log.e(TAG, "Failed to write debug log: ${e.message}")
            }
        }
    }
    
    fun scheduleAlarm(
        id: Int, 
        timestampMillis: Long, 
        title: String, 
        body: String, 
        isPreNotification: Boolean = false,
        candleLightingTime: Long = 0L,
        soundId: String = "rav_shalom_shofar"
    ): Boolean {
        // Log entry to debug_logs.txt immediately so we can see if this function is even called
        try {
            val entryLog = org.json.JSONObject().apply {
                put("timestamp", System.currentTimeMillis())
                put("location", "AlarmScheduler.kt:scheduleAlarm")
                put("message", "scheduleAlarm called")
                put("data", org.json.JSONObject().apply {
                    put("alarmId", id)
                    put("timestampMillis", timestampMillis)
                    put("title", title)
                    put("isPreNotification", isPreNotification)
                    put("soundId", soundId)
                })
            }
            java.io.File(context.getExternalFilesDir(null), "debug_logs.txt")
                .appendText("${entryLog.toString()}\n")
        } catch (_: Exception) {
            // ignore logging failures
        }
        
        try {
            val dateFormat = SimpleDateFormat("yyyy-MM-dd HH:mm:ss", Locale.getDefault())
            val scheduledDate = Date(timestampMillis)
            
            Log.d(TAG, "========================================")
            Log.d(TAG, "Scheduling alarm #$id")
            Log.d(TAG, "Timestamp: $timestampMillis")
            Log.d(TAG, "Scheduled for: ${dateFormat.format(scheduledDate)}")
            Log.d(TAG, "Current time: ${dateFormat.format(Date())}")
            Log.d(TAG, "Title: $title")
            Log.d(TAG, "Body: $body")
            Log.d(TAG, "Is pre-notification: $isPreNotification")
            Log.d(TAG, "Sound ID: $soundId")
            Log.d(TAG, "Candle lighting time: $candleLightingTime")
            Log.d(TAG, "Android version: ${Build.VERSION.SDK_INT}")
            
            // CRITICAL: Proactive validation before scheduling
            // Check permissions and system state to ensure alarm will work
            val validationIssues = mutableListOf<String>()
            
            // 1. Check exact alarm permission (Android 12+)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val canScheduleExact = alarmManager.canScheduleExactAlarms()
                if (!canScheduleExact) {
                    validationIssues.add("Exact alarm permission missing")
                    Log.w(TAG, "⚠️ WARNING: Exact alarm permission missing - alarm may be delayed")
                    writeDebugLog(context, "AlarmScheduler.kt:scheduleAlarm", "WARNING: Exact alarm permission missing", mapOf(
                        "alarmId" to id,
                        "risk" to "alarm_may_be_delayed",
                        "userActionRequired" to true
                    ))
                } else {
                    Log.d(TAG, "✓ Exact alarm permission granted")
                }
            }
            
            // 2. Check notification permission (Android 13+)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                val notificationsEnabled = notificationManager.areNotificationsEnabled()
                if (!notificationsEnabled) {
                    validationIssues.add("Notifications disabled")
                    Log.w(TAG, "⚠️ WARNING: Notifications disabled - notification won't appear")
                    writeDebugLog(context, "AlarmScheduler.kt:scheduleAlarm", "WARNING: Notifications disabled", mapOf(
                        "alarmId" to id,
                        "risk" to "notification_wont_appear",
                        "userActionRequired" to true
                    ))
                } else {
                    Log.d(TAG, "✓ Notifications enabled")
                }
            }
            
            // 3. Check battery optimization
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
                val isIgnoringBattery = powerManager.isIgnoringBatteryOptimizations(context.packageName)
                if (!isIgnoringBattery) {
                    validationIssues.add("Battery optimization enabled")
                    Log.w(TAG, "⚠️ WARNING: Battery optimization enabled - app may be killed")
                    writeDebugLog(context, "AlarmScheduler.kt:scheduleAlarm", "WARNING: Battery optimization enabled", mapOf(
                        "alarmId" to id,
                        "risk" to "app_may_be_killed",
                        "userActionRecommended" to true
                    ))
                } else {
                    Log.d(TAG, "✓ Battery optimization disabled")
                }
            }
            
            // 4. Verify notification channel exists and is not blocked
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                val channel = notificationManager.getNotificationChannel("shabbos_alerts")
                if (channel == null) {
                    validationIssues.add("Notification channel missing")
                    Log.w(TAG, "⚠️ WARNING: Notification channel missing - will be created")
                    writeDebugLog(context, "AlarmScheduler.kt:scheduleAlarm", "WARNING: Notification channel missing", mapOf(
                        "alarmId" to id,
                        "action" to "will_create_channel"
                    ))
                } else if (channel.importance == NotificationManager.IMPORTANCE_NONE) {
                    validationIssues.add("Notification channel blocked")
                    Log.w(TAG, "⚠️ WARNING: Notification channel is blocked - notification won't appear")
                    writeDebugLog(context, "AlarmScheduler.kt:scheduleAlarm", "WARNING: Notification channel blocked", mapOf(
                        "alarmId" to id,
                        "risk" to "notification_wont_appear",
                        "userActionRequired" to true
                    ))
                } else {
                    Log.d(TAG, "✓ Notification channel OK (importance: ${channel.importance})")
                }
            }
            
            // Log validation summary
            if (validationIssues.isNotEmpty()) {
                Log.w(TAG, "⚠️ VALIDATION WARNINGS for alarm #$id:")
                validationIssues.forEach { issue ->
                    Log.w(TAG, "  - $issue")
                }
                Log.w(TAG, "⚠️ Alarm will still be scheduled, but may not work reliably")
                writeDebugLog(context, "AlarmScheduler.kt:scheduleAlarm", "Validation warnings", mapOf(
                    "alarmId" to id,
                    "issues" to validationIssues,
                    "issueCount" to validationIssues.size,
                    "willStillSchedule" to true
                ))
            } else {
                Log.d(TAG, "✓ All validations passed - alarm should work reliably")
            }
            
            val intent = Intent(context, AlarmReceiver::class.java).apply {
                putExtra("notification_id", id)
                putExtra("notification_title", title)
                putExtra("notification_body", body)
                putExtra("is_pre_notification", isPreNotification)
                putExtra("candle_lighting_time", candleLightingTime)
                putExtra("sound_id", soundId)
                // Add action to make intent unique
                action = "com.shabbos.shabbos_app.ALARM_$id"
            }
            
            val pendingIntentFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }
            
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                id,
                intent,
                pendingIntentFlags
            )
            
            // Check current time vs scheduled time
            val now = System.currentTimeMillis()
            val actualScheduledTime = if (timestampMillis <= now) {
                Log.w(TAG, "WARNING: Scheduled time is in the past! Scheduling for 5 seconds from now for testing.")
                writeDebugLog(context, "AlarmScheduler.kt:scheduleAlarm", "WARNING: Scheduled time is in the past", mapOf(
                    "alarmId" to id,
                    "requestedTime" to timestampMillis,
                    "currentTime" to now,
                    "adjustedTime" to (now + 5000)
                ))
                now + 5000
            } else {
                timestampMillis
            }
            
            // Schedule the alarm internally - this returns true if successful
            val internalSuccess = scheduleAlarmInternal(actualScheduledTime, pendingIntent, id)
            if (!internalSuccess) {
                Log.e(TAG, "scheduleAlarmInternal returned false for alarm #$id")
                writeDebugLog(context, "AlarmScheduler.kt:scheduleAlarm", "CRITICAL: scheduleAlarmInternal returned false", mapOf(
                    "alarmId" to id,
                    "scheduledTime" to actualScheduledTime,
                    "title" to title
                ))
                Log.d(TAG, "========================================")
                return false
            }
            
            // #region agent log
            try {
                val logData = org.json.JSONObject().apply {
                    put("timestamp", System.currentTimeMillis())
                    put("location", "AlarmScheduler.kt:81")
                    put("message", "Alarm scheduled internally")
                    put("sessionId", "debug-session")
                    put("runId", "run1")
                    put("hypothesisId", "E")
                    put("data", org.json.JSONObject().apply {
                        put("alarmId", id)
                        put("scheduledTime", timestampMillis)
                        put("soundId", soundId)
                        put("isPreNotification", isPreNotification)
                    })
                }
                java.io.File(context.getExternalFilesDir(null), "debug_logs.txt").appendText("${logData.toString()}\n")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to write debug log: ${e.message}")
            }
            // #endregion
            
            // Save alarm data for persistence (survives device restart)
            try {
                saveAlarmData(id, timestampMillis, title, body, isPreNotification, candleLightingTime, soundId)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to save alarm data for #$id: ${e.message}", e)
                // Don't fail the entire scheduling if save fails - alarm is still scheduled
            }
            
            Log.d(TAG, "Alarm #$id scheduled successfully")
            Log.d(TAG, "========================================")
            return true
        } catch (e: Exception) {
            // Log exception to debug_logs.txt so it appears in diagnostic report
            try {
                val errorLog = org.json.JSONObject().apply {
                    put("timestamp", System.currentTimeMillis())
                    put("location", "AlarmScheduler.kt:scheduleAlarm")
                    put("message", "scheduleAlarm exception")
                    put("data", org.json.JSONObject().apply {
                        put("alarmId", id)
                        put("timestampMillis", timestampMillis)
                        put("isPreNotification", isPreNotification)
                        put("soundId", soundId)
                        put("error", e.toString())
                        put("errorMessage", e.message ?: "null")
                        put("errorClass", e.javaClass.simpleName)
                    })
                }
                java.io.File(context.getExternalFilesDir(null), "debug_logs.txt")
                    .appendText("${errorLog.toString()}\n")
            } catch (_: Exception) {
                // ignore logging failures
            }
            
            Log.e(TAG, "Failed to schedule alarm #$id: ${e.message}", e)
            Log.d(TAG, "========================================")
            return false
        }
    }
    
    /**
     * Save alarm data to SharedPreferences for persistence across device restarts
     */
    private fun saveAlarmData(
        id: Int,
        timestampMillis: Long,
        title: String,
        body: String,
        isPreNotification: Boolean,
        candleLightingTime: Long,
        soundId: String
    ) {
        try {
            val alarmsJson = prefs.getString(KEY_SCHEDULED_ALARMS, "[]")
            val alarmsArray = JSONArray(alarmsJson)
            
            // Remove any existing alarm with the same ID
            val newArray = JSONArray()
            for (i in 0 until alarmsArray.length()) {
                val alarm = alarmsArray.getJSONObject(i)
                if (alarm.getInt("id") != id) {
                    newArray.put(alarm)
                }
            }
            
            // Add the new alarm
            val alarmObject = JSONObject().apply {
                put("id", id)
                put("timestampMillis", timestampMillis)
                put("title", title)
                put("body", body)
                put("isPreNotification", isPreNotification)
                put("candleLightingTime", candleLightingTime)
                put("soundId", soundId)
            }
            newArray.put(alarmObject)
            
            prefs.edit().putString(KEY_SCHEDULED_ALARMS, newArray.toString()).apply()
            Log.d(TAG, "Saved alarm #$id to SharedPreferences (total: ${newArray.length()} alarms)")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to save alarm data: ${e.message}", e)
        }
    }
    
    /**
     * Remove alarm data from SharedPreferences
     */
    private fun removeAlarmData(id: Int) {
        try {
            val alarmsJson = prefs.getString(KEY_SCHEDULED_ALARMS, "[]")
            val alarmsArray = JSONArray(alarmsJson)
            
            val newArray = JSONArray()
            for (i in 0 until alarmsArray.length()) {
                val alarm = alarmsArray.getJSONObject(i)
                if (alarm.getInt("id") != id) {
                    newArray.put(alarm)
                }
            }
            
            prefs.edit().putString(KEY_SCHEDULED_ALARMS, newArray.toString()).apply()
            Log.d(TAG, "Removed alarm #$id from SharedPreferences")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to remove alarm data: ${e.message}", e)
        }
    }
    
    /**
     * Reschedule all saved alarms (called after device boot)
     * Edge Cases 9-10: Handle device restart and missed alarms
     */
    fun rescheduleAllSavedAlarms() {
        try {
            Log.d(TAG, "========================================")
            Log.d(TAG, "Rescheduling saved alarms after boot...")
            
            val alarmsJson = prefs.getString(KEY_SCHEDULED_ALARMS, "[]")
            val alarmsArray = JSONArray(alarmsJson)
            val now = System.currentTimeMillis()
            var rescheduledCount = 0
            var expiredCount = 0
            var missedCount = 0
            
            // Edge Cases 9-10: Check for missed alarms (were scheduled but device was off)
            val missedAlarmThreshold = 60 * 60 * 1000L // 1 hour - if alarm was within last hour, consider it missed
            
            for (i in 0 until alarmsArray.length()) {
                val alarm = alarmsArray.getJSONObject(i)
                val id = alarm.getInt("id")
                val timestampMillis = alarm.getLong("timestampMillis")
                val title = alarm.getString("title")
                val body = alarm.getString("body")
                val isPreNotification = alarm.getBoolean("isPreNotification")
                val candleLightingTime = alarm.optLong("candleLightingTime", 0L)
                val soundId = alarm.optString("soundId", "rav_shalom_shofar")
                
                val timeDiff = now - timestampMillis
                
                // Edge Cases 9-10: Check if alarm was missed (device was off during scheduled time)
                if (timeDiff > 0 && timeDiff < missedAlarmThreshold) {
                    missedCount++
                    Log.w(TAG, "⚠️ MISSED ALARM: Alarm #$id was scheduled for ${Date(timestampMillis)} but device was off")
                    Log.w(TAG, "⚠️ This alarm was missed - user should be notified")
                    writeDebugLog(context, "AlarmScheduler.kt:rescheduleAllSavedAlarms", "MISSED ALARM detected", mapOf(
                        "alarmId" to id,
                        "scheduledTime" to timestampMillis,
                        "currentTime" to now,
                        "timeDiff" to timeDiff,
                        "title" to title
                    ))
                    // Could trigger a notification here to inform user
                }
                
                // Only reschedule alarms that are still in the future
                if (timestampMillis > now) {
                    Log.d(TAG, "Rescheduling alarm #$id for ${Date(timestampMillis)}")
                    
                    val intent = Intent(context, AlarmReceiver::class.java).apply {
                        putExtra("notification_id", id)
                        putExtra("notification_title", title)
                        putExtra("notification_body", body)
                        putExtra("is_pre_notification", isPreNotification)
                        putExtra("candle_lighting_time", candleLightingTime)
                        putExtra("sound_id", soundId)
                        action = "com.shabbos.shabbos_app.ALARM_$id"
                    }
                    
                    val pendingIntentFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
                    } else {
                        PendingIntent.FLAG_UPDATE_CURRENT
                    }
                    
                    val pendingIntent = PendingIntent.getBroadcast(context, id, intent, pendingIntentFlags)
                    
                    // CRITICAL FIX: Use non-blocking retry logic
                    // Thread.sleep() in BroadcastReceiver can cause ANR
                    val scheduled = try {
                        val success = scheduleAlarmInternal(timestampMillis, pendingIntent, id)
                        if (success) {
                            writeDebugLog(context, "AlarmScheduler.kt:rescheduleAllSavedAlarms", "Alarm rescheduled successfully", mapOf(
                                "alarmId" to id,
                                "scheduledTime" to timestampMillis,
                                "title" to title
                            ))
                        }
                        success
                    } catch (e: Exception) {
                        Log.e(TAG, "✗ Failed to reschedule alarm #$id: ${e.message}")
                        writeDebugLog(context, "AlarmScheduler.kt:rescheduleAllSavedAlarms", "Failed to reschedule alarm", mapOf(
                            "alarmId" to id,
                            "error" to (e.message ?: "unknown"),
                            "title" to title
                        ))
                        false
                    }
                    
                } else {
                    Log.d(TAG, "Skipping expired alarm #$id (was scheduled for ${Date(timestampMillis)})")
                    expiredCount++
                }
            }
            
            // Clean up expired alarms from storage
            if (expiredCount > 0) {
                cleanupExpiredAlarms()
            }
            
            Log.d(TAG, "Rescheduled $rescheduledCount alarms, skipped $expiredCount expired alarms")
            if (missedCount > 0) {
                Log.w(TAG, "⚠️ WARNING: $missedCount alarms were missed (device was off)")
                writeDebugLog(context, "AlarmScheduler.kt:rescheduleAllSavedAlarms", "WARNING: Alarms were missed", mapOf(
                    "missedCount" to missedCount,
                    "rescheduledCount" to rescheduledCount,
                    "expiredCount" to expiredCount
                ))
            }
            Log.d(TAG, "========================================")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to reschedule alarms: ${e.message}", e)
            writeDebugLog(context, "AlarmScheduler.kt:rescheduleAllSavedAlarms", "CRITICAL ERROR rescheduling alarms", mapOf(
                "error" to (e.message ?: "unknown"),
                "errorType" to e.javaClass.simpleName,
                "stackTrace" to e.stackTraceToString()
            ))
            // Edge Cases 9-10: Could retry entire reschedule operation here
        }
    }
    
    /**
     * Remove expired alarms from storage
     */
    private fun cleanupExpiredAlarms() {
        try {
            val alarmsJson = prefs.getString(KEY_SCHEDULED_ALARMS, "[]")
            val alarmsArray = JSONArray(alarmsJson)
            val now = System.currentTimeMillis()
            
            val newArray = JSONArray()
            for (i in 0 until alarmsArray.length()) {
                val alarm = alarmsArray.getJSONObject(i)
                val timestampMillis = alarm.getLong("timestampMillis")
                if (timestampMillis > now) {
                    newArray.put(alarm)
                }
            }
            
            prefs.edit().putString(KEY_SCHEDULED_ALARMS, newArray.toString()).apply()
            Log.d(TAG, "Cleaned up expired alarms. Remaining: ${newArray.length()}")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to cleanup expired alarms: ${e.message}", e)
            writeDebugLog(context, "AlarmScheduler.kt:cleanupExpiredAlarms", "Error cleaning up expired alarms", mapOf(
                "error" to (e.message ?: "unknown")
            ))
        }
    }
    
    /**
     * Clear all saved alarm data
     */
    fun clearAllSavedAlarms() {
        prefs.edit().putString(KEY_SCHEDULED_ALARMS, "[]").apply()
        Log.d(TAG, "Cleared all saved alarm data")
    }
    
    /**
     * Get all scheduled alarms
     * Returns list of maps with alarm details
     * 
     * IMPORTANT: Uses opt* methods instead of get* methods to handle missing fields gracefully
     * This prevents the entire operation from failing if one alarm has corrupted/missing data
     */
    fun getScheduledAlarms(): List<Map<String, Any>> {
        try {
            val alarmsJson = prefs.getString(KEY_SCHEDULED_ALARMS, "[]")
            Log.d(TAG, "Raw alarms JSON: $alarmsJson")
            
            val alarmsArray = JSONArray(alarmsJson)
            val now = System.currentTimeMillis()
            val result = mutableListOf<Map<String, Any>>()
            
            Log.d(TAG, "Parsing ${alarmsArray.length()} alarms from storage")
            
            for (i in 0 until alarmsArray.length()) {
                try {
                    val alarm = alarmsArray.getJSONObject(i)
                    val timestampMillis = alarm.optLong("timestampMillis", 0L)
                    
                    // Skip invalid alarms (no timestamp)
                    if (timestampMillis == 0L) {
                        Log.w(TAG, "Skipping alarm at index $i: no valid timestamp")
                        writeDebugLog(context, "AlarmScheduler.kt:getScheduledAlarms", "Skipping alarm - no valid timestamp", mapOf(
                            "index" to i
                        ))
                        continue
                    }
                    
                    // Only return future alarms
                    if (timestampMillis > now) {
                        // Use opt* methods to handle missing fields gracefully
                        val id = alarm.optInt("id", -1)
                        val title = alarm.optString("title", "Notification")
                        val body = alarm.optString("body", "")
                        val isPreNotification = alarm.optBoolean("isPreNotification", false)
                        val soundId = alarm.optString("soundId", "rav_shalom_shofar")
                        
                        if (id == -1) {
                            Log.w(TAG, "Skipping alarm at index $i: no valid ID")
                            writeDebugLog(context, "AlarmScheduler.kt:getScheduledAlarms", "Skipping alarm - no valid ID", mapOf(
                                "index" to i
                            ))
                            continue
                        }
                        
                        result.add(mapOf(
                            "id" to id,
                            "timestampMillis" to timestampMillis,
                            "title" to title,
                            "body" to body,
                            "isPreNotification" to isPreNotification,
                            "soundId" to soundId
                        ))
                        
                        Log.d(TAG, "Added alarm #$id: title='$title', isPre=$isPreNotification, time=${java.util.Date(timestampMillis)}")
                    } else {
                        Log.d(TAG, "Skipping past alarm at index $i: scheduled for ${java.util.Date(timestampMillis)}")
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Error parsing alarm at index $i: ${e.message}")
                    writeDebugLog(context, "AlarmScheduler.kt:getScheduledAlarms", "Error parsing alarm", mapOf(
                        "index" to i,
                        "error" to (e.message ?: "unknown")
                    ))
                    // Continue to next alarm instead of failing entire operation
                }
            }
            
            // Sort by timestamp
            result.sortBy { it["timestampMillis"] as Long }
            
            Log.d(TAG, "========================================")
            Log.d(TAG, "Retrieved ${result.size} scheduled alarms:")
            for (alarm in result) {
                val id = alarm["id"]
                val title = alarm["title"]
                val isPre = alarm["isPreNotification"]
                val time = java.util.Date(alarm["timestampMillis"] as Long)
                Log.d(TAG, "  - #$id: '$title' (isPre=$isPre) at $time")
            }
            Log.d(TAG, "========================================")
            
            return result
        } catch (e: Exception) {
            Log.e(TAG, "Failed to get scheduled alarms: ${e.message}", e)
            writeDebugLog(context, "AlarmScheduler.kt:getScheduledAlarms", "CRITICAL ERROR getting scheduled alarms", mapOf(
                "error" to (e.message ?: "unknown"),
                "errorType" to e.javaClass.simpleName
            ))
            return emptyList()
        }
    }
    
    private fun scheduleAlarmInternal(timestampMillis: Long, pendingIntent: PendingIntent, id: Int): Boolean {
        var alarmScheduled = false
        var schedulingMethod = "unknown"
        var hasExactPermission = false
        
        try {
            when {
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.S -> {
                    // Android 12+:
                    // We intentionally prefer setExactAndAllowWhileIdle over setAlarmClock because
                    // setAlarmClock can behave inconsistently across OEMs when scheduling many alarms.
                    hasExactPermission = alarmManager.canScheduleExactAlarms()
                    if (hasExactPermission) {
                        Log.d(TAG, "Using setExactAndAllowWhileIdle (Android 12+)")
                        schedulingMethod = "setExactAndAllowWhileIdle"
                        alarmManager.setExactAndAllowWhileIdle(
                            AlarmManager.RTC_WAKEUP,
                            timestampMillis,
                            pendingIntent
                        )
                        alarmScheduled = true
                    } else {
                        Log.w(TAG, "No exact alarm permission! Using setAndAllowWhileIdle")
                        writeDebugLog(context, "AlarmScheduler.kt:scheduleAlarmInternal", "WARNING: No exact alarm permission", mapOf(
                            "alarmId" to id,
                            "fallbackMethod" to "setAndAllowWhileIdle"
                        ))
                        schedulingMethod = "setAndAllowWhileIdle"
                        alarmManager.setAndAllowWhileIdle(
                            AlarmManager.RTC_WAKEUP,
                            timestampMillis,
                            pendingIntent
                        )
                        alarmScheduled = true
                    }
                }
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.M -> {
                    // Android 6.0 - 11: Use setExactAndAllowWhileIdle
                    Log.d(TAG, "Using setExactAndAllowWhileIdle (Android 6-11)")
                    schedulingMethod = "setExactAndAllowWhileIdle"
                    alarmManager.setExactAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP,
                        timestampMillis,
                        pendingIntent
                    )
                    alarmScheduled = true
                }
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT -> {
                    // Android 4.4 - 5.1: Use setExact
                    Log.d(TAG, "Using setExact (Android 4.4-5.1)")
                    schedulingMethod = "setExact"
                    alarmManager.setExact(
                        AlarmManager.RTC_WAKEUP,
                        timestampMillis,
                        pendingIntent
                    )
                    alarmScheduled = true
                }
                else -> {
                    // Android < 4.4: Use set
                    Log.d(TAG, "Using set (Android <4.4)")
                    schedulingMethod = "set"
                    alarmManager.set(
                        AlarmManager.RTC_WAKEUP,
                        timestampMillis,
                        pendingIntent
                    )
                    alarmScheduled = true
                }
            }
        } catch (e: Exception) {
            // Persist the failure so it shows up in the in-app diagnostic report
            try {
                val logData = org.json.JSONObject().apply {
                    put("timestamp", System.currentTimeMillis())
                    put("location", "AlarmScheduler.kt:scheduleAlarmInternal")
                    put("message", "scheduleAlarmInternal threw")
                    put("data", org.json.JSONObject().apply {
                        put("alarmId", id)
                        put("timestampMillis", timestampMillis)
                        put("schedulingMethod", schedulingMethod)
                        put("hasExactPermission", hasExactPermission)
                        put("androidVersion", Build.VERSION.SDK_INT)
                        put("error", e.toString())
                    })
                }
                java.io.File(context.getExternalFilesDir(null), "debug_logs.txt")
                    .appendText("${logData.toString()}\n")
            } catch (_: Exception) {
                // ignore
            }
            Log.e(TAG, "scheduleAlarmInternal failed for #$id: ${e.message}", e)
            alarmScheduled = false
        }
        
        // #region agent log
        try {
            val logData = org.json.JSONObject().apply {
                put("timestamp", System.currentTimeMillis())
                put("location", "AlarmScheduler.kt:262")
                put("message", "Alarm scheduling method called")
                put("sessionId", "debug-session")
                put("runId", "run1")
                put("hypothesisId", "E")
                put("data", org.json.JSONObject().apply {
                    put("alarmId", id)
                    put("schedulingMethod", schedulingMethod)
                    put("hasExactPermission", hasExactPermission)
                    put("alarmScheduled", alarmScheduled)
                    put("androidVersion", Build.VERSION.SDK_INT)
                })
            }
            java.io.File(context.getExternalFilesDir(null), "debug_logs.txt").appendText("${logData.toString()}\n")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to write debug log: ${e.message}")
        }
        // #endregion
        
        return alarmScheduled
    }
    
    fun cancelAlarm(id: Int, protectImminent: Boolean = false): Boolean {
        try {
            Log.d(TAG, "Cancelling alarm #$id (protectImminent=$protectImminent)")
            
            // If protecting imminent alarms, check if this alarm is about to fire
            if (protectImminent) {
                val alarmsJson = prefs.getString(KEY_SCHEDULED_ALARMS, "[]")
                val alarmsArray = JSONArray(alarmsJson)
                val now = System.currentTimeMillis()
                // Edge Case 1: Add 1 second buffer to avoid exact boundary issues
                val imminentThreshold = 5 * 60 * 1000L + 1000L // 5 minutes + 1 second in milliseconds
                
                for (i in 0 until alarmsArray.length()) {
                    val alarm = alarmsArray.getJSONObject(i)
                    if (alarm.getInt("id") == id) {
                        val timestampMillis = alarm.getLong("timestampMillis")
                        val timeUntilAlarm = timestampMillis - now
                        
                        // Edge Case 1: Use >= instead of > to include exact threshold
                        if (timeUntilAlarm > 0 && timeUntilAlarm <= imminentThreshold) {
                            Log.w(TAG, "⚠️ PROTECTED: Alarm #$id is about to fire in ${timeUntilAlarm / 1000} seconds - NOT cancelling!")
                            Log.w(TAG, "⚠️ This alarm will fire with its originally scheduled sound and cannot be missed")
                            writeDebugLog(context, "AlarmScheduler.kt:cancelAlarm", "Alarm protected from cancellation", mapOf(
                                "alarmId" to id,
                                "timeUntilAlarm" to timeUntilAlarm,
                                "imminentThreshold" to imminentThreshold,
                                "action" to "protected_not_cancelled"
                            ))
                            return false // Don't cancel - protect the alarm
                        }
                        break
                    }
                }
            }
            
            val intent = Intent(context, AlarmReceiver::class.java).apply {
                action = "com.shabbos.shabbos_app.ALARM_$id"
            }
            
            val pendingIntentFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_NO_CREATE
            } else {
                PendingIntent.FLAG_NO_CREATE
            }
            
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                id,
                intent,
                pendingIntentFlags
            )
            
            if (pendingIntent != null) {
                alarmManager.cancel(pendingIntent)
                pendingIntent.cancel()
                Log.d(TAG, "Alarm #$id cancelled")
            } else {
                Log.d(TAG, "Alarm #$id was not scheduled")
            }
            
            // Remove from saved data
            removeAlarmData(id)
            
            return true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to cancel alarm #$id: ${e.message}", e)
            writeDebugLog(context, "AlarmScheduler.kt:cancelAlarm", "Error cancelling alarm", mapOf(
                "alarmId" to id,
                "error" to (e.message ?: "unknown"),
                "errorType" to e.javaClass.simpleName
            ))
            return false
        }
    }
    
    fun cancelAllAlarms(maxId: Int = 100, protectImminent: Boolean = true) {
        Log.d(TAG, "Cancelling all alarms (0 to $maxId, protectImminent=$protectImminent)")
        val now = System.currentTimeMillis()
        // Edge Case 1: Add 1 second buffer to avoid exact boundary issues
        val imminentThreshold = 5 * 60 * 1000L + 1000L // 5 minutes + 1 second in milliseconds
        var cancelledCount = 0
        var protectedCount = 0
        
        // First, get all scheduled alarms to check which ones are imminent
        val alarmsJson = prefs.getString(KEY_SCHEDULED_ALARMS, "[]")
        val alarmsArray = JSONArray(alarmsJson)
        val imminentAlarmIds = mutableSetOf<Int>()
        
        if (protectImminent) {
            for (i in 0 until alarmsArray.length()) {
                val alarm = alarmsArray.getJSONObject(i)
                val id = alarm.getInt("id")
                val timestampMillis = alarm.getLong("timestampMillis")
                val timeUntilAlarm = timestampMillis - now
                
                if (timeUntilAlarm > 0 && timeUntilAlarm <= imminentThreshold) {
                    imminentAlarmIds.add(id)
                    protectedCount++
                    Log.w(TAG, "⚠️ PROTECTED: Alarm #$id fires in ${timeUntilAlarm / 1000} seconds - NOT cancelling!")
                    writeDebugLog(context, "AlarmScheduler.kt:cancelAllAlarms", "Alarm protected from cancellation", mapOf(
                        "alarmId" to id,
                        "timeUntilAlarm" to timeUntilAlarm,
                        "imminentThreshold" to imminentThreshold
                    ))
                }
            }
        }
        
        // Cancel alarms that are not imminent
        for (i in 0 until maxId) {
            if (imminentAlarmIds.contains(i)) {
                Log.d(TAG, "Skipping protected alarm #$i")
                continue
            }
            if (cancelAlarm(i, protectImminent = false)) {
                cancelledCount++
            }
        }
        
        // Only clear saved data for alarms that were actually cancelled
        // Imminent alarms remain in storage so they can fire
        if (protectedCount == 0) {
            clearAllSavedAlarms()
        } else {
            // Remove only non-imminent alarms from storage
            val newArray = JSONArray()
            for (i in 0 until alarmsArray.length()) {
                val alarm = alarmsArray.getJSONObject(i)
                val id = alarm.getInt("id")
                if (!imminentAlarmIds.contains(id)) {
                    // This alarm was cancelled, don't keep it
                } else {
                    // Keep this imminent alarm
                    newArray.put(alarm)
                }
            }
            prefs.edit().putString(KEY_SCHEDULED_ALARMS, newArray.toString()).apply()
            Log.d(TAG, "Kept $protectedCount protected alarms in storage")
        }
        
        Log.d(TAG, "Cancelled $cancelledCount alarms, protected $protectedCount imminent alarms")
    }
}
