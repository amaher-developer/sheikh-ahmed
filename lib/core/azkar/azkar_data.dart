import '../quran/surah_meta.dart';
import '../utils/arabic_numerals.dart';

/// Short, traditional Islamic remembrances (dhikr) — the kind of brief,
/// universally repeated phrases found identically across virtually every
/// Muslim prayer book, not the creative wording of any single modern
/// author. Items that reference a specific Quranic passage (e.g. Ayat
/// al-Kursi) carry a [quranRefs] pointer instead of the verse text itself
/// — the actual text is fetched live via [QuranTextService], the same
/// trusted source and cache used by the Quran reader, rather than being
/// hand-transcribed here.
///
/// Wording and repetition counts follow the standard حصن المسلم ordering.
/// An earlier version of this file carried abbreviated openings — e.g.
/// "أصبحنا وأصبح الملك لله والحمد لله" stopping there, less than a third of
/// the actual dhikr — which made the morning/evening lists read as wrong to
/// anyone who knows them. Each [textAr] below is the complete dhikr; when
/// editing, keep them complete rather than trimming for layout, since the
/// screen already scrolls.
class QuranRef {
  final int surahNumber;
  final int fromAyah;
  final int toAyah;

  const QuranRef({
    required this.surahNumber,
    required this.fromAyah,
    required this.toAyah,
  });
}

class AzkarItem {
  final String id;
  final String textAr;
  final String countLabel;
  final int count;
  final List<QuranRef> quranRefs;

  /// True when [textAr] is a translation key rather than the dhikr
  /// itself. Items that point at a Quranic passage carry an instruction
  /// ("read Ayat al-Kursi") instead of recitable text, and an
  /// instruction has to follow the app's language — the dhikr texts do
  /// not, because they are what the user says aloud.
  bool get isLabelKey => quranRefs.isNotEmpty;

  const AzkarItem({
    required this.id,
    required this.textAr,
    required this.countLabel,
    this.count = 1,
    this.quranRefs = const [],
  });
}

class AzkarCategory {
  final String id;
  final String titleKey;
  final List<AzkarItem> items;

  const AzkarCategory({
    required this.id,
    required this.titleKey,
    required this.items,
  });
}

// Translation keys, not literals. These are UI labels describing how many
// times to repeat a dhikr — unlike the dhikr text itself, they have to
// follow the app's language.
const _once = 'azkar_count.once';
const _thrice = 'azkar_count.thrice';
const _fourTimes = 'azkar_count.four_times';
const _sevenTimes = 'azkar_count.seven_times';
const _tenTimes = 'azkar_count.ten_times';
const _thirtyThree = 'azkar_count.thirty_three';
const _thirtyFour = 'azkar_count.thirty_four';
const _hundred = 'azkar_count.hundred';

const _ayatAlKursi = QuranRef(surahNumber: 2, fromAyah: 255, toAyah: 255);

/// The closing verses of Al Imran, which the Prophet recited on waking.
const _imranClosing = QuranRef(surahNumber: 3, fromAyah: 190, toAyah: 200);

// Al-Ikhlas and the two "seeking refuge" surahs. These are listed as three
// separate items everywhere they appear below, not bundled into one. Each
// is recited three times in its own right, so combining them made the
// counter ambiguous — three taps had to stand for nine recitations — and
// ran all three surahs together into a single unbroken block of text with
// no visible boundary between them.
const _ikhlas = QuranRef(surahNumber: 112, fromAyah: 1, toAyah: 4);
const _falaq = QuranRef(surahNumber: 113, fromAyah: 1, toAyah: 5);
const _nas = QuranRef(surahNumber: 114, fromAyah: 1, toAyah: 6);

// The passages recited in الرقية الشرعية, in the order they are read.
// Refs rather than transcribed text for the same reason as everything
// above: the words come from the Quran source the reader already uses,
// so a mistyped letter here cannot put wrong Quran on the screen.
const _fatiha = QuranRef(surahNumber: 1, fromAyah: 1, toAyah: 7);
const _baqarahOpening = QuranRef(surahNumber: 2, fromAyah: 1, toAyah: 5);
const _baqarahLastTwo = QuranRef(surahNumber: 2, fromAyah: 285, toAyah: 286);
const _aarafCreation = QuranRef(surahNumber: 7, fromAyah: 54, toAyah: 56);
const _aarafMoses = QuranRef(surahNumber: 7, fromAyah: 117, toAyah: 122);
const _yunusMoses = QuranRef(surahNumber: 10, fromAyah: 81, toAyah: 82);
const _tahaMoses = QuranRef(surahNumber: 20, fromAyah: 69, toAyah: 69);
const _muminunClosing = QuranRef(surahNumber: 23, fromAyah: 115, toAyah: 118);
const _saffatOpening = QuranRef(surahNumber: 37, fromAyah: 1, toAyah: 10);
const _rahmanChallenge = QuranRef(surahNumber: 55, fromAyah: 33, toAyah: 36);
const _hashrClosing = QuranRef(surahNumber: 59, fromAyah: 21, toAyah: 24);
const _jinnOpening = QuranRef(surahNumber: 72, fromAyah: 1, toAyah: 9);

// آيات الشفاء — the six verses that name healing outright. They are the
// heart of a ruqyah recited over illness and were missing from the list:
// it carried the passages for protection and left out the ones for
// شفاء. Recited as one set, which is why they are one item with six
// references rather than six items.
const _shifaVerses = [
  QuranRef(surahNumber: 9, fromAyah: 14, toAyah: 14),
  QuranRef(surahNumber: 10, fromAyah: 57, toAyah: 57),
  QuranRef(surahNumber: 16, fromAyah: 69, toAyah: 69),
  QuranRef(surahNumber: 17, fromAyah: 82, toAyah: 82),
  QuranRef(surahNumber: 26, fromAyah: 80, toAyah: 80),
  QuranRef(surahNumber: 41, fromAyah: 44, toAyah: 44),
];

