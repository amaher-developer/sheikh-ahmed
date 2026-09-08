import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the contract between AdhanAlarmReceiver and the Dart scheduler.
///
/// The Dart side cancels its own notification-path adhan whenever the native
/// schedule call reports success, so "success" has to mean the alarms can
/// really play the adhan — not merely that something was registered.
void main() {
  final receiver = File(
    'android/app/src/main/kotlin/com/sheikhahmed/sheikh_ahmed_app/'
    'AdhanAlarmReceiver.kt',
  ).readAsStringSync();
  final activity = File(
    'android/app/src/main/kotlin/com/sheikhahmed/sheikh_ahmed_app/'
    'MainActivity.kt',
  ).readAsStringSync();

  test('adhan alarms are never downgraded to setAndAllowWhileIdle', () {
    // The tempting fix when exact alarms are unavailable, and the reason the
    // adhan went silent: an inexact alarm still fires, but it is not one of
    // the exemptions that allow starting a foreground service from the
    // background on Android 12+, so onReceive is blocked and nothing plays.
    // Meanwhile the Dart side has already dropped the notification fallback.
    expect(
      // A call, not a mention: the comment above the guard in that
      // file names the method precisely because it is the trap to avoid.
      receiver.contains('.setAndAllowWhileIdle('),
      isFalse,
      reason: 'an inexact adhan alarm cannot start the playback service',
    );
  });

  test('schedule() reports whether the alarms were really registered', () {
    expect(receiver.contains('): Boolean {'), isTrue);
    expect(receiver.contains('return false'), isTrue);
  });

  test('MainActivity forwards that result instead of always claiming true', () {
    final call = activity.substring(activity.indexOf('"scheduleAdhanAlarms"'));
    // Cut at the next case rather than at a named one: other cases are added
    // between them over time, and a fixed end marker silently widens this
    // slice to cover their bodies too.
    final nextCase = RegExp(r'"\w+" ->').allMatches(call).elementAt(1).start;
    final body = call.substring(0, nextCase);
    expect(
      body.contains('result.success(true)'),
      isFalse,
      reason: 'hardcoding true makes Dart cancel its working fallback',
    );
    expect(body.contains('AdhanAlarmReceiver.schedule'), isTrue);
  });

  test('the narrowed slice still catches a hardcoded true', () {
    // The slice is computed, so it is worth proving it still covers the case
    // it exists for rather than trusting that it does.
    const sample = '''
                    "scheduleAdhanAlarms" -> {
                        AdhanAlarmReceiver.schedule(this)
                        result.success(true)
                    }
                    "stopAdhan" -> { result.success(true) }
''';
    final call = sample.substring(sample.indexOf('"scheduleAdhanAlarms"'));
    final nextCase = RegExp(r'"\w+" ->').allMatches(call).elementAt(1).start;
    expect(call.substring(0, nextCase).contains('result.success(true)'), isTrue);
  });

  group('the adhan yields to a call', () {
    final service = File(
      'android/app/src/main/kotlin/com/sheikhahmed/sheikh_ahmed_app/'
      'AdhanPlaybackService.kt',
    ).readAsStringSync();

    test('the focus request carries a listener', () {
      // It was built without one, which is why the adhan carried on over an
      // incoming call: with no listener the system has nowhere to deliver
      // the loss, so the service never learned anything had happened.
      expect(service.contains('setOnAudioFocusChangeListener'), isTrue);
      expect(
        service.contains('AudioManager.OnAudioFocusChangeListener'),
        isTrue,
      );
    });

    test('losing focus stops the adhan rather than pausing it', () {
      // A call outlasts the adhan. Resuming three minutes of الله أكبر when
      // the call ends is not what anyone wants.
      final listener = service.substring(
        service.indexOf('AudioManager.OnAudioFocusChangeListener'),
        service.indexOf('private val modeWatch'),
      );
      expect(listener.contains('AUDIOFOCUS_LOSS_TRANSIENT'), isTrue);
      expect(listener.contains('stopPlayback()'), isTrue);
      expect(listener.contains('mp.pause()'), isFalse);
    });

    test('the audio mode is watched too, not only focus', () {
      // The adhan plays on USAGE_ALARM, and Android deliberately lets
      // alarms sound through a call — so focus alone would never fire.
      expect(service.contains('AudioManager.MODE_IN_CALL'), isTrue);
      expect(service.contains('AudioManager.MODE_IN_COMMUNICATION'), isTrue);
      expect(service.contains('AudioManager.MODE_RINGTONE'), isTrue);
      // Checked repeatedly while playing, not only once at the start: the
      // call usually arrives after the adhan has already begun.
      expect(service.contains('handler.postDelayed(modeWatch'), isTrue);
    });

    test('a prayer arriving mid-call is announced but not played', () {
      final start = service.substring(
        service.indexOf('override fun onStartCommand'),
        service.indexOf('private fun play('),
      );
      expect(start.contains('if (inCall())'), isTrue);
      expect(start.contains('postFallbackNotification'), isTrue);
    });

    test('no permission is required to know about the call', () {
      // READ_PHONE_STATE would put a phone-permission prompt in front of
      // every user of a prayer-times app, and Play asks about it besides.
      final manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();
      expect(manifest.contains('READ_PHONE_STATE'), isFalse);
      expect(service.contains('TelephonyManager'), isFalse);
    });

    test('there is more than one way to stop it', () {
      // "I could not stop it or close it" was a real report. The button,
      // swiping the notification away, and the control inside the app.
      expect(service.contains('.setDeleteIntent(stopIntent)'), isTrue);
      expect(service.contains('.addAction('), isTrue);
      expect(service.contains('fun stop(context: Context)'), isTrue);
    });

    test('it cannot play for ever, whatever happens to the player', () {
      expect(service.contains('MAX_PLAYBACK_MS'), isTrue);
    });

    test('every watcher is cancelled when playback ends', () {
      // A polling Runnable left behind would go on waking the phone once a
      // second after the service was gone.
      final stop = service.substring(
        service.indexOf('private fun stopPlayer()'),
        service.indexOf('override fun onDestroy()'),
      );
      expect(stop.contains('handler.removeCallbacksAndMessages(null)'), isTrue);
      expect(stop.contains('abandonAudioFocus()'), isTrue);
    });
  });
}
