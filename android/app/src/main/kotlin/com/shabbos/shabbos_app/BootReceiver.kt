package com.shabbos.shabbos_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * Receives BOOT_COMPLETED broadcast to reschedule alarms after device restart.
 * 
 * Note: This receiver logs that the device has rebooted. The actual rescheduling
 * happens when the user opens the app next time, as we need the Flutter engine
 * to fetch the updated candle lighting times.
 * 
 * For a more robust solution, we could store scheduled alarm data in SharedPreferences
 * and reschedule them here, but that would require duplicating the scheduling logic.
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
            Log.d(TAG, "Alarms will be rescheduled when the app is opened.")
            Log.d(TAG, "========================================")
            
            // Note: In a production app, you might want to:
            // 1. Read saved alarm data from SharedPreferences
            // 2. Reschedule alarms using AlarmScheduler
            // 3. Or start a foreground service to handle this
            
            // For now, we just log that boot completed.
            // The app will reschedule notifications when opened.
        }
    }
}

