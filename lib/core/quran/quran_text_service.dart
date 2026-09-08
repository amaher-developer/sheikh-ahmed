import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class Ayah {
  final int numberInSurah;
  final String text;
  final int juz;

  /// The ayah's page in the standard 604-page Madani Mus'haf, straight
  /// from the API. This is what makes real page division possible — the
  /// boundaries are the printed Mus'haf's own, not a count of ayahs or
  /// characters, so a page here holds exactly what the page holds on paper.
  final int page;

  /// Saheeh International's English translation of this ayah — only
  /// populated when fetched with `includeTranslation: true` (the reader
  /// only asks for it in the English locale; Arabic reading stays pure
  /// Uthmani text, matching the printed Mus'haf).
  final String? translation;

  const Ayah({
    required this.numberInSurah,
    required this.text,
    required this.juz,
    required this.page,
    this.translation,
  });

  Map<String, dynamic> toJson() => {
    'n': numberInSurah,
    't': text,
    'j': juz,
    'p': page,
    if (translation != null) 'tr': translation,
  };

  factory Ayah.fromJson(Map<String, dynamic> json) => Ayah(
    numberInSurah: json['n'] as int,
    text: json['t'] as String,
    juz: json['j'] as int,
    page: (json['p'] as num?)?.toInt() ?? 0,
    translation: json['tr'] as String?,
  );
}

class QuranLoadException implements Exception {}

/// The Arabic edition, and the plain `quran-uthmani` rather than the
/// `-quran-academy` variant this used to fetch.
///
/// Both carry the same Madani page numbers (2:255 lands on page 42 either
/// way, which is where it is on paper), so the page division is unaffected.
/// They differ in orthography: the academy variant encodes the Uthmani marks
/// with KFGQPC-specific codepoints — U+06E1 in place of sukun, U+06CC in
/// place of yeh, U+06E4 for the small madda — which render only in fonts
/// built for that scheme and look broken or blank in anything else. This one
/// uses the ordinary Arabic codepoints (U+0652, U+064A, U+0653, U+0670) that
/// every Arabic font supports.
///
/// "Saheeh International" is one of the most widely used English
/// translations.
const _arabicEdition = 'quran-uthmani';
const _translationEdition = 'en.sahih';

/// Al-Muyassar — a concise, general-audience tafsir from the King Fahd
/// Quran Complex (the same publishing authority behind the standard
/// Uthmani Mus'haf this app already uses), fetched only on demand (see
/// [QuranTextService.fetchTafsir]) rather than alongside every surah open,
/// since tafsir text runs long enough per ayah that pulling it in
/// automatically would slow down and bloat ordinary reading for anyone
/// who never opens it.
const _tafsirEdition = 'ar.muyassar';

/// The API prefixes the Basmala onto ayah 1 of every surah except
/// At-Tawbah (9). The reader renders it as its own centered heading (as the
/// Mus'haf does), so it has to come off the verse text or it shows twice.
/// Matched by letter skeleton with diacritics/tatweel/alef-variants allowed
/// between letters, so it survives the API's Uthmani orthography. Only the
/// Arabic text carries this prefix — the English translation edition
/// doesn't repeat it, so no equivalent stripping is needed there.
final _basmalaPattern = RegExp(
  r'^[ء-يٰ-ۿً-ْـ\s]{0,12}?'
  r'ب\p{Mn}*س\p{Mn}*م\p{Mn}*\s*[اٱ]\p{Mn}*ل\p{Mn}*ل\p{Mn}*ه\p{Mn}*\s*'
  r'[اٱ]\p{Mn}*ل\p{Mn}*ر\p{Mn}*ح\p{Mn}*[مـ]\p{Mn}*[ـٰ]*ن\p{Mn}*\s*'
  r'[اٱ]\p{Mn}*ل\p{Mn}*ر\p{Mn}*ح\p{Mn}*[يی]\p{Mn}*م\p{Mn}*\s*',
  unicode: true,
);

String _stripBasmala(String text) =>
    text.replaceFirst(_basmalaPattern, '').trim();

