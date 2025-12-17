package com.shabbos.shabbos_app

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.shabbos.shabbos_app/alarms"
    private lateinit var alarmScheduler: AlarmScheduler
    
    companion object {
        private const val TAG = "ShabbosMainActivity"
    }
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        Log.d(TAG, "Configuring Flutter engine")
        
        alarmScheduler = AlarmScheduler(applicationContext)
        
        // Create notification channel on startup
        createNotificationChannel()
        
        // Check and log permissions status
        logPermissionsStatus()
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            Log.d(TAG, "Method call received: ${call.method}")
            
            when (call.method) {
                "scheduleAlarm" -> {
                    val id = call.argument<Int>("id") ?: 0
                    val timestampMillis = call.argument<Long>("timestampMillis") ?: 0L
                    val title = call.argument<String>("title") ?: "שבת שלום!"
                    val body = call.argument<String>("body") ?: "Time to light candles 🕯️🕯️"
                    
                    Log.d(TAG, "Scheduling alarm from Flutter: ID=$id, time=$timestampMillis")
                    
                    val success = alarmScheduler.scheduleAlarm(id, timestampMillis, title, body)
                    result.success(success)
                }
                "cancelAlarm" -> {
                    val id = call.argument<Int>("id") ?: 0
                    val success = alarmScheduler.cancelAlarm(id)
                    result.success(success)
                }
                "cancelAllAlarms" -> {
                    alarmScheduler.cancelAllAlarms()
                    result.success(true)
                }
                "canScheduleExactAlarms" -> {
                    val canSchedule = canScheduleExactAlarms()
                    Log.d(TAG, "Can schedule exact alarms: $canSchedule")
                    result.success(canSchedule)
                }
                "requestExactAlarmPermission" -> {
                    requestExactAlarmPermission()
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
        
        Log.d(TAG, "Flutter engine configuration complete")
    }
    
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channelId = "shabbos_alerts"
            val channelName = "Shabbos Alerts"
            val importance = NotificationManager.IMPORTANCE_HIGH
            
            val channel = NotificationChannel(channelId, channelName, importance).apply {
                description = "Candle lighting time reminders"
                enableVibration(true)
                enableLights(true)
                setShowBadge(true)
            }
            
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
            
            Log.d(TAG, "Notification channel created")
        }
    }
    
    private fun canScheduleExactAlarms(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
            alarmManager.canScheduleExactAlarms()
        } else {
            true // Not needed before Android 12
        }
    }
    
    private fun requestExactAlarmPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            try {
                val intent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM)
                intent.data = Uri.parse("package:$packageName")
                startActivity(intent)
                Log.d(TAG, "Requesting exact alarm permission")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to request exact alarm permission", e)
                // Fallback to app settings
                val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                intent.data = Uri.parse("package:$packageName")
                startActivity(intent)
            }
        }
    }
    
    private fun logPermissionsStatus() {
        Log.d(TAG, "========================================")
        Log.d(TAG, "Permissions Status:")
        Log.d(TAG, "Android Version: ${Build.VERSION.SDK_INT}")
        Log.d(TAG, "Manufacturer: ${Build.MANUFACTURER}")
        Log.d(TAG, "Model: ${Build.MODEL}")
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val canSchedule = canScheduleExactAlarms()
            Log.d(TAG, "Can schedule exact alarms: $canSchedule")
            if (!canSchedule) {
                Log.w(TAG, "WARNING: Exact alarm permission NOT granted!")
                Log.w(TAG, "Notifications may not work when app is closed!")
            }
        }
        
        Log.d(TAG, "========================================")
    }
}
