package com.sheikhahmed.sheikh_ahmed_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * Puts the adhan alarms back after anything that clears them.
 *
 * Android drops an app's alarms on reboot, on app update, and they no longer
 * mean the right thing after the clock or the time zone is changed. Without
 * this, the adhan stopped dead at each of those and stayed stopped until the
 * app happened to be opened again — silently, with nothing to indicate the
 * schedule was gone.
 *
 * MY_PACKAGE_REPLACED matters as much as BOOT_COMPLETED here: every update
 * from the Play Store wipes the schedule the same way a reboot does.
 *
 * A time change is handled by re-registering the stored instants unchanged.
 * They are absolute moments, so moving the clock does not move the prayer —
 * but the alarms were queued against the old reading of it and have to be
 * set again. The prayer times themselves are recomputed by Dart the next
 * time the app runs, which is the only place that can do it.
 */
class AdhanBootReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED,
            "android.intent.action.QUICKBOOT_POWERON",
            "com.htc.intent.action.QUICKBOOT_POWERON",
            Intent.ACTION_MY_PACKAGE_REPLACED,
            Intent.ACTION_TIME_CHANGED,
            Intent.ACTION_TIMEZONE_CHANGED,
            -> restore(context)
        }
    }

    private fun restore(context: Context) {
        // The dhikr cards are cleared by the same events and restored the
        // same way. Done first and independently: a device with no adhan
        // schedule stored should still get its cards back.
        ZikrAlarmReceiver.restore(
            context,
            System.currentTimeMillis(),
            ZIKR_SLOTS,
        )

        val stored = AdhanSchedule.load(context, System.currentTimeMillis())
        if (stored == null) {
            // Logged rather than returned silently. "The adhan stopped after
            // I restarted my phone" is the exact bug this class exists for,
            // and without a line here there is no way to tell a receiver
            // that never ran from one that ran and found nothing stored.
            Log.i(TAG, "nothing stored to restore")
            return
        }
        Log.i(TAG, "restoring ${stored.times.size} adhan alarms")
        AdhanAlarmReceiver.schedule(
            context = context,
            times = stored.times,
            titles = stored.titles,
            body = stored.body,
            res = stored.res,
            // Every slot, not just the ones being refilled: a schedule that
            // has shrunk since it was stored must not leave the tail of the
            // old one behind.
            clearUpTo = SLOTS,
            // Already stored — re-saving here would only rewrite the same
            // thing minus the instants that have since passed, and losing
            // those costs nothing but buys nothing either.
            persist = false,
        )
    }

    private companion object {
        const val TAG = "AdhanBoot"

        /** Mirrors kAdhanAlarmSlots in adhan_scheduler.dart (7 days x 5). */
        const val SLOTS = 35

        /** Mirrors kZikrAlarmSlots in adhan_scheduler.dart (7 days x 8). */
        const val ZIKR_SLOTS = 56
    }
}
