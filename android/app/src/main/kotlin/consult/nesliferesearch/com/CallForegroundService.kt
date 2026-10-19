package consult.nesliferesearch.com

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.util.Log

/**
 * Keeps the microphone and camera running while a consultation is on screen.
 *
 * Android stops handing an app the microphone and camera the moment it is no
 * longer in front — the screen locks, the doctor glances at a message — unless
 * a foreground service of the matching type is running. Without this, the
 * other side hears silence and sees a frozen frame until the app comes back.
 *
 * Started by the call screen once the call has its media, stopped when the
 * screen closes. The ongoing notification it has to show doubles as the way
 * back into the call.
 */
class CallForegroundService : Service() {

    companion object {
        private const val TAG = "CallForegroundService"
        private const val CHANNEL_ID = "ongoing_consultation"
        private const val NOTIFICATION_ID = 7301
        private const val EXTRA_VIDEO = "video"
        private const val EXTRA_TITLE = "title"

        fun start(context: Context, video: Boolean, title: String) {
            val intent = Intent(context, CallForegroundService::class.java)
                .putExtra(EXTRA_VIDEO, video)
                .putExtra(EXTRA_TITLE, title)

            // Android 12+ refuses to start a foreground service from the
            // background. Refused, the call carries on while the app is in
            // front; it only loses the ability to keep going behind it.
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(intent)
                } else {
                    context.startService(intent)
                }
            } catch (error: Exception) {
                Log.w(TAG, "Could not start the call service", error)
            }
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, CallForegroundService::class.java))
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val video = intent?.getBooleanExtra(EXTRA_VIDEO, false) ?: false
        val title = intent?.getStringExtra(EXTRA_TITLE) ?: "Consultation in progress"
        val notification = buildNotification(title)

        // A service started with startForegroundService MUST reach
        // startForeground — stopping it first is not a way out, Android closes
        // the whole app for it a few seconds later. That is what crashed a
        // call picked up before the microphone had been granted: no type could
        // be claimed, the service stopped itself, and the app was killed under
        // the doctor. So it always goes foreground, trying the richest set of
        // types first and settling for less, down to plain "phone call", which
        // needs no runtime permission at all.
        val attempts = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val phoneCall = ServiceInfo.FOREGROUND_SERVICE_TYPE_PHONE_CALL
            var media = 0
            if (granted(Manifest.permission.RECORD_AUDIO)) {
                media = media or ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
            }
            if (video && granted(Manifest.permission.CAMERA)) {
                media = media or ServiceInfo.FOREGROUND_SERVICE_TYPE_CAMERA
            }
            listOf(phoneCall or media, media, phoneCall).filter { it != 0 }.distinct()
        } else {
            emptyList()
        }

        if (attempts.isEmpty()) {
            try {
                startForeground(NOTIFICATION_ID, notification)
            } catch (error: Exception) {
                Log.w(TAG, "Could not go foreground", error)
            }
            return START_NOT_STICKY
        }

        for (types in attempts) {
            try {
                startForeground(NOTIFICATION_ID, notification, types)
                return START_NOT_STICKY
            } catch (error: Exception) {
                // Android 14 refuses a microphone or camera type while the app
                // is not in front, or without the permission. Try fewer.
                Log.w(TAG, "Could not go foreground with types $types", error)
            }
        }

        // Nothing was accepted. The call carries on while the app is in front;
        // it only cannot survive going behind it.
        return START_NOT_STICKY
    }

    /** Swiping the app away ends the call, so it ends this too. */
    override fun onTaskRemoved(rootIntent: Intent?) {
        stopSelf()
        super.onTaskRemoved(rootIntent)
    }

    private fun granted(permission: String): Boolean =
        checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED

    private fun buildNotification(title: String): Notification {
        val manager = getSystemService(NotificationManager::class.java)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            manager?.getNotificationChannel(CHANNEL_ID) == null
        ) {
            manager?.createNotificationChannel(
                NotificationChannel(
                    CHANNEL_ID,
                    "Ongoing consultation",
                    // Low: it is there to be found, not to make a sound in the
                    // middle of the consultation it describes.
                    NotificationManager.IMPORTANCE_LOW,
                ).apply { setShowBadge(false) }
            )
        }

        val open = PendingIntent.getActivity(
            this,
            0,
            packageManager.getLaunchIntentForPackage(packageName)
                ?.addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }

        return builder
            .setSmallIcon(R.drawable.ic_stat_notification)
            .setColor(getColor(R.color.notification_accent))
            .setContentTitle(title)
            .setContentText("Tap to return to the call")
            .setCategory(Notification.CATEGORY_CALL)
            .setOngoing(true)
            .setContentIntent(open)
            .build()
    }
}
