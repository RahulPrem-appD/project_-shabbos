package com.shabbos.shabbos_app

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import java.text.SimpleDateFormat
import java.util.*

class AlarmScheduler(private val context: Context) {
    private val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
    
    companion object {
        private const val TAG = "ShabbosAlarmScheduler"
    }
    
    fun scheduleAlarm(id: Int, timestampMillis: Long, title: String, body: String): Boolean {
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
            Log.d(TAG, "Android version: ${Build.VERSION.SDK_INT}")
            
            val intent = Intent(context, AlarmReceiver::class.java).apply {
                putExtra("notification_id", id)
                putExtra("notification_title", title)
                putExtra("notification_body", body)
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
            
            Log.d(TAG, "Alarm #$id scheduled successfully")
            Log.d(TAG, "========================================")
            return true
        } catch (e: Exception) {
            Log.e(TAG, "Failed to schedule alarm #$id: ${e.message}", e)
            Log.d(TAG, "========================================")
            return false
        }
    }
    
    private fun scheduleAlarmInternal(timestampMillis: Long, pendingIntent: PendingIntent, id: Int) {
        when {
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.S -> {
                // Android 12+ - check if we have exact alarm permission
                if (alarmManager.canScheduleExactAlarms()) {
                    Log.d(TAG, "Using setAlarmClock (Android 12+)")
                    alarmManager.setAlarmClock(
                        AlarmManager.AlarmClockInfo(timestampMillis, pendingIntent),
                        pendingIntent
                    )
                } else {
                    Log.w(TAG, "No exact alarm permission! Using setAndAllowWhileIdle")
                    alarmManager.setAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP,
                        timestampMillis,
                        pendingIntent
                    )
                }
            }
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.M -> {
                // Android 6.0 - 11: Use setExactAndAllowWhileIdle
                Log.d(TAG, "Using setExactAndAllowWhileIdle (Android 6-11)")
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    timestampMillis,
                    pendingIntent
                )
            }
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT -> {
                // Android 4.4 - 5.1: Use setExact
                Log.d(TAG, "Using setExact (Android 4.4-5.1)")
                alarmManager.setExact(
                    AlarmManager.RTC_WAKEUP,
                    timestampMillis,
                    pendingIntent
                )
            }
            else -> {
                // Android < 4.4: Use set
                Log.d(TAG, "Using set (Android <4.4)")
                alarmManager.set(
                    AlarmManager.RTC_WAKEUP,
                    timestampMillis,
                    pendingIntent
                )
            }
        }
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
        Log.d(TAG, "Cancelled $cancelledCount alarms")
    }
}
