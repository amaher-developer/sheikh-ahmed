import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/audio/audio_providers.dart';
import '../../../core/quran/ayah_position.dart';
import '../../../core/quran/bookmarks_providers.dart';
import '../../../core/quran/mushaf_pages.dart';
import '../../../core/quran/quran_providers.dart';
import 'quran_jump_sheet.dart';
import 'reading_settings_sheet.dart';
import 'word_by_word_sheet.dart';
import '../../../core/quran/quran_text_service.dart';
import '../../../core/quran/surah_meta.dart';
import '../../../core/quran/tajweed_service.dart';
import '../../../core/quran/tajweed.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/quran/mushaf_page_data.dart';
import '../../../core/quran/mushaf_page_service.dart';
import '../../../core/quran/mushaf_providers.dart';
import '../../../core/quran/page_starts.dart';
import 'mushaf_page_view.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/arabic_numerals.dart';
import '../../../shared/widgets/khatim_pattern.dart';
import 'memorization_screen.dart';
import 'quran_screen.dart' show openReciterPicker;

/// Why the printed reader stood aside — no connection, and this page has
/// not been opened before.
class _NoPrintedPage implements Exception {
  const _NoPrintedPage();
}

/// Swipeable across all 114 surahs — like turning pages in a Mus'haf —
/// instead of the old "pop back to the list, tap the next one" flow. The
/// AppBar (title, reciter, bookmark, font-size, play button) lives here and
/// tracks whichever surah is currently on screen; the actual per-surah
/// content (fetch, scroll, reading-position tracking) is [_SurahPage],
/// swapped in per page by the PageView.
class SurahReaderScreen extends ConsumerStatefulWidget {
  final Surah surah;
  final int? startAyah;

  const SurahReaderScreen({super.key, required this.surah, this.startAyah});

  @override
  ConsumerState<SurahReaderScreen> createState() => _SurahReaderScreenState();
}

class _SurahReaderScreenState extends ConsumerState<SurahReaderScreen> {
  late final PageController _pageController;
  late int _currentSurahNumber;
  int _currentFurthestAyah = 1;

  /// The page the printed Mus'haf opens on.
  ///
  /// Resolved from the local page table rather than from the surah text,
  /// so the printed reader does not wait on a surah download before it
  /// can show anything — and fixed for the life of the screen, so turning
  /// pages does not re-decide which reader is in use halfway through.
  late final int _openingPage =
      pageForAyah(widget.surah.number, widget.startAyah ?? 1) ?? 1;

  /// How long the printed page gets before the reader gives up on it.
  ///
  /// Long enough that a normal connection never reaches it, short enough
  /// that a bad one does not leave someone staring at a spinner with a
  /// Quran they could have been reading. On timeout the app's own text
  /// takes over, the same as when there is no connection at all.
  static const _printedGiveUpAfter = Duration(seconds: 6);

  Timer? _printedTimer;
  bool _printedGaveUp = false;

  /// Guards against re-triggering the same auto-advance while the page
  /// animation from it is still settling (onPageChanged/currentMediaItem
  /// can both fire again before that finishes).
  int? _autoAdvancedToSurah;

  @override
  void initState() {
    super.initState();
    _currentSurahNumber = widget.surah.number;
    _currentFurthestAyah = widget.startAyah ?? 1;
    _pageController = PageController(initialPage: widget.surah.number - 1);
    _printedTimer = Timer(_printedGiveUpAfter, () {
      if (mounted) setState(() => _printedGaveUp = true);
    });
  }

  @override
  void dispose() {
    _printedTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  /// A page of the printed Mus'haf came into view.
  ///
  /// The printed reader runs straight through all 604 pages, so the surah
  /// on screen is whatever that page opens in — the app bar, the bookmark
  /// button and the saved reading position all follow from it.
  void _onPrintedPageChanged(int page) {
    final start = pageStartFor(page);
    if (start == null) return;
    setState(() {
      _currentSurahNumber = start.surahNumber;
      _currentFurthestAyah = start.ayahNumber;
    });
    ref
        .read(readingPositionProvider.notifier)
        .update(start.surahNumber, start.ayahNumber);
  }

  /// Opens the reader somewhere else in the Mus'haf.
  ///
  /// Replaces the screen rather than moving the pager. The target verse
  /// reaches the page through a widget field fixed when a page is built,
  /// and the outer pager keeps its 114 children alive across a jump — so
  /// animating to another surah would land on a page that was constructed
  /// to open at ayah 1 and stay there. A replacement rebuilds it at the
  /// verse asked for, and leaves the back stack exactly as deep as it was.
  Future<void> _openJumpSheet() async {
    final target = await showQuranJumpSheet(context);
    if (target == null || !mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => SurahReaderScreen(
          surah: surahByNumber(target.surahNumber),
          startAyah: target.ayahNumber,
        ),
      ),
    );
  }

  void _goToSurah(int surahNumber) {
    _pageController.animateToPage(
      surahNumber - 1,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOut,
    );
  }


