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

class AlarmAudioService : Service() {
    companion object {
        private const val TAG = "ShabbosAlarmAudioService"
        private const val CHANNEL_ID = "shabbos_audio_service"
        private const val NOTIFICATION_ID = 1001
        
        
        private const val EXTRA_SOUND_ID = "sound_id"
        private const val EXTRA_TITLE = "title"
        private const val EXTRA_BODY = "body"
        
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
    private var wakeLock: PowerManager.WakeLock? = null
    
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
        
        Log.d(TAG, "Sound ID: $soundId")
        Log.d(TAG, "Title: $title")
        Log.d(TAG, "Body: $body")
        
        // CRITICAL: Ensure notification channel exists (required for foreground service)
        // This must work even when app hasn't been opened for weeks
        createNotificationChannel()
        
        // #region agent log
        try {
            val logData = org.json.JSONObject().apply {
                put("timestamp", System.currentTimeMillis())
                put("location", "AlarmAudioService.kt:onStartCommand")
                put("message", "Service started to play audio")
                put("sessionId", "debug-session")
                put("runId", "run1")
                put("hypothesisId", "C")
                put("data", org.json.JSONObject().apply {
                    put("soundId", soundId)
                    put("title", title)
                })
            }
            java.io.File(getExternalFilesDir(null), "debug_logs.txt").appendText("${logData.toString()}\n")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to write debug log: ${e.message}")
        }
        // #endregion
        
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
        Log.d(TAG, "Calling playSound($soundId)...")
        playSound(soundId)
        
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
        releaseMediaPlayer()
        releaseWakeLock()
        Log.d(TAG, "✓ Cleanup complete")
        Log.d(TAG, "========================================")
        writeDebugLog("AlarmAudioService.kt:onDestroy", "Service destroyed - cleanup complete")
        super.onDestroy()
    }
    
