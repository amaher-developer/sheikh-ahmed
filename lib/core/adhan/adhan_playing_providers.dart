import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../audio/audio_providers.dart';
import '../prayer/prayer_providers.dart';
import 'adhan_alarm_channel.dart';

/// How long after a prayer the adhan could still be sounding.
///
/// The recordings run three to four minutes; this leaves room either side
/// rather than cutting the stop button while the call is still audible.
const _adhanWindow = Duration(minutes: 8);

/// Whether the adhan is sounding right now, from either player.
///
/// Polled rather than pushed: the sound comes from a native foreground
/// service that has no callback into Dart, and the app needs to know so it
/// can offer a way to stop it.
///
/// Polling only runs inside [_adhanWindow] after a prayer. Outside it this
/// reports false without touching the platform channel, so the ordinary case
/// — the twenty-three hours a day when no adhan is due — costs nothing.
final adhanPlayingProvider = StreamProvider<bool>((ref) async* {
  final next = ref.watch(nextPrayerProvider);
  final sinceDue = next.now.difference(next.windowStart);

  if (sinceDue.isNegative || sinceDue > _adhanWindow) {
    yield false;
    return;
  }

  yield await AdhanAlarmChannel.isPlaying();
  yield* Stream.periodic(const Duration(seconds: 2))
      .asyncMap((_) => AdhanAlarmChannel.isPlaying());
});

/// Stops the adhan, whichever player is sounding it.
///
/// Both are asked unconditionally. There are two — the native service woken
/// by the alarm, and the in-app player used when exact alarms are refused —
/// and stopping only the one that is *believed* to be playing is how a
/// half-stopped adhan happens. Neither call is harmful when idle.
Future<void> stopAdhan(WidgetRef ref) async {
  await AdhanAlarmChannel.stop();
  try {
    await ref.read(audioHandlerProvider).stop();
  } catch (_) {
    // Nothing playing through the handler.
  }
}