  @override
  Widget build(BuildContext context) {
    final currentSurah = surahByNumber(_currentSurahNumber);
    final reciter = ref.watch(selectedReciterProvider);

    // In English the printed Mus'haf is the wrong reader.
    //
    // Its page is a photograph of the Arabic, and there is nowhere on a
    // fifteen-line printed grid to put a translation — so an English
    // reader got a page they could not read at all. The app's own layout,
    // which sets each verse with its translation underneath, is what
    // English had before and is what it keeps.
    final arabic = context.locale.languageCode == 'ar';

    // The reader's own choice of layout. Not a fallback: the printed page
    // has one pre-shaped font per page and a fixed fifteen-line grid, so
    // a reader who wants a different face, a larger one, or a bold one has
    // to be in the other layout to get it. Read before the page fetches so
    // choosing text does not sit through a download it will not use.
    final wantsPrinted = ref.watch(printedMushafProvider);

    // Whether the printed Mus'haf can be drawn: its glyph layout and its
    // page font, which are independent fetches and both required — either
    // one alone renders as empty boxes. Only the opening page is checked;
    // the rest load as they are turned to.
    final pageData = arabic && wantsPrinted
        ? ref.watch(mushafPageProvider(_openingPage))
        : const AsyncValue<MushafPageData>.loading();
    final pageFont = arabic && wantsPrinted
        ? ref.watch(mushafFontProvider(_openingPage))
        : const AsyncValue<void>.loading();
    final printedState = !arabic ||
            !wantsPrinted ||
            pageData.hasError ||
            pageFont.hasError ||
            (_printedGaveUp && !(pageData.hasValue && pageFont.hasValue))
        ? const AsyncValue<void>.error(_NoPrintedPage(), StackTrace.empty)
        : pageData.hasValue && pageFont.hasValue
        ? const AsyncValue<void>.data(null)
        : const AsyncValue<void>.loading();
    if (!printedState.isLoading) _printedTimer?.cancel();
    final bookmarks = ref.watch(bookmarksProvider);
    final currentIsBookmarked = bookmarks.any(
      (b) =>
          b.surahNumber == _currentSurahNumber &&
          b.ayahNumber == _currentFurthestAyah,
    );
    // Compared by the surah number stashed in extras, not the media id
    // itself — a downloaded surah plays from a local file path instead of
    // reciter.audioUrl(...), which would never match a raw id comparison.
    final nowSurahNumber =
        ref.watch(currentMediaItemProvider).valueOrNull?.extras?['surahNumber']
            as int?;
    final isThisPlaying =
        nowSurahNumber == _currentSurahNumber &&
        (ref.watch(playbackStateProvider).valueOrNull?.playing ?? false);

    // When auto-advance (see playSurahWithAutoAdvance) moves playback from
    // the current surah straight into the next one, turn the page along
    // with it — this is what makes "book mode" track continuous listening
    // instead of leaving the reader stuck on the surah that already
    // finished.
    ref.listen<AsyncValue<MediaItem?>>(currentMediaItemProvider, (
      previous,
      next,
    ) {
      final prevSurah = previous?.valueOrNull?.extras?['surahNumber'] as int?;
      final nextSurah = next.valueOrNull?.extras?['surahNumber'] as int?;
      if (prevSurah == _currentSurahNumber &&
          nextSurah == _currentSurahNumber + 1 &&
          nextSurah! <= 114 &&
          _autoAdvancedToSurah != nextSurah) {
        _autoAdvancedToSurah = nextSurah;
        // Only the fallback reader has a surah pager to move. In the
        // printed one the controller is never attached, and animating it
        // throws.
        if (_pageController.hasClients) _goToSurah(nextSurah);
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        // Trimmed from the default 56: the reader wants the height for the
        // Mus'haf page, and the bar carries only a title and four controls.
        toolbarHeight: 48,
        titleSpacing: 4,
        title: Text(
          surahDisplayName(currentSurah, context.locale.languageCode == 'ar'),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: Icon(
              currentIsBookmarked
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_border_rounded,
              size: 20,
            ),
            tooltip: 'quran_screen.tap_to_bookmark'.tr(),
            onPressed: () {
              final added = ref
                  .read(bookmarksProvider.notifier)
                  .toggle(_currentSurahNumber, _currentFurthestAyah);
              HapticFeedback.selectionClick();
              ScaffoldMessenger.of(context).clearSnackBars();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  duration: const Duration(seconds: 2),
                  content: Text(
                    added
                        ? 'quran_screen.bookmark_added'.tr()
                        : 'quran_screen.bookmark_removed'.tr(),
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.my_location_rounded, size: 20),
            tooltip: 'quran_screen.jump_title'.tr(),
            onPressed: _openJumpSheet,
          ),
          IconButton(
            icon: const Icon(Icons.school_rounded, size: 20),
            tooltip: 'memorization_screen.title'.tr(),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => MemorizationScreen(
                  surah: currentSurah,
                  startAyah: _currentFurthestAyah,
                ),
              ),
            ),
          ),
          // Reading mode and font settings live in an overflow menu. The
          // bar previously carried six actions plus the reciter chip, and
          // the row overflowed far enough that the chip was drawn over the
          // back button, leaving no way out of the reader.
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, size: 20),
            color: AppColors.surface,
            onSelected: (value) {
              switch (value) {
                case 'reciter':
                  openReciterPicker(context);
                case 'reading':
                  showReadingSettings(context);



              }
            },
            itemBuilder: (context) => [
              // The reciter lives here rather than as a chip in the bar. As a
              // chip its width grew with the reciter's name, which is what
              // pushed the row over its width and covered the back button;
              // as a menu row it also shows which reciter is selected,
              // which the chip could only do by taking that space.
              PopupMenuItem(
                value: 'reciter',
                child: _MenuRow(
                  icon: Icons.mic_none_rounded,
                  label: reciter.nameKey.tr(),
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'reading',
                child: _MenuRow(
                  icon: Icons.text_fields_rounded,
                  label: 'quran_screen.reading_settings'.tr(),
                ),
              ),



            ],
          ),
          IconButton(
            icon: Icon(
              isThisPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            ),
            tooltip: reciter.nameKey.tr(),
            onPressed: () async {
              try {
                // Something from this surah — the full track, or a
                // specific ayah started via the reader's "play from here"
                // — may already be loaded. Toggling play/pause on it in
                // place is what the pause icon promises; re-running
                // playSurahWithAutoAdvance unconditionally would instead
                // load the *full-surah* track fresh (a different id than
                // an ayah-specific one) and restart from ayah 1 — the bug
                // this replaced: tapping "pause" while playing from ayah
                // 40 jumped back to the beginning instead of pausing.
                final handler = ref.read(audioHandlerProvider);
                final currentSurahNumber =
                    handler.mediaItem.value?.extras?['surahNumber'] as int?;
                if (currentSurahNumber == _currentSurahNumber) {
                  if (ref.read(playbackStateProvider).valueOrNull?.playing ??
                      false) {
                    await handler.pause();
                  } else {
                    await handler.play();
                  }
                  return;
                }
                await playSurahWithAutoAdvance(ref, currentSurah, reciter);
              } catch (_) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('radio_screen.playback_error'.tr())),
                );
              }
            },
          ),
        ],
      ),
      body: printedState.isLoading
          ? const _MushafLoading()
          : printedState.hasError
          ? _surahPager()
          : _PrintedMushaf(
              initialPage: _openingPage,
              onPageChanged: _onPrintedPageChanged,
            ),
    );
  }

  /// The fallback reader: one swipeable page per surah, set in the app's
  /// own text rather than the printed page's glyphs.
  ///
  /// Reached only when the printed page cannot be had at all — no
  /// connection, and this page never opened before. Keyed because it
  /// nests pagers, and tests that swipe between *surahs* need to address
  /// this one unambiguously.
  Widget _surahPager() {
    return PageView.builder(
        key: const ValueKey('surahPageView'),
        controller: _pageController,
        itemCount: 114,
        itemBuilder: (context, index) {
          final surahNumber = index + 1;
          return _SurahPage(
            key: ValueKey(surahNumber),
            surah: surahByNumber(surahNumber),
            startAyah: surahNumber == widget.surah.number
                ? widget.startAyah
                : null,
            isActive: surahNumber == _currentSurahNumber,
            onFurthestAyahChanged: (ayah) {
              setState(() => _currentFurthestAyah = ayah);
              ref
                  .read(readingPositionProvider.notifier)
                  .update(surahNumber, ayah);
            },
          );
        },
        onPageChanged: (index) {
          setState(() {
            _currentSurahNumber = index + 1;
            _currentFurthestAyah = 1;
          });
        },
    );
  }
}

/// The whole printed Mus'haf as one pager: 604 pages, end to end.
///
/// Not one pager per surah nested inside another. Two pagers on the same
/// axis do not hand a gesture to one another, so at the last page of a
/// surah the inner one had nowhere left to go and the swipe simply died —
/// the reader was stuck at every surah boundary with no way forward but
/// the back button. One continuous pager is also what a Mus'haf actually
/// is: page 293 follows 292 whatever surah either of them belongs to.
class _PrintedMushaf extends ConsumerStatefulWidget {
  final int initialPage;
  final ValueChanged<int> onPageChanged;

