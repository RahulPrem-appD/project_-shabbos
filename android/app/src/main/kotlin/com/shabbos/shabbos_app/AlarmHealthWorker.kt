package app.shabbos.android

import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.work.*
import java.util.concurrent.TimeUnit

/**
 * WorkManager worker that monitors alarm health and auto-recovers if alarms are cleared.
 * Runs every 12 hours to detect and fix force-stop or other alarm clearing scenarios.
 * 
 * This enables "install and forget" functionality - users never need to worry about
 * checking if alarms are active.
 */
class AlarmHealthWorker(
    context: Context,
    params: WorkerParameters
) : Worker(context, params) {
    
    companion object {
        private const val TAG = "ShabbosAlarmHealthWorker"
        private const val WORK_NAME = "alarm_health_check"
        
        /**
         * Schedule periodic health checks.
         * Call this from MainActivity.onCreate() to start monitoring.
         */
        fun schedule(context: Context) {
            val constraints = Constraints.Builder()
                .setRequiresBatteryNotLow(false)  // Run even on low battery
                .setRequiresCharging(false)       // Run even when not charging
                .setRequiresDeviceIdle(false)     // Run even when device is active
                .build()
            
            val workRequest = PeriodicWorkRequestBuilder<AlarmHealthWorker>(
                12, TimeUnit.HOURS,  // Check every 12 hours
                1, TimeUnit.HOURS     // Flex period: can run 1 hour earlier/later
            )
                .setConstraints(constraints)
                .build()
            
            WorkManager.getInstance(context)
                .enqueueUniquePeriodicWork(
                    WORK_NAME,
                    ExistingPeriodicWorkPolicy.KEEP,  // Keep existing if already scheduled
                    workRequest
                )
            
            Log.d(TAG, "✓ Alarm health monitoring scheduled (runs every 12 hours)")
            writeDebugLog(context, "AlarmHealthWorker.schedule", "Health monitoring scheduled")
        }
        
        /**
         * Helper function to write logs to debug_logs.txt for diagnostic reports
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
                java.io.File(context.getExternalFilesDir(null), "debug_logs.txt")
                    .appendText("${logData.toString()}\n")
            } catch (e: Exception) {
                android.util.Log.e(TAG, "Failed to write debug log: ${e.message}")
            }
        }
    }
    
    override fun doWork(): Result {
        val context = applicationContext
        
        Log.d(TAG, "========================================")
        Log.d(TAG, "Health check running at ${System.currentTimeMillis()}")
        writeDebugLog(context, "AlarmHealthWorker.doWork", "Health check started")
        
        try {
            val scheduler = AlarmScheduler(context)
            
            // Get scheduled alarms from SharedPreferences
            val savedAlarms = scheduler.getScheduledAlarms()
            
            Log.d(TAG, "Saved alarms in storage: ${savedAlarms.size}")
            
            if (savedAlarms.isEmpty()) {
                // No alarms should be scheduled - this is OK (user might not have set up location yet)
                Log.d(TAG, "No alarms in storage - health check complete")
                writeDebugLog(context, "AlarmHealthWorker.doWork", "No alarms to check")
                return Result.success()
            }
            
            // Check if alarms are actually scheduled with Android AlarmManager
            var validAlarmCount = 0
            var missingAlarmCount = 0
            
            for (alarm in savedAlarms) {
                val id = alarm["id"] as? Int ?: continue
                val timestampMillis = alarm["timestampMillis"] as? Long ?: continue
                val now = System.currentTimeMillis()
                
                // Skip past alarms
                if (timestampMillis <= now) {
                    continue
                }
                
                // Check if this alarm is still scheduled with AlarmManager
                val intent = Intent(context, AlarmReceiver::class.java).apply {
                    action = "app.shabbos.android.ALARM_$id"
                }
                
                val pendingIntent = PendingIntent.getBroadcast(
                    context,
                    id,
                    intent,
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_NO_CREATE
                    } else {
                        PendingIntent.FLAG_NO_CREATE
                    }
                )
                
                if (pendingIntent != null) {
                    validAlarmCount++
                    Log.d(TAG, "Alarm #$id: ✓ Active")
                } else {
                    missingAlarmCount++
                    Log.w(TAG, "Alarm #$id: ✗ MISSING")
                }
            }
            
            Log.d(TAG, "Health check results: $validAlarmCount active, $missingAlarmCount missing")
            writeDebugLog(context, "AlarmHealthWorker.doWork", "Health check results", mapOf(
                "savedAlarms" to savedAlarms.size,
                "validAlarms" to validAlarmCount,
                "missingAlarms" to missingAlarmCount
            ))
            
            // If ANY alarms are missing, reschedule ALL
            if (missingAlarmCount > 0) {
                Log.e(TAG, "❌ CRITICAL: $missingAlarmCount alarms are MISSING!")
                Log.e(TAG, "This usually means:")
                Log.e(TAG, "  1. User force-stopped the app")
                Log.e(TAG, "  2. System cleared alarms due to memory pressure")
                Log.e(TAG, "  3. App was disabled and re-enabled")
                Log.e(TAG, "Attempting auto-recovery...")
                
                writeDebugLog(context, "AlarmHealthWorker.doWork", "CRITICAL: Alarms missing - attempting recovery", mapOf(
                    "missingCount" to missingAlarmCount,
                    "validCount" to validAlarmCount
                ))
                
                // Show warning notification to user
                showAlarmsClearedNotification(context, missingAlarmCount)
                
                // Auto-reschedule all alarms
                try {
                    scheduler.rescheduleAllSavedAlarms()
                    Log.d(TAG, "✅ Alarms auto-rescheduled successfully")
                    writeDebugLog(context, "AlarmHealthWorker.doWork", "Alarms auto-rescheduled successfully", mapOf(
                        "rescheduledCount" to savedAlarms.size
                    ))
                    
                    // Show success notification
                    showAlarmsRestoredNotification(context, savedAlarms.size)
                } catch (e: Exception) {
                    Log.e(TAG, "✗ Failed to reschedule alarms: ${e.message}", e)
                    writeDebugLog(context, "AlarmHealthWorker.doWork", "CRITICAL: Failed to reschedule alarms", mapOf(
                        "error" to (e.message ?: "unknown"),
                        "errorType" to e.javaClass.simpleName
                    ))
                    // Keep showing the warning notification
                    return Result.failure()
                }
            } else if (validAlarmCount > 0) {
                Log.d(TAG, "✓ All alarms healthy ($validAlarmCount active)")
                writeDebugLog(context, "AlarmHealthWorker.doWork", "All alarms healthy", mapOf(
                    "activeCount" to validAlarmCount
                ))
            }
            
            Log.d(TAG, "Health check complete")
            Log.d(TAG, "========================================")
            
            return Result.success()
            
        } catch (e: Exception) {
            Log.e(TAG, "✗ Health check failed: ${e.message}", e)
            e.printStackTrace()
            writeDebugLog(context, "AlarmHealthWorker.doWork", "Health check failed", mapOf(
                "error" to (e.message ?: "unknown"),
                "errorType" to e.javaClass.simpleName,
                "stackTrace" to e.stackTraceToString()
            ))
            
            // Retry on failure
            return Result.retry()
        }
    }
    
    private fun showAlarmsClearedNotification(context: Context, count: Int) {
        try {
            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

            val pendingIntentFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }

            // Create intent to open app
            val intent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
            }

            val pendingIntent = PendingIntent.getActivity(
                context, 0, intent, pendingIntentFlags
            )

            // Dismiss action — cancels this notification
            val dismissIntent = Intent(context, NotificationDismissReceiver::class.java).apply {
                putExtra(NotificationDismissReceiver.EXTRA_NOTIFICATION_ID, 9999)
            }
            val dismissPendingIntent = PendingIntent.getBroadcast(
                context, 9999, dismissIntent, pendingIntentFlags
            )

            // Create high-priority notification
            val notification = NotificationCompat.Builder(context, "shabbos_alerts")
                .setSmallIcon(R.drawable.ic_notification)
                .setContentTitle("⚠️ Shabbos Alarms Were Cleared")
                .setContentText("$count alarms were cleared. Auto-rescheduling now...")
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setAutoCancel(true)
                .setContentIntent(pendingIntent)
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                .addAction(R.drawable.ic_notification, "Dismiss", dismissPendingIntent)
                .setDeleteIntent(dismissPendingIntent)
                .build()

            notificationManager.notify(9999, notification)
            Log.d(TAG, "✓ Warning notification shown to user")
            
        } catch (e: Exception) {
            Log.e(TAG, "Failed to show warning notification: ${e.message}")
        }
    }
    
    private fun showAlarmsRestoredNotification(context: Context, count: Int) {
        try {
            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

            val pendingIntentFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }

            // Create intent to open app
            val intent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
            }

            val pendingIntent = PendingIntent.getActivity(
                context, 0, intent, pendingIntentFlags
            )

            // Dismiss action — cancels this notification
            val dismissIntent = Intent(context, NotificationDismissReceiver::class.java).apply {
                putExtra(NotificationDismissReceiver.EXTRA_NOTIFICATION_ID, 9998)
            }
            val dismissPendingIntent = PendingIntent.getBroadcast(
                context, 9998, dismissIntent, pendingIntentFlags
            )

            val notification = NotificationCompat.Builder(context, "shabbos_alerts")
                .setSmallIcon(R.drawable.ic_notification)
                .setContentTitle("✅ Alarms Restored")
                .setContentText("Your $count Shabbos alarms have been automatically restored.")
                .setPriority(NotificationCompat.PRIORITY_LOW)
                .setAutoCancel(true)
                .setContentIntent(pendingIntent)
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                .addAction(R.drawable.ic_notification, "Dismiss", dismissPendingIntent)
                .setDeleteIntent(dismissPendingIntent)
                .build()

            notificationManager.notify(9998, notification)
            Log.d(TAG, "✓ Success notification shown to user")
            
            // Auto-dismiss after 5 seconds
            android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                notificationManager.cancel(9999)  // Dismiss warning notification
            }, 5000)
            
        } catch (e: Exception) {
            Log.e(TAG, "Failed to show success notification: ${e.message}")
        }
    }
}
