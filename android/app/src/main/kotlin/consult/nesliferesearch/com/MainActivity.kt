package consult.nesliferesearch.com

import android.content.ActivityNotFoundException
import android.content.ComponentName
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/** The action the callkit plugin launches the app with on Accept. */
private const val CALLKIT_ACCEPT = "com.hiennv.flutter_callkit_incoming.ACTION_CALL_ACCEPT"

class MainActivity : FlutterActivity() {
    /** Google Play in-app updates. See [AppUpdateBridge]. */
    private var appUpdate: AppUpdateBridge? = null

    /** Held on a voice call on the earpiece. See [setProximityScreenOff]. */
    private var proximityLock: PowerManager.WakeLock? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        if (isCallAccept(intent)) showOverLockScreen(true)

        // Android 15+ draws every app edge to edge and ignores the navigation
        // bar colour Flutter asks for. With three-button navigation it then lays
        // a translucent grey "contrast" scrim over the bar — and with the dark
        // icons our light screens ask for, the buttons disappeared into it.
        //
        // Turning the scrim off lets the screen's own background show through
        // the bar, and the icon colour each screen sets (dark on light pages,
        // light on the call screen) is then drawn against that.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            window.isNavigationBarContrastEnforced = false
            window.isStatusBarContrastEnforced = false
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        appUpdate = AppUpdateBridge(this, flutterEngine.dartExecutor.binaryMessenger)

        // Mixes and shrinks a recorded consultation before it is uploaded.
        // Holds the application context, not this activity: an export can
        // outlive the screen that started it.
        RecordingComposer(applicationContext, flutterEngine.dartExecutor.binaryMessenger)