    private fun playSound(soundId: String) {
        Log.d(TAG, "playSound called with soundId: '$soundId'")
        
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
                playSoundFromAsset(defaultPath)
            } else {
                Log.e(TAG, "✗ CRITICAL: Even default sound path is null!")
                stopSelf()
            }
            return
        }
        
        Log.d(TAG, "✓ Found asset path for '$soundId': $assetPath")
        playSoundFromAsset(assetPath)
    }
    
    private fun playSoundFromAsset(assetPath: String) {
        try {
            Log.d(TAG, "========================================")
            Log.d(TAG, "playSoundFromAsset: Starting playback")
            Log.d(TAG, "Asset path: $assetPath")
            
            // Get audio manager FIRST
            audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            
            // CRITICAL: Ensure alarm stream volume is up and not muted
            // Even with USAGE_ALARM, we need to check/adjust volume
            val maxVolume = audioManager!!.getStreamMaxVolume(AudioManager.STREAM_ALARM)
            val currentVolume = audioManager!!.getStreamVolume(AudioManager.STREAM_ALARM)
            val isMuted = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                audioManager!!.isStreamMute(AudioManager.STREAM_ALARM)
            } else {
                currentVolume == 0
            }
            
            Log.d(TAG, "Alarm stream volume: $currentVolume / $maxVolume (muted: $isMuted)")
            writeDebugLog("AlarmAudioService.kt:volumeCheck", "Alarm stream volume check", mapOf(
                "currentVolume" to currentVolume,
                "maxVolume" to maxVolume,
                "isMuted" to isMuted
            ))
            
            if (isMuted || currentVolume == 0) {
                Log.w(TAG, "⚠️ Alarm stream is muted or volume is 0!")
                Log.w(TAG, "⚠️ Attempting to unmute and set volume...")
                writeDebugLog("AlarmAudioService.kt:volumeCheck", "WARNING: Alarm stream muted or volume is 0", mapOf(
                    "currentVolume" to currentVolume,
                    "isMuted" to isMuted,
                    "action" to "attempting_to_fix"
                ))
                
                // Try to unmute (requires MODIFY_AUDIO_SETTINGS permission)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    try {
                        audioManager!!.adjustStreamVolume(
                            AudioManager.STREAM_ALARM,
                            AudioManager.ADJUST_UNMUTE,
                            0
                        )
                        Log.d(TAG, "✓ Attempted to unmute alarm stream")
                    } catch (e: SecurityException) {
                        Log.e(TAG, "✗ Cannot unmute: Missing MODIFY_AUDIO_SETTINGS permission")
                    }
                }
                
                // Set volume to maximum (requires MODIFY_AUDIO_SETTINGS permission)
                try {
                    audioManager!!.setStreamVolume(
                        AudioManager.STREAM_ALARM,
                        maxVolume,
                        0
                    )
                    Log.d(TAG, "✓ Set alarm stream volume to maximum: $maxVolume")
                    writeDebugLog("AlarmAudioService.kt:volumeCheck", "Set alarm stream volume to maximum", mapOf(
                        "maxVolume" to maxVolume
                    ))
                } catch (e: SecurityException) {
                    Log.e(TAG, "✗ Cannot set volume: Missing MODIFY_AUDIO_SETTINGS permission")
                    Log.e(TAG, "✗ User must manually enable alarm volume in system settings")
                    writeDebugLog("AlarmAudioService.kt:volumeCheck", "Cannot set volume - permission denied", mapOf(
                        "error" to "SecurityException",
                        "userActionRequired" to true,
                        "action" to "enable_alarm_volume_manually"
                    ))
                }
            }
            
            // Request audio focus
            val audioFocusResult = requestAudioFocus()
            
            Log.d(TAG, "Audio focus result: $audioFocusResult")
            
            // #region agent log
            try {
                val logData = org.json.JSONObject().apply {
                    put("timestamp", System.currentTimeMillis())
                    put("location", "AlarmAudioService.kt:playSoundFromAsset")
                    put("message", "Audio focus requested in service")
                    put("sessionId", "debug-session")
                    put("runId", "run1")
                    put("hypothesisId", "C")
                    put("data", org.json.JSONObject().apply {
                        put("audioFocusResult", audioFocusResult)
                        put("assetPath", assetPath)
                    })
                }
                java.io.File(getExternalFilesDir(null), "debug_logs.txt").appendText("${logData.toString()}\n")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to write debug log: ${e.message}")
            }
            // #endregion
            
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
                    afd?.close()
                    throw e
                }
                
                Log.d(TAG, "Setting audio attributes (USAGE_ALARM)...")
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                        .setFlags(AudioAttributes.FLAG_AUDIBILITY_ENFORCED) // Ensure sound plays even in silent mode
                        .build()
                )
                Log.d(TAG, "✓ Audio attributes set (with AUDIBILITY_ENFORCED flag)")
                
                // Set volume to maximum (1.0 = 100%)
                // This ensures the sound plays at full volume regardless of system volume
                setVolume(1.0f, 1.0f)
                Log.d(TAG, "✓ MediaPlayer volume set to maximum (1.0)")
                
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
                            val stillPlaying = isPlaying
                            val currentPos = currentPosition
                            Log.d(TAG, "Playback verification (500ms later):")
                            Log.d(TAG, "  Still playing: $stillPlaying")
                            Log.d(TAG, "  Position: $currentPos ms")
                            
                            if (!stillPlaying && currentPos == 0) {
                                Log.e(TAG, "✗ ERROR: MediaPlayer is NOT playing after 500ms!")
                                Log.e(TAG, "✗ Position is still 0 - playback never started")
                                Log.e(TAG, "✗ Possible causes:")
                                Log.e(TAG, "  - Audio focus was lost")
                                Log.e(TAG, "  - MediaPlayer error occurred")
                                Log.e(TAG, "  - Audio system issue")
                            } else if (stillPlaying) {
                                Log.d(TAG, "✓ Playback confirmed - audio is playing at position $currentPos ms")
                            } else {
                                Log.w(TAG, "⚠️ Playback stopped but position is $currentPos ms (might have completed quickly)")
                            }
                        }, 500)
                        
                        // #region agent log
                        try {
                            val logData = org.json.JSONObject().apply {
                                put("timestamp", System.currentTimeMillis())
                                put("location", "AlarmAudioService.kt:onPrepared")
                                put("message", "MediaPlayer started in service")
                                put("sessionId", "debug-session")
                                put("runId", "run1")
                                put("hypothesisId", "C")
                                put("data", org.json.JSONObject().apply {
                                    put("isPlaying", nowPlaying)
                                    put("position", position)
                                })
                            }
                            java.io.File(getExternalFilesDir(null), "debug_logs.txt").appendText("${logData.toString()}\n")
                        } catch (e: Exception) {
                            Log.e(TAG, "Failed to write debug log: ${e.message}")
                        }
                        // #endregion
                    } catch (e: Exception) {
                        Log.e(TAG, "✗ CRITICAL ERROR starting playback: ${e.message}", e)
                        e.printStackTrace()
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
                "stackTrace" to e.stackTraceToString()
            ))
            stopSelf()
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
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Plays alarm sounds"
                setSound(null, null)
                setShowBadge(false) // Don't show badge for background service notification
                lockscreenVisibility = Notification.VISIBILITY_SECRET // Hide on lock screen to avoid confusion
            }
            
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
            Log.d(TAG, "Foreground service notification channel created (LOW importance, hidden)")
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
        
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(body)
            .setSmallIcon(R.drawable.ic_notification)
            .setContentIntent(pendingIntent)
            .setOngoing(false)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setSound(null)
            .setVisibility(NotificationCompat.VISIBILITY_SECRET) // Hide on lock screen
            .setShowWhen(false) // Don't show timestamp
            .setCategory(NotificationCompat.CATEGORY_SERVICE) // Mark as service notification
            .build()
    }
}

