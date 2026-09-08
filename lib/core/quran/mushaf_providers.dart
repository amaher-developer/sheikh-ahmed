import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../prayer/prayer_providers.dart' show sharedPreferencesProvider;
import 'mushaf_font_service.dart';
import 'mushaf_page_data.dart';
import 'mushaf_page_service.dart';

final mushafFontServiceProvider = Provider<MushafFontService>((ref) {
  return MushafFontService();
});

final mushafPageServiceProvider = Provider<MushafPageService>((ref) {
  return MushafPageService(ref.watch(sharedPreferencesProvider));
});

/// The glyph layout of one page.
final mushafPageProvider = FutureProvider.family<MushafPageData, int>((
  ref,
  page,
) {
  return ref.watch(mushafPageServiceProvider).fetchPage(page);
});

/// That page's font, registered with the engine.
///
/// Kept as its own provider rather than folded into [mushafPageProvider] so
/// the two fetches run in parallel — they are independent, and a page needs
/// both before it can draw anything.
final mushafFontProvider = FutureProvider.family<void, int>((ref, page) {
  return ref.watch(mushafFontServiceProvider).ensureLoaded(page);
});

/// Progress of a "download the whole Mus'haf" run — the 604 page fonts.
class MushafDownloadState {
  final bool running;
  final int completed;
  final int total;
  final int failures;

  /// Page fonts already on disk across all runs, so the card can answer
  /// "have I got this already?" after a restart.
  final int cachedCount;

  const MushafDownloadState({
    this.running = false,
    this.completed = 0,
    this.total = 0,
    this.failures = 0,
    this.cachedCount = 0,
  });

  double get progress => total == 0 ? 0 : (completed / total).clamp(0.0, 1.0);

  MushafDownloadState copyWith({
    bool? running,
    int? completed,
    int? total,
    int? failures,
    int? cachedCount,
  }) => MushafDownloadState(
    running: running ?? this.running,
    completed: completed ?? this.completed,
    total: total ?? this.total,
    failures: failures ?? this.failures,
    cachedCount: cachedCount ?? this.cachedCount,
  );
}

class MushafDownloadNotifier extends StateNotifier<MushafDownloadState> {
  final Ref _ref;
  bool _cancelled = false;

  MushafDownloadNotifier(this._ref) : super(const MushafDownloadState()) {
    refreshCached();
  }

  Future<void> refreshCached() async {
    final count = await _ref.read(mushafFontServiceProvider).downloadedCount();
    if (!mounted) return;
    state = state.copyWith(cachedCount: count);
  }

  /// Fetches every page font not already stored.
  ///
  /// Around 72 MB in total, which is why it is an explicit action rather than
  /// something the reader does on its own. Individual pages are still fetched
  /// on demand as they are opened, so this is only for reading offline.
  Future<void> start() async {
    if (state.running) return;
    _cancelled = false;
    final service = _ref.read(mushafFontServiceProvider);
    state = MushafDownloadState(
      running: true,
      total: MushafPageService.totalPages,
      cachedCount: state.cachedCount,
    );

    for (var page = 1; page <= MushafPageService.totalPages; page++) {
      if (_cancelled) break;
      try {
        await service.download(page);
        state = state.copyWith(completed: state.completed + 1);
      } catch (_) {
        // One unreachable page shouldn't abandon the other six hundred.
        state = state.copyWith(failures: state.failures + 1);
      }
    }

    state = state.copyWith(running: false);
    await refreshCached();
  }

  void cancel() {
    _cancelled = true;
    if (!state.running) return;
    state = state.copyWith(running: false);
  }
}

final mushafDownloadProvider =
    StateNotifierProvider<MushafDownloadNotifier, MushafDownloadState>((ref) {
      return MushafDownloadNotifier(ref);
    });
