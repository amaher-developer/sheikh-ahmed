import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'audio_download_providers.dart';
import 'audio_download_service.dart';
import 'mushaf_page_service.dart';
import 'mushaf_providers.dart';
import 'quran_providers.dart';
import 'reciter_data.dart';
import 'surah_meta.dart';

/// Progress of a "download the whole Quran" run.
///
/// Separate from [downloadProgressProvider], which tracks one surah at a
/// time for the per-row rings: this is the run as a whole, so the UI can
/// show "31 of 114" and a cancel button while it works through the list.
class BulkDownloadState {
  final bool running;

  /// Surahs finished in this run — not the total downloaded overall, since
  /// a run skips whatever is already on disk.
  final int completed;

  /// How many this run set out to fetch.
  final int total;

  /// The surah being fetched right now, for a live label.
  final int? currentSurah;

  /// Set when a surah fails. The run keeps going regardless — one bad
  /// download shouldn't abandon the other hundred — and this surfaces
  /// afterwards so the user knows to retry.
  final int failures;

  /// How far through the *current* surah, 0..1.
  ///
  /// Surah count alone is a poor progress signal here: al-Baqara is around
  /// 115 MB, so a bar that only moves once a whole surah lands sits
  /// motionless for many minutes and the download looks hung.
  final double fileProgress;

  const BulkDownloadState({
    this.running = false,
    this.completed = 0,
    this.total = 0,
    this.currentSurah,
    this.failures = 0,
    this.fileProgress = 0,
  });

  double get progress => total == 0 ? 0 : (completed / total).clamp(0.0, 1.0);

  BulkDownloadState copyWith({
    bool? running,
    int? completed,
    int? total,
    int? currentSurah,
    bool clearCurrent = false,
    int? failures,
    double? fileProgress,
  }) => BulkDownloadState(
    running: running ?? this.running,
    completed: completed ?? this.completed,
    total: total ?? this.total,
    currentSurah: clearCurrent ? null : (currentSurah ?? this.currentSurah),
    failures: failures ?? this.failures,
    fileProgress: fileProgress ?? this.fileProgress,
  );
}

class BulkDownloadNotifier extends StateNotifier<BulkDownloadState> {
  final Ref _ref;
  DownloadCancelToken? _token;

  BulkDownloadNotifier(this._ref) : super(const BulkDownloadState());

  /// Surahs of [reciter] not yet on disk.
  List<int> _pending(Reciter reciter) {
    final downloaded = _ref.read(downloadedSurahsProvider);
    return [
      for (final surah in kAllSurahs)
        if (!downloaded.contains('${reciter.id}:${surah.number}')) surah.number,
    ];
  }

  int remainingFor(Reciter reciter) => _pending(reciter).length;

  /// Fetches every surah still missing, one at a time.
  ///
  /// Sequential on purpose: a hundred-odd parallel requests would saturate
  /// the connection, and a partially-written file on a dropped connection
  /// is exactly what the service's .part-then-rename already guards
  /// against per surah.
  Future<void> start(Reciter reciter) async {
    if (state.running) return;
    final pending = _pending(reciter);
    if (pending.isEmpty) return;

    final token = _token = DownloadCancelToken();
    state = BulkDownloadState(running: true, total: pending.length);

    final downloads = _ref.read(downloadedSurahsProvider.notifier);
    for (final surahNumber in pending) {
      if (token.isCancelled) break;
      state = state.copyWith(currentSurah: surahNumber, fileProgress: 0);
      try {
        await downloads.download(
          reciter,
          surahNumber,
          // Throttled to whole percent. The callback fires per network
          // chunk — thousands of times for a 115 MB surah — and every one
          // of those would otherwise rebuild the card.
          onProgress: (p) {
            if ((p - state.fileProgress).abs() < 0.01) return;
            state = state.copyWith(fileProgress: p);
          },
          cancelToken: token,
        );
        state = state.copyWith(
          completed: state.completed + 1,
          fileProgress: 0,
        );
      } catch (_) {
        // A cancelled surah is not a failed one — counting it would tell the
        // user something needs retrying when they are the one who stopped it.
        if (token.isCancelled) break;
        // Otherwise keep going: one unreachable surah shouldn't end the run.
        state = state.copyWith(failures: state.failures + 1);
      }
    }

    // Only the current run may write the terminal state. Cancelling frees the
    // button immediately, so the user can start a new run while this loop is
    // still unwinding — and without this guard the old loop would then reach
    // here and mark the *new* run as finished.
    if (!identical(_token, token)) return;
    _token = null;
    state = state.copyWith(running: false, clearCurrent: true);
  }

