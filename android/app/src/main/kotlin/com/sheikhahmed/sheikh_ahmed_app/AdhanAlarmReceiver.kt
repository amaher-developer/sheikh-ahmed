package com.sheikhahmed.sheikh_ahmed_app

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.content.ContextCompat

/**
 * Wakes at a prayer time and hands off to [AdhanPlaybackService].
 *
 * The alarms are registered with [AlarmManager.setAlarmClock], not the
 * ordinary set/setExact methods. That matters twice over: alarm-clock
 * alarms are exempt from Doze, so they fire on time on an idle phone, and
 * they are one of the documented exemptions that let an app start a
 * foreground service while in the background on Android 12+. An ordinary
 * exact alarm would be allowed to fire but blocked from starting the
 * service, and the adhan would silently not play.
 */
class AdhanAlarmReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val service = Intent(context, AdhanPlaybackService::class.java)
            .putExtra(
                AdhanPlaybackService.EXTRA_TITLE,
                intent.getStringExtra(AdhanPlaybackService.EXTRA_TITLE),
            )
            .putExtra(
                AdhanPlaybackService.EXTRA_BODY,
                intent.getStringExtra(AdhanPlaybackService.EXTRA_BODY),
            )
            .putExtra(
                AdhanPlaybackService.EXTRA_RES,
                intent.getStringExtra(AdhanPlaybackService.EXTRA_RES),
            )
        try {
            ContextCompat.startForegroundService(context, service)
        } catch (e: Exception) {
            // ForegroundServiceStartNotAllowedException on Android 12+.
            // [schedule] refuses to register these alarms without the
            // exact-alarm permission precisely so this cannot happen, but the
            // user can revoke it after the fact and leave already-queued
            // alarms behind. Announce the prayer with a plain notification
            // rather than letting it pass in silence.
            AdhanPlaybackService.postFallbackNotification(
                context,
                intent.getStringExtra(AdhanPlaybackService.EXTRA_TITLE),
                intent.getStringExtra(AdhanPlaybackService.EXTRA_BODY),
            )
        }
    }

    companion object {
        /** Ids stay in their own range, clear of the notification ids. */
        private const val REQUEST_BASE = 7000

        private fun pendingIntent(
            context: Context,
            index: Int,
            title: String?,
            body: String?,
            res: String?,
            mutableFlags: Int = 0,
        ): PendingIntent {
            val intent = Intent(context, AdhanAlarmReceiver::class.java)
                .setAction("com.manassa.sheikhahmed.ADHAN_$index")
                .putExtra(AdhanPlaybackService.EXTRA_TITLE, title)
                .putExtra(AdhanPlaybackService.EXTRA_BODY, body)
                .putExtra(AdhanPlaybackService.EXTRA_RES, res)
            return PendingIntent.getBroadcast(
                context,
                REQUEST_BASE + index,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE or
                    mutableFlags,
            )
        }

        /**
         * Replaces every scheduled adhan with [times] (epoch millis, already
         * filtered to the future by the Dart side).
         *
         * [count] is how many slots to clear first — passed separately
         * because a shrinking schedule has to cancel the alarms that are no
         * longer wanted, which a loop over [times] alone would miss.
         */
        fun schedule(
            context: Context,
            times: List<Long>,
            titles: List<String>,
            body: String,
            res: String,
            clearUpTo: Int,
        ): Boolean {
            val manager =
                context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

            for (i in 0 until clearUpTo) {
                manager.cancel(pendingIntent(context, i, null, null, null))
            }

            // These alarms exist for one purpose: to start
            // AdhanPlaybackService from the background. Only an alarm-clock
            // alarm carries that exemption on Android 12+, and setAlarmClock
            // needs the exact-alarm permission.
            //
            // Falling back to setAndAllowWhileIdle here looks harmless — the
            // alarm still fires — but it is worse than useless: onReceive is
            // then blocked from starting the service, so the adhan is lost
            // completely, and the caller has already cancelled the
            // notification path on the strength of this returning true.
            // Report the refusal instead and let the notification path stand.
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
                !manager.canScheduleExactAlarms()
            ) {
                return false
            }

            times.forEachIndexed { i, at ->
                val pi = pendingIntent(
                    context, i, titles.getOrNull(i), body, res,
                )
                manager.setAlarmClock(AlarmManager.AlarmClockInfo(at, pi), pi)
            }
            return true
        }

        fun cancelAll(context: Context, count: Int) {
            val manager =
                context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            for (i in 0 until count) {
                manager.cancel(pendingIntent(context, i, null, null, null))
            }
        }
    }
}
