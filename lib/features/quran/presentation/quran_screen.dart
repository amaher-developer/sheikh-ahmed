import 'dart:async';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/audio/audio_providers.dart';
import '../../../core/quran/audio_download_providers.dart';
import '../../../core/quran/bookmarks_providers.dart';
import '../../../core/quran/juz_meta.dart';
import '../../../core/quran/bulk_download_providers.dart';
import '../../../core/quran/quran_providers.dart';
import '../../../core/quran/mushaf_page_service.dart';
import '../../../core/quran/quran_search_service.dart';
import '../../../core/quran/reciter_data.dart';
import '../../../core/quran/surah_meta.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/arabic_numerals.dart';
import '../../../shared/widgets/sub_screen_header.dart';
import 'surah_reader_screen.dart';

/// Shared by [QuranScreen] and [SurahReaderScreen] so the reciter picker
/// looks and behaves identically wherever it's opened from.
void openReciterPicker(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const ReciterSheet(),
  );
}

class QuranScreen extends ConsumerStatefulWidget {
  const QuranScreen({super.key});

  @override
  ConsumerState<QuranScreen> createState() => _QuranScreenState();
}

class _QuranScreenState extends ConsumerState<QuranScreen> {
  int _chipIndex = 0;
  String _search = '';

  /// The query the ayah search actually runs, set a beat after typing
  /// stops. Surah names are filtered from [_search] on every keystroke —
  /// that is local and free — but searching the text of the Quran is a
  /// network call, and one per letter is a request storm.
  String _submitted = '';
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    setState(() => _search = value);
    _debounce?.cancel();
    final query = value.trim();
    // Two letters match most of the Quran; below that the results are
    // noise and the request is wasted.
    if (query.length < 3) {
      if (_submitted.isNotEmpty) setState(() => _submitted = '');
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 450), () {
      if (mounted) setState(() => _submitted = query);
    });
  }
  final _chips = const [
    'quran_screen.surahs',
    'quran_screen.juz',
    'quran_screen.favorites',
    'quran_screen.bookmarks',
  ];

  static const _arabicDigits = [
    '٠',
    '١',
    '٢',
    '٣',
    '٤',
    '٥',
    '٦',
    '٧',
    '٨',
    '٩',
  ];
  static String _ar(int n) =>
      n.toString().split('').map((d) => _arabicDigits[int.parse(d)]).join();

  List<Surah> get _visible {
    var list = _chipIndex == 2
        ? kAllSurahs.where((s) => s.favorite).toList()
        : kAllSurahs;
    if (_search.trim().isNotEmpty) {
      // Search both names, so an English reader can find a surah by the
      // transliteration they can actually see in the list.
      final q = _search.trim().toLowerCase();
      list = list
          .where((s) =>
              s.name.contains(_search.trim()) ||
              s.englishName.toLowerCase().contains(q))
          .toList();
    }
    return list;
  }

  void _openReader(Surah surah, {int? startAyah}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SurahReaderScreen(surah: surah, startAyah: startAyah),
      ),
    );
  }

  Future<void> _play(Surah surah, Reciter reciter) async {
    try {
      await playSurahWithAutoAdvance(ref, surah, reciter);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('radio_screen.playback_error'.tr())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final continueReadingSurah = ref.watch(continueReadingSurahProvider);
    final readingPosition = ref.watch(readingPositionProvider);
    final reciter = ref.watch(selectedReciterProvider);
    // Compared by the surah number stashed in extras, not the media id
    // itself — a downloaded surah plays from a local file path instead of
    // reciter.audioUrl(...), which would never match a raw id comparison.
    final nowPlayingSurah =
        ref.watch(currentMediaItemProvider).valueOrNull?.extras?['surahNumber']
            as int?;
    final isPlaying =
        ref.watch(playbackStateProvider).valueOrNull?.playing ?? false;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: SubScreenHeader(
            bottomPadding: 50,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SubScreenTitleRow(
                  title: 'quran_screen.title'.tr(),
                  trailing: GestureDetector(
                    onTap: () => openReciterPicker(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.mic_none_rounded,
                            size: 13,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            reciter.nameKey.tr(),
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 13,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.search,
                        size: 17,
                        color: AppColors.textOnPrimaryMuted,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          onChanged: _onSearchChanged,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Colors.white,
                          ),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            isDense: true,
                            hintText: 'quran_screen.search_hint'.tr(),
                            hintStyle: const TextStyle(
                              fontSize: 12.5,
                              color: AppColors.textOnPrimaryMuted,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ContinueReadingCard(
                  surah: continueReadingSurah,
                  ayahNumber: readingPosition.ayahNumber,
                  onTap: () => _openReader(
                    continueReadingSurah,
                    startAyah: readingPosition.ayahNumber,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 40,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _chips.length,
                    separatorBuilder: (context, i) => const SizedBox(width: 9),
                    itemBuilder: (context, i) {
                      final active = i == _chipIndex;
                      return GestureDetector(
                        onTap: () => setState(() => _chipIndex = i),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 17,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: active
                                ? AppColors.primary
                                : AppColors.surface,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: active
                                ? null
                                : [
                                    BoxShadow(
                                      color: AppColors.primaryDark.withValues(
                                        alpha: 0.05,
                                      ),
                                      blurRadius: 8,
                                    ),
                                  ],
                          ),
                          child: Center(
                            child: Text(
                              _chips[i].tr(),
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: active
                                    ? Colors.white
                                    : AppColors.textSecondary,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
        if (_chipIndex == 1)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
            sliver: SliverList.list(
              children: kJuzStarts
                  .map(
                    (juz) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _JuzRow(
                        juz: juz,
                        numberLabel: _ar(juz.number),
                        onTap: () => _openReader(
                          surahByNumber(juz.surahNumber),
                          startAyah: juz.ayahNumber,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          )
        else if (_chipIndex == 3)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
            sliver: SliverToBoxAdapter(
              child: _BookmarksList(onOpenAyah: _openReader),
            ),
          )
        // Ahead of the "nothing found" branch: a query that matches no
        // surah name can still match dozens of verses, and showing "not
        // found" over a list of them is the app contradicting itself.
        else if (_submitted.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
            sliver: SliverToBoxAdapter(
              child: _AyahSearchResults(
                query: _submitted,
                surahs: _visible,
                onOpenAyah: _openReader,
              ),
            ),
          )
        else if (_visible.isEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
            sliver: SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Text(
                    'quran_screen.no_results'.tr(),
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                ),
              ),
            ),
          )
        else ...[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
            sliver: const SliverToBoxAdapter(child: _OfflineQuranCard()),
          ),
          // Built lazily (only the rows near the viewport), not all 114+
          // at once — this list used to be a plain Column spread into a
          // single SliverToBoxAdapter, which built and laid out every
          // surah row up front regardless of scroll position.
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
            sliver: SliverList.builder(
              itemCount: _visible.length,
              itemBuilder: (context, i) {
                final s = _visible[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _SurahRow(
                    surah: s,
                    numberLabel: _ar(s.number),
                    ayahLabel:
                        '${s.meccan ? "مكية" : "مدنية"} · ${_ar(s.ayahCount)} آية',
                    isPlaying: isPlaying && nowPlayingSurah == s.number,
                    reciter: reciter,
                    onTap: () => _openReader(s),
                    onPlay: () => _play(s, reciter),
                    onToggleFavorite: () =>
                        setState(() => s.favorite = !s.favorite),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}

class _ContinueReadingCard extends StatelessWidget {
  final Surah surah;
  final int ayahNumber;
  final VoidCallback onTap;

  const _ContinueReadingCard({
    required this.surah,
    required this.ayahNumber,
    required this.onTap,
  });

  static const _arabicDigits = [
    '٠',
    '١',
    '٢',
    '٣',
    '٤',
    '٥',
    '٦',
    '٧',
    '٨',
    '٩',
  ];
  static String _ar(int n) =>
      n.toString().split('').map((d) => _arabicDigits[int.parse(d)]).join();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryDark.withValues(alpha: 0.10),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'quran_screen.continue_reading'.tr(),
                    style: AppTextStyles.accent,
                  ),
                  const SizedBox(height: 9),
                  Text(
                    surahDisplayName(surah, context.locale.languageCode == 'ar'),
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    '${'quran_screen.verse'.tr()} ${_ar(ayahNumber)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      height: 1.7,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.menu_book_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _JuzRow extends StatelessWidget {
  final JuzStart juz;
  final String numberLabel;
  final VoidCallback onTap;

  const _JuzRow({
    required this.juz,
    required this.numberLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final startSurah = surahByNumber(juz.surahNumber);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryDark.withValues(alpha: 0.05),
              blurRadius: 12,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.goldTint,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Center(
                child: Text(
                  numberLabel,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.gold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${'quran_screen.juz'.tr()} ${_QuranScreenState._ar(juz.number)}',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${surahDisplayName(startSurah, context.locale.languageCode == 'ar')} · ${_QuranScreenState._ar(juz.ayahNumber)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: AppColors.textSecondary,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_left_rounded,
              size: 20,
              color: AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _BookmarksList extends ConsumerWidget {
  final void Function(Surah surah, {int? startAyah}) onOpenAyah;
  const _BookmarksList({required this.onOpenAyah});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookmarks = ref.watch(bookmarksProvider);
    if (bookmarks.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: Text(
            'quran_screen.no_bookmarks'.tr(),
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted),
          ),
        ),
      );
    }

    // Grouped by colour, newest first inside each group. Sorting only by
    // date scatters the three meanings through one another, which is
    // exactly what colouring them was meant to prevent.
    final sorted = [...bookmarks]
      ..sort((a, b) {
        final byColor = a.color.index.compareTo(b.color.index);
        if (byColor != 0) return byColor;
        return b.savedAt.compareTo(a.savedAt);
      });

    return Column(
      children: sorted.map((bookmark) {
        final surah = surahByNumber(bookmark.surahNumber);
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: GestureDetector(
            onTap: () =>
                onOpenAyah(surah, startAyah: bookmark.ayahNumber),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryDark.withValues(alpha: 0.05),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: bookmark.color.color.withValues(alpha: 0.13),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(
                      Icons.bookmark_rounded,
                      size: 17,
                      color: bookmark.color.color,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          surahDisplayName(surah, context.locale.languageCode == 'ar'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${'quran_screen.verse'.tr()} ${_QuranScreenState._ar(bookmark.ayahNumber)}'
                          ' · ${bookmark.color.labelKey.tr()}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10.5,
                            color: AppColors.textSecondary,
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => ref
                        .read(bookmarksProvider.notifier)
                        .remove(bookmark.surahNumber, bookmark.ayahNumber),
                    child: Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _SurahRow extends StatelessWidget {
  final Surah surah;
  final String numberLabel;
  final String ayahLabel;
  final bool isPlaying;
  final Reciter reciter;
  final VoidCallback onTap;
  final VoidCallback onPlay;
  final VoidCallback onToggleFavorite;

  const _SurahRow({
    required this.surah,
    required this.numberLabel,
    required this.ayahLabel,
    required this.isPlaying,
    required this.reciter,
    required this.onTap,
    required this.onPlay,
    required this.onToggleFavorite,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isPlaying ? AppColors.primaryTint : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: isPlaying
              ? Border.all(color: AppColors.primary, width: 1.2)
              : null,
          boxShadow: isPlaying
              ? null
              : [
                  BoxShadow(
                    color: AppColors.primaryDark.withValues(alpha: 0.05),
                    blurRadius: 12,
                  ),
                ],
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isPlaying ? AppColors.primary : AppColors.primaryTint,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Center(
                child: isPlaying
                    ? const _MiniEqualizer()
                    : Text(
                        numberLabel,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    surahDisplayName(surah, context.locale.languageCode == 'ar'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isPlaying ? 'quran_screen.now_playing'.tr() : ayahLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: isPlaying ? FontWeight.w700 : FontWeight.normal,
                      color: isPlaying
                          ? AppColors.primary
                          : AppColors.textSecondary,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: onPlay,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Icon(
                  isPlaying
                      ? Icons.pause_circle_rounded
                      : Icons.play_circle_outline_rounded,
                  size: 22,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(width: 6),
            _DownloadButton(surah: surah, reciter: reciter),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: onToggleFavorite,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Icon(
                  surah.favorite
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  size: 20,
                  color: surah.favorite
                      ? AppColors.gold
                      : AppColors.iconMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Per-surah offline download control — the same "tap to save for offline,
/// tap again to remove" pattern as YouTube's download button. Downloading
/// shows a small progress ring; downloaded shows a filled offline icon
/// that deletes the local file on tap.
class _DownloadButton extends ConsumerWidget {
  final Surah surah;
  final Reciter reciter;

  const _DownloadButton({required this.surah, required this.reciter});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = '${reciter.id}:${surah.number}';
    final isDownloaded = ref.watch(downloadedSurahsProvider).contains(key);
    final progress = ref.watch(downloadProgressProvider)[key];

    if (progress != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            value: progress > 0 ? progress : null,
            strokeWidth: 2.4,
            color: AppColors.primary,
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () async {
        if (isDownloaded) {
          await ref
              .read(downloadedSurahsProvider.notifier)
              .delete(reciter, surah.number);
          return;
        }
        try {
          await downloadSurah(ref, reciter, surah.number);
        } catch (_) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('quran_screen.download_error'.tr())),
          );
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Icon(
          isDownloaded
              ? Icons.offline_pin_rounded
              : Icons.download_for_offline_outlined,
          size: 20,
          color: isDownloaded ? AppColors.primary : AppColors.iconMuted,
        ),
      ),
    );
  }
}

class ReciterSheet extends ConsumerWidget {
  const ReciterSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedReciterProvider);
    final notifier = ref.read(selectedReciterProvider.notifier);

    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'quran_screen.select_reciter'.tr(),
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 14),
            ...kReciters.map((reciter) {
              final on = reciter.id == selected.id;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GestureDetector(
                  onTap: () async {
                    await notifier.select(reciter);
                    if (context.mounted) Navigator.of(context).pop();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 13,
                    ),
                    decoration: BoxDecoration(
                      color: on
                          ? AppColors.primaryTint
                          : AppColors.chipBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            reciter.nameKey.tr(),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        Icon(
                          on
                              ? Icons.check_circle_rounded
                              : Icons.circle_outlined,
                          size: 18,
                          color: on
                              ? AppColors.primary
                              : AppColors.iconMuted,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

/// Small animated equalizer bars — replaces the surah-number badge on
/// whichever row is currently playing, so it's visible which surah is
/// active without reading the subtitle text.
class _MiniEqualizer extends StatefulWidget {
  const _MiniEqualizer();

  @override
  State<_MiniEqualizer> createState() => _MiniEqualizerState();
}

class _MiniEqualizerState extends State<_MiniEqualizer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: List.generate(3, (i) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final phase = (_controller.value + i * 0.3) % 1.0;
            final height = 5 + (phase * 10);
            return Container(
              width: 3,
              height: height,
              margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(2),
              ),
            );
          },
        );
      }),
    );
  }
}

/// "Download the whole Quran" — the bulk counterpart to the per-surah
/// download button on each row.
///
/// Downloading 114 surahs one tap at a time is not a realistic way to take
/// the Quran offline, which is what this is for. It only ever fetches what
/// is missing, so it doubles as "resume": interrupt it, come back, and it
/// picks up the surahs that never arrived.
class _OfflineQuranCard extends ConsumerWidget {
  const _OfflineQuranCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reciter = ref.watch(selectedReciterProvider);
    final downloaded = ref.watch(downloadedSurahsProvider);
    final bulk = ref.watch(bulkDownloadProvider);
    final have = downloadedCountFor(downloaded, reciter);
    final total = kAllSurahs.length;
    final complete = have >= total;
    final arabic = context.locale.languageCode == 'ar';
    String n(int v) => arabic ? toArabicDigits('$v') : '$v';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.28)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                complete
                    ? Icons.offline_pin_rounded
                    : Icons.download_for_offline_rounded,
                size: 20,
                color: complete ? AppColors.primary : AppColors.gold,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'quran_screen.offline_title'.tr(),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        height: 1.5,
                      ),
                    ),
                    Text(
                      // Names the reciter: downloads are per reciter, so
                      // "114 of 114" means nothing without saying whose.
                      'quran_screen.offline_progress'.tr(
                        namedArgs: {
                          'have': n(have),
                          'total': n(total),
                          'reciter': reciter.nameKey.tr(),
                        },
                      ),
                      style: TextStyle(
                        fontSize: 10.5,
                        color: AppColors.textSecondary,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
              if (!bulk.running && !complete)
                GestureDetector(
                  onTap: () => ref
                      .read(bulkDownloadProvider.notifier)
                      .start(reciter),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'quran_screen.offline_download'.tr(),
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                )
              else if (bulk.running)
                GestureDetector(
                  onTap: ref.read(bulkDownloadProvider.notifier).cancel,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(
                      'quran_screen.offline_cancel'.tr(),
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDanger,
                      ),
                    ),
                  ),
                )
              else
                // Everything is on disk. The button was already hidden in
                // this case, but hiding it and leaving the space blank reads
                // as a control having gone missing rather than as the work
                // being done.
                const _DownloadedChip(),
            ],
          ),
          if (bulk.running) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: bulk.progress,
                minHeight: 6,
                backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation(AppColors.primary),
              ),
            ),
            const SizedBox(height: 5),
            // A second, thinner bar for the surah in flight. The bar above
            // counts whole surahs, and al-Baqara alone is around 115 MB — it
            // can sit on one step for many minutes, which reads as a hang.
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: bulk.fileProgress,
                minHeight: 3,
                backgroundColor: AppColors.primary.withValues(alpha: 0.10),
                valueColor: AlwaysStoppedAnimation(AppColors.gold),
              ),
            ),
            const SizedBox(height: 7),
            Text(
              '${'quran_screen.offline_running'.tr(namedArgs: {'done': n(bulk.completed), 'total': n(bulk.total)})}'
              ' · ${n((bulk.fileProgress * 100).round())}%',
              style: TextStyle(fontSize: 10.5, color: AppColors.textMuted),
            ),
          ],
          const SizedBox(height: 12),
          Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: 12),
          const _OfflineTextRow(),
          // Surfaced only after the run: failures don't stop it, so this is
          // the only place the user learns some surahs need another go.
          if (!bulk.running && bulk.failures > 0) ...[
            const SizedBox(height: 8),
            Text(
              'quran_screen.offline_failed'.tr(
                namedArgs: {'count': n(bulk.failures)},
              ),
              style: TextStyle(fontSize: 10.5, color: AppColors.textDanger),
            ),
          ],
        ],
      ),
    );
  }
}

/// The Mus'haf-text half of the offline card.
///
/// Downloading the text is a separate action from downloading the
/// recitations: it is a few megabytes against several hundred, and it is
/// what makes *reading* work with no connection.
class _OfflineTextRow extends ConsumerWidget {
  const _OfflineTextRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = ref.watch(textDownloadProvider);
    // Both halves, not just the text. Reporting the text alone as done
    // is what let the card show a tick over a Mus'haf that fell back to
    // the plain layout the moment the connection went.
    final textComplete = text.isComplete;
    final arabic = context.locale.languageCode == 'ar';
    String n(int v) => arabic ? toArabicDigits('$v') : '$v';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.menu_book_rounded, size: 18, color: AppColors.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'quran_screen.offline_text_title'.tr(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      height: 1.5,
                    ),
                  ),
                  // Says what is already stored, so "do I need to do
                  // this?" is answerable at a glance instead of only
                  // after starting a run.
                  if (!text.running)
                    Text(
                      'quran_screen.offline_text_progress'.tr(
                        namedArgs: {
                          'have': n(text.cachedPages),
                          'total': n(MushafPageService.totalPages),
                        },
                      ),
                      style: TextStyle(
                        fontSize: 10.5,
                        color: AppColors.textSecondary,
                        height: 1.6,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (text.running)
              GestureDetector(
                onTap: ref.read(textDownloadProvider.notifier).cancel,
                child: Text(
                  'quran_screen.offline_cancel'.tr(),
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDanger,
                  ),
                ),
              )
            else if (textComplete)
              const _DownloadedChip()
            else
              GestureDetector(
                onTap: ref.read(textDownloadProvider.notifier).start,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryTint,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'quran_screen.offline_download'.tr(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
          ],
        ),
        if (text.running) ...[
          const SizedBox(height: 9),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: text.progress,
              minHeight: 5,
              backgroundColor: AppColors.primary.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation(AppColors.gold),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            (text.stage == OfflineStage.pages
                    ? 'quran_screen.offline_running_pages'
                    : 'quran_screen.offline_running')
                .tr(
                  namedArgs: {
                    'done': n(text.completed),
                    'total': n(text.total),
                  },
                ),
            style: TextStyle(fontSize: 10.5, color: AppColors.textMuted),
          ),
        ],
        if (!text.running && text.failures > 0) ...[
          const SizedBox(height: 6),
          Text(
            'quran_screen.offline_failed'.tr(
              namedArgs: {'count': n(text.failures)},
            ),
            style: TextStyle(fontSize: 10.5, color: AppColors.textDanger),
          ),
        ],
      ],
    );
  }
}

/// The "already on this device" marker shown where a download button would
/// otherwise sit.
///
/// Replacing the button rather than simply removing it: an empty space where
/// a control used to be reads as something missing, not as something
/// finished, and the whole question here is "do I still need to download
/// this?".
class _DownloadedChip extends StatelessWidget {
  const _DownloadedChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primaryTint,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle_rounded,
            size: 14,
            color: AppColors.primary,
          ),
          const SizedBox(width: 5),
          Text(
            'quran_screen.offline_done'.tr(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Surah names that matched, then the verses whose text did.
///
/// Both in one list because a reader searching "الرحمن" does not think of
/// them as two different questions — they want the surah or the verse,
/// whichever the app can find.
class _AyahSearchResults extends ConsumerWidget {
  final String query;
  final List<Surah> surahs;
  final void Function(Surah surah, {int? startAyah}) onOpenAyah;

  const _AyahSearchResults({
    required this.query,
    required this.surahs,
    required this.onOpenAyah,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final arabic = context.locale.languageCode == 'ar';
    final hits = ref.watch(quranSearchProvider(query));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (surahs.isNotEmpty) ...[
          _SearchHeading('quran_screen.search_surahs'.tr()),
          for (final s in surahs.take(5))
            _SearchRow(
              title: surahDisplayName(s, arabic),
              subtitle: '',
              onTap: () => onOpenAyah(s),
            ),
          const SizedBox(height: 14),
        ],
        _SearchHeading('quran_screen.search_ayahs'.tr()),
        hits.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 22),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, _) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Text(
              'quran_screen.search_error'.tr(),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ),
          data: (list) => list.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: Text(
                    'quran_screen.search_none'.tr(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final hit in list)
                      _SearchRow(
                        title: hit.text,
                        subtitle:
                            '${surahDisplayName(surahByNumber(hit.surah), arabic)}'
                            ' · '
                            '${'quran_screen.ayah_n'.tr(namedArgs: {'n': arabic ? toArabicDigits('${hit.ayah}') : '${hit.ayah}'})}',
                        arabicText: true,
                        onTap: () => onOpenAyah(
                          surahByNumber(hit.surah),
                          startAyah: hit.ayah,
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _SearchHeading extends StatelessWidget {
  final String text;

  const _SearchHeading(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.gold,
          height: 1.6,
        ),
      ),
    );
  }
}

class _SearchRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool arabicText;
  final VoidCallback onTap;

  const _SearchRow({
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.arabicText = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 9),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: arabicText
                  ? AppTextStyles.mushaf(fontSize: 16, height: 1.9)
                  : TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      height: 1.6,
                    ),
            ),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 10.5,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
