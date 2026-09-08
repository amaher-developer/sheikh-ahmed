import 'package:audio_service/audio_service.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../audio/audio_providers.dart';
import '../prayer/prayer_providers.dart'
    show currentDateKeyProvider, sharedPreferencesProvider;
import '../theme/app_text_styles.dart';
import '../utils/date_key.dart';
import 'audio_download_providers.dart';
import 'quran_text_service.dart';
import 'reciter_data.dart';
import 'surah_meta.dart';

/// Where the user last stopped reading — surah + ayah number — so
/// "continue reading" resumes the real position instead of a fixed surah.
class ReadingPosition {
  final int surahNumber;
  final int ayahNumber;

  const ReadingPosition({required this.surahNumber, required this.ayahNumber});
}

class QuranReadingRepository {
  final SharedPreferences _prefs;

  QuranReadingRepository(this._prefs);

  static const _kSurah = 'quran.reading.surah';
  static const _kAyah = 'quran.reading.ayah';
  static const _kReciter = 'quran.reciter';
  static const _kFontSize = 'quran.fontSize';
  static const _kPageMode = 'quran.pageMode';
  static const _kPrintedMushaf = 'quran.printedMushaf';
  static const _kFont = 'quran.font';
  static const _kBold = 'quran.fontBold';
  static const _kLastReadDate = 'quran.reading.lastDate';

  ReadingPosition load() {
    final surah = _prefs.getInt(_kSurah) ?? 18;
    final ayah = _prefs.getInt(_kAyah) ?? 1;
    return ReadingPosition(surahNumber: surah, ayahNumber: ayah);
  }

  Future<void> save(ReadingPosition position) async {
    await _prefs.setInt(_kSurah, position.surahNumber);
    await _prefs.setInt(_kAyah, position.ayahNumber);
    // Tracked so the worship tracker can show "read today" without
    // duplicating this screen's own position storage.
    await _prefs.setString(_kLastReadDate, dateKey(DateTime.now()));
  }

  /// Whether the Quran was read at all today, from the date stamped by
  /// [save] — so the worship tracker can answer it without keeping its own
  /// copy of the reading position.
  bool readToday() =>
      _prefs.getString(_kLastReadDate) == dateKey(DateTime.now());

  /// Nullable: findReciter treats a missing id as the default reciter, so
  /// there is no need to name one here as well.
  String? loadReciterId() => _prefs.getString(_kReciter);

  Future<void> saveReciterId(String id) => _prefs.setString(_kReciter, id);

  double loadFontSize() =>
      (_prefs.getDouble(_kFontSize) ?? kDefaultQuranFontSize)
          .clamp(kMinQuranFontSize, kMaxQuranFontSize);

  Future<void> saveFontSize(double size) =>
      _prefs.setDouble(_kFontSize, size);

  bool loadPageMode() => _prefs.getBool(_kPageMode) ?? false;

  Future<void> savePageMode(bool value) => _prefs.setBool(_kPageMode, value);

  bool loadPrintedMushaf() => _prefs.getBool(_kPrintedMushaf) ?? true;

  Future<void> savePrintedMushaf(bool value) =>
      _prefs.setBool(_kPrintedMushaf, value);

  String loadFont() => _prefs.getString(_kFont) ?? 'ScheherazadeNew';

  Future<void> saveFont(String family) => _prefs.setString(_kFont, family);

  bool loadFontBold() => _prefs.getBool(_kBold) ?? false;

  Future<void> saveFontBold(bool value) => _prefs.setBool(_kBold, value);
}

const kDefaultQuranFontSize = 22.0;
const kMinQuranFontSize = 16.0;
const kMaxQuranFontSize = 40.0;

final quranReadingRepositoryProvider = Provider<QuranReadingRepository>((ref) {
  return QuranReadingRepository(ref.watch(sharedPreferencesProvider));
});

final quranTextServiceProvider = Provider<QuranTextService>(
  (ref) => QuranTextService(ref.watch(sharedPreferencesProvider)),
);

