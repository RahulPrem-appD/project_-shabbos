package app.shabbos.android

import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * Simple BroadcastReceiver that cancels a notification by ID.
 * Used as the dismiss action on informational notifications (e.g. AlarmHealthWorker)
 * so they have an explicit "Dismiss" button even on OEMs that hide swipe-to-dismiss.
 */
class NotificationDismissReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "NotifDismissReceiver"
        const val EXTRA_NOTIFICATION_ID = "notification_id"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val notificationId = intent.getIntExtra(EXTRA_NOTIFICATION_ID, -1)
        if (notificationId != -1) {
            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.cancel(notificationId)
            Log.d(TAG, "Dismissed notification ID: $notificationId")
        }
    }
}
