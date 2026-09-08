import 'quran_text_service.dart';

const _arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];

String arabicNumeral(int n) =>
    n.toString().split('').map((d) => _arabicDigits[int.parse(d)]).join();

/// U+06DD (END OF AYAH) followed by the verse number: AmiriQuran draws the
/// digits inside the rosette, exactly as a printed Mus'haf does.
String ayahEndMark(int number) => ' ۝${arabicNumeral(number)} ';

String ayahDisplayText(Ayah ayah) => '${ayah.text.trim()}${ayahEndMark(ayah.numberInSurah)}';

/// Cumulative character length up to and including each ayah, in display
/// order — the basis for estimating scroll position to/from a given ayah
/// in the continuous justified Mus'haf paragraph. There's no per-ayah
/// widget to measure directly (it's one Text.rich, not a list), so
/// position is estimated by where the ayah's text falls in the overall
/// character stream rather than pixel-measured.
List<int> cumulativeAyahLengths(List<Ayah> ayahs) {
  final result = <int>[];
  var total = 0;
  for (final ayah in ayahs) {
    total += ayahDisplayText(ayah).length;
    result.add(total);
  }
  return result;
}

/// Scroll fraction (0..1) at which [ayahNumber] begins, given the surah's
/// [ayahs] in order. Used to jump the reader to a specific ayah on open
/// (e.g. a Juz boundary, or a bookmark) — falls back to 0 (the top) if the
/// ayah isn't found rather than throwing, since a bad deep link shouldn't
/// crash the reader.
double fractionForAyah(List<Ayah> ayahs, int ayahNumber) {
  final cumulative = cumulativeAyahLengths(ayahs);
  if (cumulative.isEmpty) return 0;
  final total = cumulative.last;
  if (total == 0) return 0;
  final index = ayahs.indexWhere((a) => a.numberInSurah == ayahNumber);
  if (index <= 0) return 0;
  // The offset just before this ayah's own text starts.
  final startOffset = cumulative[index - 1];
  return (startOffset / total).clamp(0, 1);
}

/// The ayah estimated to be at scroll [fraction] (0..1) — the inverse of
/// [fractionForAyah], used to track reading position as the user scrolls.
int ayahForFraction(List<Ayah> ayahs, double fraction) {
  if (ayahs.isEmpty) return 1;
  final cumulative = cumulativeAyahLengths(ayahs);
  final total = cumulative.last;
  if (total == 0) return ayahs.first.numberInSurah;
  final target = fraction.clamp(0, 1) * total;
  for (var i = 0; i < cumulative.length; i++) {
    if (target <= cumulative[i]) return ayahs[i].numberInSurah;
  }
  return ayahs.last.numberInSurah;
}