/// Fetches the actual Quranic text (and, optionally, its English
/// translation). Nothing here is authored in this codebase — it's read
/// from a public Quran API — but unlike a plain in-memory cache, every
/// surah successfully fetched is also written to disk (see
/// [_storageKey]), so once a surah has been opened once it stays readable
/// with no connection, including after the app is fully closed and
/// reopened. The in-memory [_cache] just avoids re-parsing that stored
/// JSON on every rebuild within the same session.
class QuranTextService {
  final SharedPreferences _prefs;

  QuranTextService(this._prefs);

  final Map<String, List<Ayah>> _cache = {};
  final Map<int, Map<int, String>> _tafsirCache = {};

  /// The `.v3` is a cache generation, bumped whenever the stored text or
  /// [Ayah]'s shape changes — v3 is the move to the plain `quran-uthmani`
  /// edition (see [_arabicEdition]). It has to move with the edition:
  /// anything already on disk was written from the old one, and without a new
  /// prefix every device would keep serving that from cache and never see the
  /// change at all.
  ///
  /// Orphaning the old generation is cheap. This is only the text, a few tens
  /// of KB per surah, and it is unrelated to the downloaded recitation audio,
  /// which lives in files and is untouched.
  String _storageKey(int surahNumber, bool includeTranslation) =>
      'quran.text.v3.$surahNumber.${includeTranslation ? 'tr' : 'ar'}';

  String _tafsirStorageKey(int surahNumber) => 'quran.tafsir.$surahNumber';

  /// How many surahs' text is already stored on this device.
  ///
  /// Counts the Arabic entries only. That is what makes the reader work with
  /// no connection; the translation copy is a second, optional cache written
  /// under the same scheme with a `tr` suffix, and counting both would report
  /// well over 114.
  ///
  /// Reads the keys rather than tracking a counter so it stays correct across
  /// a cache-generation bump: entries from an older generation carry a
  /// different prefix and simply stop counting, which is exactly right, since
  /// they will be refetched.
  int cachedSurahCount() {
    final prefix = _storageKey(0, false).replaceFirst('.0.ar', '.');
    return _prefs
        .getKeys()
        .where((k) => k.startsWith(prefix) && k.endsWith('.ar'))
        .length;
  }

  /// Maps the API's ayah JSON into [Ayah]s, removing the Basmala the API
  /// prefixes onto ayah 1 (see [_basmalaPattern]). Surah 1's ayah 1 *is*
  /// the Basmala and surah 9 has none, so both are left untouched.
  /// [translationJson], if given, must be the same surah's ayahs from the
  /// translation edition — same length and order, paired up by index.
  static List<Ayah> parseAyahs(
    int surahNumber,
    List<dynamic> ayahsJson, {
    List<dynamic>? translationJson,
  }) {
    final stripFirstBasmala = surahNumber != 1 && surahNumber != 9;
    return List.generate(ayahsJson.length, (i) {
      final a = ayahsJson[i] as Map<String, dynamic>;
      final numberInSurah = a['numberInSurah'] as int;
      final raw = a['text'] as String;
      final translation = translationJson != null && i < translationJson.length
          ? ((translationJson[i] as Map<String, dynamic>)['text'] as String)
                .trim()
          : null;
      return Ayah(
        numberInSurah: numberInSurah,
        text: stripFirstBasmala && numberInSurah == 1
            ? _stripBasmala(raw)
            : raw.trim(),
        juz: a['juz'] as int,
        // Tolerated as missing rather than cast outright: page only drives
        // how the reader is *divided*, so an edition that omits it should
        // cost the page split, not the surah. A hard cast here would fail
        // the whole fetch and leave the reader unable to show the text at
        // all. Zero collapses to a single page (see splitIntoMushafPages).
        page: (a['page'] as num?)?.toInt() ?? 0,
        translation: translation,
      );
    });
  }

