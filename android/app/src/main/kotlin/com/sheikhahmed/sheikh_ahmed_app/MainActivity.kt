package com.sheikhahmed.sheikh_ahmed_app

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Extends AudioServiceActivity, not FlutterActivity: audio_service requires
 * its own activity for background playback and lock-screen controls, so the
 * manifest used to point straight at AudioServiceActivity. Subclassing it
 * keeps all of that intact while giving the app somewhere to host a method
 * channel.
 *
 * The channel exists for one thing — asking the launcher to pin the azkar
 * widget. A home-screen widget is otherwise only reachable by long-pressing
 * the wallpaper, opening the widget drawer, and finding the app in a long
 * alphabetical list, which is not discoverable enough for people to find
 * on their own.
 */
class MainActivity : AudioServiceActivity() {

    private companion object {
        const val CHANNEL = "com.manassa.sheikhahmed/widget"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // Whether a one-tap pin is even possible: it needs
                    // Android 8+ *and* a launcher that supports pinning
                    // (many third-party ones don't). The Flutter side hides
                    // the button rather than offering an action that would
                    // silently do nothing.
                    "canPinWidget" -> result.success(canPin())
                    // Registers the alarm-clock alarms that play the full
                    // adhan. Dart supplies the instants (already filtered to
                    // the future) and the labels, since it owns the prayer
                    // calculation and the translations.
                    "scheduleAdhanAlarms" -> {
                        @Suppress("UNCHECKED_CAST")
                        val times = (call.argument<List<Number>>("times") ?: emptyList())
                            .map { it.toLong() }
                        val titles = call.argument<List<String>>("titles") ?: emptyList()
                        val body = call.argument<String>("body").orEmpty()
                        val res = call.argument<String>("res") ?: "adhan_call"
                        val clearUpTo = call.argument<Int>("clearUpTo") ?: times.size
                        // Not success(true) unconditionally: schedule()
                        // refuses when exact alarms are unavailable, and the
                        // Dart side cancels its own notification path only if
                        // this reports the alarms are really in place.
                        result.success(
                            AdhanAlarmReceiver.schedule(
                                this, times, titles, body, res, clearUpTo,
                            ),
                        )
                    }
                    // Lets the app stop the adhan without the user having
                    // to find the notification, and tell whether the
                    // service already has it in hand so it does not start
                    // a second copy of its own.
                    "stopAdhan" -> {
                        AdhanPlaybackService.stop(this)
                        result.success(true)
                    }
                    "isAdhanPlaying" -> {
                        result.success(AdhanPlaybackService.isPlaying)
                    }
                    "cancelAdhanAlarms" -> {
                        AdhanAlarmReceiver.cancelAll(
                            this,
                            call.argument<Int>("count") ?: 0,
                        )
                        result.success(true)
                    }
                    // Called after Dart writes a fresh snapshot, so a
                    // placed widget picks it up at once instead of at its
                    // next scheduled refresh half an hour later.
                    // "Appear on top". The app draws nothing over other
                    // apps; what it needs is the side effect — holding
                    // this permission exempts the app from Android 12's
                    // ban on starting a foreground service from the
                    // background, which is what the adhan does when its
                    // alarm fires with the app closed.
                    "canDrawOverlays" -> result.success(canDrawOverlays())
                    "requestOverlayPermission" -> {
                        result.success(openOverlaySettings())
                    }
                    "refreshWidget" -> {
                        AzkarWidgetProvider.refreshAll(this)
                        result.success(null)
                    }
                    "pinWidget" -> {
                        if (!canPin()) {
                            result.success(false)
                            return@setMethodCallHandler
                        }
                        val manager = AppWidgetManager.getInstance(this)
                        val provider =
                            ComponentName(this, AzkarWidgetProvider::class.java)
                        // requestPinAppWidget shows the launcher's own
                        // confirmation dialog; the user still chooses where
                        // it lands. Returning true means "asked", not
                        // "placed" — Android gives no callback for the
                        // outcome without a separate broadcast.
                        result.success(manager.requestPinAppWidget(provider, null, null))
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * Whether the app may display over other apps.
     *
     * True below Android 6, where the permission is granted at install
     * and there is no screen to send anyone to.
     */
    private fun canDrawOverlays(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
        return Settings.canDrawOverlays(this)
    }

    /**
     * Opens the system's "Display over other apps" screen for this app.
     *
     * Returns false when there is nothing to open — already granted, or
     * a device with no such screen, which some manufacturers ship. The
     * Flutter side needs to tell those two apart from "asked", or it
     * would leave a row prompting for a permission that cannot be
     * granted from here.
     */
    private fun openOverlaySettings(): Boolean {
        if (canDrawOverlays()) return false
        return try {
            startActivity(
                Intent(
                    Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                    Uri.parse("package:$packageName"),
                ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            )
            true
        } catch (e: Exception) {
            false
        }
    }

    private fun canPin(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return false
        return AppWidgetManager.getInstance(this).isRequestPinAppWidgetSupported
    }
}
