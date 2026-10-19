package consult.nesliferesearch.com

import android.app.Activity
import com.google.android.play.core.appupdate.AppUpdateInfo
import com.google.android.play.core.appupdate.AppUpdateManager
import com.google.android.play.core.appupdate.AppUpdateManagerFactory
import com.google.android.play.core.appupdate.AppUpdateOptions
import com.google.android.play.core.install.InstallStateUpdatedListener
import com.google.android.play.core.install.model.AppUpdateType
import com.google.android.play.core.install.model.InstallStatus
import com.google.android.play.core.install.model.UpdateAvailability
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * Google Play in-app updates, spoken to directly rather than through a Flutter
 * plugin.
 *
 * `consult/app_update` (methods):
 *  - `check`    → `{available, flexibleAllowed, immediateAllowed, priority,
 *                   stalenessDays, availableVersionCode, downloaded}`
 *  - `start`    → `{immediate: Boolean}` — opens Play's consent sheet and, once
 *                   accepted, downloads in the background (flexible) or takes
 *                   over the screen (immediate)
 *  - `complete` → installs a downloaded flexible update; Play restarts the app
 *
 * `consult/app_update/events` streams the download:
 *  `{status: pending|downloading|downloaded|installing|installed|failed|canceled,
 *    downloaded: Long, total: Long}`
 *
 * Only works for an install that came from Play — a debug or sideloaded build
 * reports no update, which the Dart side treats as "nothing to show".
 */
class AppUpdateBridge(private val activity: Activity, messenger: BinaryMessenger) {
    companion object {
        const val REQUEST_CODE = 4127
    }

    private val manager: AppUpdateManager = AppUpdateManagerFactory.create(activity)
    private var events: EventChannel.EventSink? = null
    private var lastInfo: AppUpdateInfo? = null

    private val listener = InstallStateUpdatedListener { state ->
        val status = when (state.installStatus()) {
            InstallStatus.PENDING -> "pending"
            InstallStatus.DOWNLOADING -> "downloading"
            InstallStatus.DOWNLOADED -> "downloaded"
            InstallStatus.INSTALLING -> "installing"
            InstallStatus.INSTALLED -> "installed"
            InstallStatus.FAILED -> "failed"
            InstallStatus.CANCELED -> "canceled"
            else -> return@InstallStateUpdatedListener
        }
        emit(status, state.bytesDownloaded(), state.totalBytesToDownload())
    }

    init {
        MethodChannel(messenger, "consult/app_update").setMethodCallHandler { call, result ->
            when (call.method) {
                "check" -> check(result)
                "start" -> start(call.argument<Boolean>("immediate") ?: false, result)
                "complete" -> {
                    manager.completeUpdate()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        EventChannel(messenger, "consult/app_update/events").setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
                    events = sink
                    manager.registerListener(listener)
                }

                override fun onCancel(arguments: Any?) {
                    manager.unregisterListener(listener)
                    events = null
                }
            },
        )
    }

    private fun check(result: MethodChannel.Result) {
        manager.appUpdateInfo
            .addOnSuccessListener { info ->
                lastInfo = info
                val available =
                    info.updateAvailability() == UpdateAvailability.UPDATE_AVAILABLE ||
                        info.updateAvailability() ==
                        UpdateAvailability.DEVELOPER_TRIGGERED_UPDATE_IN_PROGRESS
                result.success(
                    mapOf(
                        "available" to available,
                        "flexibleAllowed" to info.isUpdateTypeAllowed(AppUpdateType.FLEXIBLE),
                        "immediateAllowed" to info.isUpdateTypeAllowed(AppUpdateType.IMMEDIATE),
                        "priority" to info.updatePriority(),
                        "stalenessDays" to (info.clientVersionStalenessDays() ?: 0),
                        "availableVersionCode" to info.availableVersionCode(),
                        "downloaded" to (info.installStatus() == InstallStatus.DOWNLOADED),
                    ),
                )
            }
            .addOnFailureListener { error ->
                // Not from Play, no Play services, offline: there is simply no
                // update to offer.
                result.success(mapOf("available" to false, "error" to (error.message ?: "")))
            }
    }

    private fun start(immediate: Boolean, result: MethodChannel.Result) {
        val launch = { info: AppUpdateInfo ->
            val type = if (immediate) AppUpdateType.IMMEDIATE else AppUpdateType.FLEXIBLE
            try {
                @Suppress("DEPRECATION")
                val started = manager.startUpdateFlowForResult(
                    info,
                    activity,
                    AppUpdateOptions.newBuilder(type).build(),
                    REQUEST_CODE,
                )
                result.success(started)
            } catch (error: Exception) {
                result.error("start_failed", error.message, null)
            }
        }

        // The info a flow is started from must be fresh — Play refuses a
        // stale one — so it is read again rather than reused from `check`.
        manager.appUpdateInfo
            .addOnSuccessListener(launch)
            .addOnFailureListener { error ->
                result.error("start_failed", error.message, null)
            }
    }

    /** From `MainActivity.onActivityResult`: the user declined Play's sheet. */
    fun onFlowResult(resultCode: Int) {
        if (resultCode != Activity.RESULT_OK) emit("canceled", 0, 0)
    }

    /**
     * On resume: a flexible download may have finished while the app was in
     * the background, and an immediate update left half-way must be resumed.
     */
    fun onResume() {
        manager.appUpdateInfo.addOnSuccessListener { info ->
            if (info.installStatus() == InstallStatus.DOWNLOADED) {
                emit("downloaded", info.bytesDownloaded(), info.totalBytesToDownload())
            } else if (
                info.updateAvailability() ==
                UpdateAvailability.DEVELOPER_TRIGGERED_UPDATE_IN_PROGRESS &&
                info.isUpdateTypeAllowed(AppUpdateType.IMMEDIATE) &&
                info.installStatus() != InstallStatus.DOWNLOADING
            ) {
                try {
                    @Suppress("DEPRECATION")
                    manager.startUpdateFlowForResult(
                        info,
                        activity,
                        AppUpdateOptions.newBuilder(AppUpdateType.IMMEDIATE).build(),
                        REQUEST_CODE,
                    )
                } catch (_: Exception) {
                }
            }
        }
    }

    fun dispose() {
        manager.unregisterListener(listener)
    }

    private fun emit(status: String, downloaded: Long, total: Long) {
        activity.runOnUiThread {
            events?.success(
                mapOf("status" to status, "downloaded" to downloaded, "total" to total),
            )
        }
    }
}
