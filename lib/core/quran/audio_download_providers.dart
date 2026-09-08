import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'audio_download_service.dart';
import 'reciter_data.dart';

final audioDownloadServiceProvider = Provider<AudioDownloadService>(
  (ref) => const AudioDownloadService(),
);

/// In-progress download percentage (0..1) keyed by "reciterId:surahNumber"
/// — a key absent from this map means nothing is currently downloading for
/// that surah/reciter. Drives the per-surah progress ring in the UI.
final downloadProgressProvider =
    StateProvider<Map<String, double>>((ref) => {});

/// Tracks which (reciter, surah) pairs are downloaded for offline
/// playback, and resolves their local file path synchronously once the
/// app's documents directory has been read (see [cachedLocalPath]) — so
/// playback call sites never need to await a filesystem check just to
/// decide whether to stream or play a local file.
class DownloadedSurahsNotifier extends StateNotifier<Set<String>> {
  final AudioDownloadService _service;
  String? _docsPath;

  DownloadedSurahsNotifier(this._service) : super({}) {
    _init();
  }

  Future<void> _init() async {
    _docsPath = await _service.docsPath();
    state = await _service.scanDownloaded();
  }

  String _key(String reciterId, int surahNumber) => '$reciterId:$surahNumber';

  bool isDownloaded(Reciter reciter, int surahNumber) =>
      state.contains(_key(reciter.id, surahNumber));

  String? cachedLocalPath(Reciter reciter, int surahNumber) {
    final docsPath = _docsPath;
    if (docsPath == null || !isDownloaded(reciter, surahNumber)) return null;
    return AudioDownloadService.buildPath(docsPath, reciter.id, surahNumber);
  }

  Future<void> download(
    Reciter reciter,
    int surahNumber, {
    required void Function(double progress) onProgress,
    DownloadCancelToken? cancelToken,
  }) async {
    await _service.download(
      reciter,
      surahNumber,
      onProgress: onProgress,
      cancelToken: cancelToken,
    );
    state = {...state, _key(reciter.id, surahNumber)};
  }

  Future<void> delete(Reciter reciter, int surahNumber) async {
    await _service.delete(reciter, surahNumber);
    state = {...state}..remove(_key(reciter.id, surahNumber));
  }
}

final downloadedSurahsProvider =
    StateNotifierProvider<DownloadedSurahsNotifier, Set<String>>((ref) {
      return DownloadedSurahsNotifier(ref.watch(audioDownloadServiceProvider));
    });

/// Downloads [surahNumber] for [reciter], reporting progress through
/// [downloadProgressProvider] so any widget watching that key updates live
/// without each surah row needing its own provider.
Future<void> downloadSurah(WidgetRef ref, Reciter reciter, int surahNumber) async {
  final key = '${reciter.id}:$surahNumber';
  void setProgress(double? value) {
    final current = {...ref.read(downloadProgressProvider)};
    if (value == null) {
      current.remove(key);
    } else {
      current[key] = value;
    }
    ref.read(downloadProgressProvider.notifier).state = current;
  }

  setProgress(0);
  try {
    await ref
        .read(downloadedSurahsProvider.notifier)
        .download(reciter, surahNumber, onProgress: setProgress);
  } finally {
    setProgress(null);
  }
}
