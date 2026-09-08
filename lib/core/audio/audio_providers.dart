import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'quran_audio_handler.dart';

/// Overridden in main() with the handler returned by `AudioService.init()`
/// — that init call must happen before runApp, so the handler is built
/// once at startup and threaded in here rather than created by a plain
/// Provider body.
final audioHandlerProvider = Provider<QuranAudioHandler>((ref) {
  throw UnimplementedError(
    'audioHandlerProvider must be overridden in main() after AudioService.init()',
  );
});

/// Live playback state (playing/paused/buffering) — reflects the *real*
/// audio_service state, so it updates from lock-screen/notification button
/// presses too, not just in-app taps.
final playbackStateProvider = StreamProvider<PlaybackState>((ref) {
  final handler = ref.watch(audioHandlerProvider);
  return handler.playbackState;
});

/// The currently loaded station/surah (id = its URL), or null if nothing
/// has played yet this session.
final currentMediaItemProvider = StreamProvider<MediaItem?>((ref) {
  final handler = ref.watch(audioHandlerProvider);
  return handler.mediaItem;
});

/// Loads [item] if it isn't already the active one, then toggles play/pause.
/// Shared by RadioScreen and QuranScreen so both use identical play logic.
Future<void> toggleAudio(WidgetRef ref, MediaItem item) async {
  final handler = ref.read(audioHandlerProvider);
  final current = handler.mediaItem.valueOrNull;

  if (current?.id == item.id) {
    if (handler.playbackState.valueOrNull?.playing ?? false) {
      await handler.pause();
    } else {
      await handler.play();
    }
    return;
  }

  await handler.playMediaItem(item);
}

/// Always switches to [item] and starts playing it, regardless of what was
/// previously loaded — used for "skip to next/previous station" where the
/// intent is never "toggle," only "play this one now."
Future<void> playMediaItem(WidgetRef ref, MediaItem item) async {
  await ref.read(audioHandlerProvider).playMediaItem(item);
}
