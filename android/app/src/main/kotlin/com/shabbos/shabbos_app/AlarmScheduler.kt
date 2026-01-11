package com.shabbos.shabbos_app

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build
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
            if (timestampMillis <= now) {
                Log.w(TAG, "WARNING: Scheduled time is in the past! Scheduling for 5 seconds from now for testing.")
                val testTime = now + 5000
                scheduleAlarmInternal(testTime, pendingIntent, id)
            } else {
                scheduleAlarmInternal(timestampMillis, pendingIntent, id)
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
            saveAlarmData(id, timestampMillis, title, body, isPreNotification, candleLightingTime, soundId)
            
            Log.d(TAG, "Alarm #$id scheduled successfully")
            Log.d(TAG, "========================================")
            return true
        } catch (e: Exception) {
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
            
            for (i in 0 until alarmsArray.length()) {
                val alarm = alarmsArray.getJSONObject(i)
                val id = alarm.getInt("id")
                val timestampMillis = alarm.getLong("timestampMillis")
                val title = alarm.getString("title")
                val body = alarm.getString("body")
                val isPreNotification = alarm.getBoolean("isPreNotification")
                val candleLightingTime = alarm.optLong("candleLightingTime", 0L)
                val soundId = alarm.optString("soundId", "rav_shalom_shofar")
                
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
                    scheduleAlarmInternal(timestampMillis, pendingIntent, id)
                    rescheduledCount++
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
            Log.d(TAG, "========================================")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to reschedule alarms: ${e.message}", e)
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
        }
    }
    
    /**
     * Clear all saved alarm data
     */
    fun clearAllSavedAlarms() {
        prefs.edit().putString(KEY_SCHEDULED_ALARMS, "[]").apply()
        Log.d(TAG, "Cleared all saved alarm data")
    }
    
    private fun scheduleAlarmInternal(timestampMillis: Long, pendingIntent: PendingIntent, id: Int) {
        var alarmScheduled = false
        var schedulingMethod = "unknown"
        var hasExactPermission = false
        
        when {
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.S -> {
                // Android 12+ - check if we have exact alarm permission
                hasExactPermission = alarmManager.canScheduleExactAlarms()
                if (hasExactPermission) {
                    Log.d(TAG, "Using setAlarmClock (Android 12+)")
                    schedulingMethod = "setAlarmClock"
                    alarmManager.setAlarmClock(
                        AlarmManager.AlarmClockInfo(timestampMillis, pendingIntent),
                        pendingIntent
                    )
                    alarmScheduled = true
                } else {
                    Log.w(TAG, "No exact alarm permission! Using setAndAllowWhileIdle")
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
    }
    
    fun cancelAlarm(id: Int): Boolean {
        try {
            Log.d(TAG, "Cancelling alarm #$id")
            
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
            return false
        }
    }
    
    fun cancelAllAlarms(maxId: Int = 100) {
        Log.d(TAG, "Cancelling all alarms (0 to $maxId)")
        var cancelledCount = 0
        for (i in 0 until maxId) {
            if (cancelAlarm(i)) {
                cancelledCount++
            }
        }
        // Clear all saved alarm data
        clearAllSavedAlarms()
        Log.d(TAG, "Cancelled $cancelledCount alarms and cleared saved data")
    }
}
