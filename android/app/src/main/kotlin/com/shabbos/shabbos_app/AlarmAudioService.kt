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
        Log.d(TAG, "onStartCommand called")
        
        val soundId = intent?.getStringExtra(EXTRA_SOUND_ID) ?: "rav_shalom_shofar"
        val title = intent?.getStringExtra(EXTRA_TITLE) ?: "שבת שלום!"
        val body = intent?.getStringExtra(EXTRA_BODY) ?: "Time to light candles 🕯️🕯️"
        
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
                })
            }
            java.io.File(getExternalFilesDir(null), "debug_logs.txt").appendText("${logData.toString()}\n")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to write debug log: ${e.message}")
        }
        // #endregion
        
        // Acquire wake lock
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = powerManager.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "ShabbosApp::AlarmAudioWakeLock"
        )
        wakeLock?.acquire(120000) // 2 minutes
        
        // Start foreground service
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                createNotification(title, body),
                android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK
            )
        } else {
            startForeground(NOTIFICATION_ID, createNotification(title, body))
        }
        
        // Play the sound
        playSound(soundId)
        
        return START_NOT_STICKY
    }
    
    override fun onBind(intent: Intent?): IBinder? = null
    
    override fun onDestroy() {
        Log.d(TAG, "AlarmAudioService destroyed")
        releaseMediaPlayer()
        releaseWakeLock()
        super.onDestroy()
    }
    
    private fun playSound(soundId: String) {
        if (soundId == "silent") {
            Log.d(TAG, "Silent mode - stopping service")
            stopSelf()
            return
        }
        
        if (soundId == "default") {
            Log.d(TAG, "Default sound - stopping service (notification sound already played)")
            stopSelf()
            return
        }
        
        val assetPath = SOUND_FILES[soundId]
        if (assetPath == null) {
            Log.e(TAG, "Sound ID not found: $soundId, using default")
            val defaultPath = SOUND_FILES["rav_shalom_shofar"]
            if (defaultPath != null) {
                playSoundFromAsset(defaultPath)
            } else {
                stopSelf()
            }
            return
        }
        
        playSoundFromAsset(assetPath)
    }
    
    private fun playSoundFromAsset(assetPath: String) {
        try {
            Log.d(TAG, "Playing sound from asset: $assetPath")
            
            // Request audio focus
            audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            val audioFocusResult = requestAudioFocus()
            
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
                    })
                }
                java.io.File(getExternalFilesDir(null), "debug_logs.txt").appendText("${logData.toString()}\n")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to write debug log: ${e.message}")
            }
            // #endregion
            
            if (audioFocusResult != AudioManager.AUDIOFOCUS_REQUEST_GRANTED) {
                Log.e(TAG, "Audio focus denied: $audioFocusResult")
                stopSelf()
                return
            }
            
            mediaPlayer = MediaPlayer().apply {
                val afd: AssetFileDescriptor = assets.openFd(assetPath)
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
                    try {
                        start()
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
                                    put("isPlaying", isPlaying)
                                })
                            }
                            java.io.File(getExternalFilesDir(null), "debug_logs.txt").appendText("${logData.toString()}\n")
                        } catch (e: Exception) {
                            Log.e(TAG, "Failed to write debug log: ${e.message}")
                        }
                        // #endregion
                    } catch (e: Exception) {
                        Log.e(TAG, "Error starting playback: ${e.message}", e)
                        stopSelf()
                    }
                }
                
                setOnCompletionListener {
                    Log.d(TAG, "Playback completed")
                    stopSelf()
                }
                
                setOnErrorListener { _, what, extra ->
                    Log.e(TAG, "MediaPlayer error: what=$what, extra=$extra")
                    stopSelf()
                    true
                }
                
                prepareAsync()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error setting up MediaPlayer: ${e.message}", e)
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
        mediaPlayer?.let {
            try {
                if (it.isPlaying) {
                    it.stop()
                }
                it.release()
            } catch (e: Exception) {
                Log.e(TAG, "Error releasing MediaPlayer: ${e.message}")
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

