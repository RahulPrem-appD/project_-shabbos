package com.shabbos.shabbos_app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.res.AssetFileDescriptor
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
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
        // IMPORTANT: File names must match actual files in assets/sounds/
        private val SOUND_FILES = mapOf(
            "rav_shalom_shofar" to "flutter_assets/assets/sounds/RavShalomShofarDefaultCandle_Default.mp3",
            "shabbat_shalom_song" to "flutter_assets/assets/sounds/RaYomTovShabbosDefault-Android.mp3",
            "yomtov_default" to "flutter_assets/assets/sounds/Vesamachta-YomTov-Default-Android.mp3",
            "ata_bechartanu" to "flutter_assets/assets/sounds/Ata Bechartanu-YomTov.mp3",
            "ata_bechartanu_2" to "flutter_assets/assets/sounds/Ata Bechartanu2-YomTov.mp3",
            "hodu_lahashem" to "flutter_assets/assets/sounds/Hodu La'Hashem Ki Tov-YomTov.mp3"
        )
    }
    
    private var mediaPlayer: MediaPlayer? = null
    private var audioFocusRequest: AudioFocusRequest? = null
    private var audioManager: AudioManager? = null
    
    override fun onReceive(context: Context, intent: Intent) {
        // #region agent log
        try {
            val logData = org.json.JSONObject().apply {
                put("timestamp", System.currentTimeMillis())
                put("location", "AlarmReceiver.kt:39")
                put("message", "onReceive called")
                put("sessionId", "debug-session")
                put("runId", "run1")
                put("hypothesisId", "A")
                put("data", org.json.JSONObject().apply {
                    put("intentAction", intent.action ?: "null")
                    put("intentExtras", intent.extras?.keySet()?.joinToString() ?: "none")
                })
            }
            java.io.File(context.getExternalFilesDir(null), "debug_logs.txt").appendText("${logData.toString()}\n")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to write debug log: ${e.message}")
        }
        // #endregion
        
        Log.d(TAG, "========================================")
        Log.d(TAG, "AlarmReceiver: onReceive() called!")
        Log.d(TAG, "Intent action: ${intent.action}")
        Log.d(TAG, "Intent extras: ${intent.extras?.keySet()?.joinToString()}")
        Log.d(TAG, "========================================")
        
        // Acquire a WakeLock to ensure the device stays awake long enough
        val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        val wakeLock = powerManager.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "ShabbosApp::AlarmWakeLock"
        )
        wakeLock.acquire(120000) // Hold for 2 minutes max (for audio playback)
        
        // #region agent log
        try {
            val logData = org.json.JSONObject().apply {
                put("timestamp", System.currentTimeMillis())
                put("location", "AlarmReceiver.kt:50")
                put("message", "WakeLock acquired")
                put("sessionId", "debug-session")
                put("runId", "run1")
                put("hypothesisId", "F")
                put("data", org.json.JSONObject().apply {
                    put("wakeLockHeld", wakeLock.isHeld)
                })
            }
            java.io.File(context.getExternalFilesDir(null), "debug_logs.txt").appendText("${logData.toString()}\n")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to write debug log: ${e.message}")
        }
        // #endregion
        
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
            var notificationsEnabled = true
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                notificationsEnabled = notificationManager.areNotificationsEnabled()
                if (!notificationsEnabled) {
                    Log.e(TAG, "Notifications are disabled by user!")
                    // #region agent log
                    try {
                        val logData = org.json.JSONObject().apply {
                            put("timestamp", System.currentTimeMillis())
                            put("location", "AlarmReceiver.kt:70")
                            put("message", "Notifications disabled - returning early")
                            put("sessionId", "debug-session")
                            put("runId", "run1")
                            put("hypothesisId", "D")
                        }
                        java.io.File(context.getExternalFilesDir(null), "debug_logs.txt").appendText("${logData.toString()}\n")
                    } catch (e: Exception) {
                        Log.e(TAG, "Failed to write debug log: ${e.message}")
                    }
                    // #endregion
                    return
                }
            }
            
            // #region agent log
            try {
                val logData = org.json.JSONObject().apply {
                    put("timestamp", System.currentTimeMillis())
                    put("location", "AlarmReceiver.kt:75")
                    put("message", "Notifications enabled check passed")
                    put("sessionId", "debug-session")
                    put("runId", "run1")
                    put("hypothesisId", "D")
                    put("data", org.json.JSONObject().apply {
                        put("notificationsEnabled", notificationsEnabled)
                    })
                }
                java.io.File(context.getExternalFilesDir(null), "debug_logs.txt").appendText("${logData.toString()}\n")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to write debug log: ${e.message}")
            }
            // #endregion
            
            // Create notification channel (required for Android 8.0+)
            createNotificationChannel(context, notificationManager)
            
            // Verify channel exists and is enabled
            var channelImportance = -1
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val channel = notificationManager.getNotificationChannel(CHANNEL_ID)
                if (channel == null) {
                    Log.e(TAG, "Notification channel is null!")
                    createNotificationChannel(context, notificationManager)
                } else {
                    channelImportance = channel.importance
                    Log.d(TAG, "Channel importance: ${channel.importance}")
                    if (channel.importance == NotificationManager.IMPORTANCE_NONE) {
                        Log.e(TAG, "Notification channel is disabled!")
                    }
                }
            }
            
            // #region agent log
            try {
                val logData = org.json.JSONObject().apply {
                    put("timestamp", System.currentTimeMillis())
                    put("location", "AlarmReceiver.kt:91")
                    put("message", "Channel verification complete")
                    put("sessionId", "debug-session")
                    put("runId", "run1")
                    put("hypothesisId", "B")
                    put("data", org.json.JSONObject().apply {
                        put("channelImportance", channelImportance)
                        put("channelExists", channelImportance != -1)
                    })
                }
                java.io.File(context.getExternalFilesDir(null), "debug_logs.txt").appendText("${logData.toString()}\n")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to write debug log: ${e.message}")
            }
            // #endregion
            
            // Play custom sound using foreground service (works when app is closed)
            // #region agent log
            try {
                val logData = org.json.JSONObject().apply {
                    put("timestamp", System.currentTimeMillis())
                    put("location", "AlarmReceiver.kt:94")
                    put("message", "About to start audio service")
                    put("sessionId", "debug-session")
                    put("runId", "run1")
                    put("hypothesisId", "C")
                    put("data", org.json.JSONObject().apply {
                        put("soundId", soundId)
                    })
                }
                java.io.File(context.getExternalFilesDir(null), "debug_logs.txt").appendText("${logData.toString()}\n")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to write debug log: ${e.message}")
            }
            // #endregion
            
            // Start foreground service to play audio (ensures it works when app is closed)
            val serviceIntent = Intent(context, AlarmAudioService::class.java).apply {
                putExtra("sound_id", soundId)
                putExtra("title", title)
                putExtra("body", body)
            }
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(serviceIntent)
            } else {
                context.startService(serviceIntent)
            }
            
            Log.d(TAG, "Started AlarmAudioService for sound: $soundId")
            
            // Create and show notification (without system sound since we play our own)
            // Pass soundId to determine if this is an Issur Melacha notification (soundId == "default")
            // #region agent log
            try {
                val logData = org.json.JSONObject().apply {
                    put("timestamp", System.currentTimeMillis())
                    put("location", "AlarmReceiver.kt:98")
                    put("message", "About to show notification")
                    put("sessionId", "debug-session")
                    put("runId", "run1")
                    put("hypothesisId", "D")
                    put("data", org.json.JSONObject().apply {
                        put("notificationId", notificationId)
                        put("title", title)
                    })
                }
                java.io.File(context.getExternalFilesDir(null), "debug_logs.txt").appendText("${logData.toString()}\n")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to write debug log: ${e.message}")
            }
            // #endregion
            showNotification(context, notificationId, title, body, isPreNotification, candleLightingTime, soundId)
            
            // #region agent log
            try {
                val logData = org.json.JSONObject().apply {
                    put("timestamp", System.currentTimeMillis())
                    put("location", "AlarmReceiver.kt:100")
                    put("message", "Notification shown successfully")
                    put("sessionId", "debug-session")
                    put("runId", "run1")
                    put("hypothesisId", "D")
                }
                java.io.File(context.getExternalFilesDir(null), "debug_logs.txt").appendText("${logData.toString()}\n")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to write debug log: ${e.message}")
            }
            // #endregion
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
        
        // #region agent log
        try {
            val logData = org.json.JSONObject().apply {
                put("timestamp", System.currentTimeMillis())
                put("location", "AlarmReceiver.kt:184")
                put("message", "playAssetSound called")
                put("sessionId", "debug-session")
                put("runId", "run1")
                put("hypothesisId", "C")
                put("data", org.json.JSONObject().apply {
                    put("assetPath", assetPath)
                })
            }
            java.io.File(context.getExternalFilesDir(null), "debug_logs.txt").appendText("${logData.toString()}\n")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to write debug log: ${e.message}")
        }
        // #endregion
        
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
                    Log.d(TAG, "✓ MediaPlayer prepared, requesting audio focus...")
                    
                    // Request audio focus before starting playback
                    val audioMgr = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
                    audioManager = audioMgr
                    val audioFocusResult = requestAudioFocus(context, audioMgr)
                    
                    // #region agent log
                    try {
                        val logData = org.json.JSONObject().apply {
                            put("timestamp", System.currentTimeMillis())
                            put("location", "AlarmReceiver.kt:424")
                            put("message", "Audio focus requested")
                            put("sessionId", "debug-session")
                            put("runId", "run1")
                            put("hypothesisId", "C")
                            put("data", org.json.JSONObject().apply {
                                put("audioFocusResult", audioFocusResult)
                            })
                        }
                        java.io.File(context.getExternalFilesDir(null), "debug_logs.txt").appendText("${logData.toString()}\n")
                    } catch (e: Exception) {
                        Log.e(TAG, "Failed to write debug log: ${e.message}")
                    }
                    // #endregion
                    
                    if (audioFocusResult == AudioManager.AUDIOFOCUS_REQUEST_GRANTED) {
                        Log.d(TAG, "✓ Audio focus granted, starting playback NOW")
                        try {
                            start()
                            // #region agent log
                            try {
                                val logData = org.json.JSONObject().apply {
                                    put("timestamp", System.currentTimeMillis())
                                    put("location", "AlarmReceiver.kt:440")
                                    put("message", "MediaPlayer.start() called after audio focus")
                                    put("sessionId", "debug-session")
                                    put("runId", "run1")
                                    put("hypothesisId", "C")
                                    put("data", org.json.JSONObject().apply {
                                        put("isPlaying", isPlaying)
                                        put("currentPosition", currentPosition)
                                    })
                                }
                                java.io.File(context.getExternalFilesDir(null), "debug_logs.txt").appendText("${logData.toString()}\n")
                            } catch (e: Exception) {
                                Log.e(TAG, "Failed to write debug log: ${e.message}")
                            }
                            // #endregion
                            
                            // Check state after a short delay to see if it's still playing
                            android.os.Handler(context.mainLooper).postDelayed({
                                val stillPlaying = isPlaying
                                val position = currentPosition
                                Log.d(TAG, "MediaPlayer state check: isPlaying=$stillPlaying, position=$position")
                                // #region agent log
                                try {
                                    val logData = org.json.JSONObject().apply {
                                        put("timestamp", System.currentTimeMillis())
                                        put("location", "AlarmReceiver.kt:460")
                                        put("message", "MediaPlayer state check after 500ms")
                                        put("sessionId", "debug-session")
                                        put("runId", "run1")
                                        put("hypothesisId", "C")
                                        put("data", org.json.JSONObject().apply {
                                            put("isPlaying", stillPlaying)
                                            put("currentPosition", position)
                                        })
                                    }
                                    java.io.File(context.getExternalFilesDir(null), "debug_logs.txt").appendText("${logData.toString()}\n")
                                } catch (e: Exception) {
                                    Log.e(TAG, "Failed to write debug log: ${e.message}")
                                }
                                // #endregion
                            }, 500)
                            
                            Log.d(TAG, "✓ MediaPlayer.start() called - isPlaying: ${isPlaying}")
                        } catch (e: Exception) {
                            Log.e(TAG, "✗ Error starting playback: ${e.message}")
                            // #region agent log
                            try {
                                val logData = org.json.JSONObject().apply {
                                    put("timestamp", System.currentTimeMillis())
                                    put("location", "AlarmReceiver.kt:475")
                                    put("message", "Error starting playback")
                                    put("sessionId", "debug-session")
                                    put("runId", "run1")
                                    put("hypothesisId", "C")
                                    put("data", org.json.JSONObject().apply {
                                        put("error", e.message ?: "unknown")
                                    })
                                }
                                java.io.File(context.getExternalFilesDir(null), "debug_logs.txt").appendText("${logData.toString()}\n")
                            } catch (e2: Exception) {
                                Log.e(TAG, "Failed to write debug log: ${e2.message}")
                            }
                            // #endregion
                        }
                    } else {
                        Log.e(TAG, "✗ Audio focus NOT granted! Result: $audioFocusResult")
                        // #region agent log
                        try {
                            val logData = org.json.JSONObject().apply {
                                put("timestamp", System.currentTimeMillis())
                                put("location", "AlarmReceiver.kt:490")
                                put("message", "Audio focus denied")
                                put("sessionId", "debug-session")
                                put("runId", "run1")
                                put("hypothesisId", "C")
                                put("data", org.json.JSONObject().apply {
                                    put("audioFocusResult", audioFocusResult)
                                })
                            }
                            java.io.File(context.getExternalFilesDir(null), "debug_logs.txt").appendText("${logData.toString()}\n")
                        } catch (e: Exception) {
                            Log.e(TAG, "Failed to write debug log: ${e.message}")
                        }
                        // #endregion
                    }
                }
                
                setOnCompletionListener {
                    Log.d(TAG, "✓ Sound playback completed")
                    releaseAudioFocus(context, audioManager)
                    release()
                }
                
                setOnErrorListener { _, what, extra ->
                    Log.e(TAG, "✗ MediaPlayer error: what=$what, extra=$extra")
                    // #region agent log
                    try {
                        val logData = org.json.JSONObject().apply {
                            put("timestamp", System.currentTimeMillis())
                            put("location", "AlarmReceiver.kt:495")
                            put("message", "MediaPlayer error occurred")
                            put("sessionId", "debug-session")
                            put("runId", "run1")
                            put("hypothesisId", "C")
                            put("data", org.json.JSONObject().apply {
                                put("what", what)
                                put("extra", extra)
                            })
                        }
                        java.io.File(context.getExternalFilesDir(null), "debug_logs.txt").appendText("${logData.toString()}\n")
                    } catch (e: Exception) {
                        Log.e(TAG, "Failed to write debug log: ${e.message}")
                    }
                    // #endregion
                    releaseAudioFocus(context, audioManager)
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
    
    private fun requestAudioFocus(context: Context, audioManager: AudioManager): Int {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            // Android 8.0+ - use AudioFocusRequest
            val audioAttributes = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_ALARM)
                .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                .build()
            
            val focusRequest = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN)
                .setAudioAttributes(audioAttributes)
                .setAcceptsDelayedFocusGain(false)
                .setWillPauseWhenDucked(false)
                .setOnAudioFocusChangeListener { focusChange ->
                    Log.d(TAG, "Audio focus change: $focusChange")
                    when (focusChange) {
                        AudioManager.AUDIOFOCUS_LOSS, AudioManager.AUDIOFOCUS_LOSS_TRANSIENT -> {
                            // Don't pause alarms - they should play regardless
                            Log.w(TAG, "Audio focus lost but continuing alarm playback")
                        }
                        AudioManager.AUDIOFOCUS_GAIN -> {
                            // Resume playback if focus is regained
                            if (mediaPlayer != null && !mediaPlayer!!.isPlaying) {
                                mediaPlayer!!.start()
                            }
                        }
                    }
                }
                .build()
            
            audioFocusRequest = focusRequest
            audioManager.requestAudioFocus(focusRequest)
        } else {
            // Android < 8.0 - use legacy method with STREAM_ALARM for alarms
            audioManager.requestAudioFocus(
                null,
                AudioManager.STREAM_ALARM,
                AudioManager.AUDIOFOCUS_GAIN
            )
        }
    }
    
    private fun releaseAudioFocus(context: Context, audioManager: AudioManager?) {
        if (audioManager == null) return
        
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                audioFocusRequest?.let {
                    audioManager.abandonAudioFocusRequest(it)
                    audioFocusRequest = null
                }
            } else {
                audioManager.abandonAudioFocus(null)
            }
            Log.d(TAG, "Audio focus released")
        } catch (e: Exception) {
            Log.e(TAG, "Error releasing audio focus: ${e.message}")
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
            
            var notificationPosted = false
            var notificationError: String? = null
            try {
                notificationManager.notify(id, notification)
                notificationPosted = true
                Log.d(TAG, "Notification posted successfully with ID: $id using NotificationManager")
            } catch (e: SecurityException) {
                notificationError = "SecurityException: ${e.message}"
                Log.e(TAG, "SecurityException with NotificationManager: ${e.message}", e)
                // Fallback to NotificationManagerCompat
                try {
                    NotificationManagerCompat.from(context).notify(id, notification)
                    notificationPosted = true
                    Log.d(TAG, "Notification posted successfully with ID: $id using NotificationManagerCompat (fallback)")
                } catch (e2: Exception) {
                    notificationError = "NotificationManagerCompat error: ${e2.message}"
                    Log.e(TAG, "Failed to post notification with NotificationManagerCompat: ${e2.message}", e2)
                }
            } catch (e: Exception) {
                notificationError = "Exception: ${e.message}"
                Log.e(TAG, "Exception showing notification with NotificationManager: ${e.message}", e)
                // Fallback to NotificationManagerCompat
                try {
                    NotificationManagerCompat.from(context).notify(id, notification)
                    notificationPosted = true
                    Log.d(TAG, "Notification posted successfully with ID: $id using NotificationManagerCompat (fallback)")
                } catch (e2: Exception) {
                    notificationError = "NotificationManagerCompat error: ${e2.message}"
                    Log.e(TAG, "Failed to post notification with NotificationManagerCompat: ${e2.message}", e2)
                }
            }
            
            // #region agent log
            try {
                val logData = org.json.JSONObject().apply {
                    put("timestamp", System.currentTimeMillis())
                    put("location", "AlarmReceiver.kt:430")
                    put("message", "Notification post attempt complete")
                    put("sessionId", "debug-session")
                    put("runId", "run1")
                    put("hypothesisId", "D")
                    put("data", org.json.JSONObject().apply {
                        put("notificationPosted", notificationPosted)
                        put("notificationId", id)
                        put("error", notificationError ?: "none")
                    })
                }
                java.io.File(context.getExternalFilesDir(null), "debug_logs.txt").appendText("${logData.toString()}\n")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to write debug log: ${e.message}")
            }
            // #endregion
        } catch (e: Exception) {
            Log.e(TAG, "Critical error in showNotification: ${e.message}", e)
            e.printStackTrace()
        }
    }
}
