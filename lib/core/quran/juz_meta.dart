/// The 30 Juz (أجزاء) and where each one starts — structural metadata
/// about the Mus'haf's division into 30 equal reading portions, not verse
/// text. Sourced from api.alquran.cloud's `/v1/meta` endpoint (the same
/// trusted source used for live verse text) rather than hand-transcribed,
/// to avoid a boundary being off by an ayah.
class JuzStart {
  final int number;
  final int surahNumber;
  final int ayahNumber;

  const JuzStart({
    required this.number,
    required this.surahNumber,
    required this.ayahNumber,
  });
}

const kJuzStarts = <JuzStart>[
  JuzStart(number: 1, surahNumber: 1, ayahNumber: 1),
  JuzStart(number: 2, surahNumber: 2, ayahNumber: 142),
  JuzStart(number: 3, surahNumber: 2, ayahNumber: 253),
  JuzStart(number: 4, surahNumber: 3, ayahNumber: 93),
  JuzStart(number: 5, surahNumber: 4, ayahNumber: 24),
  JuzStart(number: 6, surahNumber: 4, ayahNumber: 148),
  JuzStart(number: 7, surahNumber: 5, ayahNumber: 82),
  JuzStart(number: 8, surahNumber: 6, ayahNumber: 111),
  JuzStart(number: 9, surahNumber: 7, ayahNumber: 88),
  JuzStart(number: 10, surahNumber: 8, ayahNumber: 41),
  JuzStart(number: 11, surahNumber: 9, ayahNumber: 93),
  JuzStart(number: 12, surahNumber: 11, ayahNumber: 6),
  JuzStart(number: 13, surahNumber: 12, ayahNumber: 53),
  JuzStart(number: 14, surahNumber: 15, ayahNumber: 1),
  JuzStart(number: 15, surahNumber: 17, ayahNumber: 1),
  JuzStart(number: 16, surahNumber: 18, ayahNumber: 75),
  JuzStart(number: 17, surahNumber: 21, ayahNumber: 1),
  JuzStart(number: 18, surahNumber: 23, ayahNumber: 1),
  JuzStart(number: 19, surahNumber: 25, ayahNumber: 21),
  JuzStart(number: 20, surahNumber: 27, ayahNumber: 56),
  JuzStart(number: 21, surahNumber: 29, ayahNumber: 46),
  JuzStart(number: 22, surahNumber: 33, ayahNumber: 31),
  JuzStart(number: 23, surahNumber: 36, ayahNumber: 28),
  JuzStart(number: 24, surahNumber: 39, ayahNumber: 32),
  JuzStart(number: 25, surahNumber: 41, ayahNumber: 47),
  JuzStart(number: 26, surahNumber: 46, ayahNumber: 1),
  JuzStart(number: 27, surahNumber: 51, ayahNumber: 31),
  JuzStart(number: 28, surahNumber: 58, ayahNumber: 1),
  JuzStart(number: 29, surahNumber: 67, ayahNumber: 1),
  JuzStart(number: 30, surahNumber: 78, ayahNumber: 1),
];
