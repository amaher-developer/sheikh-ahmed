import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

/// Wraps a single `just_audio` player and broadcasts its state through
/// `audio_service` — this is what makes playback survive backgrounding and
/// puts real controls (play/pause/skip/stop) on the lock screen and system
/// notification, not just inside the app's own UI. The notification's icon
/// and title come from `AudioServiceConfig`/each `MediaItem` respectively
/// (see main.dart), so it already reads as "this app playing something",
/// not a generic system player.
class QuranAudioHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer _player = AudioPlayer();

  /// When set, called with the just-finished [MediaItem] once playback
  /// reaches [ProcessingState.completed]; a non-null result is loaded and
  /// played immediately, so e.g. Quran surahs can advance one after another
  /// without the user tapping play again. Also what [skipToNext] uses for
  /// the notification's "next" button. Callers are responsible for
  /// clearing this when switching to content that shouldn't
  /// skip/auto-advance (e.g. radio stations) — see `playSurahWithAutoAdvance`
  /// and `RadioScreen`'s play calls.
  Future<MediaItem?> Function(MediaItem finished)? nextItemResolver;

  /// Same idea as [nextItemResolver], for the notification's "previous"
  /// button — there's no natural "playback reached the start" event to
  /// hook this to, so it's only ever driven by [skipToPrevious].
  Future<MediaItem?> Function(MediaItem current)? previousItemResolver;

  QuranAudioHandler() {
    _player.playbackEventStream.map(_transformEvent).pipe(playbackState);
    _player.processingStateStream.listen((state) async {
      if (state != ProcessingState.completed) return;
      final resolver = nextItemResolver;
      final finished = mediaItem.value;
      if (resolver == null || finished == null) return;
      final next = await resolver(finished);
      if (next != null) await playMediaItem(next);
    });
  }

  /// Switches to a new station/surah and starts playing it, updating the
  /// notification's title/artist immediately. This is `AudioHandler`'s own
  /// designated extension point for "load and play a specific item" (its
  /// `BaseAudioHandler` default is a no-op) — not a name collision.
  @override
  Future<void> playMediaItem(MediaItem item) async {
    mediaItem.add(item);
    // setUrl handles http(s) and file://; a bundled asset needs setAsset.
    // The adhan voices are all streamed except the Rifaat recording, which
    // ships with the app because it has no CDN to stream from.
    if (item.id.startsWith('asset:///')) {
      await _player.setAsset(item.id.substring('asset:///'.length));
    } else if (_isLocalFilePath(item.id)) {
      // A downloaded surah's id is its bare path on disk. Android plays that
      // through setUrl, but iOS only treats a file:// URI as a local file and
      // reads anything else as a web address, so there every downloaded
      // surah failed to play. setFilePath adds the scheme.
      await _player.setFilePath(item.id);
    } else {
      await _setUrlRetryingOnce(item);
    }
    await play();
  }

  /// Whether [id] is a path on disk rather than a URL — see [playMediaItem].
  static bool _isLocalFilePath(String id) => id.startsWith('/');

  /// Loads a stream, trying once more if the server refuses it.
  ///
  /// Stream hosts sometimes answer with a transient HTTP 500 — mp3quran's
  /// backup.qurango.net did for two to five requests in every ten when
  /// measured, with the next request playing fine — which reached the
  /// listener as a playback error on a station that works. One retry absorbs
  /// that. It is skipped once the listener has moved on to something else,
  /// and an interrupted load (replaced by a newer one) throws a different
  /// exception and is never retried.
  Future<void> _setUrlRetryingOnce(MediaItem item) async {
    try {
      await _player.setUrl(item.id);
    } on PlayerException {
      if (mediaItem.value?.id != item.id) rethrow;
      await Future<void>.delayed(const Duration(milliseconds: 700));
      if (mediaItem.value?.id != item.id) rethrow;
      await _player.setUrl(item.id);
    }
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  /// Backs the notification's "next" button — e.g. the next surah for the
  /// currently selected reciter. A no-op when [nextItemResolver] isn't
  /// set (radio has nothing meaningful to skip to), so the button simply
  /// doesn't appear (see [_transformEvent]) rather than doing nothing.
  @override
  Future<void> skipToNext() async {
    final resolver = nextItemResolver;
    final current = mediaItem.value;
    if (resolver == null || current == null) return;
    final next = await resolver(current);
    if (next != null) await playMediaItem(next);
  }

  /// Backs the notification's "previous" button — see [skipToNext].
  @override
  Future<void> skipToPrevious() async {
    final resolver = previousItemResolver;
    final current = mediaItem.value;
    if (resolver == null || current == null) return;
    final previous = await resolver(current);
    if (previous != null) await playMediaItem(previous);
  }

  // Deliberately not calling super.stop(): playbackState is already
  // continuously fed by the playbackEventStream pipe set up in the
  // constructor, and that pipe's own addStream conflicts with a second,
  // manual playbackState.add() from BaseAudioHandler's default — rxdart
  // throws "cannot add items while items are being added from addStream".
  // Stopping the player alone still flows through the pipe correctly.
  @override
  Future<void> stop() => _player.stop();

  PlaybackState _transformEvent(PlaybackEvent event) {
    // Previous/next only show up when there's somewhere to go — radio
    // stations (no resolvers set) get a plain play/pause/stop notification
    // instead of skip buttons that would silently do nothing.
    final controls = [
      if (previousItemResolver != null) MediaControl.skipToPrevious,
      if (_player.playing) MediaControl.pause else MediaControl.play,
      if (nextItemResolver != null) MediaControl.skipToNext,
      MediaControl.stop,
    ];
    return PlaybackState(
      controls: controls,
      systemActions: const {MediaAction.seek},
      // The notification's compact (collapsed) view shows at most 3
      // actions — always the first three of the list above, which is
      // previous/play-pause/next when both resolvers are set, or
      // play-pause/stop (plus whichever skip button is set) otherwise.
      androidCompactActionIndices: [
        for (var i = 0; i < controls.length && i < 3; i++) i,
      ],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState]!,
      playing: _player.playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: event.currentIndex,
    );
  }
}