class ReadingPositionNotifier extends StateNotifier<ReadingPosition> {
  final QuranReadingRepository _repo;

  ReadingPositionNotifier(this._repo) : super(_repo.load());

  Future<void> update(int surahNumber, int ayahNumber) async {
    final position = ReadingPosition(
      surahNumber: surahNumber,
      ayahNumber: ayahNumber,
    );
    state = position;
    await _repo.save(position);
  }
}

final readingPositionProvider =
    StateNotifierProvider<ReadingPositionNotifier, ReadingPosition>((ref) {
      return ReadingPositionNotifier(ref.watch(quranReadingRepositoryProvider));
    });

class ReciterNotifier extends StateNotifier<Reciter> {
  final QuranReadingRepository _repo;

  ReciterNotifier(this._repo) : super(findReciter(_repo.loadReciterId()));

  Future<void> select(Reciter reciter) async {
    state = reciter;
    await _repo.saveReciterId(reciter.id);
  }
}

final selectedReciterProvider = StateNotifierProvider<ReciterNotifier, Reciter>(
  (ref) {
    return ReciterNotifier(ref.watch(quranReadingRepositoryProvider));
  },
);

/// Reader font size, persisted so it survives reopening the app.
class QuranFontSizeNotifier extends StateNotifier<double> {
  final QuranReadingRepository _repo;

  QuranFontSizeNotifier(this._repo) : super(_repo.loadFontSize());

  Future<void> set(double size) async {
    final clamped = size.clamp(kMinQuranFontSize, kMaxQuranFontSize);
    if (clamped == state) return;
    state = clamped;
    await _repo.saveFontSize(clamped);
  }

  Future<void> increase() => set(state + 2);
  Future<void> decrease() => set(state - 2);
}

/// Whether the reader shows real Mus'haf pages (see splitIntoMushafPages)
/// rather than one continuous scroll per surah.
class QuranPageModeNotifier extends StateNotifier<bool> {
  final QuranReadingRepository _repo;

  QuranPageModeNotifier(this._repo) : super(_repo.loadPageMode());

  Future<void> toggle() async {
    state = !state;
    await _repo.savePageMode(state);
  }
}

/// Whether to render the real printed Mus'haf page instead of the app's
/// own reflowed text.
///
/// Kept separate from [quranPageModeProvider] rather than folded into one
/// three-way setting: that one chooses how *this* app lays the text out and
/// respects the reader's font size, while this replaces the layout wholesale
/// with the printed page, where the size is fixed by the page itself. They
/// are different questions and a single control would have to explain that.
class PrintedMushafNotifier extends StateNotifier<bool> {
  final QuranReadingRepository _repo;

  PrintedMushafNotifier(this._repo) : super(_repo.loadPrintedMushaf());

  Future<void> toggle() async {
    state = !state;
    await _repo.savePrintedMushaf(state);
  }
}

final printedMushafProvider =
    StateNotifierProvider<PrintedMushafNotifier, bool>((ref) {
      return PrintedMushafNotifier(ref.watch(quranReadingRepositoryProvider));
    });

final quranPageModeProvider =
    StateNotifierProvider<QuranPageModeNotifier, bool>((ref) {
      return QuranPageModeNotifier(ref.watch(quranReadingRepositoryProvider));
    });

/// The Mus'haf face and weight. Applied by mutating AppTextStyles rather
/// than threaded through every widget, matching how AppColors handles the
/// theme in this codebase — see [QuranReadingStyle.apply].
class QuranReadingStyle {
  final String family;
  final bool bold;

  const QuranReadingStyle({required this.family, required this.bold});

  QuranReadingStyle copyWith({String? family, bool? bold}) =>
      QuranReadingStyle(family: family ?? this.family, bold: bold ?? this.bold);

  void apply() {
    AppTextStyles.mushafFamily = family;
    AppTextStyles.mushafBold = bold;
  }
}

/// The faces offered in the reader. Both were verified to carry every
/// Uthmani mark the Quran API returns before being offered — a face that
/// misses them renders verses with missing and misplaced diacritics.
const kQuranFonts = <String, String>{
  'ScheherazadeNew': 'شهرزاد',
  'AmiriQuran': 'أميري',
};

