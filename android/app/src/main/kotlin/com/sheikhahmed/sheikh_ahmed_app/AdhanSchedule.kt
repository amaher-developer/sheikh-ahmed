package com.sheikhahmed.sheikh_ahmed_app

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

/**
 * The adhan schedule, kept on the native side so it can be re-registered
 * without Flutter.
 *
 * Android drops every one of an app's alarms on reboot **and on app update**
 * (MY_PACKAGE_REPLACED). Nothing re-registered these: the boot receiver in
 * the manifest belongs to flutter_local_notifications and only restores the
 * *notification* alarms, while the adhan runs on alarm-clock alarms set
 * natively by [AdhanAlarmReceiver]. So after a reboot — or after installing
 * a new build — the adhan simply stopped until the app was next opened, with
 * nothing on screen to say so. A phone rebooted overnight lost Fajr.
 *
 * Recomputing the times natively is not an option: the prayer calculation
 * lives in Dart, with the user's coordinates, method and madhab. Storing the
 * instants Dart already computed is enough — a 7-day window is still a
 * 7-day window after a reboot.
 */
object AdhanSchedule {

    private const val PREFS = "adhan_schedule"
    private const val KEY_ITEMS = "items"
    private const val KEY_BODY = "body"
    private const val KEY_RES = "res"

    data class Stored(
        val times: List<Long>,
        val titles: List<String>,
        val body: String,
        val res: String,
    )

    /** Replaces the stored schedule with what was just registered. */
    fun save(
        context: Context,
        times: List<Long>,
        titles: List<String>,
        body: String,
        res: String,
    ) {
        val items = JSONArray()
        times.forEachIndexed { i, at ->
            items.put(
                JSONObject()
                    .put("at", at)
                    .put("title", titles.getOrNull(i) ?: ""),
            )
        }
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_ITEMS, items.toString())
            .putString(KEY_BODY, body)
            .putString(KEY_RES, res)
            .apply()
    }

    fun clear(context: Context) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .clear()
            .apply()
    }

    /**
     * What is still ahead of [now], in order.
     *
     * Past instants are dropped rather than re-registered: an alarm set for
     * a time already gone fires the moment it is registered, which after a
     * reboot would sound every adhan the phone was switched off for, one
     * after another.
     */
    fun load(context: Context, now: Long): Stored? {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val raw = prefs.getString(KEY_ITEMS, null) ?: return null
        val body = prefs.getString(KEY_BODY, null) ?: return null
        val res = prefs.getString(KEY_RES, null) ?: return null

        val times = mutableListOf<Long>()
        val titles = mutableListOf<String>()
        try {
            val items = JSONArray(raw)
            for (i in 0 until items.length()) {
                val item = items.getJSONObject(i)
                val at = item.getLong("at")
                if (at <= now) continue
                times.add(at)
                titles.add(item.optString("title"))
            }
        } catch (e: Exception) {
            // Unreadable storage is treated as none rather than fatal: the
            // app re-registers on its next launch.
            return null
        }

        if (times.isEmpty()) return null
        return Stored(times, titles, body, res)
    }
}