  /// Aborts the transfer in progress, not just the queue.
  ///
  /// The state flips to stopped here rather than waiting for [start]'s loop to
  /// notice, so the button responds on the tap instead of staying stuck on
  /// "cancelling" until the current surah finishes downloading.
  void cancel() {
    _token?.cancel();
    if (!state.running) return;
    state = state.copyWith(running: false, clearCurrent: true);
  }
}

final bulkDownloadProvider =
    StateNotifierProvider<BulkDownloadNotifier, BulkDownloadState>((ref) {
      return BulkDownloadNotifier(ref);
    });

/// How many surahs are on disk for [reciter], for the "114 / 114" readout.
int downloadedCountFor(Set<String> downloaded, Reciter reciter) {
  final prefix = '${reciter.id}:';
  return downloaded.where((k) => k.startsWith(prefix)).length;
}

/// Which part of the offline Mus'haf a run is working on.
enum OfflineStage {
  idle,

  /// The app's own Uthmani text, 114 surahs.
  ///
  /// Needed even though the printed page is what gets drawn: the reader
  /// loads a surah before it can show any of its pages, and everything a
  /// tap on the page opens — tafsir, word-by-word, play from here — is
  /// keyed off that text. Without it an offline reader gets the retry
  /// screen and never reaches a page at all.
  text,

  /// The 604 printed pages: each page's glyph layout and its own font.
  ///
  /// This is what was missing. Downloading only the text left the reader
  /// with nothing to draw the printed page from, so going offline fell
  /// back to the plain text layout — which is what "it shows the old
  /// version" was.
  pages,
}

/// Progress of a "make the Mus'haf work offline" run.
///
/// Separate from the audio run because the two are worth doing
/// independently: the Mus'haf is around 75 MB and makes the *reader* work
/// with no connection, while the recitations are hundreds of megabytes and
/// make *listening* work. Someone on a small data plan may well want the
/// first and not the second.
class TextDownloadState {
  final bool running;
  final OfflineStage stage;

  /// Done and expected within the stage currently running.
  final int completed;
  final int total;

  final int failures;

  /// What is on this device already, across all past runs — not just this
  /// one. [completed] counts the current run and resets, so it cannot
  /// answer "have I downloaded this yet?" after a restart.
  final int cachedSurahs;
  final int cachedPages;

  const TextDownloadState({
    this.running = false,
    this.stage = OfflineStage.idle,
    this.completed = 0,
    this.total = 0,
    this.failures = 0,
    this.cachedSurahs = 0,
    this.cachedPages = 0,
  });

  double get progress => total == 0 ? 0 : (completed / total).clamp(0.0, 1.0);

  /// True only when both halves are stored. The text alone is not enough —
  /// that is exactly the state that looked complete and then showed the
  /// wrong Mus'haf with the connection off.
  bool get isComplete =>
      cachedSurahs >= kAllSurahs.length &&
      cachedPages >= MushafPageService.totalPages;

  /// How far through the whole job, counting both stages by their real
  /// sizes rather than treating the two as halves.
  double get overallProgress {
    const totalUnits = 114 + MushafPageService.totalPages;
    return ((cachedSurahs + cachedPages) / totalUnits).clamp(0.0, 1.0);
  }

  TextDownloadState copyWith({
    bool? running,
    OfflineStage? stage,
    int? completed,
    int? total,
    int? failures,
    int? cachedSurahs,
    int? cachedPages,
  }) => TextDownloadState(
    running: running ?? this.running,
    stage: stage ?? this.stage,
    completed: completed ?? this.completed,
    total: total ?? this.total,
    failures: failures ?? this.failures,
    cachedSurahs: cachedSurahs ?? this.cachedSurahs,
    cachedPages: cachedPages ?? this.cachedPages,
  );
}