  const _PrintedMushaf({
    required this.initialPage,
    required this.onPageChanged,
  });

  @override
  ConsumerState<_PrintedMushaf> createState() => _PrintedMushafState();
}

class _PrintedMushafState extends ConsumerState<_PrintedMushaf> {
  late final PageController _controller = PageController(
    initialPage: widget.initialPage - 1,
  );
  late int _index = widget.initialPage - 1;

  /// The verse last tapped, as "surah:ayah".
  String? _selectedVerse;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// A tap on the page, which reports a verse rather than an [Ayah].
  ///
  /// The surah text is fetched here rather than held by the reader: a
  /// continuous Mus''haf crosses surahs constantly, so there is no one
  /// surah whose text could have been loaded in advance. It is cached, so
  /// this is instant for any surah already opened.
  Future<void> _openActions(int surahNumber, int ayahNumber) async {
    setState(() => _selectedVerse = '$surahNumber:$ayahNumber');
    List<Ayah> ayahs;
    try {
      ayahs = await ref
          .read(quranTextServiceProvider)
          .fetchSurah(surahNumber);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text('quran_screen.load_error'.tr())));
      return;
    }
    if (!mounted) return;
    final index = ayahs.indexWhere((a) => a.numberInSurah == ayahNumber);
    if (index < 0) return;
    showAyahActions(
      context: context,
      ref: ref,
      surah: surahByNumber(surahNumber),
      ayahs: ayahs,
      ayah: ayahs[index],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Forced RTL rather than reversed. A horizontal PageView already takes
    // its direction from the ambient Directionality, so in Arabic it was
    // already turning right to left and reverse: true flipped it back the
    // wrong way. Pinning it also keeps the Mus'haf turning the right way
    // in the English UI, where the app itself is left to right.
    return Directionality(
      textDirection: material.TextDirection.rtl,
      child: PageView.builder(
        key: const ValueKey('printedMushafPages'),
        controller: _controller,
        itemCount: MushafPageService.totalPages,
        onPageChanged: (i) {
          setState(() => _index = i);
          widget.onPageChanged(i + 1);
        },
        itemBuilder: (context, i) => _PinchPage(
          isCurrent: i == _index,
          child: MushafPageView(
            page: i + 1,
            onAyahTap: _openActions,
            selectedVerse: _selectedVerse,
          ),
        ),
      ),
    );
  }
}

/// The frame of a Mus'haf page with nothing in it yet.
///
/// Shown while the first page loads, in place of the app's own text
/// layout. Rendering that instead meant the reader saw one typesetting of
/// the Quran and then watched it be replaced by another a moment later,
/// which reads as a fault rather than as loading.
class _MushafLoading extends StatelessWidget {
  const _MushafLoading();

  @override
  Widget build(BuildContext context) {
    return const MushafPageFrame(
      child: Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );
  }
}

/// One surah's worth of reader content: fetches its ayahs, tracks how far
/// into it the user has scrolled, and reports that back up to
/// [SurahReaderScreen] — but only while [isActive], so a neighboring page
/// PageView pre-builds for a smooth swipe preview never gets mistaken for
/// "the surah the user is actually reading" before they've swiped to it.
class _SurahPage extends ConsumerStatefulWidget {
  final Surah surah;
  final int? startAyah;
  final bool isActive;
  final ValueChanged<int> onFurthestAyahChanged;

  const _SurahPage({
    super.key,
    required this.surah,
    required this.startAyah,
    required this.isActive,
    required this.onFurthestAyahChanged,
  });

  @override
  ConsumerState<_SurahPage> createState() => _SurahPageState();
}

class _SurahPageState extends ConsumerState<_SurahPage> {
  late Future<List<Ayah>> _future;
  final _scrollController = ScrollController();
  int _furthestAyah = 1;
  bool _scrolledToStart = false;
  bool? _loadedWithTranslation;

  @override
  void initState() {
    super.initState();
    _furthestAyah = widget.startAyah ?? 1;
    // Not loaded here: context.locale depends on an InheritedWidget
    // (EasyLocalization), which Flutter disallows reading from initState —
    // didChangeDependencies is the first safe point, and conveniently also
    // fires again if the user changes locale while this screen is open.
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final showTranslation = context.locale.languageCode == 'en';
    if (_loadedWithTranslation != showTranslation) {
      _load(showTranslation);
    }
  }

  @override
  void didUpdateWidget(covariant _SurahPage old) {
    super.didUpdateWidget(old);
    // Just became the visible page — e.g. the user swiped onto a neighbor
    // PageView had already pre-built off-screen. Report its (already
    // resolved) reading position now, since it was deliberately withheld
    // while inactive.
    //
    // Deferred to a post-frame callback, not called synchronously here:
    // didUpdateWidget runs *during* the PageView's own build/update pass
    // (this is itself one of its children being updated), and
    // onFurthestAyahChanged calls setState() on the parent
    // SurahReaderScreen — doing that synchronously is a re-entrant
    // "setState() called during build", which reliably corrupted the
    // PageView's sliver child list on a real device (reproduced via a
    // fling-then-swipe widget test: it threw "setState() ... called
    // during build", then a sliver child-order assertion, then the
    // RenderErrorBox/RenderSemanticsGestureHandler cast crash during the
    // next scroll — all one cascade from this same root cause).
    if (widget.isActive && !old.isActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _reportFurthestAyah();
      });
    }
  }

  /// Jumps the reader straight to widget.startAyah — e.g. a Juz boundary
  /// most of the way through a long surah, or a bookmark — instead of
  /// always opening at the top and leaving the user to scroll and hunt for
  /// it. Runs once per page instance, after the first layout with real
  /// content so maxScrollExtent is accurate.
  void _scrollToStartAyahIfNeeded(List<Ayah> ayahs) {
    if (_scrolledToStart) return;
    _scrolledToStart = true;

    // Mark this as the current reading position as soon as it's open (and
    // active), not only once the user scrolls further into it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _reportFurthestAyah();
    });

    final target = widget.startAyah;
    if (target == null || target <= 1) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final fraction = fractionForAyah(ayahs, target);
      final offset = fraction * _scrollController.position.maxScrollExtent;
      _scrollController.jumpTo(offset.clamp(
        0.0,
        _scrollController.position.maxScrollExtent,
      ));
    });
  }

  /// Reports the furthest-read ayah up to [SurahReaderScreen], which is
  /// what actually persists it as the reading position — but only while
  /// this page is the one the user is genuinely looking at (see the class
  /// doc comment).
  void _reportFurthestAyah() {
    if (!widget.isActive) return;
    widget.onFurthestAyahChanged(_furthestAyah);
  }

  void _load([bool? showTranslation]) {
    // English readers get the translation alongside the Arabic; Arabic
    // stays pure Mus'haf text, matching a printed copy.
    final translate = showTranslation ?? (context.locale.languageCode == 'en');
    _loadedWithTranslation = translate;
    _future = ref
        .read(quranTextServiceProvider)
        .fetchSurah(widget.surah.number, includeTranslation: translate);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fontSize = ref.watch(quranFontSizeProvider);
    // As in _MushafPageState: the face lives in mutable statics, so the
    // provider has to be watched for a change to it to repaint anything.
    ref.watch(quranReadingStyleProvider);

    return FutureBuilder<List<Ayah>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.wifi_off_rounded,
                    size: 40,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'quran_screen.load_error'.tr(),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => setState(_load),
                    child: Text('quran_screen.retry'.tr()),
                  ),
                ],
              ),
            ),
          );
        }

        final ayahs = snapshot.data!;
        // At-Tawbah (9) is the one surah the Mus'haf omits the Bismillah
        // from; Al-Fatihah (1) already carries it as its own first ayah.
        final showBasmala =
            widget.surah.number != 1 && widget.surah.number != 9;

        _scrollToStartAyahIfNeeded(ayahs);

        if (ref.watch(quranPageModeProvider)) {
          return _MushafPageView(
            surah: widget.surah,
            ayahs: ayahs,
            showBasmala: showBasmala,
            fontSize: fontSize,
            startAyah: widget.startAyah,
            onFurthestAyahChanged: (ayah) {
              if (ayah > _furthestAyah) {
                _furthestAyah = ayah;
                _reportFurthestAyah();
              }
            },
          );
        }

        return NotificationListener<ScrollUpdateNotification>(
          onNotification: (notification) {
            // Track the furthest ayah scrolled past. Estimated by character
            // position within the surah's text (see ayah_position.dart)
            // rather than by ayah *count*, since ayahs vary hugely in
            // length — a uniform per-ayah fraction was the bug behind Juz
            // links landing in the wrong place.
            final pixels = notification.metrics.pixels;
            final extent = notification.metrics.maxScrollExtent;
            if (extent > 0) {
              final fraction = (pixels / extent).clamp(0.0, 1.0);
              final estimated = ayahForFraction(ayahs, fraction);
              // setState only on an actual change (crossing into a new
              // ayah), not every scroll delta.
              if (estimated > _furthestAyah) {
                setState(() => _furthestAyah = estimated);
                _reportFurthestAyah();
              }
            }
            return false;
          },
          child: SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(14, 16, 14, 40),
            child: _MushafPage(
              surah: widget.surah,
              ayahs: ayahs,
              showBasmala: showBasmala,
              fontSize: fontSize,
            ),
          ),
        );
      },
    );
  }
}

