import 'hizb_meta.dart';

/// One word as the printed Mus'haf sets it.
///
/// [glyph] is not readable Arabic. It is a Private Use Area codepoint that
/// only means anything in that page's own font: the King Fahd Complex ships a
/// separate font per page whose glyphs are pre-shaped to fill that page's
/// fifteen lines exactly, which is how a Mus'haf page is identical in every
/// printed copy. Render it in any other font and you get boxes.
class MushafWord {
  final String glyph;

  /// 1..15 — which printed line this word sits on.
  final int line;

  /// True for the ayah-number rosette that closes a verse. It is a word in
  /// the font like any other, but it is not part of the verse text and must
  /// not be coloured with it.
  final bool isEnd;

  /// True for لفظ الجلالة, which the printed Mus'haf sets in red.
  ///
  /// Decided from the word's readable Uthmani spelling rather than its glyph:
  /// glyph codes differ from page to page, so the same word has a different
  /// codepoint on every page it appears and could never be matched by code.
  final bool isJalalah;

  /// The surah this word belongs to, and the ayah within it.
  ///
  /// Carried per word because a printed page is not a list of ayahs: a
  /// line runs straight through a verse boundary, and a page routinely
  /// spans two surahs. Without this a tap on the page has no way to say
  /// which verse was touched.
  final int surah;
  final int ayah;

  const MushafWord({
    required this.glyph,
    required this.line,
    required this.isEnd,
    required this.isJalalah,
    required this.surah,
    required this.ayah,
  });

  Map<String, dynamic> toJson() => {
    'g': glyph,
    'l': line,
    's': surah,
    'a': ayah,
    if (isEnd) 'e': 1,
    if (isJalalah) 'j': 1,
  };

  factory MushafWord.fromJson(Map<String, dynamic> j) => MushafWord(
    glyph: j['g'] as String,
    line: (j['l'] as num).toInt(),
    surah: (j['s'] as num).toInt(),
    ayah: (j['a'] as num).toInt(),
    isEnd: j['e'] == 1,
    isJalalah: j['j'] == 1,
  );
}

/// Every page of the Madani Mus'haf is set in fifteen lines, except the
/// first two, which sit in a decorative frame and carry fewer.
const kLinesPerPage = 15;

/// The two pages set in the decorative frame rather than on the grid.
const kFramedPages = 2;

/// One row of a printed page: a line of verse, a surah heading, the
/// basmala that follows one, or a line the page leaves empty.
class MushafRow {
  final List<MushafWord>? words;
  final int? surahHeading;
  final bool isBasmala;
  final bool isBlank;

  const MushafRow.text(this.words)
    : surahHeading = null,
      isBasmala = false,
      isBlank = false;
  const MushafRow.heading(this.surahHeading)
    : words = null,
      isBasmala = false,
      isBlank = false;
  const MushafRow.basmala()
    : words = null,
      surahHeading = null,
      isBasmala = true,
      isBlank = false;

  /// A line slot the page prints nothing on.
  ///
  /// Kept rather than dropped because it is part of the page. Page 594
  /// ends al-Balad on line 14 and leaves line 15 empty; dropping it left
  /// the page with fourteen rows, which read as a short page and got
  /// centred — the whole text pushed down from the top with a band of
  /// white above it.
  const MushafRow.blank()
    : words = null,
      surahHeading = null,
      isBasmala = false,
      isBlank = true;
}

class MushafPageData {
  final int page;
  final List<MushafWord> words;

  /// Verse keys ("2:253") present on the page, in order — used for the
  /// header and to know which surah a page belongs to.
  final List<String> verseKeys;

  /// The juz this page opens in — what a printed page names in its
  /// header. Taken from the first verse rather than the last, so a page
  /// that crosses a juz boundary is labelled by where it starts, the way
  /// the printed one is.
  final int juz;

  const MushafPageData({
    required this.page,
    required this.words,
    required this.verseKeys,
    required this.juz,
  });

  /// Every printed line of the page, 1..15, including the blank ones.
  ///
  /// The blanks are the point. A printed page leaves a line empty exactly
  /// where a surah heading and its basmala sit, and the source reports no
  /// words for those lines — page 2 starts at line 3, page 604 runs
  /// 3,4 … 7,8,9 … 12. Those gaps are the only signal that a new surah
  /// begins on the page, so a view that drops them (as [lines] does)
  /// cannot draw the heading.
  Map<int, List<MushafWord>> get linesByNumber {
    final byLine = <int, List<MushafWord>>{};
    for (final w in words) {
      (byLine[w.line] ??= []).add(w);
    }
    return byLine;
  }

  /// The surah whose first verse begins on [line], or null.
  ///
  /// Only ayah 1 counts: a surah continuing onto the page did not begin
  /// there and takes no heading.
  int? surahBeginningOn(int line) {
    final first = linesByNumber[line]?.firstOrNull;
    if (first == null || first.ayah != 1) return null;
    return first.surah;
  }