  Future<List<Ayah>> fetchSurah(
    int surahNumber, {
    bool includeTranslation = false,
  }) async {
    final cacheKey = '$surahNumber:$includeTranslation';
    final cached = _cache[cacheKey];
    if (cached != null) return cached;

    final storageKey = _storageKey(surahNumber, includeTranslation);
    final stored = _prefs.getString(storageKey);
    if (stored != null) {
      final ayahs = (jsonDecode(stored) as List)
          .map((e) => Ayah.fromJson(e as Map<String, dynamic>))
          .toList();
      _cache[cacheKey] = ayahs;
      return ayahs;
    }

    final editions = includeTranslation
        ? '$_arabicEdition,$_translationEdition'
        : _arabicEdition;
    final uri = Uri.parse(
      'https://api.alquran.cloud/v1/surah/$surahNumber/editions/$editions',
    );
    http.Response response;
    try {
      response = await http.get(uri).timeout(const Duration(seconds: 15));
    } catch (_) {
      throw QuranLoadException();
    }

    if (response.statusCode != 200) throw QuranLoadException();

    final Map<String, dynamic> body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw QuranLoadException();
    }

    final editionsData = body['data'] as List<dynamic>?;
    final ayahsJson =
        (editionsData?.isNotEmpty ?? false)
            ? (editionsData![0] as Map<String, dynamic>)['ayahs']
                  as List<dynamic>?
            : null;
    if (ayahsJson == null) throw QuranLoadException();

    final translationJson =
        includeTranslation && (editionsData?.length ?? 0) > 1
            ? (editionsData![1] as Map<String, dynamic>)['ayahs']
                  as List<dynamic>?
            : null;

    final ayahs = parseAyahs(
      surahNumber,
      ayahsJson,
      translationJson: translationJson,
    );

    _cache[cacheKey] = ayahs;
    // Best-effort: a write failure (e.g. storage full) shouldn't break
    // reading the surah that was just successfully fetched.
    unawaited(
      _prefs.setString(
        storageKey,
        jsonEncode(ayahs.map((a) => a.toJson()).toList()),
      ),
    );
    return ayahs;
  }

  /// The Al-Muyassar tafsir for every ayah in [surahNumber], keyed by
  /// numberInSurah — opt-in and cached separately from [fetchSurah] (see
  /// [_tafsirEdition]'s doc comment for why). Same offline-first pattern
  /// as the main text: checked in memory, then on disk, and only hits the
  /// network the first time this surah's tafsir is actually opened.
  Future<Map<int, String>> fetchTafsir(int surahNumber) async {
    final cached = _tafsirCache[surahNumber];
    if (cached != null) return cached;

    final storageKey = _tafsirStorageKey(surahNumber);
    final stored = _prefs.getString(storageKey);
    if (stored != null) {
      final decoded = (jsonDecode(stored) as Map<String, dynamic>).map(
        (k, v) => MapEntry(int.parse(k), v as String),
      );
      _tafsirCache[surahNumber] = decoded;
      return decoded;
    }

    final uri = Uri.parse(
      'https://api.alquran.cloud/v1/surah/$surahNumber/editions/$_tafsirEdition',
    );
    http.Response response;
    try {
      response = await http.get(uri).timeout(const Duration(seconds: 15));
    } catch (_) {
      throw QuranLoadException();
    }

    if (response.statusCode != 200) throw QuranLoadException();

    final Map<String, dynamic> body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw QuranLoadException();
    }

    final editionsData = body['data'] as List<dynamic>?;
    final ayahsJson =
        (editionsData?.isNotEmpty ?? false)
            ? (editionsData![0] as Map<String, dynamic>)['ayahs']
                  as List<dynamic>?
            : null;
    if (ayahsJson == null) throw QuranLoadException();

    final result = <int, String>{
      for (final a in ayahsJson)
        (a as Map<String, dynamic>)['numberInSurah'] as int:
            (a['text'] as String).trim(),
    };

    _tafsirCache[surahNumber] = result;
    unawaited(
      _prefs.setString(
        storageKey,
        jsonEncode(result.map((k, v) => MapEntry('$k', v))),
      ),
    );
    return result;
  }
}
