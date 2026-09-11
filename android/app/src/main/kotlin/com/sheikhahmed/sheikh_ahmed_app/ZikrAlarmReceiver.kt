package com.sheikhahmed.sheikh_ahmed_app

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Settings
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject

/**
 * Shows the dhikr card at a reminder time.
 *
 * Runs alongside the dhikr *notifications*, which are unchanged and still
 * scheduled by flutter_local_notifications — this only adds the card over
 * other apps, and only where the user has granted "Appear on top". Both are
 * computed from the same instants in one place on the Dart side, so the two
 * cannot drift apart.
 *
 * Registered with setExactAndAllowWhileIdle rather than setAlarmClock, which
 * is the opposite of the adhan's choice and deliberate. setAlarmClock puts a
 * standing alarm icon in the status bar and shows up in the system's "next
 * alarm" — right for a prayer the user is waiting for, wrong for a dhikr
 * that comes round eight times a day. Nothing here starts a foreground
 * service, so the exemption that made setAlarmClock necessary for the adhan
 * does not apply.
 */
class ZikrAlarmReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        // Without the permission there is nothing to show. The notification
        // for this same moment is posted separately and is unaffected.
        if (!canDrawOverlays(context)) {
            // Logged rather than returned silently: "nothing appeared" has
            // several possible causes — the permission, a background-start
            // refusal, the alarm never firing — and they are impossible to
            // tell apart from the outside. This says which one it was.
            Log.i(TAG, "card skipped: appear-on-top not granted")
            return
        }
        try {
            context.startActivity(
                ZikrAlertActivity.intent(
                    context,
                    intent.getStringExtra(ZikrAlertActivity.EXTRA_TEXT),
                ),
            )
            Log.i(TAG, "card shown")
        } catch (e: Exception) {
            // A device that refuses it anyway. The notification still
            // arrives; a missed card is not worth a crash in a receiver.
            Log.w(TAG, "card refused by the system", e)
        }
    }

    private fun canDrawOverlays(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return true
        return Settings.canDrawOverlays(context)
    }

    companion object {
        private const val TAG = "ZikrCard"

        /** Clear of the adhan's 7000 range and of the notification ids. */
        private const val REQUEST_BASE = 7600

        private const val PREFS = "zikr_schedule"
        private const val KEY_ITEMS = "items"

        private fun pendingIntent(
            context: Context,
            index: Int,
            text: String?,
        ): PendingIntent {
            val intent = Intent(context, ZikrAlarmReceiver::class.java)
                .setAction("com.manassa.sheikhahmed.ZIKR_$index")
                .putExtra(ZikrAlertActivity.EXTRA_TEXT, text)
            return PendingIntent.getBroadcast(
                context,
                REQUEST_BASE + index,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }

        /**
         * Replaces every scheduled dhikr card with [times] (epoch millis,
         * already filtered to the future by the Dart side).
         */
        fun schedule(
            context: Context,
            times: List<Long>,
            texts: List<String>,
            clearUpTo: Int,
            persist: Boolean = true,
        ) {
            val manager =
                context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

            for (i in 0 until clearUpTo) {
                manager.cancel(pendingIntent(context, i, null))
            }

            // Exact where the app is allowed to be, and inexact where it is
            // not — unlike the adhan, a dhikr card arriving in the next Doze
            // window instead of on the hour is still worth having, and is
            // certainly better than none.
            val exact = Build.VERSION.SDK_INT < Build.VERSION_CODES.S ||
                manager.canScheduleExactAlarms()

            times.forEachIndexed { i, at ->
                val pi = pendingIntent(context, i, texts.getOrNull(i))
                if (exact) {
                    manager.setExactAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP, at, pi,
                    )
                } else {
                    manager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pi)
                }
            }

            if (persist) save(context, times, texts)
        }

        fun cancelAll(context: Context, count: Int) {
            val manager =
                context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            for (i in 0 until count) {
                manager.cancel(pendingIntent(context, i, null))
            }
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .edit().clear().apply()
        }

        private fun save(
            context: Context,
            times: List<Long>,
            texts: List<String>,
        ) {
            val items = JSONArray()
            times.forEachIndexed { i, at ->
                items.put(
                    JSONObject()
                        .put("at", at)
                        .put("text", texts.getOrNull(i) ?: ""),
                )
            }
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .edit().putString(KEY_ITEMS, items.toString()).apply()
        }

        /**
         * Puts the cards back after a reboot or an app update, which clear
         * every alarm the app had. Past instants are dropped: an alarm set
         * for a moment already gone fires immediately, and a phone switched
         * on after a day off would otherwise show every card it had missed.
         */
        fun restore(context: Context, now: Long, clearUpTo: Int) {
            val raw = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .getString(KEY_ITEMS, null) ?: return

            val times = mutableListOf<Long>()
            val texts = mutableListOf<String>()
            try {
                val items = JSONArray(raw)
                for (i in 0 until items.length()) {
                    val item = items.getJSONObject(i)
                    val at = item.getLong("at")
                    if (at <= now) continue
                    times.add(at)
                    texts.add(item.optString("text"))
                }
            } catch (e: Exception) {
                return
            }
            if (times.isEmpty()) return
            schedule(context, times, texts, clearUpTo, persist = false)
        }
    }
}