class QuranReadingStyleNotifier extends StateNotifier<QuranReadingStyle> {
  final QuranReadingRepository _repo;

  QuranReadingStyleNotifier(this._repo)
    : super(QuranReadingStyle(
        family: _repo.loadFont(),
        bold: _repo.loadFontBold(),
      )) {
    // Applied at construction, not only on change: the statics have to
    // match the stored choice from the very first frame the reader paints.
    state.apply();
  }

  Future<void> setFamily(String family) async {
    state = state.copyWith(family: family);
    state.apply();
    await _repo.saveFont(family);
  }

  Future<void> setBold(bool bold) async {
    state = state.copyWith(bold: bold);
    state.apply();
    await _repo.saveFontBold(bold);
  }
}

final quranReadingStyleProvider =
    StateNotifierProvider<QuranReadingStyleNotifier, QuranReadingStyle>((ref) {
      return QuranReadingStyleNotifier(ref.watch(quranReadingRepositoryProvider));
    });

final quranFontSizeProvider =
    StateNotifierProvider<QuranFontSizeNotifier, double>((ref) {
      return QuranFontSizeNotifier(ref.watch(quranReadingRepositoryProvider));
    });

/// The "continue reading" surah, resolved from the saved position.
final continueReadingSurahProvider = Provider<Surah>((ref) {
  final position = ref.watch(readingPositionProvider);
  return surahByNumber(position.surahNumber);
});

/// Whether the Quran reader was opened today — watches [readingPositionProvider]
/// only so the worship tracker updates the instant a session's reading
/// position is first saved, without needing its own separate state.
final readQuranTodayProvider = Provider<bool>((ref) {
  ref.watch(readingPositionProvider);
  // Also re-checked on a day change, not just when the reading position
  // changes — otherwise "read today" would stay true into the next day
  // for as long as the app is kept open.
  ref.watch(currentDateKeyProvider);
  return ref.watch(quranReadingRepositoryProvider).readToday();
});

/// Extra keys stashed on a Quran [MediaItem] so the audio handler's
/// completion callback can figure out what "next" means without the
/// handler itself knowing anything about surahs or reciters.
const _kSurahNumberExtra = 'surahNumber';
const _kReciterIdExtra = 'reciterId';
const _kAyahNumberExtra = 'ayahNumber';

MediaItem quranMediaItem(Surah surah, Reciter reciter, {String? localPath}) =>
    MediaItem(
      id: localPath ?? reciter.audioUrl(surah.number),
      title: surah.name,
      // Translated here, not at the call site: this string goes straight to
      // the lock screen / notification, which would otherwise show the raw
      // key.
      artist: reciter.nameKey.tr(),
      extras: {_kSurahNumberExtra: surah.number, _kReciterIdExtra: reciter.id},
    );

/// [quranMediaItem], but preferring a downloaded local file over streaming
/// the remote URL when [surah] has been downloaded for [reciter] — this is
/// what actually makes a downloaded surah play offline instead of just
/// sitting on disk unused. Looked up synchronously against the in-memory
/// downloaded-set (see [DownloadedSurahsNotifier]), never awaited, so it's
/// safe to call from the audio handler's completion callback.
MediaItem _resolvedQuranMediaItem(WidgetRef ref, Surah surah, Reciter reciter) {
  final localPath = ref
      .read(downloadedSurahsProvider.notifier)
      .cachedLocalPath(reciter, surah.number);
  return quranMediaItem(surah, reciter, localPath: localPath);
}

/// A single-ayah track (see [Reciter.ayahAudioUrl]) — only used to start
/// playback partway through a surah; once it reaches the surah's last ayah,
/// [playFromAyah]'s resolver hands off to the ordinary full-surah track
/// rather than stringing hundreds of individual ayah files together.
MediaItem _ayahMediaItem(Surah surah, int ayahNumber, Reciter reciter) =>
    MediaItem(
      id: reciter.ayahAudioUrl(surah.number, ayahNumber),
      title: '${surah.name} · $ayahNumber',
      artist: reciter.nameKey.tr(),
      extras: {
        _kSurahNumberExtra: surah.number,
        _kAyahNumberExtra: ayahNumber,
        _kReciterIdExtra: reciter.id,
      },
    );

