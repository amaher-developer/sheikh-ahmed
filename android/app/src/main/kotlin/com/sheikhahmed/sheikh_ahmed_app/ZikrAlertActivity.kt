package com.sheikhahmed.sheikh_ahmed_app

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.View
import android.view.WindowManager
import android.widget.TextView

/**
 * A dhikr card over whatever the phone is showing, which goes away by
 * itself.
 *
 * A card near the top rather than a full-screen takeover, and it dismisses
 * on a timer: a dhikr is a nudge, not an alarm. Taking the whole screen for
 * one several times a day is how a feature like this gets switched off — the
 * same reasoning that put the reminder hours on a waking-hours list instead
 * of an every-N-hours interval.
 *
 * Not a Flutter screen, for the same reason [AdhanAlertActivity] is not: it
 * is opened by a broadcast receiver with the app not running, and starting
 * an engine to draw one line of Arabic would cost seconds and add a great
 * deal that can fail.
 */
class ZikrAlertActivity : Activity() {

    private val dismiss = Handler(Looper.getMainLooper())
    private val close = Runnable { fadeOutAndFinish() }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED)
        }
        // Touches outside the card go to whatever is underneath, so the card
        // never interrupts what the phone was doing — it only sits over it.
        window.addFlags(WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL)
        window.clearFlags(WindowManager.LayoutParams.FLAG_DIM_BEHIND)

        setContentView(R.layout.activity_zikr_alert)

        val text = intent.getStringExtra(EXTRA_TEXT)
        if (!text.isNullOrBlank()) {
            findViewById<TextView>(R.id.zikr_text).text = text
        }

        val card = findViewById<View>(R.id.zikr_card)
        card.alpha = 0f
        card.translationY = -40f
        card.animate().alpha(1f).translationY(0f).setDuration(260).start()
        // Tapping the card dismisses it early rather than opening anything:
        // someone who has read it wants it gone, not a new screen.
        card.setOnClickListener { fadeOutAndFinish() }

        dismiss.postDelayed(close, VISIBLE_MS)
    }

    private fun fadeOutAndFinish() {
        dismiss.removeCallbacks(close)
        val card = findViewById<View>(R.id.zikr_card)
        card.animate()
            .alpha(0f)
            .translationY(-40f)
            .setDuration(200)
            .withEndAction {
                finish()
                overridePendingTransition(0, 0)
            }
            .start()
    }

    override fun onPause() {
        super.onPause()
        // Whatever took the foreground wins. Leaving the card queued behind
        // another app's screen would bring it back at a moment that has
        // nothing to do with the dhikr.
        dismiss.removeCallbacks(close)
        finish()
    }

    override fun onDestroy() {
        dismiss.removeCallbacks(close)
        super.onDestroy()
    }

    companion object {
        const val EXTRA_TEXT = "text"

        /** Long enough to read a short dhikr twice, short enough to ignore. */
        private const val VISIBLE_MS = 7000L

        fun intent(context: Context, text: String?): Intent =
            Intent(context, ZikrAlertActivity::class.java)
                .putExtra(EXTRA_TEXT, text)
                .addFlags(
                    Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_CLEAR_TOP or
                        Intent.FLAG_ACTIVITY_NO_ANIMATION or
                        Intent.FLAG_ACTIVITY_EXCLUDE_FROM_RECENTS,
                )
    }
}
