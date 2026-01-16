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
            "rav_shalom_shofar" to "flutter_assets/assets/sounds/RavShalomShofarDefaultlouder.mp3",
            "shabbat_shalom_song" to "flutter_assets/assets/sounds/RYomTovShabbatShalomSong.mp3",
            "yomtov_default" to "flutter_assets/assets/sounds/YomTov-Default.mp3",
            "ata_bechartanu" to "flutter_assets/assets/sounds/Ata Bechartanu-YomTov.mp3",
            "ata_bechartanu_2" to "flutter_assets/assets/sounds/Ata Bechartanu2-YomTov.mp3",
            "hodu_lahashem" to "flutter_assets/assets/sounds/Hodu La'Hashem Ki Tov-YomTov.mp3"
        )
    }
    
    private var mediaPlayer: MediaPlayer? = null
    private var audioFocusRequest: AudioFocusRequest? = null
    private var audioManager: AudioManager? = null
    private var wakeLock: PowerManager.WakeLock? = null
    
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
        
        val soundId = intent?.getStringExtra(EXTRA_SOUND_ID) ?: "rav_shalom_shofar"
        val title = intent?.getStringExtra(EXTRA_TITLE) ?: "שבת שלום!"
        val body = intent?.getStringExtra(EXTRA_BODY) ?: "Time to light candles 🕯️🕯️"
        
        Log.d(TAG, "Sound ID: $soundId")
        Log.d(TAG, "Title: $title")
        Log.d(TAG, "Body: $body")
        
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
        
        // Start foreground service (required for background audio playback)
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(
                    NOTIFICATION_ID,
                    createNotification(title, body),
                    android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK
                )
                Log.d(TAG, "Foreground service started (Android 10+)")
            } else {
                startForeground(NOTIFICATION_ID, createNotification(title, body))
                Log.d(TAG, "Foreground service started (Android < 10)")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error starting foreground service: ${e.message}", e)
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
        releaseMediaPlayer()
        releaseWakeLock()
        Log.d(TAG, "✓ Cleanup complete")
        Log.d(TAG, "========================================")
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
            
            // Request audio focus FIRST
            audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
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
            } else {
                Log.d(TAG, "✓ Audio focus GRANTED")
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
                        .build()
                )
                Log.d(TAG, "✓ Audio attributes set")
                
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
                            // Try to get more info about the error
                            try {
                                Log.e(TAG, "MediaPlayer state after start: ${if (isPlaying) "PLAYING" else "NOT PLAYING"}")
                            } catch (e: Exception) {
                                Log.e(TAG, "Could not check MediaPlayer state: ${e.message}")
                            }
                        } else {
                            Log.d(TAG, "✓ MediaPlayer is playing!")
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
                    stopSelf()
                }
                
                setOnErrorListener { _, what, extra ->
                    Log.e(TAG, "✗ MediaPlayer ERROR:")
                    Log.e(TAG, "  what=$what, extra=$extra")
                    Log.e(TAG, "  This usually means the audio file is corrupted or unsupported")
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
            }
            
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
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
            .build()
    }
}

