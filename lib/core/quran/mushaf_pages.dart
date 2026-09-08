import 'quran_text_service.dart';

/// One page of the printed Mus'haf, as it falls within a single surah.
class MushafPage {
  /// Page number in the standard 604-page Madani Mus'haf.
  final int number;
  final List<Ayah> ayahs;

  const MushafPage({required this.number, required this.ayahs});

  /// True when this page opens the surah, which is the only page that
  /// should carry the surah heading and the Basmala.
  bool get startsSurah => ayahs.isNotEmpty && ayahs.first.numberInSurah == 1;
}

/// Splits a surah's ayahs at the printed Mus'haf's own page boundaries.
///
/// The boundaries come from [Ayah.page], which the Quran API reports per
/// ayah — so a page here contains exactly the ayahs that page contains on
/// paper, rather than a guess based on ayah count or character length.
///
/// One honest limitation: a physical Mus'haf page can hold the end of one
/// surah and the start of the next (page 604 carries four surahs). This
/// reader is organised by surah — one swipeable surah after another — so a
/// shared page appears in both surahs, each showing only its own portion.
/// The page *number* stays correct in both, which is what matters for
/// following along with a physical copy; the alternative is a global
/// 604-page reader with no surah structure at all.
List<MushafPage> splitIntoMushafPages(List<Ayah> ayahs) {
  if (ayahs.isEmpty) return const [];

  final pages = <MushafPage>[];
  var current = <Ayah>[ayahs.first];

  for (var i = 1; i < ayahs.length; i++) {
    final ayah = ayahs[i];
    if (ayah.page != current.last.page) {
      pages.add(MushafPage(number: current.first.page, ayahs: current));
      current = <Ayah>[ayah];
    } else {
      current.add(ayah);
    }
  }
  pages.add(MushafPage(number: current.first.page, ayahs: current));
  return pages;
}

/// Index of the page holding [ayahNumber], or 0 when it isn't found —
/// used to open the reader on the page containing a bookmark or a saved
/// reading position rather than at the start of the surah.
int mushafPageIndexForAyah(List<MushafPage> pages, int ayahNumber) {
  for (var i = 0; i < pages.length; i++) {
    for (final ayah in pages[i].ayahs) {
      if (ayah.numberInSurah == ayahNumber) return i;
    }
  }
  return 0;
}