const _ikhlasLabel = 'azkar_items.ikhlas';
const _falaqLabel = 'azkar_items.falaq';
const _nasLabel = 'azkar_items.nas';

const kAzkarCategories = <AzkarCategory>[
  AzkarCategory(
    id: 'morning',
    titleKey: 'azkar_screen.morning',
    items: [
      AzkarItem(
        id: 'm1',
        textAr: 'azkar_items.ayat_kursi',
        countLabel: _once,
        quranRefs: [_ayatAlKursi],
      ),
      AzkarItem(
        id: 'm2a',
        textAr: _ikhlasLabel,
        countLabel: _thrice,
        count: 3,
        quranRefs: [_ikhlas],
      ),
      AzkarItem(
        id: 'm2b',
        textAr: _falaqLabel,
        countLabel: _thrice,
        count: 3,
        quranRefs: [_falaq],
      ),
      AzkarItem(
        id: 'm2c',
        textAr: _nasLabel,
        countLabel: _thrice,
        count: 3,
        quranRefs: [_nas],
      ),
      AzkarItem(
        id: 'm3',
        textAr:
            'أَصْبَحْنَا وَأَصْبَحَ الْمُلْكُ لِلَّهِ، وَالْحَمْدُ لِلَّهِ، لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ. رَبِّ أَسْأَلُكَ خَيْرَ مَا فِي هَذَا الْيَوْمِ وَخَيْرَ مَا بَعْدَهُ، وَأَعُوذُ بِكَ مِنْ شَرِّ مَا فِي هَذَا الْيَوْمِ وَشَرِّ مَا بَعْدَهُ، رَبِّ أَعُوذُ بِكَ مِنَ الْكَسَلِ وَسُوءِ الْكِبَرِ، رَبِّ أَعُوذُ بِكَ مِنْ عَذَابٍ فِي النَّارِ وَعَذَابٍ فِي الْقَبْرِ',
        countLabel: _once,
      ),
      AzkarItem(
        id: 'm4',
        textAr:
            'اللَّهُمَّ بِكَ أَصْبَحْنَا، وَبِكَ أَمْسَيْنَا، وَبِكَ نَحْيَا، وَبِكَ نَمُوتُ، وَإِلَيْكَ النُّشُورُ',
        countLabel: _once,
      ),
      // سيد الاستغفار — named in the hadith as the foremost of all
      // supplications for forgiveness, and the anchor of both the morning
      // and evening lists.
      AzkarItem(
        id: 'm5',
        textAr:
            'اللَّهُمَّ أَنْتَ رَبِّي لَا إِلَهَ إِلَّا أَنْتَ، خَلَقْتَنِي وَأَنَا عَبْدُكَ، وَأَنَا عَلَى عَهْدِكَ وَوَعْدِكَ مَا اسْتَطَعْتُ، أَعُوذُ بِكَ مِنْ شَرِّ مَا صَنَعْتُ، أَبُوءُ لَكَ بِنِعْمَتِكَ عَلَيَّ، وَأَبُوءُ لَكَ بِذَنْبِي فَاغْفِرْ لِي، فَإِنَّهُ لَا يَغْفِرُ الذُّنُوبَ إِلَّا أَنْتَ',
        countLabel: _once,
      ),
      AzkarItem(
        id: 'm6',
        textAr:
            'اللَّهُمَّ إِنِّي أَصْبَحْتُ أُشْهِدُكَ، وَأُشْهِدُ حَمَلَةَ عَرْشِكَ، وَمَلَائِكَتَكَ، وَجَمِيعَ خَلْقِكَ، أَنَّكَ أَنْتَ اللَّهُ لَا إِلَهَ إِلَّا أَنْتَ وَحْدَكَ لَا شَرِيكَ لَكَ، وَأَنَّ مُحَمَّدًا عَبْدُكَ وَرَسُولُكَ',
        countLabel: _fourTimes,
        count: 4,
      ),
      AzkarItem(
        id: 'm7',
        textAr:
            'اللَّهُمَّ مَا أَصْبَحَ بِي مِنْ نِعْمَةٍ أَوْ بِأَحَدٍ مِنْ خَلْقِكَ فَمِنْكَ وَحْدَكَ لَا شَرِيكَ لَكَ، فَلَكَ الْحَمْدُ وَلَكَ الشُّكْرُ',
        countLabel: _once,
      ),
      AzkarItem(
        id: 'm8',
        textAr:
            'اللَّهُمَّ عَافِنِي فِي بَدَنِي، اللَّهُمَّ عَافِنِي فِي سَمْعِي، اللَّهُمَّ عَافِنِي فِي بَصَرِي، لَا إِلَهَ إِلَّا أَنْتَ. اللَّهُمَّ إِنِّي أَعُوذُ بِكَ مِنَ الْكُفْرِ وَالْفَقْرِ، وَأَعُوذُ بِكَ مِنْ عَذَابِ الْقَبْرِ، لَا إِلَهَ إِلَّا أَنْتَ',
        countLabel: _thrice,
        count: 3,
      ),
      AzkarItem(
        id: 'm9',
        textAr:
            'حَسْبِيَ اللَّهُ لَا إِلَهَ إِلَّا هُوَ، عَلَيْهِ تَوَكَّلْتُ، وَهُوَ رَبُّ الْعَرْشِ الْعَظِيمِ',
        countLabel: _sevenTimes,
        count: 7,
      ),
      AzkarItem(
        id: 'm10',
        textAr:
            'بِسْمِ اللَّهِ الَّذِي لَا يَضُرُّ مَعَ اسْمِهِ شَيْءٌ فِي الْأَرْضِ وَلَا فِي السَّمَاءِ، وَهُوَ السَّمِيعُ الْعَلِيمُ',
        countLabel: _thrice,
        count: 3,
      ),
      AzkarItem(
        id: 'm11',
        textAr:
            'رَضِيتُ بِاللَّهِ رَبًّا، وَبِالْإِسْلَامِ دِينًا، وَبِمُحَمَّدٍ ﷺ نَبِيًّا',
        countLabel: _thrice,
        count: 3,
      ),
      AzkarItem(
        id: 'm12',
        textAr:
            'يَا حَيُّ يَا قَيُّومُ بِرَحْمَتِكَ أَسْتَغِيثُ، أَصْلِحْ لِي شَأْنِي كُلَّهُ، وَلَا تَكِلْنِي إِلَى نَفْسِي طَرْفَةَ عَيْنٍ',
        // Narrated without a repetition count, so listed once rather than
        // inventing a number for it.
        countLabel: _once,
      ),
      AzkarItem(
        id: 'm13',
        textAr:
            'أَصْبَحْنَا عَلَى فِطْرَةِ الْإِسْلَامِ، وَعَلَى كَلِمَةِ الْإِخْلَاصِ، وَعَلَى دِينِ نَبِيِّنَا مُحَمَّدٍ ﷺ، وَعَلَى مِلَّةِ أَبِينَا إِبْرَاهِيمَ حَنِيفًا مُسْلِمًا وَمَا كَانَ مِنَ الْمُشْرِكِينَ',
        countLabel: _once,
      ),
      AzkarItem(
        id: 'm14',
        textAr:
            'أَعُوذُ بِكَلِمَاتِ اللَّهِ التَّامَّاتِ مِنْ شَرِّ مَا خَلَقَ',
        countLabel: _thrice,
        count: 3,
      ),
      AzkarItem(
        id: 'm15',
        textAr:
            'سُبْحَانَ اللَّهِ وَبِحَمْدِهِ، عَدَدَ خَلْقِهِ، وَرِضَا نَفْسِهِ، وَزِنَةَ عَرْشِهِ، وَمِدَادَ كَلِمَاتِهِ',
        countLabel: _thrice,
        count: 3,
      ),
      // Morning only — the wording asks for provision for the day ahead.
      AzkarItem(
        id: 'm16',
        textAr:
            'اللَّهُمَّ إِنِّي أَسْأَلُكَ عِلْمًا نَافِعًا، وَرِزْقًا طَيِّبًا، وَعَمَلًا مُتَقَبَّلًا',
        countLabel: _once,
      ),
      AzkarItem(
        id: 'm17',
        textAr: 'سُبْحَانَ اللَّهِ وَبِحَمْدِهِ',
        countLabel: _hundred,
        count: 100,
      ),
      AzkarItem(
        id: 'm18',
        textAr:
            'لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ',
        countLabel: _tenTimes,
        count: 10,
      ),
      AzkarItem(
        id: 'm19',
        textAr: 'أَسْتَغْفِرُ اللَّهَ وَأَتُوبُ إِلَيْهِ',
        countLabel: _hundred,
        count: 100,
      ),
      AzkarItem(
        id: 'm20',
        textAr: 'اللَّهُمَّ صَلِّ وَسَلِّمْ عَلَى نَبِيِّنَا مُحَمَّدٍ',
        countLabel: _tenTimes,
        count: 10,
      ),
    ],
  ),
  AzkarCategory(
    id: 'evening',
    titleKey: 'azkar_screen.evening',
    items: [
      AzkarItem(
        id: 'e1',
        textAr: 'azkar_items.ayat_kursi',
        countLabel: _once,
        quranRefs: [_ayatAlKursi],
      ),
      AzkarItem(
        id: 'e2a',
        textAr: _ikhlasLabel,
        countLabel: _thrice,
        count: 3,
        quranRefs: [_ikhlas],
      ),
      AzkarItem(
        id: 'e2b',
        textAr: _falaqLabel,
        countLabel: _thrice,
        count: 3,
        quranRefs: [_falaq],
      ),
      AzkarItem(
        id: 'e2c',
        textAr: _nasLabel,
        countLabel: _thrice,
        count: 3,
        quranRefs: [_nas],
      ),
      AzkarItem(
        id: 'e3',
        textAr:
            'أَمْسَيْنَا وَأَمْسَى الْمُلْكُ لِلَّهِ، وَالْحَمْدُ لِلَّهِ، لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ. رَبِّ أَسْأَلُكَ خَيْرَ مَا فِي هَذِهِ اللَّيْلَةِ وَخَيْرَ مَا بَعْدَهَا، وَأَعُوذُ بِكَ مِنْ شَرِّ مَا فِي هَذِهِ اللَّيْلَةِ وَشَرِّ مَا بَعْدَهَا، رَبِّ أَعُوذُ بِكَ مِنَ الْكَسَلِ وَسُوءِ الْكِبَرِ، رَبِّ أَعُوذُ بِكَ مِنْ عَذَابٍ فِي النَّارِ وَعَذَابٍ فِي الْقَبْرِ',
        countLabel: _once,
      ),
      AzkarItem(
        id: 'e4',
        textAr:
            'اللَّهُمَّ بِكَ أَمْسَيْنَا، وَبِكَ أَصْبَحْنَا، وَبِكَ نَحْيَا، وَبِكَ نَمُوتُ، وَإِلَيْكَ الْمَصِيرُ',
        countLabel: _once,
      ),
      AzkarItem(
        id: 'e5',
        textAr:
            'اللَّهُمَّ أَنْتَ رَبِّي لَا إِلَهَ إِلَّا أَنْتَ، خَلَقْتَنِي وَأَنَا عَبْدُكَ، وَأَنَا عَلَى عَهْدِكَ وَوَعْدِكَ مَا اسْتَطَعْتُ، أَعُوذُ بِكَ مِنْ شَرِّ مَا صَنَعْتُ، أَبُوءُ لَكَ بِنِعْمَتِكَ عَلَيَّ، وَأَبُوءُ لَكَ بِذَنْبِي فَاغْفِرْ لِي، فَإِنَّهُ لَا يَغْفِرُ الذُّنُوبَ إِلَّا أَنْتَ',
        countLabel: _once,
      ),
      AzkarItem(
        id: 'e6',
        textAr:
            'اللَّهُمَّ إِنِّي أَمْسَيْتُ أُشْهِدُكَ، وَأُشْهِدُ حَمَلَةَ عَرْشِكَ، وَمَلَائِكَتَكَ، وَجَمِيعَ خَلْقِكَ، أَنَّكَ أَنْتَ اللَّهُ لَا إِلَهَ إِلَّا أَنْتَ وَحْدَكَ لَا شَرِيكَ لَكَ، وَأَنَّ مُحَمَّدًا عَبْدُكَ وَرَسُولُكَ',
        countLabel: _fourTimes,
        count: 4,
      ),
      AzkarItem(
        id: 'e7',
        textAr:
            'اللَّهُمَّ مَا أَمْسَى بِي مِنْ نِعْمَةٍ أَوْ بِأَحَدٍ مِنْ خَلْقِكَ فَمِنْكَ وَحْدَكَ لَا شَرِيكَ لَكَ، فَلَكَ الْحَمْدُ وَلَكَ الشُّكْرُ',
        countLabel: _once,
      ),
      AzkarItem(
        id: 'e8',
        textAr:
            'اللَّهُمَّ عَافِنِي فِي بَدَنِي، اللَّهُمَّ عَافِنِي فِي سَمْعِي، اللَّهُمَّ عَافِنِي فِي بَصَرِي، لَا إِلَهَ إِلَّا أَنْتَ. اللَّهُمَّ إِنِّي أَعُوذُ بِكَ مِنَ الْكُفْرِ وَالْفَقْرِ، وَأَعُوذُ بِكَ مِنْ عَذَابِ الْقَبْرِ، لَا إِلَهَ إِلَّا أَنْتَ',
        countLabel: _thrice,
        count: 3,
      ),
      AzkarItem(
        id: 'e9',
        textAr:
            'حَسْبِيَ اللَّهُ لَا إِلَهَ إِلَّا هُوَ، عَلَيْهِ تَوَكَّلْتُ، وَهُوَ رَبُّ الْعَرْشِ الْعَظِيمِ',
        countLabel: _sevenTimes,
        count: 7,
      ),
      AzkarItem(
        id: 'e10',
        textAr:
            'بِسْمِ اللَّهِ الَّذِي لَا يَضُرُّ مَعَ اسْمِهِ شَيْءٌ فِي الْأَرْضِ وَلَا فِي السَّمَاءِ، وَهُوَ السَّمِيعُ الْعَلِيمُ',
        countLabel: _thrice,
        count: 3,
      ),
      AzkarItem(
        id: 'e11',
        textAr:
            'رَضِيتُ بِاللَّهِ رَبًّا، وَبِالْإِسْلَامِ دِينًا، وَبِمُحَمَّدٍ ﷺ نَبِيًّا',
        countLabel: _thrice,
        count: 3,
      ),
      AzkarItem(
        id: 'e12',
        textAr:
            'يَا حَيُّ يَا قَيُّومُ بِرَحْمَتِكَ أَسْتَغِيثُ، أَصْلِحْ لِي شَأْنِي كُلَّهُ، وَلَا تَكِلْنِي إِلَى نَفْسِي طَرْفَةَ عَيْنٍ',
        // Narrated without a repetition count, so listed once rather than
        // inventing a number for it.
        countLabel: _once,
      ),
      AzkarItem(
        id: 'e13',
        textAr:
            'أَمْسَيْنَا عَلَى فِطْرَةِ الْإِسْلَامِ، وَعَلَى كَلِمَةِ الْإِخْلَاصِ، وَعَلَى دِينِ نَبِيِّنَا مُحَمَّدٍ ﷺ، وَعَلَى مِلَّةِ أَبِينَا إِبْرَاهِيمَ حَنِيفًا مُسْلِمًا وَمَا كَانَ مِنَ الْمُشْرِكِينَ',
        countLabel: _once,
      ),
      // Evening especially: the hadith ties this wording to being unharmed
      // through the night.
      AzkarItem(
        id: 'e14',
        textAr:
            'أَعُوذُ بِكَلِمَاتِ اللَّهِ التَّامَّاتِ مِنْ شَرِّ مَا خَلَقَ',
        countLabel: _thrice,
        count: 3,
      ),
      AzkarItem(
        id: 'e15',
        textAr:
            'سُبْحَانَ اللَّهِ وَبِحَمْدِهِ، عَدَدَ خَلْقِهِ، وَرِضَا نَفْسِهِ، وَزِنَةَ عَرْشِهِ، وَمِدَادَ كَلِمَاتِهِ',
        countLabel: _thrice,
        count: 3,
      ),
      AzkarItem(
        id: 'e16',
        textAr: 'سُبْحَانَ اللَّهِ وَبِحَمْدِهِ',
        countLabel: _hundred,
        count: 100,
      ),
      AzkarItem(
        id: 'e17',
        textAr:
            'لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ',
        countLabel: _tenTimes,
        count: 10,
      ),
      AzkarItem(
        id: 'e18',
        textAr: 'أَسْتَغْفِرُ اللَّهَ وَأَتُوبُ إِلَيْهِ',
        countLabel: _hundred,
        count: 100,
      ),
      AzkarItem(
        id: 'e19',
        textAr: 'اللَّهُمَّ صَلِّ وَسَلِّمْ عَلَى نَبِيِّنَا مُحَمَّدٍ',
        countLabel: _tenTimes,
        count: 10,
      ),
    ],
  ),
  AzkarCategory(
    id: 'sleep',
    titleKey: 'azkar_screen.sleep',
    items: [
      // Recited into the cupped hands, then wiped over the body — done as
      // one act three times over, so the three surahs stay adjacent here
      // even though each is now counted on its own.
      AzkarItem(
        id: 's1a',
        textAr: 'azkar_items.ikhlas_sleep',
        countLabel: _thrice,
        count: 3,
        quranRefs: [_ikhlas],
      ),
      AzkarItem(
        id: 's1b',
        textAr: _falaqLabel,
        countLabel: _thrice,
        count: 3,
        quranRefs: [_falaq],
      ),
      AzkarItem(
        id: 's1c',
        textAr: _nasLabel,
        countLabel: _thrice,
        count: 3,
        quranRefs: [_nas],
      ),
      AzkarItem(
        id: 's2',
        textAr: 'azkar_items.ayat_kursi',
        countLabel: _once,
        quranRefs: [_ayatAlKursi],
      ),
      // The closing two verses of al-Baqarah — "من قرأ بهما في ليلة كفتاه".
      AzkarItem(
        id: 's3',
        textAr: 'azkar_items.baqarah_last_two',
        countLabel: _once,
        quranRefs: [QuranRef(surahNumber: 2, fromAyah: 285, toAyah: 286)],
      ),
      AzkarItem(
        id: 's4',
        textAr: 'بِاسْمِكَ اللَّهُمَّ أَمُوتُ وَأَحْيَا',
        countLabel: _once,
      ),
      AzkarItem(
        id: 's5',
        textAr:
            'اللَّهُمَّ أَسْلَمْتُ نَفْسِي إِلَيْكَ، وَفَوَّضْتُ أَمْرِي إِلَيْكَ، وَوَجَّهْتُ وَجْهِي إِلَيْكَ، وَأَلْجَأْتُ ظَهْرِي إِلَيْكَ، رَغْبَةً وَرَهْبَةً إِلَيْكَ، لَا مَلْجَأَ وَلَا مَنْجَا مِنْكَ إِلَّا إِلَيْكَ، آمَنْتُ بِكِتَابِكَ الَّذِي أَنْزَلْتَ، وَبِنَبِيِّكَ الَّذِي أَرْسَلْتَ',
        countLabel: _once,
      ),
      AzkarItem(
        id: 's6',
        textAr:
            'اللَّهُمَّ قِنِي عَذَابَكَ يَوْمَ تَبْعَثُ عِبَادَكَ',
        countLabel: _thrice,
        count: 3,
      ),
      AzkarItem(
        id: 's7',
        textAr:
            'الْحَمْدُ لِلَّهِ الَّذِي أَطْعَمَنَا وَسَقَانَا، وَكَفَانَا، وَآوَانَا، فَكَمْ مِمَّنْ لَا كَافِيَ لَهُ وَلَا مُؤْوِيَ',
        countLabel: _once,
      ),
      AzkarItem(
        id: 's8',
        textAr: 'سُبْحَانَ اللَّهِ',
        countLabel: _thirtyThree,
        count: 33,
      ),
      AzkarItem(
        id: 's9',
        textAr: 'الْحَمْدُ لِلَّهِ',
        countLabel: _thirtyThree,
        count: 33,
      ),
      AzkarItem(
        id: 's10',
        textAr: 'اللَّهُ أَكْبَرُ',
        countLabel: _thirtyFour,
        count: 34,
      ),
      AzkarItem(
        id: 's11',
        textAr:
            'أَسْتَغْفِرُ اللَّهَ الَّذِي لَا إِلَهَ إِلَّا هُوَ الْحَيُّ الْقَيُّومُ وَأَتُوبُ إِلَيْهِ',
        countLabel: _thrice,
        count: 3,
      ),
    ],
  ),
  AzkarCategory(
    id: 'prayer',
    titleKey: 'azkar_screen.prayer',
    items: [
      AzkarItem(
        id: 'p1',
        textAr: 'أَسْتَغْفِرُ اللَّهَ',
        countLabel: _thrice,
        count: 3,
      ),
      AzkarItem(
        id: 'p2',
        textAr:
            'اللَّهُمَّ أَنْتَ السَّلَامُ، وَمِنْكَ السَّلَامُ، تَبَارَكْتَ يَا ذَا الْجَلَالِ وَالْإِكْرَامِ',
        countLabel: _once,
      ),
      AzkarItem(
        id: 'p3',
        textAr:
            'لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ، اللَّهُمَّ لَا مَانِعَ لِمَا أَعْطَيْتَ، وَلَا مُعْطِيَ لِمَا مَنَعْتَ، وَلَا يَنْفَعُ ذَا الْجَدِّ مِنْكَ الْجَدُّ',
        countLabel: _once,
      ),
      AzkarItem(
        id: 'p4',
        textAr:
            'اللَّهُمَّ أَعِنِّي عَلَى ذِكْرِكَ، وَشُكْرِكَ، وَحُسْنِ عِبَادَتِكَ',
        countLabel: _once,
      ),
      AzkarItem(
        id: 'p5',
        textAr: 'سُبْحَانَ اللَّهِ',
        countLabel: _thirtyThree,
        count: 33,
      ),
      AzkarItem(
        id: 'p6',
        textAr: 'الْحَمْدُ لِلَّهِ',
        countLabel: _thirtyThree,
        count: 33,
      ),
      AzkarItem(
        id: 'p7',
        textAr: 'اللَّهُ أَكْبَرُ',
        countLabel: _thirtyThree,
        count: 33,
      ),
      // The hundredth, completing the tasbih after the 33+33+33 above.
      AzkarItem(
        id: 'p8',
        textAr:
            'لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ',
        countLabel: _once,
      ),
      AzkarItem(
        id: 'p9',
        textAr: 'azkar_items.ayat_kursi',
        countLabel: _once,
        quranRefs: [_ayatAlKursi],
      ),
      AzkarItem(
        id: 'p10a',
        textAr: _ikhlasLabel,
        countLabel: _once,
        quranRefs: [_ikhlas],
      ),
      AzkarItem(
        id: 'p10b',
        textAr: _falaqLabel,
        countLabel: _once,
        quranRefs: [_falaq],
      ),
      AzkarItem(
        id: 'p10c',
        textAr: _nasLabel,
        countLabel: _once,
        quranRefs: [_nas],
      ),
    ],
  ),

  // الرقية الشرعية — the Quranic passages and prophetic supplications
  // recited for healing and protection.
  //
  // Included as one ordered list because that is how it is performed: it
  // is a sitting, read through from the Fatiha to the closing du'as, not
  // a menu to pick from. The counter therefore doubles as the reader's
  // place in it.
  //
  // The supplications below are the ones in Bukhari, Muslim and Abu Dawud
  // — the same standard of attestation as the rest of this file. Nothing
  // here prescribes or replaces treatment, and the app says nothing about
  // what any of it will do.
  AzkarCategory(
    id: 'ruqyah',
    titleKey: 'azkar_screen.ruqyah',
    items: [
      AzkarItem(
        id: 'r1',
        textAr: 'azkar_items.fatiha',
        countLabel: _once,
        quranRefs: [_fatiha],
      ),
      AzkarItem(
        id: 'r2',
        textAr: 'azkar_items.baqarah_opening',
        countLabel: _once,
        quranRefs: [_baqarahOpening],
      ),
      AzkarItem(
        id: 'r3',
        textAr: 'azkar_items.ayat_kursi',
        countLabel: _once,
        quranRefs: [_ayatAlKursi],
      ),
      AzkarItem(
        id: 'r4',
        textAr: 'azkar_items.baqarah_last_two',
        countLabel: _once,
        quranRefs: [_baqarahLastTwo],
      ),
      AzkarItem(
        id: 'r5',
        textAr: 'azkar_items.aaraf_creation',
        countLabel: _once,
        quranRefs: [_aarafCreation],
      ),
      AzkarItem(
        id: 'r6',
        textAr: 'azkar_items.aaraf_moses',
        countLabel: _once,
        quranRefs: [_aarafMoses],
      ),
      AzkarItem(
        id: 'r7',
        textAr: 'azkar_items.yunus_moses',
        countLabel: _once,
        quranRefs: [_yunusMoses],
      ),
      AzkarItem(
        id: 'r8',
        textAr: 'azkar_items.taha_moses',
        countLabel: _once,
        quranRefs: [_tahaMoses],
      ),
      AzkarItem(
        id: 'r9',
        textAr: 'azkar_items.muminun_closing',
        countLabel: _once,
        quranRefs: [_muminunClosing],
      ),
      AzkarItem(
        id: 'r10',
        textAr: 'azkar_items.saffat_opening',
        countLabel: _once,
        quranRefs: [_saffatOpening],
      ),
      AzkarItem(
        id: 'r11',
        textAr: 'azkar_items.rahman_challenge',
        countLabel: _once,
        quranRefs: [_rahmanChallenge],
      ),
      AzkarItem(
        id: 'r12',
        textAr: 'azkar_items.hashr_closing',
        countLabel: _once,
        quranRefs: [_hashrClosing],
      ),
      AzkarItem(
        id: 'r13',
        textAr: 'azkar_items.jinn_opening',
        countLabel: _once,
        quranRefs: [_jinnOpening],
      ),
      AzkarItem(
        id: 'r13b',
        textAr: 'azkar_items.shifa_verses',
        countLabel: _thrice,
        count: 3,
        quranRefs: _shifaVerses,
      ),
      // The three read three times each, as in the morning and evening
      // lists — separate items so three taps mean three recitations of
      // one surah rather than nine of something ambiguous.
      AzkarItem(
        id: 'r14a',
        textAr: _ikhlasLabel,
        countLabel: _thrice,
        count: 3,
        quranRefs: [_ikhlas],
      ),
      AzkarItem(
        id: 'r14b',
        textAr: _falaqLabel,
        countLabel: _thrice,
        count: 3,
        quranRefs: [_falaq],
      ),
      AzkarItem(
        id: 'r14c',
        textAr: _nasLabel,
        countLabel: _thrice,
        count: 3,
        quranRefs: [_nas],
      ),
      // The prophetic supplications, after the recitation.
      AzkarItem(
        id: 'r15',
        textAr:
            'بِسْمِ اللَّهِ أَرْقِيكَ، مِنْ كُلِّ شَيْءٍ يُؤْذِيكَ، مِنْ شَرِّ كُلِّ نَفْسٍ أَوْ عَيْنٍ حَاسِدٍ، اللَّهُ يَشْفِيكَ، بِسْمِ اللَّهِ أَرْقِيكَ',
        countLabel: _thrice,
        count: 3,
      ),
      AzkarItem(
        id: 'r16',
        textAr:
            'اللَّهُمَّ رَبَّ النَّاسِ، أَذْهِبِ الْبَأْسَ، اشْفِ أَنْتَ الشَّافِي، لَا شِفَاءَ إِلَّا شِفَاؤُكَ، شِفَاءً لَا يُغَادِرُ سَقَمًا',
        countLabel: _thrice,
        count: 3,
      ),
      AzkarItem(
        id: 'r17',
        textAr:
            'أَسْأَلُ اللَّهَ الْعَظِيمَ رَبَّ الْعَرْشِ الْعَظِيمِ أَنْ يَشْفِيَكَ',
        countLabel: _sevenTimes,
        count: 7,
      ),
      AzkarItem(
        id: 'r18',
        textAr:
            'أَعُوذُ بِكَلِمَاتِ اللَّهِ التَّامَّاتِ مِنْ كُلِّ شَيْطَانٍ وَهَامَّةٍ، وَمِنْ كُلِّ عَيْنٍ لَامَّةٍ',
        countLabel: _thrice,
        count: 3,
      ),
      AzkarItem(
        id: 'r19',
        textAr:
            'أَعُوذُ بِكَلِمَاتِ اللَّهِ التَّامَّاتِ مِنْ شَرِّ مَا خَلَقَ',
        countLabel: _thrice,
        count: 3,
      ),
      AzkarItem(
        id: 'r20',
        textAr:
            'بِسْمِ اللَّهِ الَّذِي لَا يَضُرُّ مَعَ اسْمِهِ شَيْءٌ فِي الْأَرْضِ وَلَا فِي السَّمَاءِ وَهُوَ السَّمِيعُ الْعَلِيمُ',
        countLabel: _thrice,
        count: 3,
      ),
      AzkarItem(
        id: 'r21',
        textAr:
            'حَسْبِيَ اللَّهُ لَا إِلَهَ إِلَّا هُوَ عَلَيْهِ تَوَكَّلْتُ وَهُوَ رَبُّ الْعَرْشِ الْعَظِيمِ',
        countLabel: _sevenTimes,
        count: 7,
      ),
      // Said with the hand on the place of pain: three of the first, then
      // seven of the second.
      AzkarItem(
        id: 'r22',
        textAr: 'بِسْمِ اللَّهِ',
        countLabel: _thrice,
        count: 3,
      ),
      AzkarItem(
        id: 'r23',
        textAr:
            'أَعُوذُ بِاللَّهِ وَقُدْرَتِهِ مِنْ شَرِّ مَا أَجِدُ وَأُحَاذِرُ',
        countLabel: _sevenTimes,
        count: 7,
      ),
      AzkarItem(
        id: 'r24',
        textAr:
            'لَا إِلَهَ إِلَّا اللَّهُ الْعَظِيمُ الْحَلِيمُ، لَا إِلَهَ إِلَّا اللَّهُ رَبُّ الْعَرْشِ الْعَظِيمِ، لَا إِلَهَ إِلَّا اللَّهُ رَبُّ السَّمَاوَاتِ وَرَبُّ الْأَرْضِ وَرَبُّ الْعَرْشِ الْكَرِيمِ',
        countLabel: _once,
      ),
    ],
  ),

  // أذكار الاستيقاظ من النوم — said on opening the eyes, before
  // anything else. Kept as its own list rather than folded into the
  // morning azkar: waking and the morning are different moments, and
  // someone waking at noon still says these.
  AzkarCategory(
    id: 'waking',
    titleKey: 'azkar_screen.waking',
    items: [
      AzkarItem(
        id: 'w1',
        textAr:
            'الْحَمْدُ لِلَّهِ الَّذِي أَحْيَانَا بَعْدَ مَا أَمَاتَنَا وَإِلَيْهِ النُّشُورُ',
        countLabel: _once,
      ),
      AzkarItem(
        id: 'w2',
        textAr:
            'لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ الْمُلْكُ وَلَهُ الْحَمْدُ وَهُوَ عَلَى كُلِّ شَيْءٍ قَدِيرٌ، سُبْحَانَ اللَّهِ، وَالْحَمْدُ لِلَّهِ، وَلَا إِلَهَ إِلَّا اللَّهُ، وَاللَّهُ أَكْبَرُ، وَلَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِاللَّهِ الْعَلِيِّ الْعَظِيمِ، رَبِّ اغْفِرْ لِي',
        countLabel: _once,
      ),
      AzkarItem(
        id: 'w3',
        textAr:
            'الْحَمْدُ لِلَّهِ الَّذِي عَافَانِي فِي جَسَدِي، وَرَدَّ عَلَيَّ رُوحِي، وَأَذِنَ لِي بِذِكْرِهِ',
        countLabel: _once,
      ),
      AzkarItem(
        id: 'w4',
        textAr: 'azkar_items.imran_closing',
        countLabel: _once,
        quranRefs: [_imranClosing],
      ),
    ],
  ),

  // أذكار الطعام — before, after, and the du'as around a shared meal.
  AzkarCategory(
    id: 'food',
    titleKey: 'azkar_screen.food',
    items: [
      AzkarItem(
        id: 'f1',
        textAr:
            'بِسْمِ اللَّهِ',
        countLabel: _once,
      ),
      AzkarItem(
        id: 'f2',
        textAr:
            'بِسْمِ اللَّهِ أَوَّلَهُ وَآخِرَهُ',
        countLabel: _once,
      ),
      AzkarItem(
        id: 'f3',
        textAr:
            'الْحَمْدُ لِلَّهِ الَّذِي أَطْعَمَنِي هَذَا وَرَزَقَنِيهِ مِنْ غَيْرِ حَوْلٍ مِنِّي وَلَا قُوَّةٍ',
        countLabel: _once,
      ),
      AzkarItem(
        id: 'f4',
        textAr:
            'الْحَمْدُ لِلَّهِ حَمْدًا كَثِيرًا طَيِّبًا مُبَارَكًا فِيهِ، غَيْرَ مَكْفِيٍّ وَلَا مُوَدَّعٍ وَلَا مُسْتَغْنًى عَنْهُ رَبَّنَا',
        countLabel: _once,
      ),
      AzkarItem(
        id: 'f5',
        textAr:
            'اللَّهُمَّ بَارِكْ لَهُمْ فِيمَا رَزَقْتَهُمْ، وَاغْفِرْ لَهُمْ وَارْحَمْهُمْ',
        countLabel: _once,
      ),
      AzkarItem(
        id: 'f6',
        textAr:
            'أَفْطَرَ عِنْدَكُمُ الصَّائِمُونَ، وَأَكَلَ طَعَامَكُمُ الْأَبْرَارُ، وَصَلَّتْ عَلَيْكُمُ الْمَلَائِكَةُ',
        countLabel: _once,
      ),
      AzkarItem(
        id: 'f7',
        textAr:
            'ذَهَبَ الظَّمَأُ، وَابْتَلَّتِ الْعُرُوقُ، وَثَبَتَ الْأَجْرُ إِنْ شَاءَ اللَّهُ',
        countLabel: _once,
      ),
      AzkarItem(
        id: 'f8',
        textAr:
            'اللَّهُمَّ بَارِكْ لَنَا فِيهِ وَزِدْنَا مِنْهُ',
        countLabel: _once,
      ),
      AzkarItem(
        id: 'f9',
        textAr:
            'اللَّهُمَّ أَطْعِمْ مَنْ أَطْعَمَنِي، وَاسْقِ مَنْ سَقَانِي',
        countLabel: _once,
      ),
    ],
  ),

  // أذكار الأذان — what is said while the muezzin calls and after he
  // finishes. The first item is an instruction rather than a text: what
  // you say is whatever he just said, so there is nothing to print.
  AzkarCategory(
    id: 'adhan',
    titleKey: 'azkar_screen.adhan',
    items: [
      AzkarItem(
        id: 'a1',
        textAr:
            'يُقَالُ مِثْلُ مَا يَقُولُ الْمُؤَذِّنُ، إِلَّا فِي «حَيَّ عَلَى الصَّلَاةِ» وَ«حَيَّ عَلَى الْفَلَاحِ» فَيُقَالُ: لَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِاللَّهِ',
        countLabel: _once,
      ),
      AzkarItem(
        id: 'a2',
        textAr:
            'وَأَنَا أَشْهَدُ أَنْ لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ لَا شَرِيكَ لَهُ، وَأَنَّ مُحَمَّدًا عَبْدُهُ وَرَسُولُهُ، رَضِيتُ بِاللَّهِ رَبًّا، وَبِمُحَمَّدٍ رَسُولًا، وَبِالْإِسْلَامِ دِينًا',
        countLabel: _once,
      ),
      AzkarItem(
        id: 'a3',
        textAr:
            'اللَّهُمَّ صَلِّ وَسَلِّمْ عَلَى نَبِيِّنَا مُحَمَّدٍ',
        countLabel: _once,
      ),
      AzkarItem(
        id: 'a4',
        textAr:
            'اللَّهُمَّ رَبَّ هَذِهِ الدَّعْوَةِ التَّامَّةِ، وَالصَّلَاةِ الْقَائِمَةِ، آتِ مُحَمَّدًا الْوَسِيلَةَ وَالْفَضِيلَةَ، وَابْعَثْهُ مَقَامًا مَحْمُودًا الَّذِي وَعَدْتَهُ',
        countLabel: _once,
      ),
      AzkarItem(
        id: 'a5',
        textAr:
            'اللَّهُمَّ إِنِّي أَسْأَلُكَ مِنْ فَضْلِكَ وَرَحْمَتِكَ، فَإِنَّهُ لَا يَمْلِكُهَا إِلَّا أَنْتَ',
        countLabel: _once,
      ),
    ],
  ),
];

/// Where an instruction item's passage actually is, e.g. "البقرة ٢٥٥" or
/// "Al-Ikhlas 1-4".
///
/// Items like "اقرأ آية الكرسي" name the passage but never say where it sits,
/// so anyone who does not already know it by heart has nothing to look up —
/// and when the verse text cannot be fetched (offline, or the request fails)
/// the instruction is all that is left on screen. Empty for ordinary dhikr,
/// which are their own text and need no citation.
String quranRefLabel(AzkarItem item, {required bool arabic}) {
  if (item.quranRefs.isEmpty) return '';
  String n(int value) => arabic ? toArabicDigits('$value') : '$value';
  return [
    for (final ref in item.quranRefs)
      '${surahDisplayName(surahByNumber(ref.surahNumber), arabic)} '
      '${ref.fromAyah == ref.toAyah ? n(ref.fromAyah) : '${n(ref.fromAyah)}-${n(ref.toAyah)}'}',
  ].join(' • ');
}
