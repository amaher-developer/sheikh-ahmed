import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the fix for two adhans sounding at once.
///
/// There are two players — the native foreground service woken by the alarm,
/// and the in-app player used when exact alarms are refused. Both being able
/// to run at the same time is what made the adhan impossible to stop: each
/// had its own separate stop control.
void main() {
  final watcher = File('lib/core/adhan/adhan_watcher.dart').readAsStringSync();
  final channel =
      File('lib/core/adhan/adhan_alarm_channel.dart').readAsStringSync();
  final service = File(
    'android/app/src/main/kotlin/com/sheikhahmed/sheikh_ahmed_app/'
    'AdhanPlaybackService.kt',
  ).readAsStringSync();
  final activity = File(
    'android/app/src/main/kotlin/com/sheikhahmed/sheikh_ahmed_app/'
    'MainActivity.kt',
  ).readAsStringSync();

  test('the in-app player checks the service before starting', () {
    // Without this, opening the app during the adhan starts a second copy:
    // the watcher state is new on every launch, so its "already played" mark
    // is empty while the prayer is still inside the two-minute window.
    final call = watcher.indexOf('AdhanAlarmChannel.isPlaying()');
    final play = watcher.indexOf('playAdhan(');
    expect(call, isNot(-1), reason: 'the watcher must ask before playing');
    expect(
      call < play,
      isTrue,
      reason: 'the check has to come before playback, not after',
    );
  });

  test('the check short-circuits playback rather than only logging', () {
    expect(
      watcher.contains('if (await AdhanAlarmChannel.isPlaying()) return;'),
      isTrue,
    );
  });

  test('the app can stop the service without the notification', () {
    expect(channel.contains("invokeMethod<bool>('stopAdhan')"), isTrue);
    expect(channel.contains("invokeMethod<bool>('isAdhanPlaying')"), isTrue);
    expect(activity.contains('"stopAdhan"'), isTrue);
    expect(activity.contains('"isAdhanPlaying"'), isTrue);
  });

  test('the service reports and clears its playing state', () {
    // isPlaying has to be cleared on every stop path, or the stop bar sticks
    // around after the adhan has finished.
    expect(service.contains('var isPlaying = false'), isTrue);
    expect(service.contains('isPlaying = true'), isTrue);
    final stopPlayer = service.substring(service.indexOf('fun stopPlayer()'));
    expect(
      stopPlayer.substring(0, stopPlayer.indexOf('}')).contains('isPlaying = false'),
      isTrue,
      reason: 'stopPlayer is the single path every stop goes through',
    );
  });
}