        // What the call needs from the phone that no plugin in the app offers:
        // staying alive behind the lock screen, and the settings that decide
        // whether a closed app can ring at all. See `lib/core/device/call_device.dart`.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "consult/call_device")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startCallService" -> {
                        CallForegroundService.start(
                            this,
                            call.argument<Boolean>("video") ?: false,
                            call.argument<String>("title") ?: "Consultation in progress",
                        )
                        result.success(null)
                    }
                    "stopCallService" -> {
                        CallForegroundService.stop(this)
                        result.success(null)
                    }
                    "showOverLockScreen" -> {
                        showOverLockScreen(call.argument<Boolean>("on") ?: false)
                        result.success(null)
                    }
                    "moveToBackground" -> {
                        // Back during a call: the task goes behind, nothing is
                        // finished — the call screen is exactly where it was
                        // when the notification brings it back.
                        moveTaskToBack(true)
                        result.success(null)
                    }
                    "setProximityScreenOff" -> {
                        setProximityScreenOff(call.argument<Boolean>("on") ?: false)
                        result.success(null)
                    }
                    "isIgnoringBatteryOptimizations" -> {
                        val power = getSystemService(PowerManager::class.java)
                        result.success(power?.isIgnoringBatteryOptimizations(packageName) ?: true)
                    }
                    "openBatterySettings" -> {
                        result.success(
                            open(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
                                || openAppSettings()
                        )
                    }
                    "openAutostartSettings" -> result.success(openAutostartSettings())
                    "openAppSettings" -> result.success(openAppSettings())
                    "manufacturer" -> result.success(Build.MANUFACTURER ?: "")
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * The app brought forward by Accept on the phone's ringing screen, which
     * is very often a locked phone. Shown over the lock screen at once rather
     * than when the call screen opens: until then the app sits behind the
     * keyguard, where Android counts it as backgrounded — the doctor sees a
     * lock screen instead of the patient, and the microphone it opens records
     * silence. The call screen turns this off again when the call ends.
     */
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        if (isCallAccept(intent)) showOverLockScreen(true)
    }

    private fun isCallAccept(intent: Intent?): Boolean = intent?.action == CALLKIT_ACCEPT

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == AppUpdateBridge.REQUEST_CODE) appUpdate?.onFlowResult(resultCode)
    }

    override fun onResume() {
        super.onResume()
        appUpdate?.onResume()
    }

    override fun onDestroy() {
        setProximityScreenOff(false)
        appUpdate?.dispose()
        super.onDestroy()
    }

    /**
     * Lets a call be seen and heard with the phone locked. On while the call
     * screen is open, off again when it closes — an app that sits over the
     * lock screen the rest of the time is an app anyone can pick up and use.
     */
    private fun showOverLockScreen(on: Boolean) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(on)
            setTurnScreenOn(on)
        } else {
            @Suppress("DEPRECATION")
            val flags = WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            if (on) window.addFlags(flags) else window.clearFlags(flags)
        }
    }

    /**
     * Turns the screen off while the phone is held to the ear, as the phone's
     * own dialler does. On for a voice call on the earpiece and nothing else:
     * a cheek on a lit screen mutes the call or hangs it up.
     */
    private fun setProximityScreenOff(on: Boolean) {
        if (!on) {
            proximityLock?.let { if (it.isHeld) it.release() }
            proximityLock = null
            return
        }
        if (proximityLock?.isHeld == true) return

        val power = getSystemService(PowerManager::class.java) ?: return
        if (!power.isWakeLockLevelSupported(PowerManager.PROXIMITY_SCREEN_OFF_WAKE_LOCK)) return

        proximityLock = power.newWakeLock(
            PowerManager.PROXIMITY_SCREEN_OFF_WAKE_LOCK,
            "consult:proximity",
        ).apply {
            setReferenceCounted(false)
            acquire()
        }
    }

    /**
     * The manufacturer's "auto-start" screen, where one exists.
     *
     * Xiaomi, Oppo, Vivo, Realme, OnePlus, Huawei and others stop an app that
     * is not on this list from being woken by a push once it has been swiped
     * away — so a doctor's phone never rings, and nothing on the app's side can
     * tell. There is no API for it; these are the screens' known addresses,
     * tried in turn. Falls back to the app's own settings page.
     */
    private fun openAutostartSettings(): Boolean {
        val candidates = listOf(
            "com.miui.securitycenter" to "com.miui.permcenter.autostart.AutoStartManagementActivity",
            "com.coloros.safecenter" to "com.coloros.safecenter.permission.startup.StartupAppListActivity",
            "com.coloros.safecenter" to "com.coloros.safecenter.startupapp.StartupAppListActivity",
            "com.oppo.safe" to "com.oppo.safe.permission.startup.StartupAppListActivity",
            "com.vivo.permissionmanager" to "com.vivo.permissionmanager.activity.BgStartUpManagerActivity",
            "com.iqoo.secure" to "com.iqoo.secure.ui.phoneoptimize.AddWhiteListActivity",
            "com.huawei.systemmanager" to "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity",
            "com.huawei.systemmanager" to "com.huawei.systemmanager.optimize.process.ProtectActivity",
            "com.hihonor.systemmanager" to "com.hihonor.systemmanager.startupmgr.ui.StartupNormalAppListActivity",
            "com.oneplus.security" to "com.oneplus.security.chainlaunch.view.ChainLaunchAppListActivity",
            "com.asus.mobilemanager" to "com.asus.mobilemanager.entry.FunctionActivity",
            "com.transsion.phonemaster" to "com.cyin.himgr.autostart.AutoStartActivity",
        )

        for ((pkg, cls) in candidates) {
            if (open(Intent().setComponent(ComponentName(pkg, cls)))) return true
        }

        return openAppSettings()
    }

    private fun openAppSettings(): Boolean = open(
        Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
            .setData(Uri.fromParts("package", packageName, null))
    )

    private fun open(intent: Intent): Boolean = try {
        startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        true
    } catch (error: ActivityNotFoundException) {
        false
    } catch (error: SecurityException) {
        false
    }
}
