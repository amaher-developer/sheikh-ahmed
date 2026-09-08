package com.sheikhahmed.sheikh_ahmed_app

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.view.View
import android.widget.RemoteViews

/**
 * A home-screen widget showing the day at a glance: the next prayer and
 * its time, the five daily prayer times, the Hijri date, this week's
 * mission, and a rotating dhikr.
 *
 * The dhikr is bundled natively (res/values/azkar_widget_strings.xml) and
 * picked from wall-clock time, because Android calls onUpdate() on its own
 * schedule with the Flutter engine not running at all — so the widget
 * always has *something* to show even on a device where the app hasn't
 * been opened in weeks.
 *
 * Everything else only Dart can compute (prayer times depend on location
 * and calculation method; the Hijri date comes from a network conversion),
 * so it is written to SharedPreferences by WidgetDataService and simply
 * read back here. When that snapshot is absent — a fresh install where the
 * app has never been opened — those rows are hidden and the widget falls
 * back to the dhikr alone rather than showing empty fields.
 *
 * updatePeriodMillis (see azkar_widget_info.xml) is Android's own minimum,
 * 30 minutes; actual timing beyond that is up to the OS/OEM's battery
 * management, the same caveat as any Android background work. The app also
 * pushes an immediate refresh whenever it recomputes (see
 * MainActivity's "refreshWidget" channel method).
 */
class AzkarWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        for (appWidgetId in appWidgetIds) {
            updateWidget(context, appWidgetManager, appWidgetId)
        }
        // Re-armed on every update as well as onEnabled: a repeating alarm
        // does not survive a reboot or a force-stop, and onUpdate is the
        // one callback guaranteed to run again afterwards.
        scheduleRotation(context)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        // The rotation alarm. AppWidgetProvider.onReceive only dispatches
        // the framework's own widget actions, so a custom one has to be
        // handled here. The PendingIntent names this class explicitly, so
        // no intent-filter is needed for it to arrive.
        if (intent.action == ACTION_ROTATE) refreshAll(context)
    }

    /** First instance placed. */
    override fun onEnabled(context: Context) {
        scheduleRotation(context)
    }

    /** Last instance removed — stop the alarm rather than leave it firing. */
    override fun onDisabled(context: Context) {
        alarmManager(context).cancel(rotationIntent(context))
    }

    companion object {
        /**
         * How often the displayed dhikr changes.
         *
         * Android clamps a widget's own updatePeriodMillis to a 30-minute
         * floor, which is why the phrase used to sit unchanged for half an
         * hour. Rotating faster than that needs the app to drive its own
         * alarm, which is what [scheduleRotation] does — this interval and
         * the alarm's are deliberately the same, so every wake-up lands on a
         * new phrase.
         */
        private const val ROTATION_INTERVAL_MS = 10L * 60L * 1000L

        private const val ACTION_ROTATE =
            "com.manassa.sheikhahmed.ROTATE_WIDGET_DHIKR"

        private fun alarmManager(context: Context) =
            context.getSystemService(Context.ALARM_SERVICE) as AlarmManager

        private fun rotationIntent(context: Context): PendingIntent {
            val intent = Intent(context, AzkarWidgetProvider::class.java)
                .setAction(ACTION_ROTATE)
            return PendingIntent.getBroadcast(
                context,
                1,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }

        /**
         * Inexact on purpose: this is decorative, so it should ride along
         * with whatever the device is already waking for rather than pulling
         * it out of Doze on its own. The consequence is that Android may
         * stretch the interval when the phone is idle — the dhikr changes
         * *at least* this often while the device is in use, not to the
         * second.
         */
        private fun scheduleRotation(context: Context) {
            alarmManager(context).setInexactRepeating(
                AlarmManager.RTC,
                System.currentTimeMillis() + ROTATION_INTERVAL_MS,
                ROTATION_INTERVAL_MS,
                rotationIntent(context),
            )
        }

        /** Written by Flutter's shared_preferences, which uses this file. */
        private const val FLUTTER_PREFS = "FlutterSharedPreferences"

        /**
         * The Dart side of shared_preferences prefixes every key it writes;
         * the Android side stores them verbatim. So a Dart
         * `setString('widget.dateLine', …)` lands here as
         * `flutter.widget.dateLine`.
         */
        private const val KEY_PREFIX = "flutter."

        private const val SEP = "|"

        /** Redraws every placed instance. Used by the method channel. */
        fun refreshAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(
                ComponentName(context, AzkarWidgetProvider::class.java)
            )
            for (id in ids) updateWidget(context, manager, id)
        }

        private fun SharedPreferences.flutterString(name: String): String? {
            val value = getString(KEY_PREFIX + name, null)
                // Fall back to the unprefixed key so the widget keeps
                // working if shared_preferences ever changes how it names
                // things, rather than silently going blank.
                ?: getString(name, null)
            return value?.takeIf { it.isNotBlank() }
        }

        fun updateWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int,
        ) {
            val views = RemoteViews(context.packageName, R.layout.azkar_widget)
            val prefs = context.getSharedPreferences(
                FLUTTER_PREFS,
                Context.MODE_PRIVATE,
            )

            bindDhikr(context, views)
            val hasData = bindAppData(prefs, views)
            views.setViewVisibility(
                R.id.widget_data_group,
                if (hasData) View.VISIBLE else View.GONE,
            )

            val launchIntent =
                context.packageManager.getLaunchIntentForPackage(context.packageName)
            if (launchIntent != null) {
                val pendingIntent = PendingIntent.getActivity(
                    context,
                    0,
                    launchIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                )
                views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)
            }

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }

        private fun bindDhikr(context: Context, views: RemoteViews) {
            val phrases = context.resources.getStringArray(R.array.azkar_widget_phrases)
            val slot =
                ((System.currentTimeMillis() / ROTATION_INTERVAL_MS) % phrases.size).toInt()
            views.setTextViewText(R.id.widget_azkar_text, phrases[slot])
        }

        /**
         * Returns false when the app has never published a snapshot, which
         * is what tells [updateWidget] to hide the prayer/date/mission rows
         * rather than render a row of blanks.
         */
        private fun bindAppData(prefs: SharedPreferences, views: RemoteViews): Boolean {
            val names = prefs.flutterString("widget.prayerNames")?.split(SEP)
            val times = prefs.flutterString("widget.prayerTimes")?.split(SEP)
            if (names == null || times == null || names.size != times.size) return false

            views.setTextViewText(
                R.id.widget_date,
                prefs.flutterString("widget.dateLine").orEmpty(),
            )

            val nextLabel = prefs.flutterString("widget.nextPrayerLabel")
            val nextTime = prefs.flutterString("widget.nextPrayerTime")
            views.setTextViewText(R.id.widget_next_prayer, nextLabel.orEmpty())
            views.setTextViewText(R.id.widget_next_time, nextTime.orEmpty())

            // Five fixed slots rather than a ListView: a RemoteViews
            // collection needs its own RemoteViewsService, which is a lot
            // of machinery for a list whose length never changes.
            val nameIds = intArrayOf(
                R.id.widget_p1_name, R.id.widget_p2_name, R.id.widget_p3_name,
                R.id.widget_p4_name, R.id.widget_p5_name,
            )
            val timeIds = intArrayOf(
                R.id.widget_p1_time, R.id.widget_p2_time, R.id.widget_p3_time,
                R.id.widget_p4_time, R.id.widget_p5_time,
            )
            for (i in nameIds.indices) {
                val hasSlot = i < names.size
                views.setTextViewText(nameIds[i], if (hasSlot) names[i] else "")
                views.setTextViewText(timeIds[i], if (hasSlot) times[i] else "")
            }

            val mission = prefs.flutterString("widget.missionTitle")
            views.setTextViewText(R.id.widget_mission, mission.orEmpty())
            views.setViewVisibility(
                R.id.widget_mission_row,
                if (mission != null) View.VISIBLE else View.GONE,
            )

            return true
        }
    }
}
