package com.shabbos.shabbos_app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.media.RingtoneManager
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
    }
    
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
        wakeLock.acquire(60000) // Hold for 1 minute max
        
        try {
            val notificationId = intent.getIntExtra("notification_id", 0)
            val title = intent.getStringExtra("notification_title") ?: "שבת שלום!"
            val body = intent.getStringExtra("notification_body") ?: "Time to light candles 🕯️🕯️"
            
            Log.d(TAG, "Notification ID: $notificationId")
            Log.d(TAG, "Title: $title")
            Log.d(TAG, "Body: $body")
            
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
            
            // Create and show notification
            showNotification(context, notificationId, title, body)
            
            Log.d(TAG, "Notification shown successfully")
        } catch (e: Exception) {
            Log.e(TAG, "Error in onReceive: ${e.message}", e)
            e.printStackTrace()
        } finally {
            if (wakeLock.isHeld) {
                wakeLock.release()
                Log.d(TAG, "WakeLock released")
            }
        }
    }
    
    private fun createNotificationChannel(context: Context, notificationManager: NotificationManager) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val importance = NotificationManager.IMPORTANCE_HIGH
            
            val channel = NotificationChannel(CHANNEL_ID, CHANNEL_NAME, importance).apply {
                description = "Candle lighting time reminders"
                enableVibration(true)
                enableLights(true)
                setShowBadge(true)
                setSound(
                    RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION),
                    null
                )
                lockscreenVisibility = NotificationCompat.VISIBILITY_PUBLIC
            }
            
            notificationManager.createNotificationChannel(channel)
            Log.d(TAG, "Notification channel created/updated")
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
            
            val defaultSoundUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
            
            val notification = NotificationCompat.Builder(context, CHANNEL_ID)
                .setSmallIcon(R.mipmap.ic_launcher)
                .setContentTitle(title)
                .setContentText(body)
                .setStyle(NotificationCompat.BigTextStyle().bigText(body))
                .setPriority(NotificationCompat.PRIORITY_MAX)
                .setCategory(NotificationCompat.CATEGORY_ALARM)
                .setSound(defaultSoundUri)
                .setVibrate(longArrayOf(0, 500, 250, 500))
                .setAutoCancel(true)
                .setContentIntent(pendingIntent)
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                .setDefaults(NotificationCompat.DEFAULT_ALL)
                .setWhen(System.currentTimeMillis())
                .setShowWhen(true)
                .setFullScreenIntent(pendingIntent, false) // Changed to false - fullScreenIntent can be blocked
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
