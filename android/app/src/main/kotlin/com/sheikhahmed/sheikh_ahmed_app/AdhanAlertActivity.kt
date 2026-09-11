package com.sheikhahmed.sheikh_ahmed_app

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.text.format.DateFormat
import android.view.WindowManager
import android.widget.TextView
import java.util.Date

/**
 * The screen that comes up over whatever the phone is showing when the adhan
 * sounds — the thing "Appear on top" is actually for.
 *
 * Deliberately not a Flutter screen. It has to appear at the instant the
 * alarm fires, with the app not running, on a phone that may have been idle
 * since last night. Starting a Flutter engine to draw a prayer name and a
 * stop button would add seconds and a great deal that can fail; this is a
 * plain Android view and it is on screen immediately.
 *
 * One route gets it here: a direct [Context.startActivity] from
 * [AdhanAlarmReceiver], which the system allows from the background only
 * while the app holds SYSTEM_ALERT_WINDOW — the permission the user grants
 * as "Appear on top".
 *
 * There was a second, riding on a full-screen intent attached to the
 * playback notification. It went with the USE_FULL_SCREEN_INTENT permission:
 * Google Play pre-grants that to alarm-clock and calling apps alone, a
 * prayer companion is neither, and claiming otherwise on their declaration
 * form would be a false declaration. Unpre-granted, Android would have
 * downgraded it to a floating notification anyway.
 *
 * When "Appear on top" is off, the notification is still posted and the
 * adhan still plays. Nothing here is load-bearing for the call itself.
 */
class AdhanAlertActivity : Activity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Over the lock screen, and wake the display: at Fajr the phone is
        // face down on a table with the screen off, which is the whole
        // situation this exists for.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON,
            )
        }
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)

        setContentView(R.layout.activity_adhan_alert)

        val title = intent.getStringExtra(EXTRA_TITLE)
        if (!title.isNullOrBlank()) {
            findViewById<TextView>(R.id.adhan_title).text = title
        }
        val body = intent.getStringExtra(EXTRA_BODY)
        if (!body.isNullOrBlank()) {
            findViewById<TextView>(R.id.adhan_body).text = body
        }
        // Arabic-Indic digits, like everywhere else in the app. The system
        // formatter follows the *phone's* locale, which on most of these
        // devices is English — so the one number on an otherwise Arabic
        // screen came out in Latin figures.
        findViewById<TextView>(R.id.adhan_time).text = toArabicDigits(
            DateFormat.getTimeFormat(this).format(Date()),
        )

        // Typed as TextView, not Button: the controls are styled TextViews so
        // they can carry the app's own pill backgrounds and font rather than
        // the platform button look. Casting them to Button crashed the screen
        // on launch — and because this is opened from a receiver, the crash
        // showed as the adhan simply not appearing.
        findViewById<TextView>(R.id.adhan_stop).setOnClickListener {
            AdhanPlaybackService.stop(this)
            finish()
        }
        findViewById<TextView>(R.id.adhan_dismiss).setOnClickListener {
            // Closes the screen and leaves the adhan playing — someone who
            // wants to hear it out while using the phone should not have to
            // stop it to get their screen back.
            finish()
        }
    }

    /**
     * Closing it must never stop the adhan by itself. The stop button is the
     * only thing that does, so a stray back press or a swipe away leaves the
     * call sounding, as it would from a mosque.
     */
    override fun onBackPressed() {
        finish()
    }

    /** Mirrors toArabicDigits in lib/core/utils/arabic_numerals.dart. */
    private fun toArabicDigits(input: String): String {
        val out = StringBuilder(input.length)
        for (c in input) {
            out.append(if (c in '0'..'9') '٠' + (c - '0') else c)
        }
        return out.toString()
    }

    companion object {
        const val EXTRA_TITLE = "title"
        const val EXTRA_BODY = "body"

        fun intent(context: Context, title: String?, body: String?): Intent =
            Intent(context, AdhanAlertActivity::class.java)
                .putExtra(EXTRA_TITLE, title)
                .putExtra(EXTRA_BODY, body)
                .addFlags(
                    Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_CLEAR_TOP or
                        Intent.FLAG_ACTIVITY_EXCLUDE_FROM_RECENTS,
                )
    }
}
