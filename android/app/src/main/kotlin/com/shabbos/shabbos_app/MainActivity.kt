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
        
        // Start alarm health monitoring ("install and forget" functionality)
        // This will auto-recover alarms if they get cleared (e.g., force-stop)
        AlarmHealthWorker.schedule(applicationContext)
        Log.d(TAG, "✓ Alarm health monitoring activated")
        
        // Check and log permissions status
        logPermissionsStatus()
        
        // Verify sound assets are accessible
        verifySoundAssets()
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            Log.d(TAG, "Method call received: ${call.method}")
            
            when (call.method) {
                "scheduleAlarm" -> {
                    // Log to debug_logs.txt immediately to track all calls
                    try {
                        val entryLog = org.json.JSONObject().apply {
                            put("timestamp", System.currentTimeMillis())
                            put("location", "MainActivity.kt:scheduleAlarm")
                            put("message", "MethodChannel scheduleAlarm called")
                            put("data", org.json.JSONObject().apply {
                                put("rawId", call.argument<Any>("id")?.toString() ?: "null")
                                put("rawTimestamp", call.argument<Any>("timestampMillis")?.toString() ?: "null")
                                put("rawIsPre", call.argument<Any>("isPreNotification")?.toString() ?: "null")
                            })
                        }
                        java.io.File(getExternalFilesDir(null), "debug_logs.txt")
                            .appendText("${entryLog.toString()}\n")
                    } catch (_: Exception) {}
                    
                    try {
                        val id = call.argument<Int>("id") ?: 0
                        // Handle both Integer and Long for timestampMillis (MethodChannel may send either)
                        val timestampMillis = when (val ts = call.argument<Any>("timestampMillis")) {
                            is Long -> ts
                            is Int -> ts.toLong()
                            else -> 0L
                        }
                        val title = call.argument<String>("title") ?: "שבת שלום!"
                        val body = call.argument<String>("body") ?: "Time to light candles 🕯️🕯️"
                        val isPreNotification = call.argument<Boolean>("isPreNotification") ?: false
                        // Handle both Integer and Long for candleLightingTime (MethodChannel may send either)
                        val candleLightingTime = when (val ct = call.argument<Any>("candleLightingTime")) {
                            is Long -> ct
                            is Int -> ct.toLong()
                            else -> 0L
                        }
                        val soundId = call.argument<String>("soundId") ?: "rav_shalom_shofar"
                        
                        Log.d(TAG, "Scheduling alarm from Flutter: ID=$id, time=$timestampMillis, isPre=$isPreNotification, candleTime=$candleLightingTime, sound=$soundId")
                        
                        val success = alarmScheduler.scheduleAlarm(id, timestampMillis, title, body, isPreNotification, candleLightingTime, soundId)
                        
                        // Log result
                        try {
                            val resultLog = org.json.JSONObject().apply {
                                put("timestamp", System.currentTimeMillis())
                                put("location", "MainActivity.kt:scheduleAlarm")
                                put("message", "scheduleAlarm result")
                                put("data", org.json.JSONObject().apply {
                                    put("alarmId", id)
                                    put("success", success)
                                    put("isPreNotification", isPreNotification)
                                })
                            }
                            java.io.File(getExternalFilesDir(null), "debug_logs.txt")
                                .appendText("${resultLog.toString()}\n")
                        } catch (_: Exception) {}
                        
                        result.success(success)
                    } catch (e: Exception) {
                        Log.e(TAG, "Exception in scheduleAlarm handler: ${e.message}", e)
                        // Log exception to debug_logs.txt
                        try {
                            val errorLog = org.json.JSONObject().apply {
                                put("timestamp", System.currentTimeMillis())
                                put("location", "MainActivity.kt:scheduleAlarm")
                                put("message", "scheduleAlarm exception")
                                put("data", org.json.JSONObject().apply {
                                    put("error", e.toString())
                                    put("errorMessage", e.message ?: "null")
                                    put("errorClass", e.javaClass.simpleName)
                                })
                            }
                            java.io.File(getExternalFilesDir(null), "debug_logs.txt")
                                .appendText("${errorLog.toString()}\n")
                        } catch (_: Exception) {}
                        result.success(false)
                    }
                }
                "cancelAlarm" -> {
                    val id = call.argument<Int>("id") ?: 0
                    val success = alarmScheduler.cancelAlarm(id)
                    result.success(success)
                }
                "cancelAllAlarms" -> {
                    val protectImminent = call.argument<Boolean>("protectImminent") ?: true
                    alarmScheduler.cancelAllAlarms(protectImminent = protectImminent)
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
                "readDebugLogs" -> {
                    val logs = readDebugLogs()
                    result.success(logs)
                }
                "clearDebugLogs" -> {
                    try {
                        java.io.File(getExternalFilesDir(null), "debug_logs.txt").writeText("")
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e(TAG, "Failed to clear debug logs: ${e.message}")
                        result.success(false)
                    }
                }
                "getScheduledAlarms" -> {
                    val alarms = alarmScheduler.getScheduledAlarms()
                    result.success(alarms)
                }
                "canDrawOverlays" -> {
                    val canDraw = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        Settings.canDrawOverlays(this)
                    } else {
                        true
                    }
                    result.success(canDraw)
                }
                "requestOverlayPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(this)) {
                        try {
                            val intent = Intent(
                                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                                Uri.parse("package:$packageName")
                            )
                            startActivity(intent)
                        } catch (e: Exception) {
                            Log.e(TAG, "Failed to request overlay permission: ${e.message}")
                            openAppSettings()
                        }
                    }
                    result.success(true)
                }
                "canUseFullScreenIntent" -> {
                    val canUse = if (Build.VERSION.SDK_INT >= 34) {
                        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                        notificationManager.canUseFullScreenIntent()
                    } else {
                        true
                    }
                    result.success(canUse)
                }
                "requestFullScreenIntentPermission" -> {
                    if (Build.VERSION.SDK_INT >= 34) {
                        try {
                            val intent = Intent(
                                Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT,
                                Uri.parse("package:$packageName")
                            )
                            startActivity(intent)
                        } catch (e: Exception) {
                            Log.e(TAG, "Failed to request full screen intent permission: ${e.message}")
                            openAppSettings()
                        }
                    }
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
            val importance = NotificationManager.IMPORTANCE_MAX // Use MAX for critical alarms
            
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            
            // Check if channel already exists with correct importance
            val existingChannel = notificationManager.getNotificationChannel(channelId)
            if (existingChannel != null && existingChannel.importance == NotificationManager.IMPORTANCE_MAX) {
                Log.d(TAG, "✓ Notification channel already exists with MAX importance")
                return // Channel is already configured correctly
            }
            
            // Only delete and recreate if importance is wrong
            if (existingChannel != null && existingChannel.importance != NotificationManager.IMPORTANCE_MAX) {
                Log.w(TAG, "⚠️ Channel exists with wrong importance, recreating...")
                try {
                    notificationManager.deleteNotificationChannel(channelId)
                    Log.d(TAG, "✓ Deleted existing channel")
                } catch (e: Exception) {
                    Log.e(TAG, "✗ Failed to delete channel: ${e.message}")
                }
            }
            
            val channel = NotificationChannel(channelId, channelName, importance).apply {
                description = "Candle lighting time reminders"
                enableVibration(true)
                enableLights(true)
                setShowBadge(true)
                setBypassDnd(true) // Bypass Do Not Disturb
                lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
                setSound(null, null) // We play custom sounds via MediaPlayer
            }
            
            notificationManager.createNotificationChannel(channel)
            
            Log.d(TAG, "✓ Notification channel created with MAX importance")
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
    
    private fun verifySoundAssets() {
        Log.d(TAG, "========================================")
        Log.d(TAG, "Verifying sound assets...")
        
        val soundFiles = mapOf(
            "rav_shalom_shofar" to "flutter_assets/assets/sounds/RavShalomShofarDefaultCandle_Default.mp3",
            "shabbat_shalom_song" to "flutter_assets/assets/sounds/RaYomTovShabbosDefault-Android.mp3",
            "yomtov_default" to "flutter_assets/assets/sounds/Vesamachta-YomTov-Default-Android.mp3"
        )
        
        // List all available sounds
        try {
            val availableFiles = assets.list("flutter_assets/assets/sounds")
            Log.d(TAG, "Available sound files in assets: ${availableFiles?.joinToString()}")
        } catch (e: Exception) {
            Log.e(TAG, "Could not list sound assets: ${e.message}")
        }
        
        // Check each sound file
        var allFound = true
        for ((soundId, assetPath) in soundFiles) {
            try {
                val afd = assets.openFd(assetPath)
                Log.d(TAG, "✓ $soundId: ${afd.length} bytes")
                afd.close()
            } catch (e: Exception) {
                Log.e(TAG, "✗ $soundId: NOT FOUND - $assetPath")
                Log.e(TAG, "  Error: ${e.message}")
                allFound = false
            }
        }
        
        if (allFound) {
            Log.d(TAG, "✓ All sound assets verified successfully")
        } else {
            Log.e(TAG, "⚠️ Some sound assets are missing!")
        }
        Log.d(TAG, "========================================")
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
    
    private fun readDebugLogs(): String? {
        return try {
            val logFile = java.io.File(getExternalFilesDir(null), "debug_logs.txt")
            if (logFile.exists()) {
                logFile.readText()
            } else {
                "No debug logs found"
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to read debug logs: ${e.message}", e)
            "Error reading logs: ${e.message}"
        }
    }
}
