package com.sheikhahmed.sheikh_ahmed_app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.media.MediaPlayer
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import androidx.core.app.NotificationCompat

/**
 * Plays the full adhan at prayer time.
 *
 * Why a service rather than a notification sound: Android's notification
 * player is built for short tones and stops long audio after a timeout, so
 * a three-to-four minute adhan was cut off part way through — the sound
 * would start on "الله أكبر" and die. That is a property of the mechanism,
 * not of the file, so no amount of re-encoding or shrinking fixes it. A
 * foreground service owns its own MediaPlayer and plays the file to the
 * end.
 *
 * Started by [AdhanAlarmReceiver] from an alarm-clock alarm, which is what
 * makes it legal to start a foreground service from the background on
 * Android 12+ and exempt from Doze.
 */
class AdhanPlaybackService : Service() {

    private var player: MediaPlayer? = null
    private var focusRequest: AudioFocusRequest? = null
    private val handler = Handler(Looper.getMainLooper())

    /**
     * Stops the adhan when something else takes the audio.
     *
     * The request used to be built without one at all, which is why the
     * adhan carried on over an incoming call: with no listener the system
     * has nowhere to deliver the loss, so the service never learned that
     * anything had happened and played to the end regardless.
     *
     * Any loss stops it rather than pausing. A call lasts longer than the
     * adhan, and resuming three minutes of "الله أكبر" when the call ends
     * is not what anyone wants.
     */
    private val focusListener = AudioManager.OnAudioFocusChangeListener { change ->
        when (change) {
            AudioManager.AUDIOFOCUS_LOSS,
            AudioManager.AUDIOFOCUS_LOSS_TRANSIENT,
            AudioManager.AUDIOFOCUS_LOSS_TRANSIENT_CAN_DUCK -> stopPlayback()
        }
    }

    /**
     * Watches for the phone going into a call while the adhan is playing.
     *
     * Audio focus alone is not enough here. The adhan is played on
     * USAGE_ALARM, and Android deliberately lets alarms keep sounding
     * through a call — that is the right behaviour for an alarm clock and
     * the wrong one for this. The audio mode says what the phone is doing
     * without needing READ_PHONE_STATE, so it is what this checks.
     */
    private val modeWatch = object : Runnable {
        override fun run() {
            if (inCall()) {
                stopPlayback()
                return
            }
            handler.postDelayed(this, MODE_POLL_MS)
        }
    }

    private fun audioManager() =
        getSystemService(Context.AUDIO_SERVICE) as AudioManager

    /** Whether a call is ringing or in progress. */
    private fun inCall(): Boolean = when (audioManager().mode) {
        AudioManager.MODE_IN_CALL,
        AudioManager.MODE_IN_COMMUNICATION,
        AudioManager.MODE_RINGTONE -> true
        else -> false
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopPlayback()
            return START_NOT_STICKY
        }

        val title = intent?.getStringExtra(EXTRA_TITLE) ?: "الأذان"
        val body = intent?.getStringExtra(EXTRA_BODY).orEmpty()
        val resName = intent?.getStringExtra(EXTRA_RES) ?: "adhan_call"

