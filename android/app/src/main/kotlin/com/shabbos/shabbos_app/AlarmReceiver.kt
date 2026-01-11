package com.shabbos.shabbos_app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.res.AssetFileDescriptor
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.os.Build
import android.os.PowerManager
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat

class AlarmReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "ShabbosAlarmReceiver"
        private const val CHANNEL_ID = "shabbos_alerts"
        private const val CHANNEL_NAME = "Shabbos Alerts"
        private const val PREFS_NAME = "FlutterSharedPreferences"
        
        // Sound file mappings (must match audio_service.dart)
        // NOTE: shofar_candle removed - Candle lighting ALWAYS uses rav_shalom_shofar
        private val SOUND_FILES = mapOf(
            "rav_shalom_shofar" to "flutter_assets/assets/sounds/RavShalomShofarDefaultlouder.mp3",
            "shabbat_shalom_song" to "flutter_assets/assets/sounds/RYomTovShabbatShalomSong.mp3",
            "yomtov_default" to "flutter_assets/assets/sounds/YomTov-Default.mp3",
            "ata_bechartanu" to "flutter_assets/assets/sounds/Ata Bechartanu-YomTov.mp3",
            "ata_bechartanu_2" to "flutter_assets/assets/sounds/Ata Bechartanu2-YomTov.mp3",
            "hodu_lahashem" to "flutter_assets/assets/sounds/Hodu La'Hashem Ki Tov-YomTov.mp3"
        )
    }
    
    private var mediaPlayer: MediaPlayer? = null
    
    override fun onReceive(context: Context, intent: Intent) {
        Log.d(TAG, "========================================")
        Log.d(TAG, "AlarmReceiver: onReceive() called!")
        Log.d(TAG, "========================================")
        
        // Acquire a WakeLock to ensure the device stays awake long enough
        val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        val wakeLock = powerManager.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "ShabbosApp::AlarmWakeLock"
        )
        wakeLock.acquire(120000) // Hold for 2 minutes max (for audio playback)
        
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
            
            // Check if notifications are enabled
            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                if (!notificationManager.areNotificationsEnabled()) {
                    Log.e(TAG, "Notifications are disabled by user!")
                    return
                }
            }
            
            // Create notification channel (required for Android 8.0+)
            createNotificationChannel(context, notificationManager)
            
            // Verify channel exists and is enabled
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val channel = notificationManager.getNotificationChannel(CHANNEL_ID)
                if (channel == null) {
                    Log.e(TAG, "Notification channel is null!")
                    createNotificationChannel(context, notificationManager)
                } else {
                    Log.d(TAG, "Channel importance: ${channel.importance}")
                    if (channel.importance == NotificationManager.IMPORTANCE_NONE) {
                        Log.e(TAG, "Notification channel is disabled!")
                    }
                }
            }
            
            // Play custom sound using the sound ID passed from Flutter
            playCustomSound(context, soundId)
            
            // Create and show notification (without system sound since we play our own)
            // Pass soundId to determine if this is an Issur Melacha notification (soundId == "default")
            showNotification(context, notificationId, title, body, isPreNotification, candleLightingTime, soundId)
            
            Log.d(TAG, "Notification shown successfully")
        } catch (e: Exception) {
            Log.e(TAG, "Error in onReceive: ${e.message}", e)
            e.printStackTrace()
        } finally {
            // Release wakelock after a delay to allow sound to play
            android.os.Handler(context.mainLooper).postDelayed({
                if (wakeLock.isHeld) {
                    wakeLock.release()
                    Log.d(TAG, "WakeLock released")
                }
            }, 60000) // Release after 60 seconds
        }
    }
    
    private fun playCustomSound(context: Context, soundId: String) {
        try {
            Log.d(TAG, "========================================")
            Log.d(TAG, "playCustomSound called")
            Log.d(TAG, "Sound ID requested: '$soundId'")
            Log.d(TAG, "Available sound IDs: ${SOUND_FILES.keys.joinToString()}")
            
            // Check for silent mode
            if (soundId == "silent") {
                Log.d(TAG, "Silent mode - not playing any sound")
                return
            }
            
            // Check for default system notification sound
            if (soundId == "default") {
                Log.d(TAG, "Default sound mode - using system notification sound")
                playDefaultNotificationSound(context)
                return
            }
            
            // Get the asset path for the sound
            val assetPath = SOUND_FILES[soundId]
            if (assetPath == null) {
                Log.e(TAG, "✗ No asset path found for sound ID: '$soundId'")
                Log.e(TAG, "✗ This might mean the sound ID is misspelled or not registered")
                Log.d(TAG, "Falling back to default shofar sound (rav_shalom_shofar)")
                playAssetSound(context, SOUND_FILES["rav_shalom_shofar"]!!)
                return
            }
            
            Log.d(TAG, "✓ Found asset path: $assetPath")
            Log.d(TAG, "Starting playback...")
            playAssetSound(context, assetPath)
            
        } catch (e: Exception) {
            Log.e(TAG, "✗ Error in playCustomSound: ${e.message}", e)
            e.printStackTrace()
            
            // Try system sound as ultimate fallback
            try {
                Log.d(TAG, "Attempting system notification sound as fallback")
                playDefaultNotificationSound(context)
            } catch (e2: Exception) {
                Log.e(TAG, "✗ Even fallback sound failed: ${e2.message}")
            }
        }
    }
    
    private fun playDefaultNotificationSound(context: Context) {
        try {
            Log.d(TAG, "Playing default system notification sound")
            
            // Get the default notification sound URI
            val defaultSoundUri = android.media.RingtoneManager.getDefaultUri(
                android.media.RingtoneManager.TYPE_NOTIFICATION
            )
            
            if (defaultSoundUri != null) {
                val ringtone = android.media.RingtoneManager.getRingtone(context, defaultSoundUri)
                ringtone?.play()
                Log.d(TAG, "✓ Default notification sound played")
            } else {
                Log.w(TAG, "No default notification sound available")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error playing default notification sound: ${e.message}", e)
        }
    }
    
    private fun playAssetSound(context: Context, assetPath: String) {
        Log.d(TAG, "========================================")
        Log.d(TAG, "playAssetSound called with path: $assetPath")
        
        try {
            // Release any existing player
            mediaPlayer?.release()
            mediaPlayer = null
            
            // List available assets for debugging
            try {
                val assetList = context.assets.list("flutter_assets/assets/sounds")
                Log.d(TAG, "Available sound assets: ${assetList?.joinToString()}")
                
                // Check if our file exists in the list
                val fileName = assetPath.substringAfterLast("/")
                val fileExists = assetList?.contains(fileName) == true
                Log.d(TAG, "Looking for file: $fileName - exists: $fileExists")
                
                if (!fileExists) {
                    Log.e(TAG, "✗ Sound file NOT found in assets! Available: ${assetList?.joinToString()}")
                    // Try to play default shofar as fallback
                    val defaultPath = SOUND_FILES["rav_shalom_shofar"]
                    if (defaultPath != null && defaultPath != assetPath) {
                        Log.d(TAG, "Falling back to default shofar sound")
                        playAssetSound(context, defaultPath)
                        return
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "Could not list assets: ${e.message}")
            }
            
            Log.d(TAG, "Creating MediaPlayer...")
            mediaPlayer = MediaPlayer().apply {
                Log.d(TAG, "Opening asset file descriptor for: $assetPath")
                val assetManager = context.assets
                
                // Try to open the asset - this is where it might fail with special characters
                val afd: AssetFileDescriptor
                try {
                    afd = assetManager.openFd(assetPath)
                } catch (e: java.io.FileNotFoundException) {
                    Log.e(TAG, "✗ File not found: $assetPath")
                    Log.e(TAG, "✗ Exception: ${e.message}")
                    // Try default sound as fallback
                    val defaultPath = SOUND_FILES["rav_shalom_shofar"]
                    if (defaultPath != null && defaultPath != assetPath) {
                        Log.d(TAG, "Falling back to default shofar sound after file not found")
                        release()
                        playAssetSound(context, defaultPath)
                        return
                    }
                    throw e
                }
                
                Log.d(TAG, "Asset opened - length: ${afd.length}, startOffset: ${afd.startOffset}")
                
                setDataSource(afd.fileDescriptor, afd.startOffset, afd.length)
                afd.close()
                Log.d(TAG, "Data source set successfully")
                
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                        .build()
                )
                Log.d(TAG, "Audio attributes set to ALARM")
                
                setOnPreparedListener {
                    Log.d(TAG, "✓ MediaPlayer prepared, starting playback NOW")
                    try {
                        start()
                        Log.d(TAG, "✓ MediaPlayer.start() called - isPlaying: ${isPlaying}")
                    } catch (e: Exception) {
                        Log.e(TAG, "✗ Error starting playback: ${e.message}")
                    }
                }
                
                setOnCompletionListener {
                    Log.d(TAG, "✓ Sound playback completed")
                    release()
                }
                
                setOnErrorListener { _, what, extra ->
                    Log.e(TAG, "✗ MediaPlayer error: what=$what, extra=$extra")
                    release()
                    true
                }
                
                Log.d(TAG, "Calling prepareAsync()...")
                prepareAsync()
            }
            
            Log.d(TAG, "MediaPlayer setup complete, waiting for prepare callback...")
            Log.d(TAG, "========================================")
            
        } catch (e: Exception) {
            Log.e(TAG, "✗ Error setting up MediaPlayer: ${e.message}", e)
            e.printStackTrace()
            
            // Last resort: try default notification sound
            Log.d(TAG, "Attempting to play system notification sound as last resort")
            try {
                playDefaultNotificationSound(context)
            } catch (e2: Exception) {
                Log.e(TAG, "✗ Even system sound failed: ${e2.message}")
            }
        }
    }
    
    private fun createNotificationChannel(context: Context, notificationManager: NotificationManager) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val importance = NotificationManager.IMPORTANCE_HIGH
            
            // Create channel WITHOUT sound (we play our own sound via MediaPlayer)
            val channel = NotificationChannel(CHANNEL_ID, CHANNEL_NAME, importance).apply {
                description = "Candle lighting time reminders"
                enableVibration(true)
                enableLights(true)
                setShowBadge(true)
                setSound(null, null) // Disable channel sound - we play custom sounds
                lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
                setBypassDnd(true) // Bypass Do Not Disturb mode - critical for religious reminders
            }
            
            notificationManager.createNotificationChannel(channel)
            Log.d(TAG, "Notification channel created/updated (without sound, bypass DND enabled)")
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
            
            val intent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
                action = "android.intent.action.MAIN"
                addCategory("android.intent.category.LAUNCHER")
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
            
            // Build notification - adjust priority and category based on notification type
            val builder = NotificationCompat.Builder(context, CHANNEL_ID)
                .setSmallIcon(R.drawable.ic_notification)
                .setContentTitle(title)
                .setContentText(body)
                .setPriority(if (isIssurMelacha) NotificationCompat.PRIORITY_HIGH else NotificationCompat.PRIORITY_MAX)
                .setCategory(if (isIssurMelacha) NotificationCompat.CATEGORY_REMINDER else NotificationCompat.CATEGORY_ALARM)
                .setSound(null) // No system sound - we play our own
                .setVibrate(longArrayOf(0, 500, 250, 500))
                .setAutoCancel(isIssurMelacha) // Issur Melacha can be dismissed, others stay
                .setOngoing(isPreNotification && candleLightingTime > 0) // Make it sticky for countdown
                .setContentIntent(pendingIntent)
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                .setDefaults(NotificationCompat.DEFAULT_VIBRATE or NotificationCompat.DEFAULT_LIGHTS)
            
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
                        .setContentText("Light candles at $candleTimeStr")
                        .setSubText("$remainingMinutes min remaining")
                    
                    // BigTextStyle for expanded view
                    builder.setStyle(
                        NotificationCompat.BigTextStyle()
                            .setBigContentTitle("⏱️ Countdown to Candle Lighting")
                            .bigText("$body\n\n🕯️ Light candles at $candleTimeStr\n⏰ $remainingMinutes minutes remaining")
                            .setSummaryText("Shabbos preparation")
                    )
                    
                    Log.d(TAG, "Chronometer countdown set for: $candleLightingTime")
                } else {
                    // Fallback for older devices - just show the time
                    builder.setContentTitle("🕯️ Candle Lighting Soon")
                        .setContentText("Light candles at $candleTimeStr ($remainingMinutes min)")
                        .setStyle(
                            NotificationCompat.BigTextStyle()
                                .bigText("$body\n\n🕯️ Light candles at $candleTimeStr\n⏰ About $remainingMinutes minutes remaining")
                        )
                        .setWhen(candleLightingTime)
                        .setShowWhen(true)
                }
            } else {
                builder.setStyle(NotificationCompat.BigTextStyle().bigText(body))
                    .setWhen(System.currentTimeMillis())
                    .setShowWhen(true)
                
                // Only show full screen intent for candle lighting (shofar), not for Issur Melacha reminder
                if (!isIssurMelacha) {
                    builder.setFullScreenIntent(pendingIntent, false)
                }
            }
            
            val notification = builder.build()
            
            // Use NotificationManager directly for more reliability
            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            
            try {
                notificationManager.notify(id, notification)
                Log.d(TAG, "Notification posted successfully with ID: $id using NotificationManager")
            } catch (e: SecurityException) {
                Log.e(TAG, "SecurityException with NotificationManager: ${e.message}", e)
                // Fallback to NotificationManagerCompat
                try {
                    NotificationManagerCompat.from(context).notify(id, notification)
                    Log.d(TAG, "Notification posted successfully with ID: $id using NotificationManagerCompat (fallback)")
                } catch (e2: Exception) {
                    Log.e(TAG, "Failed to post notification with NotificationManagerCompat: ${e2.message}", e2)
                }
            } catch (e: Exception) {
                Log.e(TAG, "Exception showing notification with NotificationManager: ${e.message}", e)
                // Fallback to NotificationManagerCompat
                try {
                    NotificationManagerCompat.from(context).notify(id, notification)
                    Log.d(TAG, "Notification posted successfully with ID: $id using NotificationManagerCompat (fallback)")
                } catch (e2: Exception) {
                    Log.e(TAG, "Failed to post notification with NotificationManagerCompat: ${e2.message}", e2)
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Critical error in showNotification: ${e.message}", e)
            e.printStackTrace()
        }
    }
}
