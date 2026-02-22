package com.shabbos.shabbos_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.res.AssetFileDescriptor
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaPlayer
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.media.app.NotificationCompat.MediaStyle

class AlarmAudioService : Service() {
    companion object {
        private const val TAG = "ShabbosAlarmAudioService"
        private const val CHANNEL_ID = "shabbos_audio_service_v2" // v2: IMPORTANCE_DEFAULT + VISIBILITY_PUBLIC for visible dismiss button
        private const val NOTIFICATION_ID = 1001
        
        
        const val ACTION_STOP_ALARM = "com.shabbos.shabbos_app.STOP_ALARM"
        const val EXTRA_NOTIFICATION_ID = "notification_id" // AlarmReceiver's notification ID to cancel on stop

        private const val EXTRA_SOUND_ID = "sound_id"
        private const val EXTRA_TITLE = "title"
        private const val EXTRA_BODY = "body"
        
        // SOUND_FILES: Map of sound IDs to asset paths
        // NOTE: Only sounds that actually exist in assets/sounds/ should be listed here
        // Missing files will cause playback to fail and fallback to default shofar
        private val SOUND_FILES = mapOf(
            "rav_shalom_shofar" to "flutter_assets/assets/sounds/RavShalomShofarDefaultCandle_Default.mp3",
            "shabbat_shalom_song" to "flutter_assets/assets/sounds/RaYomTovShabbosDefault-Android.mp3",
            "yomtov_default" to "flutter_assets/assets/sounds/Vesamachta-YomTov-Default-Android.mp3"
            // NOTE: The following sounds were REMOVED because files don't exist:
            // "ata_bechartanu" to "flutter_assets/assets/sounds/Ata Bechartanu-YomTov.mp3",
            // "ata_bechartanu_2" to "flutter_assets/assets/sounds/Ata Bechartanu2-YomTov.mp3",
            // "hodu_lahashem" to "flutter_assets/assets/sounds/Hodu La'Hashem Ki Tov-YomTov.mp3"
            // Add these files to assets/sounds/ to re-enable these options
        )
    }
    
    private var mediaPlayer: MediaPlayer? = null
    private var audioFocusRequest: AudioFocusRequest? = null
    private var audioManager: AudioManager? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private var initialAlarmVolume: Int = -1
    private var volumeReceiver: android.content.BroadcastReceiver? = null
    private var alarmNotificationId: Int = -1 // AlarmReceiver's notification ID — cancelled on stop
    
