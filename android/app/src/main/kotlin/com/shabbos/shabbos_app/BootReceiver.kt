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
                java.io.File(context.getExternalFilesDir(null), "debug_logs.txt").appendText("${logData.toString()}\n")
            } catch (e: Exception) {
                android.util.Log.e(TAG, "Failed to write debug log: ${e.message}")
            }
        }
    }
    
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED ||
            intent.action == "android.intent.action.QUICKBOOT_POWERON" ||
            intent.action == "com.htc.intent.action.QUICKBOOT_POWERON") {
            
            Log.d(TAG, "========================================")
            Log.d(TAG, "Device boot completed!")
            Log.d(TAG, "Rescheduling saved alarms...")
            Log.d(TAG, "========================================")
            writeDebugLog(context, "BootReceiver.kt:onReceive", "Device boot completed - rescheduling alarms", mapOf(
                "intentAction" to intent.action,
                "timestamp" to System.currentTimeMillis()
            ))
            
            // Acquire a wake lock to ensure we complete the rescheduling
            val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
            val wakeLock = powerManager.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK,
                "ShabbosApp::BootRescheduleWakeLock"
            )
            wakeLock.acquire(60000) // Hold for 60 seconds max
            writeDebugLog(context, "BootReceiver.kt:wakeLock", "WakeLock acquired for boot rescheduling")
            
            try {
                // Reschedule all saved alarms
                val alarmScheduler = AlarmScheduler(context)
                alarmScheduler.rescheduleAllSavedAlarms()
                
                Log.d(TAG, "========================================")
                Log.d(TAG, "Boot rescheduling complete!")
                Log.d(TAG, "========================================")
                writeDebugLog(context, "BootReceiver.kt:onReceive", "Boot rescheduling complete")
            } catch (e: Exception) {
                Log.e(TAG, "Error rescheduling alarms on boot: ${e.message}", e)
                writeDebugLog(context, "BootReceiver.kt:onReceive", "CRITICAL ERROR rescheduling alarms on boot", mapOf(
                    "error" to (e.message ?: "unknown"),
                    "errorType" to e.javaClass.simpleName,
                    "stackTrace" to e.stackTraceToString()
                ))
            } finally {
                if (wakeLock.isHeld) {
                    wakeLock.release()
                    writeDebugLog(context, "BootReceiver.kt:wakeLock", "WakeLock released")
                }
            }
        }
    }
}

