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
        private val SOUND_FILES = mapOf(
            "shofar_candle" to "flutter_assets/assets/sounds/Shofar-CandleAlarm.mp3",
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
            
            Log.d(TAG, "Notification ID: $notificationId")
            Log.d(TAG, "Title: $title")
            Log.d(TAG, "Body: $body")
            Log.d(TAG, "Is pre-notification: $isPreNotification")
            
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
            
            // Play custom sound
            playCustomSound(context, isPreNotification)
            
            // Create and show notification (without system sound since we play our own)
            showNotification(context, notificationId, title, body)
            
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
    
    private fun playCustomSound(context: Context, isPreNotification: Boolean) {
        try {
            // Get the selected sound from SharedPreferences
            val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            
            // Flutter SharedPreferences adds "flutter." prefix
            val soundKey = if (isPreNotification) {
                "flutter.pre_notification_sound"
            } else {
                "flutter.candle_lighting_sound"
            }
            
            val soundId = prefs.getString(soundKey, "shofar_candle") ?: "shofar_candle"
            Log.d(TAG, "Selected sound ID: $soundId for key: $soundKey")
            
            // Check for silent mode
            if (soundId == "silent") {
                Log.d(TAG, "Silent mode - not playing any sound")
                return
            }
            
            // Get the asset path for the sound
            val assetPath = SOUND_FILES[soundId]
            if (assetPath == null) {
                Log.e(TAG, "No asset path found for sound ID: $soundId, using default")
                playAssetSound(context, SOUND_FILES["shofar_candle"]!!)
                return
            }
            
            Log.d(TAG, "Playing sound from asset: $assetPath")
            playAssetSound(context, assetPath)
            
        } catch (e: Exception) {
            Log.e(TAG, "Error playing custom sound: ${e.message}", e)
        }
    }
    
    private fun playAssetSound(context: Context, assetPath: String) {
        try {
            // Release any existing player
            mediaPlayer?.release()
            
            mediaPlayer = MediaPlayer().apply {
                val assetManager = context.assets
                val afd: AssetFileDescriptor = assetManager.openFd(assetPath)
                
                setDataSource(afd.fileDescriptor, afd.startOffset, afd.length)
                afd.close()
                
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                        .build()
                )
                
                setOnPreparedListener {
                    Log.d(TAG, "MediaPlayer prepared, starting playback")
                    start()
                }
                
                setOnCompletionListener {
                    Log.d(TAG, "Sound playback completed")
                    release()
                }
                
                setOnErrorListener { _, what, extra ->
                    Log.e(TAG, "MediaPlayer error: what=$what, extra=$extra")
                    release()
                    true
                }
                
                prepareAsync()
            }
            
            Log.d(TAG, "MediaPlayer setup complete, preparing async")
            
        } catch (e: Exception) {
            Log.e(TAG, "Error setting up MediaPlayer: ${e.message}", e)
            e.printStackTrace()
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
                lockscreenVisibility = NotificationCompat.VISIBILITY_PUBLIC
            }
            
            notificationManager.createNotificationChannel(channel)
            Log.d(TAG, "Notification channel created/updated (without sound)")
        }
    }
    
    private fun showNotification(context: Context, id: Int, title: String, body: String) {
        try {
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
            
            // Build notification WITHOUT sound (we play custom sound separately)
            val notification = NotificationCompat.Builder(context, CHANNEL_ID)
                .setSmallIcon(R.drawable.ic_notification)
                .setContentTitle(title)
                .setContentText(body)
                .setStyle(NotificationCompat.BigTextStyle().bigText(body))
                .setPriority(NotificationCompat.PRIORITY_MAX)
                .setCategory(NotificationCompat.CATEGORY_ALARM)
                .setSound(null) // No system sound - we play our own
                .setVibrate(longArrayOf(0, 500, 250, 500))
                .setAutoCancel(true)
                .setContentIntent(pendingIntent)
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                .setDefaults(NotificationCompat.DEFAULT_VIBRATE or NotificationCompat.DEFAULT_LIGHTS)
                .setWhen(System.currentTimeMillis())
                .setShowWhen(true)
                .setFullScreenIntent(pendingIntent, false)
                .build()
            
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