/// One continuous Mus'haf page: the surah's verses flow as a single
/// justified block, separated by the traditional end-of-ayah rosette rather
/// than being broken into per-verse cards. Rendered in AmiriQuran — the UI
/// font has no glyphs for Uthmani marks (see AppTextStyles.mushaf).
///
/// Bookmarking is a single AppBar action on the current reading position
/// (see SurahReaderScreen), not a tap on the ayah text itself — an earlier
/// version made every ayah's whole body individually tappable via a
/// TapGestureRecognizer per span, which read as random/accidental
/// bookmarking while scrolling and reading. Bookmarked ayahs are still
/// highlighted here so the effect of that one button is visible, just not
/// triggered from here.
///
/// Tapping an ayah — its running text or the end-of-ayah rosette, both
/// wired to the same recognizer — opens a small menu (see
/// [_MushafPageState._showAyahActions]) rather than doing anything
/// immediately, unlike the old per-span bookmark toggle above: a menu
/// needs one further deliberate tap on an actual option before anything
/// happens, so it doesn't reproduce the "accidental action from a normal
/// reading/scrolling tap" problem that whole-body tapping caused there.
class _MushafPage extends ConsumerStatefulWidget {
  final Surah surah;
  final List<Ayah> ayahs;
  final bool showBasmala;

  /// False on a continuation page in Mus'haf mode — only the page that
  /// opens the surah carries its heading, as in print. Continuous mode
  /// always passes true, since it renders the surah as one unit.
  final bool showHeading;
  final double fontSize;

  const _MushafPage({
    required this.surah,
    required this.ayahs,
    required this.showBasmala,
    this.showHeading = true,
    required this.fontSize,
  });

  @override
  ConsumerState<_MushafPage> createState() => _MushafPageState();
}

class _MushafPageState extends ConsumerState<_MushafPage> {
  // Keyed by ayah number and reused across rebuilds (font size changes,
  // bookmark toggles, ...) rather than recreated every build, which would
  // leak a recognizer each time — TextSpan recognizers must be explicitly
  // disposed, and only this widget's own dispose() is a safe place to do
  // that reliably.
  final Map<int, TapGestureRecognizer> _recognizers = {};

  @override
  void dispose() {
    for (final recognizer in _recognizers.values) {
      recognizer.dispose();
    }
    super.dispose();
  }

  TapGestureRecognizer _recognizerFor(Ayah ayah) {
    return _recognizers.putIfAbsent(
      ayah.numberInSurah,
      () => TapGestureRecognizer()..onTap = () => _showAyahActions(ayah),
    );
  }

  /// Tapping the rosette opens a small menu rather than doing anything
  /// immediately — starting audio (a network fetch + player load) on
  /// every tap made rapid taps while scrolling/reading feel laggy, and
  /// could kick off playback the user never meant to start. This adds one
  /// deliberate extra tap before either action happens, and gives tafsir
  /// a home without needing its own separate tap target.
  void _showAyahActions(Ayah ayah) => showAyahActions(
    context: context,
    ref: ref,
    surah: widget.surah,
    ayahs: widget.ayahs,
    ayah: ayah,
  );