/// Plays [surah] with [reciter] and arms the handler to keep going into the
/// next surah (same reciter) as soon as the current one finishes — so
/// listening flows surah after surah instead of stopping after one.
Future<void> playSurahWithAutoAdvance(
  WidgetRef ref,
  Surah surah,
  Reciter reciter,
) async {
  final handler = ref.read(audioHandlerProvider);
  handler.nextItemResolver = (finished) async {
    final surahNumber = finished.extras?[_kSurahNumberExtra] as int?;
    final reciterId = finished.extras?[_kReciterIdExtra] as String?;
    if (surahNumber == null || reciterId == null || surahNumber >= 114) {
      return null;
    }
    return _resolvedQuranMediaItem(
      ref,
      surahByNumber(surahNumber + 1),
      findReciter(reciterId),
    );
  };
  handler.previousItemResolver = (current) async {
    final surahNumber = current.extras?[_kSurahNumberExtra] as int?;
    final reciterId = current.extras?[_kReciterIdExtra] as String?;
    if (surahNumber == null || reciterId == null || surahNumber <= 1) {
      return null;
    }
    return _resolvedQuranMediaItem(
      ref,
      surahByNumber(surahNumber - 1),
      findReciter(reciterId),
    );
  };
  await toggleAudio(ref, _resolvedQuranMediaItem(ref, surah, reciter));
}

/// Starts playback of [surah] from [ayahNumber] onward — e.g. tapping a
/// specific verse in the reader — rather than always from the top. Plays
/// single-ayah tracks (see [Reciter.ayahAudioUrl]) through the rest of the
/// surah, then continues into the next surah's ordinary full track, same as
/// [playSurahWithAutoAdvance].
Future<void> playFromAyah(
  WidgetRef ref,
  Surah surah,
  int ayahNumber,
  Reciter reciter,
) async {
  final handler = ref.read(audioHandlerProvider);
  handler.nextItemResolver = (finished) async {
    final surahNumber = finished.extras?[_kSurahNumberExtra] as int?;
    final reciterId = finished.extras?[_kReciterIdExtra] as String?;
    final ayah = finished.extras?[_kAyahNumberExtra] as int?;
    if (surahNumber == null || reciterId == null) return null;
    final nextReciter = findReciter(reciterId);

    if (ayah != null) {
      // Still working through single-ayah tracks within this surah.
      final currentSurah = surahByNumber(surahNumber);
      if (ayah < currentSurah.ayahCount) {
        return _ayahMediaItem(currentSurah, ayah + 1, nextReciter);
      }
    }
    if (surahNumber >= 114) return null;
    return _resolvedQuranMediaItem(ref, surahByNumber(surahNumber + 1), nextReciter);
  };
  handler.previousItemResolver = (current) async {
    final surahNumber = current.extras?[_kSurahNumberExtra] as int?;
    final reciterId = current.extras?[_kReciterIdExtra] as String?;
    final ayah = current.extras?[_kAyahNumberExtra] as int?;
    if (surahNumber == null || reciterId == null) return null;
    final prevReciter = findReciter(reciterId);

    if (ayah != null && ayah > 1) {
      return _ayahMediaItem(surahByNumber(surahNumber), ayah - 1, prevReciter);
    }
    // At ayah 1 (or already past the per-ayah tracks, playing the
    // full-surah track) — go back into the previous surah's last ayah.
    if (surahNumber <= 1) return null;
    final previousSurah = surahByNumber(surahNumber - 1);
    return _ayahMediaItem(previousSurah, previousSurah.ayahCount, prevReciter);
  };
  await toggleAudio(ref, _ayahMediaItem(surah, ayahNumber, reciter));
}
