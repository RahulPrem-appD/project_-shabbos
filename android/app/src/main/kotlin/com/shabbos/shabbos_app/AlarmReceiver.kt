package com.shabbos.shabbos_app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.PowerManager
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import androidx.media.app.NotificationCompat.MediaStyle

class AlarmReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "ShabbosAlarmReceiver"
        private const val CHANNEL_ID = "shabbos_alerts"
        private const val CHANNEL_NAME = "Shabbos Alerts"
        private const val PREFS_NAME = "FlutterSharedPreferences"
        
        /**
         * Helper function to write logs to debug_logs.txt for diagnostic reports
         * This ensures all critical events are captured in the diagnostic report
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
                // Don't log logging failures to avoid infinite loops
                android.util.Log.e(TAG, "Failed to write debug log: ${e.message}")
            }
        }
        
        // Sound file mappings (must match audio_service.dart)
        // NOTE: shofar_candle removed - Candle lighting ALWAYS uses rav_shalom_shofar
        // IMPORTANT: File names must match actual files in assets/sounds/
        // NOTE: Only sounds that actually exist in assets/sounds/ should be listed here
        private val SOUND_FILES = mapOf(
            "rav_shalom_shofar" to "flutter_assets/assets/sounds/RavShalomShofarDefaultCandle_Default.mp3",
            "shabbat_shalom_song" to "flutter_assets/assets/sounds/RaYomTovShabbosDefault-Android.mp3",
            "yomtov_default" to "flutter_assets/assets/sounds/Vesamachta-YomTov-Default-Android.mp3"
            // NOTE: The following sounds were REMOVED because the files don't exist:
            // "ata_bechartanu" to "flutter_assets/assets/sounds/Ata Bechartanu-YomTov.mp3",
            // "ata_bechartanu_2" to "flutter_assets/assets/sounds/Ata Bechartanu2-YomTov.mp3",
            // "hodu_lahashem" to "flutter_assets/assets/sounds/Hodu La'Hashem Ki Tov-YomTov.mp3"
            // Add these files to assets/sounds/ to re-enable these options
        )
    }
    
    override fun onReceive(context: Context, intent: Intent) {
        
        Log.d(TAG, "========================================")
        Log.d(TAG, "AlarmReceiver: onReceive() called!")
        Log.d(TAG, "Intent action: ${intent.action}")
        Log.d(TAG, "Intent extras: ${intent.extras?.keySet()?.joinToString()}")
        Log.d(TAG, "Current time: ${System.currentTimeMillis()}")
        Log.d(TAG, "App process state: ${if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) "unknown (requires ActivityManager)" else "unknown"}")
        Log.d(TAG, "========================================")
        
        // CRITICAL: Verify this receiver can run even when app is completely closed
        // This log entry proves the receiver was called by the system
        Log.d(TAG, "✓ AlarmReceiver triggered by Android AlarmManager (app may be closed)")
        writeDebugLog(context, "AlarmReceiver.kt:onReceive", "AlarmReceiver triggered by Android AlarmManager", mapOf(
            "intentAction" to (intent.action ?: "null"),
            "appMayBeClosed" to true,
            "timestamp" to System.currentTimeMillis()
        ))
        
        // CRITICAL: Pre-execution validation - check conditions before proceeding
        // This helps catch issues early and provides better diagnostics
        val preExecutionIssues = mutableListOf<String>()
        
        // Check battery optimization (if enabled, we might have been killed)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
            val isIgnoringBattery = powerManager.isIgnoringBatteryOptimizations(context.packageName)
            if (!isIgnoringBattery) {
                preExecutionIssues.add("Battery optimization enabled")
                Log.w(TAG, "⚠️ WARNING: Battery optimization is enabled - app may have been killed")
                writeDebugLog(context, "AlarmReceiver.kt:preExecution", "WARNING: Battery optimization enabled", mapOf(
                    "risk" to "app_may_have_been_killed",
                    "receiverStillRan" to true
                ))
            }
        }
        
        if (preExecutionIssues.isNotEmpty()) {
            Log.w(TAG, "⚠️ Pre-execution warnings:")
            preExecutionIssues.forEach { issue ->
                Log.w(TAG, "  - $issue")
            }
            Log.w(TAG, "⚠️ Continuing anyway - receiver was called, so system allowed it")
        } else {
            Log.d(TAG, "✓ Pre-execution validation passed")
        }
        
        // Acquire a WakeLock to ensure the device stays awake long enough
        val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        
        // CRITICAL: Use PARTIAL_WAKE_LOCK (SCREEN_BRIGHT_WAKE_LOCK is deprecated)
        // Combined with full screen intent, this ensures notification is visible
        @Suppress("DEPRECATION")
        val wakeLockFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            // Android 8.1+: Use PARTIAL_WAKE_LOCK (SCREEN_BRIGHT_WAKE_LOCK is deprecated)
            // Full screen intent will wake the screen
            PowerManager.PARTIAL_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP
        } else {
            // Android < 8.1: Use SCREEN_BRIGHT_WAKE_LOCK to wake screen
            PowerManager.SCREEN_BRIGHT_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP
        }
        
        val wakeLock = powerManager.newWakeLock(
            wakeLockFlags,
            "ShabbosApp::AlarmWakeLock"
        )
        wakeLock.acquire(120000) // Hold for 2 minutes max (for audio playback)
        Log.d(TAG, "✓ WakeLock acquired")
        writeDebugLog(context, "AlarmReceiver.kt:wakeLock", "WakeLock acquired", mapOf(
            "wakeLockHeld" to wakeLock.isHeld,
            "duration" to 120000
        ))
        
        
        try {
            val notificationId = intent.getIntExtra("notification_id", 0)
            val title = intent.getStringExtra("notification_title") ?: "שבת שלום!"
            val body = intent.getStringExtra("notification_body") ?: "Time to light candles 🕯️🕯️"
            val isPreNotification = intent.getBooleanExtra("is_pre_notification", false)
            val candleLightingTime = intent.getLongExtra("candle_lighting_time", 0L)
            val soundId = intent.getStringExtra("sound_id") ?: "rav_shalom_shofar"
            
            Log.d(TAG, "Notification ID: $notificationId")
            Log.d(TAG, "Title: $title")
            Log.d(TAG, "Body: $body")
            Log.d(TAG, "Is pre-notification: $isPreNotification")
            Log.d(TAG, "Candle lighting time: $candleLightingTime")
            Log.d(TAG, "Sound ID: $soundId")
            writeDebugLog(context, "AlarmReceiver.kt:onReceive", "Alarm data extracted", mapOf(
                "notificationId" to notificationId,
                "title" to title,
                "isPreNotification" to isPreNotification,
                "soundId" to soundId,
                "candleLightingTime" to candleLightingTime
            ))
            
            // Check if notifications are enabled
            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            var notificationsEnabled = true
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                notificationsEnabled = notificationManager.areNotificationsEnabled()
                if (!notificationsEnabled) {
                    Log.e(TAG, "✗ CRITICAL: Notifications are disabled by user!")
                    writeDebugLog(context, "AlarmReceiver.kt:notificationsCheck", "Notifications disabled - returning early", mapOf(
                        "notificationsEnabled" to false,
                        "action" to "returning_early"
                    ))
                    
                    // CRITICAL FIX: Release wake lock before returning to avoid resource leak
                    if (wakeLock.isHeld) {
                        wakeLock.release()
                        Log.d(TAG, "✓ WakeLock released (notifications disabled)")
                        writeDebugLog(context, "AlarmReceiver.kt:wakeLock", "WakeLock released (notifications disabled)")
                    }
                    return
                }
            }
            
            
            // Create notification channel (required for Android 8.0+)
            createNotificationChannel(context, notificationManager)
            
            // Verify channel exists and is enabled
            var channelImportance = -1
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val channel = notificationManager.getNotificationChannel(CHANNEL_ID)
                if (channel == null) {
                    Log.e(TAG, "Notification channel is null!")
                    writeDebugLog(context, "AlarmReceiver.kt:channelCheck", "Notification channel is null - recreating", mapOf(
                        "channelId" to CHANNEL_ID,
                        "action" to "recreating_channel"
                    ))
                    createNotificationChannel(context, notificationManager)
                } else {
                    channelImportance = channel.importance
                    Log.d(TAG, "Channel importance: ${channel.importance}")
                    writeDebugLog(context, "AlarmReceiver.kt:channelCheck", "Channel verification complete", mapOf(
                        "channelImportance" to channel.importance,
                        "channelExists" to true,
                        "canBypassDnd" to channel.canBypassDnd()
                    ))
                    if (channel.importance == NotificationManager.IMPORTANCE_NONE) {
                        Log.e(TAG, "Notification channel is disabled!")
                        writeDebugLog(context, "AlarmReceiver.kt:channelCheck", "CRITICAL: Notification channel is BLOCKED", mapOf(
                            "channelImportance" to NotificationManager.IMPORTANCE_NONE,
                            "userActionRequired" to true
                        ))
                    }
                }
            }
            
            
            // CRITICAL: Directly launch AlarmActivity FIRST for maximum reliability
            // This ensures the full-screen popup with dismiss button ALWAYS appears,
            // regardless of notification system behavior on the device.
            // We're in a BroadcastReceiver triggered by AlarmManager PendingIntent,
            // which grants us permission to start activities from background on Android 10+.
            if (soundId != "silent") {
                try {
                    val alarmActivityIntent = Intent(context, AlarmActivity::class.java).apply {
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                                Intent.FLAG_ACTIVITY_CLEAR_TOP or
                                Intent.FLAG_ACTIVITY_SINGLE_TOP
                        putExtra(AlarmActivity.EXTRA_TITLE, title)
                        putExtra(AlarmActivity.EXTRA_BODY, body)
                        putExtra(AlarmActivity.EXTRA_NOTIFICATION_ID, notificationId)
                    }
                    context.startActivity(alarmActivityIntent)
                    Log.d(TAG, "✓ AlarmActivity launched directly from AlarmReceiver")
                    writeDebugLog(context, "AlarmReceiver.kt:launchActivity", "AlarmActivity launched directly", mapOf(
                        "notificationId" to notificationId,
                        "title" to title
                    ))
                } catch (e: Exception) {
                    Log.e(TAG, "✗ Failed to launch AlarmActivity directly: ${e.message}")
                    writeDebugLog(context, "AlarmReceiver.kt:launchActivity", "Failed to launch AlarmActivity directly", mapOf(
                        "error" to (e.message ?: "unknown"),
                        "fallback" to "fullScreenIntent on notification"
                    ))
                    // Will fall back to fullScreenIntent on the notification
                }
            }

            // Play custom sound using foreground service (works when app is closed)

            // Start foreground service to play audio (ensures it works when app is closed)
            // CRITICAL: This must work even when app hasn't been opened for weeks
            val serviceIntent = Intent(context, AlarmAudioService::class.java).apply {
                putExtra("sound_id", soundId)
                putExtra("title", title)
                putExtra("body", body)
                putExtra(AlarmAudioService.EXTRA_NOTIFICATION_ID, notificationId) // So service can cancel this notification on stop
                // Add action to make intent unique and ensure it's delivered
                action = "com.shabbos.shabbos_app.PLAY_ALARM_SOUND"
            }
            
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    // Android 8.0+: Use startForegroundService
                    // This works even when app is completely closed
                    context.startForegroundService(serviceIntent)
                    Log.d(TAG, "✓ Started foreground service (Android 8.0+) for sound: $soundId")
                    writeDebugLog(context, "AlarmReceiver.kt:serviceStart", "Started foreground service", mapOf(
                        "method" to "startForegroundService",
                        "soundId" to soundId,
                        "androidVersion" to Build.VERSION.SDK_INT
                    ))
                } else {
                    // Android < 8.0: Use regular startService
                    context.startService(serviceIntent)
                    Log.d(TAG, "✓ Started service (Android < 8.0) for sound: $soundId")
                    writeDebugLog(context, "AlarmReceiver.kt:serviceStart", "Started service", mapOf(
                        "method" to "startService",
                        "soundId" to soundId,
                        "androidVersion" to Build.VERSION.SDK_INT
                    ))
                }
                
                // REMOVED: Service verification check
                // The Handler.postDelayed runs on main looper, but BroadcastReceiver.onReceive
                // might finish before the handler runs, causing the check to fail
                // Service startup is verified via logs in AlarmAudioService.onStartCommand
            } catch (e: IllegalStateException) {
                // Android 8.0+: This can happen if app is in background and service can't start
                Log.e(TAG, "✗ CRITICAL: Cannot start foreground service: ${e.message}")
                Log.e(TAG, "✗ This usually means the app was killed and Android blocked service startup")
                Log.e(TAG, "✗ User may need to disable battery optimization for this app")
                writeDebugLog(context, "AlarmReceiver.kt:serviceStart", "CRITICAL: Cannot start foreground service", mapOf(
                    "error" to (e.message ?: "unknown"),
                    "errorType" to "IllegalStateException",
                    "soundId" to soundId,
                    "userActionRequired" to true,
                    "action" to "disable_battery_optimization"
                ))
                
                // Try to start regular service as fallback (won't work on Android 8.0+ but worth trying)
                try {
                    context.startService(serviceIntent)
                    Log.d(TAG, "✓ Fallback: Started regular service")
                    writeDebugLog(context, "AlarmReceiver.kt:serviceStart", "Fallback service started", mapOf(
                        "method" to "startService",
                        "soundId" to soundId
                    ))
                } catch (e2: Exception) {
                    Log.e(TAG, "✗ Fallback service start also failed: ${e2.message}")
                    writeDebugLog(context, "AlarmReceiver.kt:serviceStart", "Fallback service start failed", mapOf(
                        "error" to (e2.message ?: "unknown"),
                        "soundId" to soundId
                    ))
                }
            } catch (e: Exception) {
                Log.e(TAG, "✗ Error starting AlarmAudioService: ${e.message}", e)
                writeDebugLog(context, "AlarmReceiver.kt:serviceStart", "Error starting AlarmAudioService", mapOf(
                    "error" to (e.message ?: "unknown"),
                    "errorType" to e.javaClass.simpleName,
                    "soundId" to soundId
                ))
            }
            
            // Create and show notification (without system sound since we play our own)
            // Pass soundId to determine if this is an Issur Melacha notification (soundId == "default")
            showNotification(context, notificationId, title, body, isPreNotification, candleLightingTime, soundId)
            
            Log.d(TAG, "Notification shown successfully")
            writeDebugLog(context, "AlarmReceiver.kt:onReceive", "Notification shown successfully", mapOf(
                "notificationId" to notificationId,
                "title" to title,
                "isPreNotification" to isPreNotification
            ))
        } catch (e: Exception) {
            Log.e(TAG, "✗ CRITICAL ERROR in onReceive: ${e.message}", e)
            e.printStackTrace()
            writeDebugLog(context, "AlarmReceiver.kt:onReceive", "CRITICAL ERROR in onReceive", mapOf(
                "error" to (e.message ?: "unknown"),
                "errorType" to e.javaClass.simpleName,
                "stackTrace" to e.stackTraceToString(),
                "intentAction" to (intent?.action ?: "null")
            ))
        } finally {
            // Release wakelock after a delay to allow sound to play
            android.os.Handler(context.mainLooper).postDelayed({
                if (wakeLock.isHeld) {
                    wakeLock.release()
                    Log.d(TAG, "WakeLock released")
                    writeDebugLog(context, "AlarmReceiver.kt:wakeLock", "WakeLock released", mapOf(
                        "delay" to 60000
                    ))
                }
            }, 60000) // Release after 60 seconds
        }
    }
    
    
    private fun createNotificationChannel(context: Context, notificationManager: NotificationManager) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            // CRITICAL: Use IMPORTANCE_MAX for alarm notifications to ensure they're always visible
            // IMPORTANCE_HIGH can still be suppressed by the system
            val importance = NotificationManager.IMPORTANCE_MAX
            
            // Check if channel already exists with correct importance
            val existingChannel = notificationManager.getNotificationChannel(CHANNEL_ID)
            if (existingChannel != null && existingChannel.importance == NotificationManager.IMPORTANCE_MAX) {
                Log.d(TAG, "✓ Notification channel already exists with MAX importance")
                return // Channel is already configured correctly
            }
            
            // CRITICAL WARNING: Deleting a notification channel will remove ALL pending notifications
            // Only delete if importance is wrong
            if (existingChannel != null && existingChannel.importance != NotificationManager.IMPORTANCE_MAX) {
                Log.w(TAG, "⚠️ Channel exists with wrong importance (${existingChannel.importance}), recreating...")
                try {
                    notificationManager.deleteNotificationChannel(CHANNEL_ID)
                    Log.d(TAG, "✓ Deleted existing channel")
                    // WARNING: This will clear any existing notifications!
                } catch (e: Exception) {
                    Log.e(TAG, "✗ Failed to delete channel: ${e.message}")
                }
            }
            
            // Create channel WITHOUT sound (we play our own sound via MediaPlayer)
            val channel = NotificationChannel(CHANNEL_ID, CHANNEL_NAME, importance).apply {
                description = "Candle lighting time reminders"
                enableVibration(true)
                enableLights(true)
                setShowBadge(true)
                setSound(null, null) // Disable channel sound - we play custom sounds
                lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
                setBypassDnd(true) // Bypass Do Not Disturb mode - critical for religious reminders
                // IMPORTANCE_MAX automatically enables heads-up notifications
            }
            
            notificationManager.createNotificationChannel(channel)
            Log.d(TAG, "✓ Notification channel created with MAX importance")
            
            // Verify channel was created correctly
            val createdChannel = notificationManager.getNotificationChannel(CHANNEL_ID)
            if (createdChannel != null) {
                Log.d(TAG, "✓ Channel verification: importance=${createdChannel.importance}, bypassDND=${createdChannel.canBypassDnd()}")
                if (createdChannel.importance != NotificationManager.IMPORTANCE_MAX) {
                    Log.e(TAG, "✗ WARNING: Channel importance is ${createdChannel.importance}, expected ${NotificationManager.IMPORTANCE_MAX}!")
                    Log.e(TAG, "✗ User may have manually changed channel settings in system settings")
                    writeDebugLog(context, "AlarmReceiver.kt:createNotificationChannel", "WARNING: Channel importance mismatch", mapOf(
                        "actualImportance" to createdChannel.importance,
                        "expectedImportance" to NotificationManager.IMPORTANCE_MAX,
                        "userActionPossible" to true
                    ))
                }
            } else {
                Log.e(TAG, "✗ CRITICAL: Channel was not created!")
                writeDebugLog(context, "AlarmReceiver.kt:createNotificationChannel", "CRITICAL: Channel was not created", mapOf(
                    "channelId" to CHANNEL_ID
                ))
            }
        }
    }
    
    private fun showNotification(
        context: Context, 
        id: Int, 
        title: String, 
        body: String,
        isPreNotification: Boolean = false,
        candleLightingTime: Long = 0L,
        soundId: String = "rav_shalom_shofar"
    ) {
        try {
            // Check if this is an Issur Melacha notification (uses default sound)
            val isIssurMelacha = soundId == "default"
            
            // Create intent to open AlarmActivity (volume keys control alarm stream)
            val intent = Intent(context, AlarmActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                putExtra(AlarmActivity.EXTRA_TITLE, title)
                putExtra(AlarmActivity.EXTRA_BODY, body)
                putExtra(AlarmActivity.EXTRA_NOTIFICATION_ID, id)
            }

            val pendingIntentFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }

            val pendingIntent = PendingIntent.getActivity(
                context,
                id,
                intent,
                pendingIntentFlags
            )

            // Create full screen intent to show AlarmActivity on lock screen
            val fullScreenIntent = Intent(context, AlarmActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                putExtra(AlarmActivity.EXTRA_TITLE, title)
                putExtra(AlarmActivity.EXTRA_BODY, body)
                putExtra(AlarmActivity.EXTRA_NOTIFICATION_ID, id)
            }

            val fullScreenPendingIntent = PendingIntent.getActivity(
                context,
                id + 10000, // Use different ID to avoid conflicts
                fullScreenIntent,
                pendingIntentFlags
            )
            
            // Dismiss action — stops alarm audio from notification button
            val stopIntent = Intent(context, AlarmAudioService::class.java).apply {
                action = AlarmAudioService.ACTION_STOP_ALARM
                putExtra(AlarmAudioService.EXTRA_NOTIFICATION_ID, id) // So service can cancel this notification on stop
            }
            val stopPendingIntent = PendingIntent.getService(
                context,
                id + 20000,
                stopIntent,
                pendingIntentFlags
            )

            // Build notification - use MAX priority for all critical alarms
            // CRITICAL: Use PRIORITY_MAX to ensure notification appears as heads-up
            val builder = NotificationCompat.Builder(context, CHANNEL_ID)
                .setSmallIcon(R.drawable.ic_notification)
                .setContentTitle(title)
                .setContentText(body)
                .setPriority(NotificationCompat.PRIORITY_MAX) // Always use MAX for critical alarms
                .setCategory(if (isIssurMelacha) NotificationCompat.CATEGORY_REMINDER else NotificationCompat.CATEGORY_ALARM)
                .setSound(null) // No system sound - we play our own
                .setVibrate(longArrayOf(0, 500, 250, 500))
                .setAutoCancel(isIssurMelacha) // Issur Melacha can be dismissed, others stay
                .setOngoing(isPreNotification && candleLightingTime > 0) // Make it sticky for countdown
                .setContentIntent(pendingIntent)
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                .setDefaults(NotificationCompat.DEFAULT_VIBRATE or NotificationCompat.DEFAULT_LIGHTS)
                .addAction(R.drawable.ic_notification, "Dismiss", stopPendingIntent)
                .setDeleteIntent(stopPendingIntent) // Swiping notification away also stops alarm audio
                .setShowWhen(true) // Always show timestamp
                .setWhen(System.currentTimeMillis()) // Set to current time
            
            // For pre-notifications with valid candle lighting time, show countdown timer
            if (isPreNotification && candleLightingTime > 0) {
                val timeFormat = java.text.SimpleDateFormat("h:mm a", java.util.Locale.getDefault())
                val candleTimeStr = timeFormat.format(java.util.Date(candleLightingTime))
                val remainingMillis = candleLightingTime - System.currentTimeMillis()
                val remainingMinutes = (remainingMillis / 60000).toInt()
                
                Log.d(TAG, "========================================")
                Log.d(TAG, "COUNTDOWN NOTIFICATION DEBUG:")
                Log.d(TAG, "Candle lighting time (millis): $candleLightingTime")
                Log.d(TAG, "Current time (millis): ${System.currentTimeMillis()}")
                Log.d(TAG, "Remaining millis: $remainingMillis")
                Log.d(TAG, "Remaining minutes: $remainingMinutes")
                Log.d(TAG, "Formatted time: $candleTimeStr")
                Log.d(TAG, "Android SDK: ${Build.VERSION.SDK_INT}")
                Log.d(TAG, "========================================")
                
                // Use chronometer for countdown (API 24+)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                    // Set chronometer with countdown
                    builder.setUsesChronometer(true)
                        .setChronometerCountDown(true)
                        .setWhen(candleLightingTime)
                        .setShowWhen(true)

                    // Update content to show countdown context
                    builder.setContentTitle("⏱️ Countdown to Candle Lighting")
                        .setContentText("Light candles at $candleTimeStr — $remainingMinutes min remaining")
                        .setSubText("Shabbos preparation")

                    Log.d(TAG, "Chronometer countdown set for: $candleLightingTime")
                } else {
                    // Fallback for older devices - just show the time
                    builder.setContentTitle("🕯️ Candle Lighting Soon")
                        .setContentText("Light candles at $candleTimeStr ($remainingMinutes min)")
                        .setWhen(candleLightingTime)
                        .setShowWhen(true)
                }

                // MediaStyle ensures dismiss button is visible in compact/heads-up view
                builder.setStyle(MediaStyle().setShowActionsInCompactView(0))

                // Full screen intent for pre-notifications too — ensures popup on lock screen
                builder.setFullScreenIntent(fullScreenPendingIntent, true)
                Log.d(TAG, "✓ Full screen intent enabled for pre-notification")
            } else {
                builder.setContentText(body)
                    .setWhen(System.currentTimeMillis())
                    .setShowWhen(true)

                // MediaStyle ensures dismiss button is visible in compact/heads-up view
                builder.setStyle(MediaStyle().setShowActionsInCompactView(0))

                // Full screen intent to wake screen and show AlarmActivity on lock screen
                builder.setFullScreenIntent(fullScreenPendingIntent, true)
                Log.d(TAG, "✓ Full screen intent enabled for maximum visibility (will wake screen)")
            }
            
            val notification = builder.build()
            
            // Use NotificationManager directly for more reliability
            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            
            // CRITICAL: Comprehensive permission and system state checks BEFORE posting
            var systemBlockingReasons = mutableListOf<String>()
            
            // 1. Check POST_NOTIFICATIONS runtime permission (Android 13+)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                val permissionStatus = ContextCompat.checkSelfPermission(context, android.Manifest.permission.POST_NOTIFICATIONS)
                val hasPostNotificationPermission = permissionStatus == android.content.pm.PackageManager.PERMISSION_GRANTED
                
                if (!hasPostNotificationPermission) {
                    systemBlockingReasons.add("POST_NOTIFICATIONS permission denied")
                    Log.e(TAG, "✗ CRITICAL: POST_NOTIFICATIONS runtime permission is DENIED!")
                    Log.e(TAG, "✗ Notification will NOT appear on Android 13+")
                    writeDebugLog(context, "AlarmReceiver.kt:permissionCheck", "CRITICAL: POST_NOTIFICATIONS permission denied", mapOf(
                        "permissionStatus" to permissionStatus,
                        "androidVersion" to Build.VERSION.SDK_INT,
                        "userActionRequired" to true,
                        "action" to "grant_post_notifications_permission"
                    ))
                } else {
                    Log.d(TAG, "✓ POST_NOTIFICATIONS permission granted")
                }
            }
            
            // 2. Check system-level notification enablement
            var systemNotificationsEnabled = true
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                systemNotificationsEnabled = notificationManager.areNotificationsEnabled()
                if (!systemNotificationsEnabled) {
                    systemBlockingReasons.add("System notifications disabled")
                    Log.e(TAG, "✗ CRITICAL: System notifications are DISABLED!")
                    writeDebugLog(context, "AlarmReceiver.kt:systemCheck", "CRITICAL: System notifications disabled", mapOf(
                        "userActionRequired" to true,
                        "action" to "enable_system_notifications"
                    ))
                } else {
                    Log.d(TAG, "✓ System notifications enabled")
                }
            }
            
            // 3. Check battery optimization (if enabled, app might be killed)
            var isIgnoringBatteryOptimizations = false
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val powerManager = context.getSystemService(Context.POWER_SERVICE) as android.os.PowerManager
                isIgnoringBatteryOptimizations = powerManager.isIgnoringBatteryOptimizations(context.packageName)
                if (!isIgnoringBatteryOptimizations) {
                    Log.w(TAG, "⚠️ WARNING: Battery optimization is ENABLED - app may be killed!")
                    Log.w(TAG, "⚠️ This receiver might not run if app is killed")
                    writeDebugLog(context, "AlarmReceiver.kt:batteryCheck", "WARNING: Battery optimization enabled", mapOf(
                        "isIgnoringBatteryOptimizations" to false,
                        "risk" to "app_may_be_killed",
                        "userActionRecommended" to true
                    ))
                } else {
                    Log.d(TAG, "✓ Battery optimization disabled (good)")
                }
            }
            
            // 4. Check Do Not Disturb mode (even with bypass, some modes might suppress)
            var dndMode = 0
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                dndMode = notificationManager.currentInterruptionFilter
                val dndNames = mapOf(
                    NotificationManager.INTERRUPTION_FILTER_ALL to "ALL",
                    NotificationManager.INTERRUPTION_FILTER_PRIORITY to "PRIORITY",
                    NotificationManager.INTERRUPTION_FILTER_NONE to "NONE",
                    NotificationManager.INTERRUPTION_FILTER_ALARMS to "ALARMS",
                    NotificationManager.INTERRUPTION_FILTER_UNKNOWN to "UNKNOWN"
                )
                Log.d(TAG, "Do Not Disturb mode: ${dndNames[dndMode] ?: dndMode}")
                if (dndMode == NotificationManager.INTERRUPTION_FILTER_NONE) {
                    Log.w(TAG, "⚠️ WARNING: DND is set to NONE - notifications may be suppressed")
                    writeDebugLog(context, "AlarmReceiver.kt:dndCheck", "WARNING: DND mode is NONE", mapOf(
                        "dndMode" to dndMode,
                        "risk" to "notifications_may_be_suppressed"
                    ))
                }
            }
            
            // CRITICAL: Ensure notification is visible
            // On Android 8.0+, check channel importance BEFORE posting
            var channelBlocked = false
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val channel = notificationManager.getNotificationChannel(CHANNEL_ID)
                if (channel != null) {
                    Log.d(TAG, "Notification channel importance: ${channel.importance}")
                    Log.d(TAG, "Notification channel can bypass DND: ${channel.canBypassDnd()}")
                    Log.d(TAG, "Notification channel can show badge: ${channel.canShowBadge()}")
                    
                    // CRITICAL: Check if channel is blocked BEFORE attempting to post
                    if (channel.importance == NotificationManager.IMPORTANCE_NONE) {
                        channelBlocked = true
                        Log.e(TAG, "✗ CRITICAL: Notification channel is BLOCKED by user!")
                        Log.e(TAG, "✗ Notification will NOT appear even if notify() succeeds!")
                        Log.e(TAG, "✗ User must enable notifications in system settings")
                        writeDebugLog(context, "AlarmReceiver.kt:channelCheck", "CRITICAL: Notification channel is BLOCKED", mapOf(
                            "channelImportance" to NotificationManager.IMPORTANCE_NONE,
                            "userActionRequired" to true,
                            "action" to "enable_notifications_in_settings",
                            "notificationWillFail" to true
                        ))
                    }
                    
                    // If channel importance is too low, recreate it with MAX importance
                    if (channel.importance < NotificationManager.IMPORTANCE_MAX && !channelBlocked) {
                        Log.w(TAG, "⚠️ Channel importance is too low (${channel.importance}), recreating with MAX importance")
                        writeDebugLog(context, "AlarmReceiver.kt:channelCheck", "Channel importance too low - recreating", mapOf(
                            "currentImportance" to channel.importance,
                            "requiredImportance" to NotificationManager.IMPORTANCE_MAX,
                            "action" to "recreating_channel"
                        ))
                        createNotificationChannel(context, notificationManager)
                    }
                } else {
                    Log.e(TAG, "✗ CRITICAL: Notification channel is NULL!")
                    writeDebugLog(context, "AlarmReceiver.kt:channelCheck", "CRITICAL: Notification channel is NULL", mapOf(
                        "channelId" to CHANNEL_ID,
                        "action" to "recreating_channel"
                    ))
                    createNotificationChannel(context, notificationManager)
                }
            }
            
            // CRITICAL: If channel is blocked, notify() will succeed but notification won't appear
            // We'll still attempt to post (user might have unblocked it) but verify immediately
            if (channelBlocked) {
                systemBlockingReasons.add("Notification channel blocked")
                Log.e(TAG, "⚠️ WARNING: Channel is blocked - notification will likely fail silently")
                Log.e(TAG, "⚠️ Attempting to post anyway (user might have unblocked it)")
                writeDebugLog(context, "AlarmReceiver.kt:showNotification", "WARNING: Channel blocked - will verify after posting", mapOf(
                    "notificationId" to id,
                    "title" to title,
                    "channelBlocked" to true,
                    "willVerify" to true
                ))
            }
            
            // Log all blocking reasons before attempting to post
            if (systemBlockingReasons.isNotEmpty()) {
                Log.e(TAG, "✗ CRITICAL: ${systemBlockingReasons.size} system blocking reason(s) detected:")
                systemBlockingReasons.forEach { reason ->
                    Log.e(TAG, "  - $reason")
                }
                writeDebugLog(context, "AlarmReceiver.kt:prePostCheck", "CRITICAL: System blocking reasons detected", mapOf(
                    "blockingReasons" to systemBlockingReasons,
                    "count" to systemBlockingReasons.size,
                    "notificationId" to id,
                    "willStillAttempt" to true
                ))
            } else {
                Log.d(TAG, "✓ All system checks passed - notification should appear")
                writeDebugLog(context, "AlarmReceiver.kt:prePostCheck", "All system checks passed", mapOf(
                    "systemNotificationsEnabled" to systemNotificationsEnabled,
                    "isIgnoringBatteryOptimizations" to isIgnoringBatteryOptimizations,
                    "dndMode" to dndMode,
                    "channelBlocked" to channelBlocked
                ))
            }
            
            var notificationPosted = false
            var notificationError: String? = null
            try {
                // CRITICAL: notify() can succeed even if notification is suppressed!
                // We must verify it actually appears
                notificationManager.notify(id, notification)
                
                // CRITICAL: Immediately verify notification was actually posted
                // notify() doesn't throw if notification is suppressed
                var actuallyPosted = false
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    val activeNotifications = notificationManager.activeNotifications
                    actuallyPosted = activeNotifications.any { it.id == id }
                    if (!actuallyPosted) {
                        Log.e(TAG, "✗ CRITICAL: notify() succeeded but notification NOT in active list!")
                        Log.e(TAG, "✗ This means notification was suppressed by the system")
                        notificationError = "Notification suppressed by system (notify() succeeded but not visible)"
                        
                        // Check channel again - might have been blocked
                        val channelAfterPost = notificationManager.getNotificationChannel(CHANNEL_ID)
                        val channelStillBlocked = channelAfterPost?.importance == NotificationManager.IMPORTANCE_NONE
                        
                        // Re-check all system blocking reasons
                        val postBlockingReasons = mutableListOf<String>()
                        if (channelStillBlocked) postBlockingReasons.add("Channel blocked")
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                            val permissionStatus = ContextCompat.checkSelfPermission(context, android.Manifest.permission.POST_NOTIFICATIONS)
                            if (permissionStatus != android.content.pm.PackageManager.PERMISSION_GRANTED) {
                                postBlockingReasons.add("POST_NOTIFICATIONS denied")
                            }
                        }
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                            if (!notificationManager.areNotificationsEnabled()) {
                                postBlockingReasons.add("System notifications disabled")
                            }
                        }
                        
                        writeDebugLog(context, "AlarmReceiver.kt:showNotification", "CRITICAL: notify() succeeded but notification not visible", mapOf(
                            "notificationId" to id,
                            "activeNotificationCount" to activeNotifications.size,
                            "suppressed" to true,
                            "channelBlocked" to channelStillBlocked,
                            "channelImportance" to (channelAfterPost?.importance ?: -1),
                            "blockingReasons" to postBlockingReasons,
                            "blockingReasonCount" to postBlockingReasons.size
                        ))
                        
                        if (postBlockingReasons.isNotEmpty()) {
                            Log.e(TAG, "✗ Notification suppressed - blocking reasons:")
                            postBlockingReasons.forEach { reason ->
                                Log.e(TAG, "  - $reason")
                            }
                            Log.e(TAG, "✗ USER ACTION REQUIRED: Fix notification settings in Settings > Apps > Shabbos!! > Notifications")
                        }
                    } else {
                        notificationPosted = true
                        Log.d(TAG, "✓ Notification posted successfully with ID: $id using NotificationManager")
                        Log.d(TAG, "✓ Notification title: $title")
                        Log.d(TAG, "✓ Notification body: $body")
                        Log.d(TAG, "✓ Notification priority: ${notification.priority}")
                        Log.d(TAG, "✓ Notification verified in active notifications list")
                    }
                } else {
                    // Android < 8.0: Can't verify, assume success
                    notificationPosted = true
                    Log.d(TAG, "✓ Notification posted successfully with ID: $id using NotificationManager")
                    Log.d(TAG, "✓ Notification title: $title")
                    Log.d(TAG, "✓ Notification body: $body")
                    Log.d(TAG, "✓ Notification priority: ${notification.priority}")
                }
            } catch (e: SecurityException) {
                notificationError = "SecurityException: ${e.message}"
                Log.e(TAG, "SecurityException with NotificationManager: ${e.message}", e)
                writeDebugLog(context, "AlarmReceiver.kt:showNotification", "SecurityException posting notification", mapOf(
                    "notificationId" to id,
                    "error" to (e.message ?: "unknown"),
                    "action" to "fallback_to_compat"
                ))
                // Fallback to NotificationManagerCompat
                try {
                    NotificationManagerCompat.from(context).notify(id, notification)
                    
                    // CRITICAL: Verify fallback also worked
                    var fallbackPosted = false
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        val activeNotifications = notificationManager.activeNotifications
                        fallbackPosted = activeNotifications.any { it.id == id }
                        if (!fallbackPosted) {
                            Log.e(TAG, "✗ CRITICAL: Fallback notify() succeeded but notification NOT visible!")
                            notificationError = "Fallback also suppressed by system"
                            writeDebugLog(context, "AlarmReceiver.kt:showNotification", "CRITICAL: Fallback also suppressed", mapOf(
                                "notificationId" to id,
                                "method" to "NotificationManagerCompat",
                                "suppressed" to true
                            ))
                        } else {
                            notificationPosted = true
                            Log.d(TAG, "Notification posted successfully with ID: $id using NotificationManagerCompat (fallback)")
                            Log.d(TAG, "✓ Fallback notification verified in active list")
                            writeDebugLog(context, "AlarmReceiver.kt:showNotification", "Notification posted via fallback", mapOf(
                                "notificationId" to id,
                                "method" to "NotificationManagerCompat",
                                "verified" to true
                            ))
                        }
                    } else {
                        notificationPosted = true
                        Log.d(TAG, "Notification posted successfully with ID: $id using NotificationManagerCompat (fallback)")
                        writeDebugLog(context, "AlarmReceiver.kt:showNotification", "Notification posted via fallback", mapOf(
                            "notificationId" to id,
                            "method" to "NotificationManagerCompat"
                        ))
                    }
                } catch (e2: Exception) {
                    notificationError = "NotificationManagerCompat error: ${e2.message}"
                    Log.e(TAG, "Failed to post notification with NotificationManagerCompat: ${e2.message}", e2)
                    writeDebugLog(context, "AlarmReceiver.kt:showNotification", "CRITICAL: Fallback also failed", mapOf(
                        "notificationId" to id,
                        "error" to (e2.message ?: "unknown")
                    ))
                }
            } catch (e: Exception) {
                notificationError = "Exception: ${e.message}"
                Log.e(TAG, "Exception showing notification with NotificationManager: ${e.message}", e)
                writeDebugLog(context, "AlarmReceiver.kt:showNotification", "Exception posting notification", mapOf(
                    "notificationId" to id,
                    "error" to (e.message ?: "unknown"),
                    "errorType" to e.javaClass.simpleName,
                    "action" to "fallback_to_compat"
                ))
                // Fallback to NotificationManagerCompat
                try {
                    NotificationManagerCompat.from(context).notify(id, notification)
                    
                    // CRITICAL: Verify fallback also worked
                    var fallbackPosted = false
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        val activeNotifications = notificationManager.activeNotifications
                        fallbackPosted = activeNotifications.any { it.id == id }
                        if (!fallbackPosted) {
                            Log.e(TAG, "✗ CRITICAL: Fallback notify() succeeded but notification NOT visible!")
                            notificationError = "Fallback also suppressed by system"
                            writeDebugLog(context, "AlarmReceiver.kt:showNotification", "CRITICAL: Fallback also suppressed", mapOf(
                                "notificationId" to id,
                                "method" to "NotificationManagerCompat",
                                "suppressed" to true
                            ))
                        } else {
                            notificationPosted = true
                            Log.d(TAG, "Notification posted successfully with ID: $id using NotificationManagerCompat (fallback)")
                            Log.d(TAG, "✓ Fallback notification verified in active list")
                            writeDebugLog(context, "AlarmReceiver.kt:showNotification", "Notification posted via fallback", mapOf(
                                "notificationId" to id,
                                "method" to "NotificationManagerCompat",
                                "verified" to true
                            ))
                        }
                    } else {
                        notificationPosted = true
                        Log.d(TAG, "Notification posted successfully with ID: $id using NotificationManagerCompat (fallback)")
                        writeDebugLog(context, "AlarmReceiver.kt:showNotification", "Notification posted via fallback", mapOf(
                            "notificationId" to id,
                            "method" to "NotificationManagerCompat"
                        ))
                    }
                } catch (e2: Exception) {
                    notificationError = "NotificationManagerCompat error: ${e2.message}"
                    Log.e(TAG, "Failed to post notification with NotificationManagerCompat: ${e2.message}", e2)
                    writeDebugLog(context, "AlarmReceiver.kt:showNotification", "CRITICAL: Fallback also failed", mapOf(
                        "notificationId" to id,
                        "error" to (e2.message ?: "unknown")
                    ))
                }
            }
            
            // CRITICAL: Additional verification - check again after a short delay
            // Sometimes notifications are suppressed after being posted (rare but possible)
            if (notificationPosted && Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                android.os.Handler(context.mainLooper).postDelayed({
                    val activeNotifications = notificationManager.activeNotifications
                    val stillVisible = activeNotifications.any { it.id == id }
                    
                    if (!stillVisible) {
                        Log.e(TAG, "✗ CRITICAL: Notification disappeared from active list after posting!")
                        Log.e(TAG, "✗ This means it was suppressed or dismissed by the system")
                        writeDebugLog(context, "AlarmReceiver.kt:notificationCheck", "CRITICAL: Notification disappeared after posting", mapOf(
                            "notificationId" to id,
                            "activeNotificationCount" to activeNotifications.size,
                            "suppressedAfterPost" to true,
                            "timeSincePost" to 500
                        ))
                        
                        // Re-check channel - user might have blocked it between checks
                        val channel = notificationManager.getNotificationChannel(CHANNEL_ID)
                        if (channel != null && channel.importance == NotificationManager.IMPORTANCE_NONE) {
                            Log.e(TAG, "✗ Channel was blocked after posting - notification suppressed")
                            writeDebugLog(context, "AlarmReceiver.kt:notificationCheck", "Channel blocked after posting", mapOf(
                                "channelImportance" to NotificationManager.IMPORTANCE_NONE,
                                "userActionRequired" to true
                            ))
                        } else {
                            Log.e(TAG, "✗ Notification suppressed for unknown reason (channel not blocked)")
                            writeDebugLog(context, "AlarmReceiver.kt:notificationCheck", "Notification suppressed - unknown reason", mapOf(
                                "channelImportance" to (channel?.importance ?: -1),
                                "possibleReasons" to "system_suppression_or_dismissal"
                            ))
                        }
                    } else {
                        Log.d(TAG, "✓ Notification still visible after 500ms - confirmed posted")
                        writeDebugLog(context, "AlarmReceiver.kt:notificationCheck", "Notification confirmed visible after delay", mapOf(
                            "notificationId" to id,
                            "visible" to true,
                            "timeSincePost" to 500
                        ))
                    }
                }, 500) // Check after 500ms
            }
            
            // Final status check
            if (!notificationPosted) {
                Log.e(TAG, "✗ CRITICAL: Notification was NOT posted!")
                Log.e(TAG, "✗ Error: ${notificationError ?: "unknown"}")
                writeDebugLog(context, "AlarmReceiver.kt:notificationPost", "CRITICAL: Notification was NOT posted", mapOf(
                    "notificationId" to id,
                    "error" to (notificationError ?: "unknown"),
                    "title" to title
                ))
                
                // Comprehensive failure analysis
                    val failureReasons = mutableListOf<String>()
                    
                    // Check all possible blocking reasons
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        val permissionStatus = ContextCompat.checkSelfPermission(context, android.Manifest.permission.POST_NOTIFICATIONS)
                        if (permissionStatus != android.content.pm.PackageManager.PERMISSION_GRANTED) {
                            failureReasons.add("POST_NOTIFICATIONS permission denied")
                            Log.e(TAG, "✗ POST_NOTIFICATIONS permission: DENIED")
                        } else {
                            Log.d(TAG, "✓ POST_NOTIFICATIONS permission: GRANTED")
                        }
                    }
                    
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                        val notificationsEnabled = notificationManager.areNotificationsEnabled()
                        Log.e(TAG, "✗ System notifications enabled: $notificationsEnabled")
                        if (!notificationsEnabled) {
                            failureReasons.add("System notifications disabled")
                            Log.e(TAG, "✗ USER ACTION REQUIRED: Notifications are disabled system-wide!")
                        }
                    }
                    
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        val channel = notificationManager.getNotificationChannel(CHANNEL_ID)
                        if (channel?.importance == NotificationManager.IMPORTANCE_NONE) {
                            failureReasons.add("Notification channel blocked")
                            Log.e(TAG, "✗ Notification channel: BLOCKED")
                        } else {
                            Log.d(TAG, "✓ Notification channel: ${channel?.importance ?: "unknown"}")
                        }
                    }
                    
                    writeDebugLog(context, "AlarmReceiver.kt:notificationPost", "CRITICAL: Notification posting failed - comprehensive analysis", mapOf(
                        "notificationId" to id,
                        "error" to (notificationError ?: "unknown"),
                        "failureReasons" to failureReasons,
                        "failureReasonCount" to failureReasons.size,
                        "userActionRequired" to (failureReasons.isNotEmpty()),
                        "action" to if (failureReasons.isNotEmpty()) "fix_notification_settings" else "unknown"
                    ))
                    
                    if (failureReasons.isNotEmpty()) {
                        Log.e(TAG, "✗ FAILURE REASONS:")
                        failureReasons.forEach { reason ->
                            Log.e(TAG, "  - $reason")
                        }
                        Log.e(TAG, "✗ USER ACTION REQUIRED: Fix notification settings in Settings > Apps > Shabbos!! > Notifications")
                    }
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "Critical error in showNotification: ${e.message}", e)
            e.printStackTrace()
            writeDebugLog(context, "AlarmReceiver.kt:showNotification", "CRITICAL ERROR in showNotification", mapOf(
                "error" to (e.message ?: "unknown"),
                "errorType" to e.javaClass.simpleName,
                "notificationId" to id,
                "stackTrace" to e.stackTraceToString()
            ))
        }
    }
}