  @override
  Widget build(BuildContext context) {
    // Watched purely to rebuild on a font change. AppTextStyles.mushaf()
    // reads mutable statics that QuranReadingStyle.apply() sets, and
    // mutating a static marks nothing dirty — so without this the new face
    // only appeared once something *else* forced a repaint, which in
    // practice meant changing the font size (that provider is watched
    // below). Same reason AppColors needs AppRestart for theme changes.
    ref.watch(quranReadingStyleProvider);

    final bookmarks = ref.watch(bookmarksProvider);
    final bookmarkedAyahs = bookmarks
        .where((b) => b.surahNumber == widget.surah.number)
        .map((b) => b.ayahNumber)
        .toSet();

    // A continuation page starts straight into the verse text, so it gets a
    // tighter top inset than the page that opens the surah. Previously both
    // used the same 24 *and* an unconditional 16px gap below the (absent)
    // heading, which left a continuation page opening with 40px of nothing.
    final opensSurah = widget.showHeading || widget.showBasmala;

    return Container(
      padding: EdgeInsets.fromLTRB(20, opensSurah ? 22 : 14, 20, 24),
      decoration: BoxDecoration(
        color: AppColors.mushafPage,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.30), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.07),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Directionality(
        textDirection: material.TextDirection.rtl,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.showHeading) _SurahHeading(surah: widget.surah),
            if (widget.showBasmala) ...[
              const SizedBox(height: 18),
              Text(
                'بِسۡمِ ٱللَّهِ ٱلرَّحۡمَـٰنِ ٱلرَّحِیمِ',
                textAlign: TextAlign.center,
                style: AppTextStyles.mushaf(
                  fontSize: widget.fontSize * 0.95,
                  height: 1.8,
                ).copyWith(color: AppColors.primary),
              ),
              const SizedBox(height: 14),
            ] else if (widget.showHeading)
              // Only when something actually sits above the text. The old
              // unconditional `else` added this gap on every continuation
              // page, where there is nothing to separate it from.
              const SizedBox(height: 14),
            if (widget.ayahs.isNotEmpty && widget.ayahs.first.translation != null)
              // Translation mode: continuous justified Arabic flow doesn't
              // work once each ayah needs an LTR English block under it —
              // each ayah gets its own Arabic-then-translation pair instead.
              for (final ayah in widget.ayahs)
                Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: Container(
                    padding: bookmarkedAyahs.contains(ayah.numberInSurah)
                        ? const EdgeInsets.all(10)
                        : EdgeInsets.zero,
                    decoration: bookmarkedAyahs.contains(ayah.numberInSurah)
                        ? BoxDecoration(
                            color: AppColors.goldLight.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(10),
                          )
                        : null,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text.rich(
                          TextSpan(
                            style: AppTextStyles.mushaf(fontSize: widget.fontSize),
                            children: [
                              TextSpan(
                                text: '${ayah.text.trim()} ',
                                // Same recognizer as the rosette below —
                                // tapping the verse text itself now opens
                                // the same play/tafsir menu, not just the
                                // small end-mark.
                                recognizer: _recognizerFor(ayah),
                              ),
                              WidgetSpan(
                                alignment: PlaceholderAlignment.middle,
                                child: GestureDetector(
                                  onTap: () => _showAyahActions(ayah),
                                  child: _AyahRosette(
                                    number: ayah.numberInSurah,
                                    fontSize: widget.fontSize,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          textAlign: TextAlign.justify,
                        ),
                        const SizedBox(height: 6),
                        Directionality(
                          textDirection: material.TextDirection.ltr,
                          child: Text(
                            ayah.translation!,
                            textAlign: TextAlign.start,
                            style: TextStyle(
                              fontSize: widget.fontSize * 0.6,
                              color: AppColors.textSecondary,
                              height: 1.6,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
            else
              Text.rich(
                TextSpan(
                  children: [
                    for (final ayah in widget.ayahs) ...[
                      TextSpan(
                        text: ayah.text.trim(),
                        style: bookmarkedAyahs.contains(ayah.numberInSurah)
                            ? TextStyle(
                                backgroundColor: AppColors.goldLight
                                    .withValues(alpha: 0.35),
                              )
                            : null,
                        // Same recognizer as the rosette below — tapping
                        // the verse text itself now opens the same
                        // play/tafsir menu, not just the small end-mark.
                        recognizer: _recognizerFor(ayah),
                      ),
                      WidgetSpan(
                        alignment: PlaceholderAlignment.middle,
                        child: GestureDetector(
                          onTap: () => _showAyahActions(ayah),
                          child: _AyahRosette(
                            number: ayah.numberInSurah,
                            fontSize: widget.fontSize,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                textAlign: TextAlign.justify,
                style: AppTextStyles.mushaf(fontSize: widget.fontSize),
              ),
          ],
        ),
      ),
    );
  }
}

/// Decorative surah title band, in the spirit of a printed Mus'haf's
/// illuminated heading.
class _SurahHeading extends StatelessWidget {
  final Surah surah;
  const _SurahHeading({required this.surah});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.gold.withValues(alpha: 0.16),
            AppColors.gold.withValues(alpha: 0.05),
            AppColors.gold.withValues(alpha: 0.16),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          KhatimGlyph(size: 14, color: AppColors.gold, strokeWidth: 2),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              'سُورَةُ ${surah.name}',
              textAlign: TextAlign.center,
              style: AppTextStyles.mushaf(fontSize: 19, height: 1.6)
                  // AppColors.textPrimary, not the fixed primaryDark brand
                  // const: primaryDark happens to equal the *light*-mode
                  // text color exactly, so it looked right by coincidence
                  // in light mode but never inverted for dark mode, where
                  // it stayed the same dark green on a now-dark card —
                  // unreadable.
                  .copyWith(color: AppColors.textPrimary),
            ),
          ),
          const SizedBox(width: 12),
          KhatimGlyph(size: 14, color: AppColors.gold, strokeWidth: 2),
        ],
      ),
    );
  }
}

/// One sheet of the Mus'haf, magnifiable by pinching it.
///
/// Pinch only. A saved zoom applied to every page was worse in practice:
/// once magnified, panning is what a horizontal drag does, so every page
/// turn had to start from an un-zoomed page — and with the setting
/// persisted, no page ever was one. The reader could not turn a page at
/// all until they found the controls again.
///
/// Panning is likewise only enabled once magnified. At rest the page must
/// hand its horizontal drags to the PageView underneath, or turning the
/// page stops working — the InteractiveViewer would swallow the gesture
/// and move a page that has nowhere to go.
class _PinchPage extends StatefulWidget {
  final Widget child;

  /// Whether this is the page the reader is actually on.
  ///
  /// A page left magnified and swiped away stays magnified, and coming
  /// back to it later you cannot turn away again — so it is reset the
  /// moment it stops being the page in hand.
  final bool isCurrent;

  const _PinchPage({required this.child, required this.isCurrent});

  @override
  State<_PinchPage> createState() => _PinchPageState();
}

class _PinchPageState extends State<_PinchPage> {
  final _controller = TransformationController();
  bool _zoomed = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTransform);
  }

  @override
  void didUpdateWidget(covariant _PinchPage old) {
    super.didUpdateWidget(old);
    if (old.isCurrent && !widget.isCurrent && _zoomed) {
      _controller.value = Matrix4.identity();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onTransform);
    _controller.dispose();
    super.dispose();
  }

  void _onTransform() {
    // getMaxScaleOnAxis is the scale factor the matrix currently applies.
    final zoomed = _controller.value.getMaxScaleOnAxis() > 1.01;
    if (zoomed != _zoomed) setState(() => _zoomed = zoomed);
  }

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      transformationController: _controller,
      minScale: 1,
      maxScale: 4,
      panEnabled: _zoomed,
      // Double tap is not bound here: the page already uses single taps on
      // words, and a double tap would fire the first tap on the way.
      child: widget.child,
    );
  }
}

/// Opens the actions for one ayah: save a marker, play from here, tafsir.
///
/// At file scope because two different readers open it — the printed
/// Mus'haf page and the app's own text layout — and each keeping its own
/// copy is how the two quietly drift apart.
void showAyahActions({
  required BuildContext context,
  required WidgetRef ref,
  required Surah surah,
  required List<Ayah> ayahs,
  required Ayah ayah,
}) {
  HapticFeedback.selectionClick();
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => _AyahActionsSheet(
      ayahNumber: ayah.numberInSurah,
      onPlayFromHere: () => _playFromAyah(context, ref, surah, ayah),
      onShowTafsir: () => _showTafsir(context, surah, ayahs, ayah),
      onShowTajweed: () => _showTajweed(context, surah, ayah),
      onWordByWord: () => showWordByWord(
        context: context,
        surah: surah,
        ayahNumber: ayah.numberInSurah,
      ),
      isBookmarked: ref
          .read(bookmarksProvider.notifier)
          .isBookmarked(surah.number, ayah.numberInSurah),
      onToggleBookmark: (color) =>
          _toggleBookmark(context, ref, surah, ayah, color),
      currentColor: ref
          .read(bookmarksProvider.notifier)
          .colorOf(surah.number, ayah.numberInSurah),
    ),
  );
}