class TextDownloadNotifier extends StateNotifier<TextDownloadState> {
  final Ref _ref;
  bool _cancelled = false;

  TextDownloadNotifier(this._ref) : super(const TextDownloadState()) {
    refreshCached();
  }

  /// Re-reads what is on disk. Called on construction so the card shows the
  /// true state on a cold start, and as the run proceeds so it climbs live.
  Future<void> refreshCached() async {
    final surahs = _ref.read(quranTextServiceProvider).cachedSurahCount();
    final pages = await _readyPageCount();
    if (!mounted) return;
    state = state.copyWith(cachedSurahs: surahs, cachedPages: pages);
  }

  /// Pages that have **both** halves stored.
  ///
  /// A page needs its glyph layout and its own font, and either alone
  /// renders nothing — layout without the font is a row of empty boxes.
  /// Counting them separately would report a Mus'haf as ready that cannot
  /// actually be read.
  Future<int> _readyPageCount() async {
    try {
      final data = await _ref.read(mushafPageServiceProvider).cachedPages();
      final fonts = await _ref.read(mushafFontServiceProvider).downloadedPages();
      return data.intersection(fonts).length;
    } catch (_) {
      // No storage yet, or none readable: nothing is downloaded.
      return 0;
    }
  }

  /// Fetches everything the reader needs to work with no connection.
  ///
  /// Both stages go through the ordinary read paths, which already write
  /// what they fetch and serve it from disk afterwards. So asking for all
  /// of it *is* the download, anything already stored returns without a
  /// request, and an interrupted run resumes by simply starting again.
  Future<void> start() async {
    if (state.running) return;
    _cancelled = false;

    await _downloadText();
    if (!_cancelled) await _downloadPages();

    if (!mounted) return;
    state = state.copyWith(running: false, stage: OfflineStage.idle);
    await refreshCached();
  }

  Future<void> _downloadText() async {
    state = state.copyWith(
      running: true,
      stage: OfflineStage.text,
      completed: 0,
      total: kAllSurahs.length,
      failures: 0,
    );

    final service = _ref.read(quranTextServiceProvider);
    for (final surah in kAllSurahs) {
      if (_cancelled || !mounted) return;
      try {
        await service.fetchSurah(surah.number);
        state = state.copyWith(
          completed: state.completed + 1,
          cachedSurahs: service.cachedSurahCount(),
        );
      } catch (_) {
        // One unreachable surah should not end the run.
        state = state.copyWith(failures: state.failures + 1);
      }
    }
  }

  Future<void> _downloadPages() async {
    final pageService = _ref.read(mushafPageServiceProvider);
    final fontService = _ref.read(mushafFontServiceProvider);

    state = state.copyWith(
      running: true,
      stage: OfflineStage.pages,
      completed: 0,
      total: MushafPageService.totalPages,
    );

    var ready = state.cachedPages;
    for (var page = 1; page <= MushafPageService.totalPages; page++) {
      if (_cancelled || !mounted) return;
      try {
        // Sequential, and layout before font: a page whose font arrived
        // but whose layout did not is not a page, and doing them in this
        // order means a run stopped part-way leaves only whole pages
        // behind plus at most one half-finished one.
        await pageService.fetchPage(page);
        await fontService.download(page);
        ready++;
        state = state.copyWith(
          completed: state.completed + 1,
          cachedPages: ready,
        );
      } catch (_) {
        state = state.copyWith(
          completed: state.completed + 1,
          failures: state.failures + 1,
        );
      }
    }
  }

  void cancel() {
    _cancelled = true;
    if (!state.running) return;
    state = state.copyWith(running: false, stage: OfflineStage.idle);
  }
}

final textDownloadProvider =
    StateNotifierProvider<TextDownloadNotifier, TextDownloadState>((ref) {
      return TextDownloadNotifier(ref);
    });