        startForegroundWithNotification(title, body)
        // Announced either way — a caller still wants to know the prayer
        // has come in — but the recording is not played over a call.
        if (inCall()) {
            postFallbackNotification(this, title, body)
            stopPlayback()
            return START_NOT_STICKY
        }
        play(resName)
        return START_NOT_STICKY
    }

    private fun play(resName: String) {
        stopPlayer()
        val resId = resources.getIdentifier(resName, "raw", packageName)
        if (resId == 0) {
            stopSelf()
            return
        }
        // Built by hand rather than with MediaPlayer.create(): create()
        // prepares the player itself, and setAudioAttributes must be called
        // *before* prepare — calling it afterwards throws, which took the
        // service down mid-start and left the adhan playing only as far as
        // the fallback notification sound got.
        try {
            val mp = MediaPlayer()
            mp.setAudioAttributes(
                AudioAttributes.Builder()
                    // ALARM, so the adhan is audible on the alarm stream
                    // even when the ringer is down — the same reasoning the
                    // notification channel used.
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                    .build()
            )
            // Without this the CPU is free to sleep while the screen is
            // off, which stops playback part way through — and prayer times
            // are exactly when the phone is sitting idle. WAKE_LOCK is
            // already declared for audio_service.
            mp.setWakeMode(applicationContext, PowerManager.PARTIAL_WAKE_LOCK)

            resources.openRawResourceFd(resId).use { afd ->
                mp.setDataSource(afd.fileDescriptor, afd.startOffset, afd.length)
            }
            mp.setOnCompletionListener { stopPlayback() }
            mp.setOnErrorListener { _, _, _ -> stopPlayback(); true }
            mp.prepare()

            requestAudioFocus()
            mp.start()
            isPlaying = true
            player = mp
            handler.postDelayed(modeWatch, MODE_POLL_MS)
            // A hard stop, in case the player never reports completion.
            // Nothing should reach this; the adhan running for ever with
            // no way to end it is bad enough to guard against anyway.
            handler.postDelayed({ stopPlayback() }, MAX_PLAYBACK_MS)
        } catch (e: Exception) {
            // A failure here used to escape onStartCommand and kill the
            // service, leaving a foreground notification with no audio.
            stopPlayback()
        }
    }

    /**
     * Asks for the alarm audio focus so other apps duck or pause instead of
     * playing over the adhan. Advisory — playback starts regardless, since
     * a refused request is no reason to skip the call to prayer.
     */
    private fun requestAudioFocus() {
        val manager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            focusRequest = AudioFocusRequest.Builder(
                AudioManager.AUDIOFOCUS_GAIN_TRANSIENT,
            ).setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                    .build()
            ).setOnAudioFocusChangeListener(focusListener)
                .build().also { manager.requestAudioFocus(it) }
        } else {
            @Suppress("DEPRECATION")
            manager.requestAudioFocus(
                focusListener,
                AudioManager.STREAM_ALARM,
                AudioManager.AUDIOFOCUS_GAIN_TRANSIENT,
            )
        }
    }

    private fun abandonAudioFocus() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            focusRequest?.let { audioManager().abandonAudioFocusRequest(it) }
            focusRequest = null
        } else {
            @Suppress("DEPRECATION")
            audioManager().abandonAudioFocus(focusListener)
        }
    }

    private fun stopPlayback() {
        stopPlayer()
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private fun stopPlayer() {
        isPlaying = false
        handler.removeCallbacksAndMessages(null)
        abandonAudioFocus()
        player?.let {
            if (it.isPlaying) it.stop()
            it.release()
        }
        player = null
    }

    override fun onDestroy() {
        stopPlayer()
        super.onDestroy()
    }


    private fun startForegroundWithNotification(title: String, body: String) {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            // No sound on this channel: the service is playing the audio
            // itself, and a channel sound here would talk over it.
            val channel = NotificationChannel(
                CHANNEL_ID,
                "الأذان",
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                setSound(null, null)
                enableVibration(false)
            }
            manager.createNotificationChannel(channel)
        }

        val open = packageManager.getLaunchIntentForPackage(packageName)
        val contentIntent = open?.let {
            PendingIntent.getActivity(
                this, 0, it,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }
        // Cancelled first, so a stale one from an earlier adhan cannot be
        // reused: FLAG_UPDATE_CURRENT keeps the original intent when only
        // its extras differ, and a stop button wired to a dead service is
        // a stop button that does nothing.
        val stopIntent = PendingIntent.getService(
            this,
            1,
            Intent(this, AdhanPlaybackService::class.java).setAction(ACTION_STOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )


        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(body)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setPriority(NotificationCompat.PRIORITY_HIGH)

            .setOngoing(true)
            .setSilent(true)
            .setContentIntent(contentIntent)
            // Three ways out, because "I could not stop it" was a real
            // report: the button, swiping the notification away, and the
            // stop control inside the app (see AdhanAlarmChannel.stop).
            .setDeleteIntent(stopIntent)
            .addAction(
                android.R.drawable.ic_menu_close_clear_cancel,
                "إيقاف الأذان",
                stopIntent,
            )
            .build()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    companion object {
        const val ACTION_STOP = "com.manassa.sheikhahmed.STOP_ADHAN"
        const val EXTRA_TITLE = "title"
        const val EXTRA_BODY = "body"
        const val EXTRA_RES = "res"

        private const val CHANNEL_ID = "com.sheikhahmed.sheikh_ahmed_app.adhan_playback"
        private const val NOTIFICATION_ID = 4100

        /** How often the audio mode is checked while the adhan plays. */
        private const val MODE_POLL_MS = 1_000L

        /** Longer than any adhan; a backstop, not a timeout. */
        private const val MAX_PLAYBACK_MS = 10 * 60 * 1_000L

        /**
         * Whether the adhan is sounding right now.
         *
         * Read over the method channel so the app can tell that the service
         * already has the adhan in hand. Without it the app has no way to
         * know, and its own in-app player starts a second copy over the top
         * — two adhans at once, each with its own stop control.
         */
        @Volatile
        var isPlaying = false
            private set

        /** Stops the adhan from anywhere in the app. */
        fun stop(context: Context) {
            context.startService(
                Intent(context, AdhanPlaybackService::class.java)
                    .setAction(ACTION_STOP),
            )
        }

        private const val FALLBACK_CHANNEL_ID =
            "com.sheikhahmed.sheikh_ahmed_app.adhan_fallback"
        private const val FALLBACK_NOTIFICATION_ID = 4101

        /**
         * Announces the prayer with an ordinary notification, for when the
         * service itself could not be started (see [AdhanAlarmReceiver]).
         *
         * Deliberately its own channel rather than [CHANNEL_ID]: that one is
         * silent by design because the service supplies the audio, and a
         * channel's sound is fixed permanently when it is created. Reusing it
         * here would post a notification nobody ever hears.
         */
        fun postFallbackNotification(context: Context, title: String?, body: String?) {
            val manager = context.getSystemService(Context.NOTIFICATION_SERVICE)
                as NotificationManager
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                manager.createNotificationChannel(
                    NotificationChannel(
                        FALLBACK_CHANNEL_ID,
                        "تنبيه الصلاة",
                        NotificationManager.IMPORTANCE_HIGH,
                    ),
                )
            }
            val open = context.packageManager
                .getLaunchIntentForPackage(context.packageName)
            val contentIntent = open?.let {
                PendingIntent.getActivity(
                    context, 0, it,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
                )
            }
            manager.notify(
                FALLBACK_NOTIFICATION_ID,
                NotificationCompat.Builder(context, FALLBACK_CHANNEL_ID)
                    .setSmallIcon(R.mipmap.ic_launcher)
                    .setContentTitle(title)
                    .setContentText(body)
                    .setCategory(NotificationCompat.CATEGORY_ALARM)
                    .setPriority(NotificationCompat.PRIORITY_HIGH)
                    .setAutoCancel(true)
                    .setContentIntent(contentIntent)
                    .build(),
            )
        }
    }
}