    /**
     * Helper function to write logs to debug_logs.txt for diagnostic reports
     */
    private fun writeDebugLog(location: String, message: String, data: Map<String, Any?>? = null) {
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
            java.io.File(getExternalFilesDir(null), "debug_logs.txt").appendText("${logData.toString()}\n")
        } catch (e: Exception) {
            android.util.Log.e(TAG, "Failed to write debug log: ${e.message}")
        }
    }
    
    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "AlarmAudioService created")
        createNotificationChannel()
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // Handle dismiss action from notification button or swipe-to-dismiss
        if (intent?.action == ACTION_STOP_ALARM) {
            Log.d(TAG, "Received STOP_ALARM action — dismissing alarm from notification")
            writeDebugLog("AlarmAudioService.kt:onStartCommand", "STOP_ALARM action received from notification button")
            // Update notification ID in case this is a fresh service start from the dismiss intent
            val dismissNotifId = intent.getIntExtra(EXTRA_NOTIFICATION_ID, -1)
            if (dismissNotifId != -1) alarmNotificationId = dismissNotifId
            stopSelf()
            return START_NOT_STICKY
        }

        Log.d(TAG, "========================================")
        Log.d(TAG, "onStartCommand called")
        Log.d(TAG, "Intent: ${intent?.action}")
        Log.d(TAG, "Flags: $flags, StartId: $startId")
        Log.d(TAG, "Current time: ${System.currentTimeMillis()}")
        Log.d(TAG, "✓ Service started by AlarmReceiver (app may be closed)")
        writeDebugLog("AlarmAudioService.kt:onStartCommand", "Service started", mapOf(
            "intentAction" to (intent?.action ?: "null"),
            "flags" to flags,
            "startId" to startId
        ))
        
        val soundId = intent?.getStringExtra(EXTRA_SOUND_ID) ?: "rav_shalom_shofar"
        val title = intent?.getStringExtra(EXTRA_TITLE) ?: "שבת שלום!"
        val body = intent?.getStringExtra(EXTRA_BODY) ?: "Time to light candles 🕯️🕯️"
        alarmNotificationId = intent?.getIntExtra(EXTRA_NOTIFICATION_ID, -1) ?: -1

        // Read alarm volume from Flutter SharedPreferences (stored as string to avoid type mismatch)
        val flutterPrefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val volumeStr = flutterPrefs.getString("flutter.alarm_volume", null) ?: "1.0"
        val alarmVolume = (volumeStr.toFloatOrNull() ?: 1.0f).coerceIn(0.1f, 1.0f)

        Log.d(TAG, "Sound ID: $soundId")
        Log.d(TAG, "Title: $title")
        Log.d(TAG, "Body: $body")
        Log.d(TAG, "Alarm volume: $alarmVolume")
        
        // CRITICAL: Ensure notification channel exists (required for foreground service)
        // This must work even when app hasn't been opened for weeks
        createNotificationChannel()
        
        
        // Acquire wake lock to keep device awake during playback
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = powerManager.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "ShabbosApp::AlarmAudioWakeLock"
        )
        wakeLock?.acquire(120000) // 2 minutes - enough for full audio playback
        Log.d(TAG, "Wake lock acquired: ${wakeLock?.isHeld}")
        
        // CRITICAL: Start foreground service IMMEDIATELY (must be within 5 seconds on Android 8.0+)
        // This is required for background audio playback when app is closed
        try {
            val notification = createNotification(title, body)
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(
                    NOTIFICATION_ID,
                    notification,
                    android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK
                )
                Log.d(TAG, "✓ Foreground service started (Android 10+)")
            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForeground(NOTIFICATION_ID, notification)
                Log.d(TAG, "✓ Foreground service started (Android 8.0-9)")
            } else {
                startForeground(NOTIFICATION_ID, notification)
                Log.d(TAG, "✓ Foreground service started (Android < 8.0)")
            }
            
            // Verify foreground service started successfully
            Log.d(TAG, "✓ Foreground service notification posted (ID: $NOTIFICATION_ID)")
        } catch (e: IllegalStateException) {
            Log.e(TAG, "✗ CRITICAL: Cannot start foreground service: ${e.message}")
            Log.e(TAG, "✗ This usually means:")
            Log.e(TAG, "  - Service was started but startForeground() wasn't called within 5 seconds")
            Log.e(TAG, "  - App is in background and Android blocked foreground service")
            Log.e(TAG, "  - User needs to disable battery optimization")
            writeDebugLog("AlarmAudioService.kt:startForeground", "CRITICAL: Cannot start foreground service", mapOf(
                "error" to (e.message ?: "unknown"),
                "errorType" to "IllegalStateException",
                "userActionRequired" to true,
                "action" to "disable_battery_optimization"
            ))
            // Try to continue anyway - audio might still play
        } catch (e: Exception) {
            Log.e(TAG, "✗ Error starting foreground service: ${e.message}", e)
            writeDebugLog("AlarmAudioService.kt:startForeground", "Error starting foreground service", mapOf(
                "error" to (e.message ?: "unknown"),
                "errorType" to e.javaClass.simpleName
            ))
            // Try to continue anyway - audio might still play
        }
        
        // Play the sound
        Log.d(TAG, "Calling playSound($soundId) at volume $alarmVolume...")
        playSound(soundId, alarmVolume)
        
        Log.d(TAG, "========================================")
        // Return START_STICKY to ensure service restarts if killed
        return START_STICKY
    }
    
    override fun onBind(intent: Intent?): IBinder? = null
    
    override fun onDestroy() {
        Log.d(TAG, "========================================")
        Log.d(TAG, "AlarmAudioService.onDestroy() called")
        Log.d(TAG, "Cleaning up resources...")
        writeDebugLog("AlarmAudioService.kt:onDestroy", "Service destroying - cleaning up resources")
        unregisterVolumeReceiver()
        releaseMediaPlayer()
        releaseWakeLock()

        // Remove the foreground service notification (ID=1001)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }

        // Also cancel the AlarmReceiver's notification so it doesn't linger after sound stops
        if (alarmNotificationId != -1) {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.cancel(alarmNotificationId)
            Log.d(TAG, "✓ Cancelled alarm notification ID: $alarmNotificationId")
        }

        // Notify AlarmActivity to dismiss itself
        sendBroadcast(Intent(AlarmActivity.ACTION_ALARM_DONE).apply {
            setPackage(packageName)
        })
        Log.d(TAG, "✓ Cleanup complete, ALARM_DONE broadcast sent")
        Log.d(TAG, "========================================")
        writeDebugLog("AlarmAudioService.kt:onDestroy", "Service destroyed - cleanup complete")
        super.onDestroy()
    }
    
    private fun playSound(soundId: String, volume: Float = 1.0f) {
        Log.d(TAG, "playSound called with soundId: '$soundId', volume: $volume")
        
        if (soundId == "silent") {
            Log.d(TAG, "Silent mode - stopping service (no sound to play)")
            stopSelf()
            return
        }
        
        if (soundId == "default") {
            Log.d(TAG, "Default sound mode - stopping service (notification sound already played by system)")
            stopSelf()
            return
        }
        
        val assetPath = SOUND_FILES[soundId]
        if (assetPath == null) {
            Log.e(TAG, "✗ Sound ID not found in map: '$soundId'")
            Log.e(TAG, "Available sound IDs: ${SOUND_FILES.keys.joinToString()}")
            Log.w(TAG, "Falling back to default shofar sound")
            writeDebugLog("AlarmAudioService.kt:playSound", "Sound ID not found - falling back", mapOf(
                "soundId" to soundId,
                "availableSounds" to SOUND_FILES.keys.joinToString(),
                "action" to "fallback_to_default"
            ))
            val defaultPath = SOUND_FILES["rav_shalom_shofar"]
            if (defaultPath != null) {
                Log.d(TAG, "Using default path: $defaultPath")
                playSoundFromAsset(defaultPath, volume = volume)
            } else {
                Log.e(TAG, "✗ CRITICAL: Even default sound path is null!")
                writeDebugLog("AlarmAudioService.kt:playSound", "CRITICAL: Even default sound path is null", mapOf(
                    "soundId" to soundId,
                    "availableSounds" to SOUND_FILES.keys.joinToString()
                ))
                stopSelf()
            }
            return
        }
        
        Log.d(TAG, "✓ Found asset path for '$soundId': $assetPath")
        playSoundFromAsset(assetPath, volume = volume)
    }
    
    private fun playSoundFromAsset(assetPath: String, isRetry: Boolean = false, volume: Float = 1.0f) {
        try {
            Log.d(TAG, "========================================")
            Log.d(TAG, "playSoundFromAsset: Starting playback")
            Log.d(TAG, "Asset path: $assetPath")
            Log.d(TAG, "Is retry: $isRetry")
            
            // Get audio manager FIRST
            audioManager = getSystemService(Context.AUDIO_SERVICE) as? AudioManager

            // Set system alarm stream volume based on user's preference (0.1 to 1.0)
            // This allows hardware volume keys to control the sound during playback
            val maxVolume = audioManager?.getStreamMaxVolume(AudioManager.STREAM_ALARM) ?: 15
            val currentVolume = audioManager?.getStreamVolume(AudioManager.STREAM_ALARM) ?: 0
            val targetVolume = Math.max(1, Math.round(volume * maxVolume))

            Log.d(TAG, "Alarm stream: current=$currentVolume, max=$maxVolume, target=$targetVolume (user pref: $volume)")
            writeDebugLog("AlarmAudioService.kt:volumeCheck", "Setting alarm stream volume", mapOf(
                "currentVolume" to currentVolume,
                "maxVolume" to maxVolume,
                "targetVolume" to targetVolume,
                "userPref" to volume
            ))

            try {
                audioManager?.setStreamVolume(
                    AudioManager.STREAM_ALARM,
                    targetVolume,
                    0  // No flags — don't show system volume UI
                )
                initialAlarmVolume = targetVolume
                Log.d(TAG, "✓ Set alarm stream volume to $targetVolume / $maxVolume")
            } catch (e: SecurityException) {
                Log.e(TAG, "✗ Cannot set alarm stream volume: ${e.message}")
                writeDebugLog("AlarmAudioService.kt:volumeCheck", "Cannot set alarm stream volume", mapOf(
                    "error" to (e.message ?: "unknown")
                ))
            }

            // Listen for volume key presses — silence alarm like an incoming call
            registerVolumeReceiver()

            // Request audio focus
            val audioFocusResult = requestAudioFocus()
            
            Log.d(TAG, "Audio focus result: $audioFocusResult")
            
            
            if (audioFocusResult != AudioManager.AUDIOFOCUS_REQUEST_GRANTED) {
                Log.e(TAG, "✗ Audio focus DENIED: $audioFocusResult")
                Log.e(TAG, "✗ Expected: ${AudioManager.AUDIOFOCUS_REQUEST_GRANTED}")
                // For alarms, we should still try to play - alarms are critical
                Log.w(TAG, "⚠️ Attempting to play anyway (alarm sounds should work even without focus)")
                writeDebugLog("AlarmAudioService.kt:audioFocus", "Audio focus DENIED", mapOf(
                    "audioFocusResult" to audioFocusResult,
                    "expected" to AudioManager.AUDIOFOCUS_REQUEST_GRANTED,
                    "action" to "playing_anyway"
                ))
            } else {
                Log.d(TAG, "✓ Audio focus GRANTED")
                writeDebugLog("AlarmAudioService.kt:audioFocus", "Audio focus GRANTED", mapOf(
                    "audioFocusResult" to audioFocusResult
                ))
            }
            
            // Release any existing player first
            releaseMediaPlayer()
            
            Log.d(TAG, "Creating new MediaPlayer...")
            mediaPlayer = MediaPlayer().apply {
                Log.d(TAG, "Opening asset file descriptor...")
                var afd: AssetFileDescriptor? = null
                try {
                    afd = assets.openFd(assetPath)
                    Log.d(TAG, "Asset opened - length: ${afd.length}, startOffset: ${afd.startOffset}")
                    
                    setDataSource(afd.fileDescriptor, afd.startOffset, afd.length)
                    afd.close()
                    afd = null
                    Log.d(TAG, "✓ Data source set successfully")
                } catch (e: Exception) {
                    Log.e(TAG, "✗ Error opening asset: ${e.message}", e)
                    writeDebugLog("AlarmAudioService.kt:playSoundFromAsset", "Error opening asset", mapOf(
                        "assetPath" to assetPath,
                        "error" to (e.message ?: "unknown"),
                        "errorType" to e.javaClass.simpleName
                    ))
                    afd?.close()
                    throw e
                }
                
                Log.d(TAG, "Setting audio attributes (USAGE_ALARM)...")
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                        .build()
                )
                Log.d(TAG, "✓ Audio attributes set")
                
                // Set MediaPlayer volume to max — actual volume is controlled via alarm stream
                // This allows hardware volume keys to adjust alarm volume in real-time
                setVolume(1.0f, 1.0f)
                Log.d(TAG, "✓ MediaPlayer volume set to 1.0 (stream volume controls actual level)")
                
                setOnPreparedListener {
                    Log.d(TAG, "========================================")
                    Log.d(TAG, "✓ MediaPlayer PREPARED callback received")
                    try {
                        // Verify MediaPlayer is in prepared state
                        val duration = duration
                        Log.d(TAG, "MediaPlayer state: PREPARED")
                        Log.d(TAG, "Audio duration: $duration ms")
                        
                        val wasPlaying = isPlaying
                        Log.d(TAG, "Calling MediaPlayer.start()...")
                        start()
                        val nowPlaying = isPlaying
                        val position = currentPosition
                        
                        Log.d(TAG, "MediaPlayer.start() called")
                        Log.d(TAG, "Was playing: $wasPlaying, Now playing: $nowPlaying")
                        Log.d(TAG, "Current position: $position ms")
                        
                            if (!nowPlaying) {
                            Log.e(TAG, "✗ CRITICAL: MediaPlayer.start() called but isPlaying is FALSE!")
                            Log.e(TAG, "✗ This means playback did NOT start")
                            
                            // Check audio stream volume and mute state
                            val audioMgr = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                            val alarmVolume = audioMgr.getStreamVolume(AudioManager.STREAM_ALARM)
                            val maxAlarmVolume = audioMgr.getStreamMaxVolume(AudioManager.STREAM_ALARM)
                            val isAlarmMuted = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                                audioMgr.isStreamMute(AudioManager.STREAM_ALARM)
                            } else {
                                alarmVolume == 0
                            }
                            
                            Log.e(TAG, "✗ Alarm stream volume: $alarmVolume / $maxAlarmVolume")
                            Log.e(TAG, "✗ Alarm stream muted: $isAlarmMuted")
                            Log.e(TAG, "✗ Audio focus granted: ${audioFocusResult == AudioManager.AUDIOFOCUS_REQUEST_GRANTED}")
                            writeDebugLog("AlarmAudioService.kt:playback", "CRITICAL: MediaPlayer not playing", mapOf(
                                "isPlaying" to nowPlaying,
                                "alarmVolume" to alarmVolume,
                                "maxAlarmVolume" to maxAlarmVolume,
                                "isAlarmMuted" to isAlarmMuted,
                                "audioFocusGranted" to (audioFocusResult == AudioManager.AUDIOFOCUS_REQUEST_GRANTED),
                                "position" to position
                            ))
                            
                            // Try to get more info about the error
                            try {
                                Log.e(TAG, "MediaPlayer state after start: ${if (isPlaying) "PLAYING" else "NOT PLAYING"}")
                            } catch (e: Exception) {
                                Log.e(TAG, "Could not check MediaPlayer state: ${e.message}")
                                writeDebugLog("AlarmAudioService.kt:playback", "Could not check MediaPlayer state", mapOf(
                                    "error" to (e.message ?: "unknown")
                                ))
                            }
                            
                            // Try to restart playback with volume adjustment
                            if (isAlarmMuted || alarmVolume == 0) {
                                Log.w(TAG, "⚠️ Attempting to fix volume issue and restart playback...")
                                android.os.Handler(mainLooper).postDelayed({
                                    try {
                                        if (!isPlaying) {
                                            start()
                                            Log.d(TAG, "Retry: MediaPlayer.start() called again")
                                        }
                                    } catch (e: Exception) {
                                        Log.e(TAG, "Retry failed: ${e.message}")
                                        writeDebugLog("AlarmAudioService.kt:playback", "Retry playback failed", mapOf(
                                            "error" to (e.message ?: "unknown")
                                        ))
                                    }
                                }, 100)
                            }
                        } else {
                            Log.d(TAG, "✓ MediaPlayer is playing!")
                            writeDebugLog("AlarmAudioService.kt:playback", "MediaPlayer started successfully", mapOf(
                                "isPlaying" to nowPlaying,
                                "position" to position,
                                "duration" to duration
                            ))
                        }
                        
                        // Verify it's actually playing after a short delay
                        android.os.Handler(mainLooper).postDelayed({
                            try {
                                val stillPlaying = isPlaying
                                val currentPos = currentPosition
                                Log.d(TAG, "Playback verification (500ms later):")
                                Log.d(TAG, "  Still playing: $stillPlaying")
                                Log.d(TAG, "  Position: $currentPos ms")

                                if (!stillPlaying && currentPos == 0) {
                                    Log.e(TAG, "✗ ERROR: MediaPlayer is NOT playing after 500ms!")
                                } else if (stillPlaying) {
                                    Log.d(TAG, "✓ Playback confirmed - audio is playing at position $currentPos ms")
                                    writeDebugLog("AlarmAudioService.kt:playback", "Playback confirmed after 500ms", mapOf(
                                        "isPlaying" to stillPlaying,
                                        "position" to currentPos
                                    ))
                                } else {
                                    Log.w(TAG, "⚠️ Playback stopped but position is $currentPos ms (completed quickly)")
                                }
                            } catch (e: IllegalStateException) {
                                Log.d(TAG, "Playback verification skipped — MediaPlayer already released")
                            }
                        }, 500)
                        
                    } catch (e: Exception) {
                        Log.e(TAG, "✗ CRITICAL ERROR starting playback: ${e.message}", e)
                        e.printStackTrace()
                        writeDebugLog("AlarmAudioService.kt:playback", "CRITICAL ERROR starting playback", mapOf(
                            "error" to (e.message ?: "unknown"),
                            "errorType" to e.javaClass.simpleName,
                            "stackTrace" to e.stackTraceToString()
                        ))
                        stopSelf()
                    }
                    Log.d(TAG, "========================================")
                }
                
                setOnCompletionListener {
                    Log.d(TAG, "✓ Sound playback COMPLETED")
                    writeDebugLog("AlarmAudioService.kt:playback", "Sound playback COMPLETED", mapOf(
                        "duration" to duration
                    ))
                    stopSelf()
                }
                
                setOnErrorListener { _, what, extra ->
                    Log.e(TAG, "✗ MediaPlayer ERROR:")
                    Log.e(TAG, "  what=$what, extra=$extra")
                    Log.e(TAG, "  This usually means the audio file is corrupted or unsupported")
                    writeDebugLog("AlarmAudioService.kt:playback", "MediaPlayer ERROR", mapOf(
                        "what" to what,
                        "extra" to extra,
                        "errorType" to "MediaPlayerError"
                    ))
                    stopSelf()
                    true
                }
                
                Log.d(TAG, "Calling prepareAsync()...")
                prepareAsync()
                Log.d(TAG, "prepareAsync() called - waiting for onPrepared callback...")
            }
            
            Log.d(TAG, "========================================")
        } catch (e: Exception) {
            Log.e(TAG, "✗ CRITICAL ERROR setting up MediaPlayer: ${e.message}", e)
            e.printStackTrace()
            writeDebugLog("AlarmAudioService.kt:playSoundFromAsset", "CRITICAL ERROR setting up MediaPlayer", mapOf(
                "error" to (e.message ?: "unknown"),
                "errorType" to e.javaClass.simpleName,
                "assetPath" to assetPath,
                "isRetry" to isRetry,
                "stackTrace" to e.stackTraceToString()
            ))
            
            // CRITICAL FIX: Fall back to default shofar sound if this isn't already a retry
            // This ensures sound ALWAYS plays even if the selected sound file is missing
            val defaultPath = SOUND_FILES["rav_shalom_shofar"]
            if (!isRetry && defaultPath != null && defaultPath != assetPath) {
                Log.w(TAG, "⚠️ Falling back to default shofar sound due to error")
                writeDebugLog("AlarmAudioService.kt:playSoundFromAsset", "Falling back to default shofar sound", mapOf(
                    "originalPath" to assetPath,
                    "fallbackPath" to defaultPath,
                    "errorReason" to (e.message ?: "unknown")
                ))
                // Try to play the default sound instead
                playSoundFromAsset(defaultPath, isRetry = true, volume = volume)
                return
            }
            
            // If fallback also failed, try system notification sound as last resort
            Log.e(TAG, "✗ Fallback also failed or not available - trying system sound")
            writeDebugLog("AlarmAudioService.kt:playSoundFromAsset", "Fallback failed - trying system sound")
            try {
                playDefaultNotificationSound()
            } catch (e2: Exception) {
                Log.e(TAG, "✗ Even system notification sound failed: ${e2.message}")
                writeDebugLog("AlarmAudioService.kt:playSoundFromAsset", "CRITICAL: All sound playback methods failed", mapOf(
                    "originalError" to (e.message ?: "unknown"),
                    "systemSoundError" to (e2.message ?: "unknown")
                ))
            }
            stopSelf()
        }
    }
    
    /**
     * Play the default system notification sound as a last resort fallback
     */
    private fun playDefaultNotificationSound() {
        try {
            Log.d(TAG, "Playing default system notification sound as fallback")
            writeDebugLog("AlarmAudioService.kt:playDefaultNotificationSound", "Playing system notification sound")
            
            val defaultSoundUri = android.media.RingtoneManager.getDefaultUri(
                android.media.RingtoneManager.TYPE_ALARM
            ) ?: android.media.RingtoneManager.getDefaultUri(
                android.media.RingtoneManager.TYPE_NOTIFICATION
            )
            
            if (defaultSoundUri != null) {
                val ringtone = android.media.RingtoneManager.getRingtone(this, defaultSoundUri)
                if (ringtone != null) {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                        ringtone.isLooping = false
                    }
                    ringtone.play()
                    Log.d(TAG, "✓ System notification/alarm sound played")
                    writeDebugLog("AlarmAudioService.kt:playDefaultNotificationSound", "System sound played successfully")
                } else {
                    Log.w(TAG, "⚠️ Ringtone is null")
                    writeDebugLog("AlarmAudioService.kt:playDefaultNotificationSound", "Ringtone is null")
                }
            } else {
                Log.w(TAG, "⚠️ No default notification/alarm sound available")
                writeDebugLog("AlarmAudioService.kt:playDefaultNotificationSound", "No default sound URI available")
            }
        } catch (e: Exception) {
            Log.e(TAG, "✗ Error playing system sound: ${e.message}")
            writeDebugLog("AlarmAudioService.kt:playDefaultNotificationSound", "Error playing system sound", mapOf(
                "error" to (e.message ?: "unknown")
            ))
            throw e
        }
    }
    
    private fun requestAudioFocus(): Int {
        val audioMgr = audioManager ?: return AudioManager.AUDIOFOCUS_REQUEST_FAILED
        
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val audioAttributes = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_ALARM)
                .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                .build()
            
            val focusRequest = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN)
                .setAudioAttributes(audioAttributes)
                .setAcceptsDelayedFocusGain(false)
                .setWillPauseWhenDucked(false)
                .build()
            
            audioFocusRequest = focusRequest
            audioMgr.requestAudioFocus(focusRequest)
        } else {
            audioMgr.requestAudioFocus(
                null,
                AudioManager.STREAM_ALARM,
                AudioManager.AUDIOFOCUS_GAIN
            )
        }
    }
    
    private fun registerVolumeReceiver() {
        volumeReceiver = object : android.content.BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                if (intent?.action == "android.media.VOLUME_CHANGED_ACTION") {
                    val streamType = intent.getIntExtra("android.media.EXTRA_VOLUME_STREAM_TYPE", -1)
                    if (streamType == AudioManager.STREAM_ALARM) {
                        val newVolume = audioManager?.getStreamVolume(AudioManager.STREAM_ALARM) ?: return
                        Log.d(TAG, "Volume changed: initial=$initialAlarmVolume, new=$newVolume")
                        if (initialAlarmVolume > 0 && newVolume < initialAlarmVolume) {
                            Log.d(TAG, "Volume pressed down — silencing alarm (like incoming call)")
                            writeDebugLog("AlarmAudioService.kt:volumeReceiver", "Silencing alarm via volume key", mapOf(
                                "initialVolume" to initialAlarmVolume,
                                "newVolume" to newVolume
                            ))
                            stopSelf()
                        }
                    }
                }
            }
        }
        val filter = android.content.IntentFilter("android.media.VOLUME_CHANGED_ACTION")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(volumeReceiver, filter, RECEIVER_EXPORTED)
        } else {
            registerReceiver(volumeReceiver, filter)
        }
        Log.d(TAG, "✓ Volume change receiver registered")
    }

    private fun unregisterVolumeReceiver() {
        volumeReceiver?.let {
            try { unregisterReceiver(it) } catch (_: Exception) {}
            volumeReceiver = null
        }
    }

    private fun releaseMediaPlayer() {
        mediaPlayer?.let { player ->
            try {
                Log.d(TAG, "Releasing MediaPlayer...")
                if (player.isPlaying) {
                    Log.d(TAG, "Stopping playback before release")
                    player.stop()
                }
                player.release()
                Log.d(TAG, "✓ MediaPlayer released")
            } catch (e: Exception) {
                Log.e(TAG, "Error releasing MediaPlayer: ${e.message}", e)
                writeDebugLog("AlarmAudioService.kt:releaseMediaPlayer", "Error releasing MediaPlayer", mapOf(
                    "error" to (e.message ?: "unknown")
                ))
            }
            mediaPlayer = null
        }
        
        releaseAudioFocus()
    }
    
    private fun releaseAudioFocus() {
        audioManager?.let { audioMgr ->
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    audioFocusRequest?.let {
                        audioMgr.abandonAudioFocusRequest(it)
                    }
                } else {
                    audioMgr.abandonAudioFocus(null)
                }
            } catch (e: Exception) {
                Log.e(TAG, "Error releasing audio focus: ${e.message}")
                writeDebugLog("AlarmAudioService.kt:releaseAudioFocus", "Error releasing audio focus", mapOf(
                    "error" to (e.message ?: "unknown")
                ))
            }
        }
        audioFocusRequest = null
    }
    
    private fun releaseWakeLock() {
        wakeLock?.let {
            if (it.isHeld) {
                it.release()
            }
        }
        wakeLock = null
    }
    
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Alarm Audio Service",
                NotificationManager.IMPORTANCE_DEFAULT
            ).apply {
                description = "Plays alarm sounds — use Dismiss to stop"
                setSound(null, null)
                setShowBadge(false)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC // Show dismiss button on lock screen
            }
            
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
            Log.d(TAG, "Foreground service notification channel created (DEFAULT importance, dismiss button visible)")
        }
    }
    
    private fun createNotification(title: String, body: String): Notification {
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
        }
        
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            intent,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }
        )
        
        // Dismiss action — stops alarm audio from the notification
        val stopIntent = Intent(this, AlarmAudioService::class.java).apply {
            action = ACTION_STOP_ALARM
            putExtra(EXTRA_NOTIFICATION_ID, alarmNotificationId) // Pass ID so cancel works even on fresh start
        }
        val stopPendingIntent = PendingIntent.getService(
            this,
            9999,
            stopIntent,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(body)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentIntent(pendingIntent)
            .setOngoing(false)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setSound(null)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setShowWhen(false)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .addAction(R.drawable.ic_notification, "Dismiss", stopPendingIntent)
            .setDeleteIntent(stopPendingIntent) // Swiping away also stops alarm
            .setStyle(MediaStyle().setShowActionsInCompactView(0)) // Show dismiss in compact view
            .build()
    }
}