  /// The quarter-hizb this page opens in, or null for an empty page.
  ///
  /// Read from the first word for the same reason [juz] is read from the
  /// first verse: a page routinely crosses a boundary, and the printed
  /// header names where the page *starts*, not where it ends.
  HizbQuarter? get hizbQuarter {
    if (words.isEmpty) return null;
    final first = words.first;
    return hizbQuarterFor(first.surah, first.ayah);
  }

  /// Whether a prostration falls anywhere on this page.
  ///
  /// Checked across every word, not just the first: unlike the juz and the
  /// hizb this is not a label for the page but a thing on it, and a reciter
  /// needs to know before they reach the bottom.
  bool get hasSajda => words.any((w) => isSajdaAyah(w.surah, w.ayah));

  /// The page split into its printed rows, surah headings included.
  ///
  /// The blank line numbers are what carry the headings. A page reports no
  /// words for the lines a heading and its basmala occupy, and how many are
  /// blank says which of the two is there:
  ///
  /// * one blank — the heading alone. Either the surah has no basmala (at
  ///   Tawbah), or its basmala is verse 1 and already among the words (al
  ///   Fatiha). Page 187 and page 1 respectively.
  /// * two blanks — heading then basmala. Page 106, where an-Nisa ends on
  ///   line 5 and al-Maida opens on line 8.
  ///
  /// So no surah needs special-casing here: the count already says it.
  ///
  /// Any blank a heading does not account for is a line the page leaves
  /// empty, and is kept as one. The grid is what makes a Mus'haf page a
  /// Mus'haf page: the lines sit where they sit whether or not there is
  /// text on all of them.
  List<MushafRow> get rows {
    final byLine = linesByNumber;
    final present = byLine.keys.toList()..sort();
    if (present.isEmpty) return const [];

    final result = <MushafRow>[];
    var line = 1;

    while (line <= slotCount) {
      final lineWords = byLine[line];
      if (lineWords != null) {
        result.add(MushafRow.text(lineWords));
        line++;
        continue;
      }

      // A run of blanks, and whatever begins after it.
      var next = line;
      while (next <= slotCount && byLine[next] == null) {
        next++;
      }
      final blanks = next - line;
      final surah = surahBeginningOn(next);

      if (surah != null) {
        result.add(MushafRow.heading(surah));
        if (blanks >= 2) result.add(const MushafRow.basmala());
        // A run longer than the heading needs is the rest of it blank.
        for (var i = blanks >= 2 ? 2 : 1; i < blanks; i++) {
          result.add(const MushafRow.blank());
        }
      } else {
        for (var i = 0; i < blanks; i++) {
          result.add(const MushafRow.blank());
        }
      }
      line = next;
    }

    return result;
  }

  /// How many printed line slots this page has.
  ///
  /// Fifteen on every page but the first two, which the Madani Mus'haf
  /// sets in a narrower decorative frame holding only the lines they
  /// carry. Padding those out to fifteen would put seven empty lines
  /// under al-Fatiha.
  int get slotCount {
    if (words.isEmpty) return 0;
    if (page <= kFramedPages) {
      return words.map((w) => w.line).reduce((a, b) => a > b ? a : b);
    }
    return kLinesPerPage;
  }

  /// Words grouped into the page's printed lines, in order.
  List<List<MushafWord>> get lines {
    final byLine = <int, List<MushafWord>>{};
    for (final w in words) {
      (byLine[w.line] ??= []).add(w);
    }
    final numbers = byLine.keys.toList()..sort();
    return [for (final n in numbers) byLine[n]!];
  }

  Map<String, dynamic> toJson() => {
    'p': page,
    'k': verseKeys,
    'z': juz,
    'w': [for (final w in words) w.toJson()],
  };

  factory MushafPageData.fromJson(Map<String, dynamic> j) => MushafPageData(
    page: (j['p'] as num).toInt(),
    verseKeys: [for (final k in j['k'] as List) k as String],
    juz: (j['z'] as num?)?.toInt() ?? 0,
    words: [
      for (final w in j['w'] as List)
        MushafWord.fromJson(w as Map<String, dynamic>),
    ],
  );
}

/// Every combining mark, so a word can be compared by its bare letters.
final _marksPattern = RegExp(
  r'[ؐ-ًؚ-ٰٟۖ-ۭـ]',
);

/// The forms لفظ الجلالة takes once its diacritics are stripped, including
/// the ones carrying an attached preposition or conjunction.
const _jalalahSkeletons = {
  'ٱلله',
  'الله',
  'لله',
  'بٱلله',
  'بالله',
  'وٱلله',
  'والله',
  'فٱلله',
  'تٱلله',
  'ٱللهم',
  'اللهم',
};

/// Whether [uthmani] is لفظ الجلالة.
///
/// Compared on the stripped skeleton because the same word appears with
/// different case endings — ٱللَّهُ, ٱللَّهَ, ٱللَّهِ — and a literal match would
/// catch only one of them. Words like إله and لها survive the stripping as
/// different skeletons and are correctly left alone.
bool isLafzAlJalalah(String uthmani) =>
    _jalalahSkeletons.contains(uthmani.replaceAll(_marksPattern, '').trim());