/// Saves or removes the ayah, confirming which of the two happened.
///
/// A marker leaves no visible trace on the page itself beyond a subtle
/// colour change, so without this the tap looks like it did nothing.
void _toggleBookmark(
  BuildContext context,
  WidgetRef ref,
  Surah surah,
  Ayah ayah,
  BookmarkColor color,
) {
  final saved = ref
      .read(bookmarksProvider.notifier)
      .toggle(surah.number, ayah.numberInSurah, color: color);
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 2),
        content: Text(
          (saved
                  ? 'quran_screen.bookmark_saved'
                  : 'quran_screen.bookmark_removed')
              .tr(namedArgs: {'ayah': '${ayah.numberInSurah}'}),
        ),
      ),
    );
}

Future<void> _playFromAyah(
  BuildContext context,
  WidgetRef ref,
  Surah surah,
  Ayah ayah,
) async {
  final reciter = ref.read(selectedReciterProvider);
  try {
    await playFromAyah(ref, surah, ayah.numberInSurah, reciter);
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('radio_screen.playback_error'.tr())),
    );
  }
}

/// Shows one verse with its tajweed rules coloured.
///
/// A sheet rather than the page itself: on the printed page every word is
/// a single pre-shaped glyph, and a rule applies to part of a word — half
/// a glyph cannot take its own colour. Rendered from the ordinary Uthmani
/// text, which can be split anywhere, the rules show properly.
void _showTajweed(BuildContext context, Surah surah, Ayah ayah) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _TajweedSheet(
      surah: surah,
      ayahNumber: ayah.numberInSurah,
    ),
  );
}

void _showTafsir(
  BuildContext context,
  Surah surah,
  List<Ayah> ayahs,
  Ayah ayah,
) {
  // The whole surah goes in, not just this ayah, so the sheet can page on
  // to the next one without being reopened. An ayah that somehow is not in
  // the list opens at the start rather than crashing on -1.
  final index = ayahs.indexWhere(
    (a) => a.numberInSurah == ayah.numberInSurah,
  );
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _TafsirSheet(
      surah: surah,
      ayahs: ayahs,
      initialIndex: index < 0 ? 0 : index,
    ),
  );
}

/// What tapping an ayah's rosette offers — kept as one small menu rather
/// than two separate tap targets/gestures on the same span (TextSpan only
/// supports one GestureRecognizer per span, so "play" and "tafsir" can't
/// just be a tap vs. a long-press on the same rosette).
class _AyahActionsSheet extends StatelessWidget {
  final int ayahNumber;
  final VoidCallback onPlayFromHere;
  final VoidCallback onShowTafsir;
  final VoidCallback onShowTajweed;
  final VoidCallback onWordByWord;

  /// Whether this ayah is already saved, so the row can offer the action
  /// the user actually wants rather than a toggle whose current state they
  /// have to guess at.
  final bool isBookmarked;
  final void Function(BookmarkColor) onToggleBookmark;

  /// The colour it is currently marked in, so the row can show which of
  /// the three is set rather than making the reader open it to find out.
  final BookmarkColor? currentColor;

