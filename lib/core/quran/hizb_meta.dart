/// The Mus'haf's own subdivisions below the juz: the 60 أحزاب, each split
/// into four أرباع, and the 15 مواضع سجود.
///
/// A printed Mus'haf marks all of these in its margin, so a page that names
/// only its juz is missing what the paper page shows. Taken from
/// api.alquran.cloud's `/v1/meta` — the same source as [kJuzStarts] — rather
/// than hand-transcribed, because a boundary off by one ayah would put the
/// wrong ربع on the page and nobody would notice until they compared with a
/// physical copy.
library;

/// Where one quarter-hizb begins. The list is in recitation order, so the
/// quarter covering an ayah is the last entry at or before it.
class HizbQuarter {
  /// 1..240, counting straight through the Mus'haf.
  final int index;
  final int surahNumber;
  final int ayahNumber;

  const HizbQuarter({
    required this.index,
    required this.surahNumber,
    required this.ayahNumber,
  });

  /// 1..60.
  int get hizb => (index - 1) ~/ 4 + 1;

  /// 0..3 — how far into the hizb this quarter sits. 0 is the hizb itself.
  int get quarter => (index - 1) % 4;
}

const kHizbQuarters = <HizbQuarter>[
  HizbQuarter(index: 1, surahNumber: 1, ayahNumber: 1),
  HizbQuarter(index: 2, surahNumber: 2, ayahNumber: 26),
  HizbQuarter(index: 3, surahNumber: 2, ayahNumber: 44),
  HizbQuarter(index: 4, surahNumber: 2, ayahNumber: 60),
  HizbQuarter(index: 5, surahNumber: 2, ayahNumber: 75),
  HizbQuarter(index: 6, surahNumber: 2, ayahNumber: 92),
  HizbQuarter(index: 7, surahNumber: 2, ayahNumber: 106),
  HizbQuarter(index: 8, surahNumber: 2, ayahNumber: 124),
  HizbQuarter(index: 9, surahNumber: 2, ayahNumber: 142),
  HizbQuarter(index: 10, surahNumber: 2, ayahNumber: 158),
  HizbQuarter(index: 11, surahNumber: 2, ayahNumber: 177),
  HizbQuarter(index: 12, surahNumber: 2, ayahNumber: 189),
  HizbQuarter(index: 13, surahNumber: 2, ayahNumber: 203),
  HizbQuarter(index: 14, surahNumber: 2, ayahNumber: 219),
  HizbQuarter(index: 15, surahNumber: 2, ayahNumber: 233),
  HizbQuarter(index: 16, surahNumber: 2, ayahNumber: 243),
  HizbQuarter(index: 17, surahNumber: 2, ayahNumber: 253),
  HizbQuarter(index: 18, surahNumber: 2, ayahNumber: 263),
  HizbQuarter(index: 19, surahNumber: 2, ayahNumber: 272),
  HizbQuarter(index: 20, surahNumber: 2, ayahNumber: 283),
  HizbQuarter(index: 21, surahNumber: 3, ayahNumber: 15),
  HizbQuarter(index: 22, surahNumber: 3, ayahNumber: 33),
  HizbQuarter(index: 23, surahNumber: 3, ayahNumber: 52),
  HizbQuarter(index: 24, surahNumber: 3, ayahNumber: 75),
  HizbQuarter(index: 25, surahNumber: 3, ayahNumber: 93),
  HizbQuarter(index: 26, surahNumber: 3, ayahNumber: 113),
  HizbQuarter(index: 27, surahNumber: 3, ayahNumber: 133),
  HizbQuarter(index: 28, surahNumber: 3, ayahNumber: 153),
  HizbQuarter(index: 29, surahNumber: 3, ayahNumber: 171),
  HizbQuarter(index: 30, surahNumber: 3, ayahNumber: 186),
  HizbQuarter(index: 31, surahNumber: 4, ayahNumber: 1),
  HizbQuarter(index: 32, surahNumber: 4, ayahNumber: 12),
  HizbQuarter(index: 33, surahNumber: 4, ayahNumber: 24),
  HizbQuarter(index: 34, surahNumber: 4, ayahNumber: 36),
  HizbQuarter(index: 35, surahNumber: 4, ayahNumber: 58),
  HizbQuarter(index: 36, surahNumber: 4, ayahNumber: 74),
  HizbQuarter(index: 37, surahNumber: 4, ayahNumber: 88),
  HizbQuarter(index: 38, surahNumber: 4, ayahNumber: 100),
  HizbQuarter(index: 39, surahNumber: 4, ayahNumber: 114),
  HizbQuarter(index: 40, surahNumber: 4, ayahNumber: 135),
  HizbQuarter(index: 41, surahNumber: 4, ayahNumber: 148),
  HizbQuarter(index: 42, surahNumber: 4, ayahNumber: 163),
  HizbQuarter(index: 43, surahNumber: 5, ayahNumber: 1),
  HizbQuarter(index: 44, surahNumber: 5, ayahNumber: 12),
  HizbQuarter(index: 45, surahNumber: 5, ayahNumber: 27),
  HizbQuarter(index: 46, surahNumber: 5, ayahNumber: 41),
  HizbQuarter(index: 47, surahNumber: 5, ayahNumber: 51),
  HizbQuarter(index: 48, surahNumber: 5, ayahNumber: 67),
  HizbQuarter(index: 49, surahNumber: 5, ayahNumber: 82),
  HizbQuarter(index: 50, surahNumber: 5, ayahNumber: 97),
  HizbQuarter(index: 51, surahNumber: 5, ayahNumber: 109),
  HizbQuarter(index: 52, surahNumber: 6, ayahNumber: 13),
  HizbQuarter(index: 53, surahNumber: 6, ayahNumber: 36),
  HizbQuarter(index: 54, surahNumber: 6, ayahNumber: 59),
  HizbQuarter(index: 55, surahNumber: 6, ayahNumber: 74),
  HizbQuarter(index: 56, surahNumber: 6, ayahNumber: 95),
  HizbQuarter(index: 57, surahNumber: 6, ayahNumber: 111),
  HizbQuarter(index: 58, surahNumber: 6, ayahNumber: 127),
  HizbQuarter(index: 59, surahNumber: 6, ayahNumber: 141),
  HizbQuarter(index: 60, surahNumber: 6, ayahNumber: 151),
  HizbQuarter(index: 61, surahNumber: 7, ayahNumber: 1),
  HizbQuarter(index: 62, surahNumber: 7, ayahNumber: 31),
  HizbQuarter(index: 63, surahNumber: 7, ayahNumber: 47),
  HizbQuarter(index: 64, surahNumber: 7, ayahNumber: 65),
  HizbQuarter(index: 65, surahNumber: 7, ayahNumber: 88),
  HizbQuarter(index: 66, surahNumber: 7, ayahNumber: 117),
  HizbQuarter(index: 67, surahNumber: 7, ayahNumber: 142),
  HizbQuarter(index: 68, surahNumber: 7, ayahNumber: 156),
  HizbQuarter(index: 69, surahNumber: 7, ayahNumber: 171),
  HizbQuarter(index: 70, surahNumber: 7, ayahNumber: 189),
  HizbQuarter(index: 71, surahNumber: 8, ayahNumber: 1),
  HizbQuarter(index: 72, surahNumber: 8, ayahNumber: 22),
  HizbQuarter(index: 73, surahNumber: 8, ayahNumber: 41),
  HizbQuarter(index: 74, surahNumber: 8, ayahNumber: 61),
  HizbQuarter(index: 75, surahNumber: 9, ayahNumber: 1),
  HizbQuarter(index: 76, surahNumber: 9, ayahNumber: 19),
  HizbQuarter(index: 77, surahNumber: 9, ayahNumber: 34),
  HizbQuarter(index: 78, surahNumber: 9, ayahNumber: 46),
  HizbQuarter(index: 79, surahNumber: 9, ayahNumber: 60),
  HizbQuarter(index: 80, surahNumber: 9, ayahNumber: 75),
  HizbQuarter(index: 81, surahNumber: 9, ayahNumber: 93),
  HizbQuarter(index: 82, surahNumber: 9, ayahNumber: 111),
  HizbQuarter(index: 83, surahNumber: 9, ayahNumber: 122),
  HizbQuarter(index: 84, surahNumber: 10, ayahNumber: 11),
  HizbQuarter(index: 85, surahNumber: 10, ayahNumber: 26),
  HizbQuarter(index: 86, surahNumber: 10, ayahNumber: 53),
  HizbQuarter(index: 87, surahNumber: 10, ayahNumber: 71),
  HizbQuarter(index: 88, surahNumber: 10, ayahNumber: 90),
  HizbQuarter(index: 89, surahNumber: 11, ayahNumber: 6),
  HizbQuarter(index: 90, surahNumber: 11, ayahNumber: 24),
  HizbQuarter(index: 91, surahNumber: 11, ayahNumber: 41),
  HizbQuarter(index: 92, surahNumber: 11, ayahNumber: 61),
  HizbQuarter(index: 93, surahNumber: 11, ayahNumber: 84),
  HizbQuarter(index: 94, surahNumber: 11, ayahNumber: 108),
  HizbQuarter(index: 95, surahNumber: 12, ayahNumber: 7),
  HizbQuarter(index: 96, surahNumber: 12, ayahNumber: 30),
  HizbQuarter(index: 97, surahNumber: 12, ayahNumber: 53),
  HizbQuarter(index: 98, surahNumber: 12, ayahNumber: 77),
  HizbQuarter(index: 99, surahNumber: 12, ayahNumber: 101),
  HizbQuarter(index: 100, surahNumber: 13, ayahNumber: 5),
  HizbQuarter(index: 101, surahNumber: 13, ayahNumber: 19),
  HizbQuarter(index: 102, surahNumber: 13, ayahNumber: 35),
  HizbQuarter(index: 103, surahNumber: 14, ayahNumber: 10),
  HizbQuarter(index: 104, surahNumber: 14, ayahNumber: 28),
  HizbQuarter(index: 105, surahNumber: 15, ayahNumber: 1),
  HizbQuarter(index: 106, surahNumber: 15, ayahNumber: 50),
  HizbQuarter(index: 107, surahNumber: 16, ayahNumber: 1),
  HizbQuarter(index: 108, surahNumber: 16, ayahNumber: 30),
  HizbQuarter(index: 109, surahNumber: 16, ayahNumber: 51),
  HizbQuarter(index: 110, surahNumber: 16, ayahNumber: 75),
  HizbQuarter(index: 111, surahNumber: 16, ayahNumber: 90),
  HizbQuarter(index: 112, surahNumber: 16, ayahNumber: 111),
  HizbQuarter(index: 113, surahNumber: 17, ayahNumber: 1),
  HizbQuarter(index: 114, surahNumber: 17, ayahNumber: 23),
  HizbQuarter(index: 115, surahNumber: 17, ayahNumber: 50),
  HizbQuarter(index: 116, surahNumber: 17, ayahNumber: 70),
  HizbQuarter(index: 117, surahNumber: 17, ayahNumber: 99),
  HizbQuarter(index: 118, surahNumber: 18, ayahNumber: 17),
  HizbQuarter(index: 119, surahNumber: 18, ayahNumber: 32),
  HizbQuarter(index: 120, surahNumber: 18, ayahNumber: 51),
  HizbQuarter(index: 121, surahNumber: 18, ayahNumber: 75),
  HizbQuarter(index: 122, surahNumber: 18, ayahNumber: 99),
  HizbQuarter(index: 123, surahNumber: 19, ayahNumber: 22),
  HizbQuarter(index: 124, surahNumber: 19, ayahNumber: 59),
  HizbQuarter(index: 125, surahNumber: 20, ayahNumber: 1),
  HizbQuarter(index: 126, surahNumber: 20, ayahNumber: 55),
  HizbQuarter(index: 127, surahNumber: 20, ayahNumber: 83),
  HizbQuarter(index: 128, surahNumber: 20, ayahNumber: 111),
  HizbQuarter(index: 129, surahNumber: 21, ayahNumber: 1),
  HizbQuarter(index: 130, surahNumber: 21, ayahNumber: 29),
  HizbQuarter(index: 131, surahNumber: 21, ayahNumber: 51),
  HizbQuarter(index: 132, surahNumber: 21, ayahNumber: 83),
  HizbQuarter(index: 133, surahNumber: 22, ayahNumber: 1),
  HizbQuarter(index: 134, surahNumber: 22, ayahNumber: 19),
  HizbQuarter(index: 135, surahNumber: 22, ayahNumber: 38),
  HizbQuarter(index: 136, surahNumber: 22, ayahNumber: 60),
  HizbQuarter(index: 137, surahNumber: 23, ayahNumber: 1),
  HizbQuarter(index: 138, surahNumber: 23, ayahNumber: 36),
  HizbQuarter(index: 139, surahNumber: 23, ayahNumber: 75),
  HizbQuarter(index: 140, surahNumber: 24, ayahNumber: 1),
  HizbQuarter(index: 141, surahNumber: 24, ayahNumber: 21),
  HizbQuarter(index: 142, surahNumber: 24, ayahNumber: 35),
  HizbQuarter(index: 143, surahNumber: 24, ayahNumber: 53),
  HizbQuarter(index: 144, surahNumber: 25, ayahNumber: 1),
  HizbQuarter(index: 145, surahNumber: 25, ayahNumber: 21),
  HizbQuarter(index: 146, surahNumber: 25, ayahNumber: 53),
  HizbQuarter(index: 147, surahNumber: 26, ayahNumber: 1),
  HizbQuarter(index: 148, surahNumber: 26, ayahNumber: 52),
  HizbQuarter(index: 149, surahNumber: 26, ayahNumber: 111),
  HizbQuarter(index: 150, surahNumber: 26, ayahNumber: 181),
  HizbQuarter(index: 151, surahNumber: 27, ayahNumber: 1),
  HizbQuarter(index: 152, surahNumber: 27, ayahNumber: 27),
  HizbQuarter(index: 153, surahNumber: 27, ayahNumber: 56),
  HizbQuarter(index: 154, surahNumber: 27, ayahNumber: 82),
  HizbQuarter(index: 155, surahNumber: 28, ayahNumber: 12),
  HizbQuarter(index: 156, surahNumber: 28, ayahNumber: 29),
  HizbQuarter(index: 157, surahNumber: 28, ayahNumber: 51),
  HizbQuarter(index: 158, surahNumber: 28, ayahNumber: 76),
  HizbQuarter(index: 159, surahNumber: 29, ayahNumber: 1),
  HizbQuarter(index: 160, surahNumber: 29, ayahNumber: 26),
  HizbQuarter(index: 161, surahNumber: 29, ayahNumber: 46),
  HizbQuarter(index: 162, surahNumber: 30, ayahNumber: 1),
  HizbQuarter(index: 163, surahNumber: 30, ayahNumber: 31),
  HizbQuarter(index: 164, surahNumber: 30, ayahNumber: 54),
  HizbQuarter(index: 165, surahNumber: 31, ayahNumber: 22),
  HizbQuarter(index: 166, surahNumber: 32, ayahNumber: 11),
  HizbQuarter(index: 167, surahNumber: 33, ayahNumber: 1),
  HizbQuarter(index: 168, surahNumber: 33, ayahNumber: 18),
  HizbQuarter(index: 169, surahNumber: 33, ayahNumber: 31),
  HizbQuarter(index: 170, surahNumber: 33, ayahNumber: 51),
  HizbQuarter(index: 171, surahNumber: 33, ayahNumber: 60),
  HizbQuarter(index: 172, surahNumber: 34, ayahNumber: 10),
  HizbQuarter(index: 173, surahNumber: 34, ayahNumber: 24),
  HizbQuarter(index: 174, surahNumber: 34, ayahNumber: 46),
  HizbQuarter(index: 175, surahNumber: 35, ayahNumber: 15),
  HizbQuarter(index: 176, surahNumber: 35, ayahNumber: 41),
  HizbQuarter(index: 177, surahNumber: 36, ayahNumber: 28),
  HizbQuarter(index: 178, surahNumber: 36, ayahNumber: 60),
  HizbQuarter(index: 179, surahNumber: 37, ayahNumber: 22),
  HizbQuarter(index: 180, surahNumber: 37, ayahNumber: 83),
  HizbQuarter(index: 181, surahNumber: 37, ayahNumber: 145),
  HizbQuarter(index: 182, surahNumber: 38, ayahNumber: 21),
  HizbQuarter(index: 183, surahNumber: 38, ayahNumber: 52),
  HizbQuarter(index: 184, surahNumber: 39, ayahNumber: 8),
  HizbQuarter(index: 185, surahNumber: 39, ayahNumber: 32),
  HizbQuarter(index: 186, surahNumber: 39, ayahNumber: 53),
  HizbQuarter(index: 187, surahNumber: 40, ayahNumber: 1),
  HizbQuarter(index: 188, surahNumber: 40, ayahNumber: 21),
  HizbQuarter(index: 189, surahNumber: 40, ayahNumber: 41),
  HizbQuarter(index: 190, surahNumber: 40, ayahNumber: 66),
  HizbQuarter(index: 191, surahNumber: 41, ayahNumber: 9),
  HizbQuarter(index: 192, surahNumber: 41, ayahNumber: 25),
  HizbQuarter(index: 193, surahNumber: 41, ayahNumber: 47),
  HizbQuarter(index: 194, surahNumber: 42, ayahNumber: 13),
  HizbQuarter(index: 195, surahNumber: 42, ayahNumber: 27),
  HizbQuarter(index: 196, surahNumber: 42, ayahNumber: 51),
  HizbQuarter(index: 197, surahNumber: 43, ayahNumber: 24),
  HizbQuarter(index: 198, surahNumber: 43, ayahNumber: 57),
  HizbQuarter(index: 199, surahNumber: 44, ayahNumber: 17),
  HizbQuarter(index: 200, surahNumber: 45, ayahNumber: 12),
  HizbQuarter(index: 201, surahNumber: 46, ayahNumber: 1),
  HizbQuarter(index: 202, surahNumber: 46, ayahNumber: 21),
  HizbQuarter(index: 203, surahNumber: 47, ayahNumber: 10),
  HizbQuarter(index: 204, surahNumber: 47, ayahNumber: 33),
  HizbQuarter(index: 205, surahNumber: 48, ayahNumber: 18),
  HizbQuarter(index: 206, surahNumber: 49, ayahNumber: 1),
  HizbQuarter(index: 207, surahNumber: 49, ayahNumber: 14),
  HizbQuarter(index: 208, surahNumber: 50, ayahNumber: 27),
  HizbQuarter(index: 209, surahNumber: 51, ayahNumber: 31),
  HizbQuarter(index: 210, surahNumber: 52, ayahNumber: 24),
  HizbQuarter(index: 211, surahNumber: 53, ayahNumber: 26),
  HizbQuarter(index: 212, surahNumber: 54, ayahNumber: 9),
  HizbQuarter(index: 213, surahNumber: 55, ayahNumber: 1),
  HizbQuarter(index: 214, surahNumber: 56, ayahNumber: 1),
  HizbQuarter(index: 215, surahNumber: 56, ayahNumber: 75),
  HizbQuarter(index: 216, surahNumber: 57, ayahNumber: 16),
  HizbQuarter(index: 217, surahNumber: 58, ayahNumber: 1),
  HizbQuarter(index: 218, surahNumber: 58, ayahNumber: 14),
  HizbQuarter(index: 219, surahNumber: 59, ayahNumber: 11),
  HizbQuarter(index: 220, surahNumber: 60, ayahNumber: 7),
  HizbQuarter(index: 221, surahNumber: 62, ayahNumber: 1),
  HizbQuarter(index: 222, surahNumber: 63, ayahNumber: 4),
  HizbQuarter(index: 223, surahNumber: 65, ayahNumber: 1),
  HizbQuarter(index: 224, surahNumber: 66, ayahNumber: 1),
  HizbQuarter(index: 225, surahNumber: 67, ayahNumber: 1),
  HizbQuarter(index: 226, surahNumber: 68, ayahNumber: 1),
  HizbQuarter(index: 227, surahNumber: 69, ayahNumber: 1),
  HizbQuarter(index: 228, surahNumber: 70, ayahNumber: 19),
  HizbQuarter(index: 229, surahNumber: 72, ayahNumber: 1),
  HizbQuarter(index: 230, surahNumber: 73, ayahNumber: 20),
  HizbQuarter(index: 231, surahNumber: 75, ayahNumber: 1),
  HizbQuarter(index: 232, surahNumber: 76, ayahNumber: 19),
  HizbQuarter(index: 233, surahNumber: 78, ayahNumber: 1),
  HizbQuarter(index: 234, surahNumber: 80, ayahNumber: 1),
  HizbQuarter(index: 235, surahNumber: 82, ayahNumber: 1),
  HizbQuarter(index: 236, surahNumber: 84, ayahNumber: 1),
  HizbQuarter(index: 237, surahNumber: 87, ayahNumber: 1),
  HizbQuarter(index: 238, surahNumber: 90, ayahNumber: 1),
  HizbQuarter(index: 239, surahNumber: 94, ayahNumber: 1),
  HizbQuarter(index: 240, surahNumber: 100, ayahNumber: 9),
];

