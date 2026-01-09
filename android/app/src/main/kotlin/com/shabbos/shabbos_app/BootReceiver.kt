package com.shabbos.shabbos_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.PowerManager
import android.util.Log

/**
 * Receives BOOT_COMPLETED broadcast to reschedule alarms after device restart.
 * 
 * This receiver reads saved alarm data from SharedPreferences and reschedules
 * all alarms that are still in the future. This ensures notifications work
 * even after device restart without requiring the user to open the app.
 */
class BootReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "ShabbosBootReceiver"
    }
    
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED ||
            intent.action == "android.intent.action.QUICKBOOT_POWERON" ||
            intent.action == "com.htc.intent.action.QUICKBOOT_POWERON") {
            
            Log.d(TAG, "========================================")
            Log.d(TAG, "Device boot completed!")
            Log.d(TAG, "Rescheduling saved alarms...")
            Log.d(TAG, "========================================")
            
            // Acquire a wake lock to ensure we complete the rescheduling
            val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
            val wakeLock = powerManager.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK,
                "ShabbosApp::BootRescheduleWakeLock"
            )
            wakeLock.acquire(60000) // Hold for 60 seconds max
            
            try {
                // Reschedule all saved alarms
                val alarmScheduler = AlarmScheduler(context)
                alarmScheduler.rescheduleAllSavedAlarms()
                
                Log.d(TAG, "========================================")
                Log.d(TAG, "Boot rescheduling complete!")
                Log.d(TAG, "========================================")
            } catch (e: Exception) {
                Log.e(TAG, "Error rescheduling alarms on boot: ${e.message}", e)
            } finally {
                if (wakeLock.isHeld) {
                    wakeLock.release()
                }
            }
        }
    }
}