  const _AyahActionsSheet({
    required this.ayahNumber,
    required this.onPlayFromHere,
    required this.onShowTafsir,
    required this.onShowTajweed,
    required this.onWordByWord,
    required this.isBookmarked,
    required this.onToggleBookmark,
    required this.currentColor,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
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
            const SizedBox(height: 16),
            Text(
              'quran_screen.ayah_actions_title'.tr(
                namedArgs: {'ayah': '$ayahNumber'},
              ),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 14),
            _AyahActionTile(
              icon: isBookmarked
                  ? Icons.bookmark_rounded
                  : Icons.bookmark_add_outlined,
              label: isBookmarked
                  ? 'quran_screen.remove_bookmark_action'.tr()
                  : 'quran_screen.save_bookmark_action'.tr(),
              onTap: () {
                Navigator.of(context).pop();
                onToggleBookmark(currentColor ?? BookmarkColor.green);
              },
            ),
            const SizedBox(height: 10),
            _BookmarkColorRow(
              selected: currentColor,
              onPick: (color) {
                Navigator.of(context).pop();
                onToggleBookmark(color);
              },
            ),
            const SizedBox(height: 10),
            _AyahActionTile(
              icon: Icons.play_circle_outline_rounded,
              label: 'quran_screen.play_from_ayah_action'.tr(),
              onTap: () {
                Navigator.of(context).pop();
                onPlayFromHere();
              },
            ),
            const SizedBox(height: 10),
            _AyahActionTile(
              icon: Icons.menu_book_outlined,
              label: 'quran_screen.show_tafsir'.tr(),
              onTap: () {
                Navigator.of(context).pop();
                onShowTafsir();
              },
            ),
            const SizedBox(height: 10),
            _AyahActionTile(
              icon: Icons.palette_outlined,
              label: 'quran_screen.show_tajweed'.tr(),
              onTap: () {
                Navigator.of(context).pop();
                onShowTajweed();
              },
            ),
            const SizedBox(height: 10),
            _AyahActionTile(
              icon: Icons.graphic_eq_rounded,
              label: 'quran_screen.word_by_word'.tr(),
              onTap: () {
                Navigator.of(context).pop();
                onWordByWord();
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// The three marker colours, as a row of labelled dots.
///
/// Shown next to the save action rather than behind it: the colour is
/// what makes a list of markers usable, and a reader who has to discover
/// a second menu to set one will simply never set one.
class _BookmarkColorRow extends StatelessWidget {
  final BookmarkColor? selected;
  final void Function(BookmarkColor) onPick;

  const _BookmarkColorRow({required this.selected, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final color in BookmarkColor.values)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onPick(color),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: color == selected
                          ? color.color
                          : AppColors.border,
                      width: color == selected ? 1.8 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: color.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        color.labelKey.tr(),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _AyahActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _AyahActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.primary),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows the Al-Muyassar tafsir for one ayah (see
/// QuranTextService.fetchTafsir) alongside the ayah's own text for
/// context, since the sheet doesn't sit next to the reader itself.
///
/// The whole surah is handed in, not just the tapped ayah, so the sheet
/// can be swiped (or stepped with the arrows) from one ayah to the next
/// without closing and re-opening it for each one — reading tafsir is
/// naturally sequential, and the tafsir map and translations are both
/// fetched per surah, so moving between ayahs costs nothing.
///
/// In the English locale the ayah's English translation is shown between
/// the two. The tafsir itself stays Arabic because there is no English
/// tafsir to fetch — every tafsir edition the Quran API publishes is
/// Arabic (ar.muyassar, ar.jalalayn, ar.qurtubi, ar.miqbas, ar.waseet,
/// ar.baghawi), and the English editions it offers are all plain
/// translations rather than commentary. So an English reader gets the
/// meaning of the verse from Saheeh International, and each block is
/// labelled with its own source rather than leaving them to guess which
/// language they're looking at.
class _TafsirSheet extends ConsumerStatefulWidget {
  final Surah surah;
  final List<Ayah> ayahs;
  final int initialIndex;

  const _TafsirSheet({
    required this.surah,
    required this.ayahs,
    required this.initialIndex,
  });

  @override
  ConsumerState<_TafsirSheet> createState() => _TafsirSheetState();
}

class _TafsirSheetState extends ConsumerState<_TafsirSheet> {
  late final PageController _controller = PageController(
    initialPage: widget.initialIndex,
  );
  late int _index = widget.initialIndex;

  /// One fetch for the whole surah, shared by every page — which is what
  /// makes paging between ayahs instant rather than a request each time.
  late final Future<Map<int, String>> _tafsirFuture;

  /// Ayah number -> English translation, or null outside the English
  /// locale. Normally resolves without touching the network: the reader
  /// loads the surah *with* translations whenever the app is in English,
  /// so the ayahs handed to this sheet already carry them. This only does
  /// real work when they don't — the reader's translation toggle is off —
  /// and it hits the same cache either way.
  Future<Map<int, String>>? _translationsFuture;
  bool _resolvedTranslations = false;

  @override
  void initState() {
    super.initState();
    _tafsirFuture = ref
        .read(quranTextServiceProvider)
        .fetchTafsir(widget.surah.number);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // context.locale reads an InheritedWidget, so it belongs here rather
    // than in initState.
    if (_resolvedTranslations) return;
    _resolvedTranslations = true;
    if (context.locale.languageCode != 'en') return;

    final alreadyLoaded = <int, String>{
      for (final a in widget.ayahs)
        if (a.translation != null && a.translation!.isNotEmpty)
          a.numberInSurah: a.translation!,
    };
    if (alreadyLoaded.length == widget.ayahs.length) {
      _translationsFuture = Future.value(alreadyLoaded);
      return;
    }
    _translationsFuture = ref
        .read(quranTextServiceProvider)
        .fetchSurah(widget.surah.number, includeTranslation: true)
        .then(
          (ayahs) => <int, String>{
            for (final a in ayahs)
              if (a.translation != null && a.translation!.isNotEmpty)
                a.numberInSurah: a.translation!,
          },
        );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goTo(int index) {
    if (index < 0 || index >= widget.ayahs.length) return;
    HapticFeedback.selectionClick();
    _controller.animateToPage(
      index,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.3,
        color: AppColors.textMuted,
      ),
    ),
  );

  Widget _navButton({
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? onTap : null,
      // Padded well past the icon's own 22px so the arrows clear the ~44dp
      // minimum touch target at the sheet's edges.
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Icon(
          icon,
          size: 22,
          color: enabled ? AppColors.primary : AppColors.iconMuted,
        ),
      ),
    );
  }

  /// The body for a single ayah. Each page scrolls independently, so a long
  /// tafsir on one ayah doesn't leave the next one scrolled halfway down.
  Widget _ayahPage(Ayah ayah) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primaryTint,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              ayah.text.trim(),
              textAlign: TextAlign.center,
              style: AppTextStyles.mushaf(fontSize: 19, height: 1.9),
            ),
          ),
          if (_translationsFuture != null) ...[
            const SizedBox(height: 18),
            FutureBuilder<Map<int, String>>(
              future: _translationsFuture,
              builder: (context, snapshot) {
                final translation = snapshot.data?[ayah.numberInSurah];
                // No spinner and no error row: the translation is
                // supporting context here, not the thing the sheet was
                // opened for, so a failure to load it should leave the
                // tafsir below perfectly usable rather than putting an
                // error in front of it.
                if (translation == null || translation.isEmpty) {
                  return const SizedBox.shrink();
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionLabel('quran_screen.tafsir_translation_source'.tr()),
                    Text(
                      translation,
                      textAlign: TextAlign.start,
                      style: TextStyle(
                        fontSize: 14.5,
                        color: AppColors.textPrimary,
                        height: 1.75,
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
          const SizedBox(height: 18),
          _sectionLabel('quran_screen.tafsir_source'.tr()),
          FutureBuilder<Map<int, String>>(
            future: _tafsirFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                );
              }
              final text = snapshot.hasError
                  ? null
                  : snapshot.data?[ayah.numberInSurah];
              if (text == null) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'quran_screen.tafsir_load_error'.tr(),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                );
              }
              return Text(
                text,
                textAlign: TextAlign.justify,
                style: TextStyle(
                  fontSize: 14.5,
                  color: AppColors.textPrimary,
                  height: 1.9,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final current = widget.ayahs[_index];

    return SafeArea(
      child: Container(
        // A fixed height rather than sizing to content: paging between a
        // one-line tafsir and a long one would otherwise make the sheet
        // jump size under the reader's finger on every swipe.
        height: MediaQuery.of(context).size.height * 0.78,
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 14),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  // Both the Row and the chevrons mirror themselves in RTL:
                  // the Row lays children start-to-end, and these icons are
                  // declared matchTextDirection, so Flutter flips the glyph
                  // too. Picking the glyph by directionality here as well
                  // was a *second* flip, which cancelled the first and left
                  // both arrows pointing inward at the title. The logical
                  // icon is the correct one to name; the framework handles
                  // the rest in both directions.
                  _navButton(
                    icon: Icons.chevron_left_rounded,
                    enabled: _index > 0,
                    onTap: () => _goTo(_index - 1),
                  ),
                  Expanded(
                    child: Text(
                      'quran_screen.tafsir_title'.tr(
                        namedArgs: {
                          'surah': surahDisplayName(widget.surah, context.locale.languageCode == 'ar'),
                          'ayah': '${current.numberInSurah}',
                        },
                      ),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  _navButton(
                    icon: Icons.chevron_right_rounded,
                    enabled: _index < widget.ayahs.length - 1,
                    onTap: () => _goTo(_index + 1),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'quran_screen.tafsir_position'.tr(
                namedArgs: {
                  'index': '${_index + 1}',
                  'total': '${widget.ayahs.length}',
                },
              ),
              style: TextStyle(fontSize: 10.5, color: AppColors.textMuted),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: widget.ayahs.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) => _ayahPage(widget.ayahs[i]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Renders a surah as the printed Mus'haf's own pages, swiped one at a
/// time, instead of one continuous scroll.
///
/// Page boundaries come from the API's per-ayah page number (see
/// splitIntoMushafPages), so what sits on a page here is what sits on that
/// page on paper. The page number is printed at the foot of each page, as
/// the Mus'haf does, which is what makes it possible to follow along with a
/// physical copy.
///
/// The PageView is not reversed: the app runs under RTL directionality, so
/// Flutter already lays page 1 on the right and advances leftward — the
/// same direction a Mus'haf turns.
class _MushafPageView extends ConsumerStatefulWidget {
  final Surah surah;
  final List<Ayah> ayahs;
  final bool showBasmala;
  final double fontSize;
  final int? startAyah;
  final ValueChanged<int> onFurthestAyahChanged;

  const _MushafPageView({
    required this.surah,
    required this.ayahs,
    required this.showBasmala,
    required this.fontSize,
    required this.startAyah,
    required this.onFurthestAyahChanged,
  });

  @override
  ConsumerState<_MushafPageView> createState() => _MushafPageViewState();
}

class _MushafPageViewState extends ConsumerState<_MushafPageView> {
  late final List<MushafPage> _pages = splitIntoMushafPages(widget.ayahs);
  late final int _initialIndex = widget.startAyah == null
      ? 0
      : mushafPageIndexForAyah(_pages, widget.startAyah!);
  late final PageController _controller = PageController(
    initialPage: _initialIndex,
  );
  late int _index = _initialIndex;

  @override
  void initState() {
    super.initState();
    // Opening straight onto a saved position counts as having reached it.
    WidgetsBinding.instance.addPostFrameCallback((_) => _report(_initialIndex));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Reaching a page means its last ayah has been reached — no scroll
  /// estimation needed here, unlike continuous mode where the position has
  /// to be inferred from pixel offset.
  void _report(int index) {
    if (index < 0 || index >= _pages.length) return;
    final ayahs = _pages[index].ayahs;
    if (ayahs.isEmpty) return;
    widget.onFurthestAyahChanged(ayahs.last.numberInSurah);
  }

  @override
  Widget build(BuildContext context) {
    if (_pages.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _controller,
            itemCount: _pages.length,
            onPageChanged: (i) {
              setState(() => _index = i);
              _report(i);
            },
            itemBuilder: (context, i) {
              final page = _pages[i];
              return SingleChildScrollView(
                // Each page scrolls on its own: a Mus'haf page at a large
                // font size can exceed the screen, and clipping the last
                // line of a page is not an option.
                padding: const EdgeInsets.fromLTRB(14, 16, 14, 8),
                child: _MushafPage(
                  surah: widget.surah,
                  ayahs: page.ayahs,
                  // Only the page that opens the surah carries the heading
                  // and Basmala, exactly as in print.
                  showBasmala: widget.showBasmala && page.startsSurah,
                  showHeading: page.startsSurah,
                  fontSize: widget.fontSize,
                ),
              );
            },
          ),
        ),
        _MushafPageFooter(
          pageNumber: _pages[_index].number,
          position: _index + 1,
          total: _pages.length,
        ),
      ],
    );
  }
}

/// The page number at the foot of the page, as the Mus'haf prints it,
/// with how far through the surah this page sits.
class _MushafPageFooter extends StatelessWidget {
  final int pageNumber;
  final int position;
  final int total;

  const _MushafPageFooter({
    required this.pageNumber,
    required this.position,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final arabic = context.locale.languageCode == 'ar';
    String n(int v) => arabic ? toArabicDigits('$v') : '$v';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      alignment: Alignment.center,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'quran_screen.mushaf_page'.tr(namedArgs: {'page': n(pageNumber)}),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
              height: 1.6,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '${n(position)} / ${n(total)}',
            style: TextStyle(fontSize: 10.5, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

/// A small selectable chip in the reading-style sheet.
class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MenuRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
        ),
      ],
    );
  }
}

/// The end-of-ayah marker: the khatim star with the ayah number centred in
/// it, drawn as a widget rather than as text.
///
/// It used to be the character U+06DD followed by Arabic-Indic digits.
/// U+06DD is a combining *enclosing* mark, so the digits are meant to
/// compose inside the circle — but the shaper doesn't compose them here, so
/// the digits landed beside the rosette instead of within it, and the whole
/// marker's width then grew with the digit count. That's what made the
/// numbers look ragged: a one-digit ayah and a three-digit one occupied
/// visibly different amounts of the justified line.
///
/// Drawn at a fixed box regardless of the number, so every marker down the
/// page is identical in size and the line rhythm stays even.
class _AyahRosette extends StatelessWidget {
  final int number;
  final double fontSize;

  const _AyahRosette({required this.number, required this.fontSize});

  @override
  Widget build(BuildContext context) {
    // Tied to the reading size so the marker scales with the text instead
    // of drifting out of proportion as the font size is changed.
    final box = fontSize * 1.5;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: fontSize * 0.14),
      child: SizedBox(
        width: box,
        height: box,
        child: Stack(
          alignment: Alignment.center,
          children: [
            KhatimGlyph(
              size: box,
              color: AppColors.gold.withValues(alpha: 0.85),
              strokeWidth: 1.1,
            ),
            // Scaled down rather than clipped: three digits have to fit the
            // same box as one.
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: EdgeInsets.all(box * 0.26),
                child: Text(
                  // Arabic-Indic digits only in the Arabic locale. The
                  // rosette hard-coded them, so an English reader saw "٢٨٦"
                  // where the rest of that screen showed 286.
                  context.locale.languageCode == 'ar'
                      ? arabicNumeral(number)
                      : '$number',
                  style: TextStyle(
                    fontSize: fontSize * 0.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                    height: 1,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TajweedSheet extends ConsumerWidget {
  final Surah surah;
  final int ayahNumber;

  const _TajweedSheet({required this.surah, required this.ayahNumber});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final arabic = context.locale.languageCode == 'ar';
    final spans = ref.watch(tajweedProvider('${surah.number}:$ayahNumber'));

    return SafeArea(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
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
              '${surahDisplayName(surah, arabic)} · '
              '${'quran_screen.ayah_n'.tr(namedArgs: {
                'n': arabic ? toArabicDigits('$ayahNumber') : '$ayahNumber',
              })}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: SingleChildScrollView(
                child: spans.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  error: (_, _) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      'quran_screen.tajweed_error'.tr(),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  data: (list) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.mushafPage,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.gold.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text.rich(
                          TextSpan(
                            children: [
                              for (final span in list)
                                TextSpan(
                                  text: span.text,
                                  style: span.rule == null
                                      ? null
                                      : TextStyle(
                                          color: kTajweedRules[span.rule]!
                                              .color,
                                        ),
                                ),
                            ],
                          ),
                          textAlign: TextAlign.center,
                          textDirection: material.TextDirection.rtl,
                          style: AppTextStyles.mushaf(
                            fontSize: 22,
                            height: 2.0,
                          ).copyWith(color: AppColors.mushafInk),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Only the rules this verse actually uses. The full
                      // set is sixteen, and a legend that long turns the
                      // sheet into a reference card nobody is reading.
                      for (final rule in rulesIn(list))
                        Padding(
                          padding: const EdgeInsets.only(bottom: 9),
                          child: Row(
                            children: [
                              Container(
                                width: 13,
                                height: 13,
                                decoration: BoxDecoration(
                                  color: kTajweedRules[rule]!.color,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  kTajweedRules[rule]!.nameKey.tr(),
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: AppColors.textPrimary,
                                    height: 1.6,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (rulesIn(list).isEmpty)
                        Text(
                          'quran_screen.tajweed_none'.tr(),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
