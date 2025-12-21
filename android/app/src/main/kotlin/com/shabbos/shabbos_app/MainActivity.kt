package com.shabbos.shabbos_app

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
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
                    val isPreNotification = call.argument<Boolean>("isPreNotification") ?: false
                    val candleLightingTime = call.argument<Long>("candleLightingTime") ?: 0L
                    
                    Log.d(TAG, "Scheduling alarm from Flutter: ID=$id, time=$timestampMillis, isPre=$isPreNotification, candleTime=$candleLightingTime")
                    
                    val success = alarmScheduler.scheduleAlarm(id, timestampMillis, title, body, isPreNotification, candleLightingTime)
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
                "isIgnoringBatteryOptimizations" -> {
                    val isIgnoring = isIgnoringBatteryOptimizations()
                    Log.d(TAG, "Is ignoring battery optimizations: $isIgnoring")
                    result.success(isIgnoring)
                }
                "requestDisableBatteryOptimization" -> {
                    requestDisableBatteryOptimization()
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
                setBypassDnd(true) // Bypass Do Not Disturb
                lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
            }
            
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
            
            Log.d(TAG, "Notification channel created with high importance")
        }
    }
    
    private fun canScheduleExactAlarms(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val canSchedule = alarmManager.canScheduleExactAlarms()
            Log.d(TAG, "Android 12+ exact alarm permission: $canSchedule")
            canSchedule
        } else {
            Log.d(TAG, "Android < 12, exact alarms always allowed")
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
                openAppSettings()
            }
        }
    }
    
    private fun isIgnoringBatteryOptimizations(): Boolean {
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        return powerManager.isIgnoringBatteryOptimizations(packageName)
    }
    
    private fun requestDisableBatteryOptimization() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
                if (!powerManager.isIgnoringBatteryOptimizations(packageName)) {
                    val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
                    intent.data = Uri.parse("package:$packageName")
                    startActivity(intent)
                    Log.d(TAG, "Requesting battery optimization exemption")
                } else {
                    Log.d(TAG, "Already ignoring battery optimizations")
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to request battery optimization exemption", e)
            // Fallback to battery settings
            try {
                val intent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                startActivity(intent)
            } catch (e2: Exception) {
                Log.e(TAG, "Failed to open battery settings", e2)
                openAppSettings()
            }
        }
    }
    
    private fun openAppSettings() {
        try {
            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
            intent.data = Uri.parse("package:$packageName")
            startActivity(intent)
            Log.d(TAG, "Opening app settings")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to open app settings", e)
        }
    }
    
    private fun logPermissionsStatus() {
        Log.d(TAG, "========================================")
        Log.d(TAG, "Device & Permissions Status:")
        Log.d(TAG, "Android Version: ${Build.VERSION.SDK_INT} (${Build.VERSION.RELEASE})")
        Log.d(TAG, "Manufacturer: ${Build.MANUFACTURER}")
        Log.d(TAG, "Model: ${Build.MODEL}")
        Log.d(TAG, "Brand: ${Build.BRAND}")
        
        // Check exact alarm permission
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val canSchedule = canScheduleExactAlarms()
            Log.d(TAG, "Can schedule exact alarms: $canSchedule")
            if (!canSchedule) {
                Log.w(TAG, "⚠️ WARNING: Exact alarm permission NOT granted!")
                Log.w(TAG, "⚠️ Scheduled notifications may not work reliably!")
            }
        } else {
            Log.d(TAG, "Can schedule exact alarms: true (Android < 12)")
        }
        
        // Check battery optimization
        val isIgnoringBattery = isIgnoringBatteryOptimizations()
        Log.d(TAG, "Ignoring battery optimizations: $isIgnoringBattery")
        if (!isIgnoringBattery) {
            Log.w(TAG, "⚠️ WARNING: Battery optimization is ENABLED!")
            Log.w(TAG, "⚠️ The system may kill this app when in background!")
            Log.w(TAG, "⚠️ Notifications may not work when app is closed!")
        }
        
        // Check notification permission (Android 13+)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val areNotificationsEnabled = notificationManager.areNotificationsEnabled()
            Log.d(TAG, "Notifications enabled: $areNotificationsEnabled")
            if (!areNotificationsEnabled) {
                Log.w(TAG, "⚠️ WARNING: Notifications are DISABLED!")
            }
        }
        
        // Manufacturer-specific warnings
        when (Build.MANUFACTURER.lowercase()) {
            "xiaomi", "redmi", "poco" -> {
                Log.w(TAG, "⚠️ Xiaomi/MIUI device detected!")
                Log.w(TAG, "⚠️ User should enable 'Autostart' and disable battery restrictions!")
            }
            "samsung" -> {
                Log.w(TAG, "⚠️ Samsung device detected!")
                Log.w(TAG, "⚠️ User should disable 'Sleeping apps' feature!")
            }
            "huawei", "honor" -> {
                Log.w(TAG, "⚠️ Huawei/Honor device detected!")
                Log.w(TAG, "⚠️ User should enable 'Protected apps' or disable battery optimization!")
            }
            "oppo", "realme", "oneplus" -> {
                Log.w(TAG, "⚠️ OPPO/Realme/OnePlus device detected!")
                Log.w(TAG, "⚠️ User should disable battery optimization and enable autostart!")
            }
            "vivo" -> {
                Log.w(TAG, "⚠️ Vivo device detected!")
                Log.w(TAG, "⚠️ User should enable 'Allow autostart' and disable battery optimization!")
            }
        }
        
        Log.d(TAG, "========================================")
    }
}