/// The quarter-hizb an ayah falls in, or null before the Mus'haf begins.
///
/// Compared as (surah, ayah) pairs, which orders correctly because the
/// quarters are already in recitation order and no surah is ever revisited.
HizbQuarter? hizbQuarterFor(int surahNumber, int ayahNumber) {
  HizbQuarter? found;
  for (final q in kHizbQuarters) {
    final beforeOrAt = q.surahNumber < surahNumber ||
        (q.surahNumber == surahNumber && q.ayahNumber <= ayahNumber);
    if (!beforeOrAt) break;
    found = q;
  }
  return found;
}

/// One موضع سجدة — a verse at which the reciter prostrates.
class SajdaSpot {
  final int surahNumber;
  final int ayahNumber;

  /// True for the four the source marks as عزائم السجود — Sajda 32:15,
  /// Fussilat 41:38, an-Najm 53:62 and al-'Alaq 96:19. Carried as the source
  /// reports it, with no ruling attached: the app marks the spot, it does not
  /// tell anyone what their madhhab requires there.
  final bool obligatory;

  const SajdaSpot({
    required this.surahNumber,
    required this.ayahNumber,
    required this.obligatory,
  });
}

const kSajdaSpots = <SajdaSpot>[
  SajdaSpot(surahNumber: 7, ayahNumber: 206, obligatory: false),
  SajdaSpot(surahNumber: 13, ayahNumber: 15, obligatory: false),
  SajdaSpot(surahNumber: 16, ayahNumber: 50, obligatory: false),
  SajdaSpot(surahNumber: 17, ayahNumber: 109, obligatory: false),
  SajdaSpot(surahNumber: 19, ayahNumber: 58, obligatory: false),
  SajdaSpot(surahNumber: 22, ayahNumber: 18, obligatory: false),
  SajdaSpot(surahNumber: 22, ayahNumber: 77, obligatory: false),
  SajdaSpot(surahNumber: 25, ayahNumber: 60, obligatory: false),
  SajdaSpot(surahNumber: 27, ayahNumber: 26, obligatory: false),
  SajdaSpot(surahNumber: 32, ayahNumber: 15, obligatory: true),
  SajdaSpot(surahNumber: 38, ayahNumber: 24, obligatory: false),
  SajdaSpot(surahNumber: 41, ayahNumber: 38, obligatory: true),
  SajdaSpot(surahNumber: 53, ayahNumber: 62, obligatory: true),
  SajdaSpot(surahNumber: 84, ayahNumber: 21, obligatory: false),
  SajdaSpot(surahNumber: 96, ayahNumber: 19, obligatory: true),
];

/// Whether a prostration is marked at this exact verse.
bool isSajdaAyah(int surahNumber, int ayahNumber) => kSajdaSpots.any(
  (s) => s.surahNumber == surahNumber && s.ayahNumber == ayahNumber,
);
