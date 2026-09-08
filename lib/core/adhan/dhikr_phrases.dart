/// Short remembrances pushed as notifications through the day (see
/// AdhanScheduler.scheduleHourly).
///
/// Deliberately a separate, shorter list from [kAzkarCategories]: those are
/// full adhkar with repetition counts, meant to be worked through on the
/// Azkar screen. These have to fit a notification line and be readable at a
/// glance on a lock screen.
///
/// Left in Arabic in both locales, like the home-screen widget's phrases:
/// these are the dhikr themselves, not UI labels, so they aren't
/// translated.
const kDhikrPhrases = <String>[
  'سُبْحَانَ اللَّهِ',
  'الْحَمْدُ لِلَّهِ',
  'اللَّهُ أَكْبَرُ',
  'لَا إِلَهَ إِلَّا اللَّهُ',
  'سُبْحَانَ اللَّهِ وَبِحَمْدِهِ',
  'سُبْحَانَ اللَّهِ الْعَظِيمِ',
  'أَسْتَغْفِرُ اللَّهَ',
  'أَسْتَغْفِرُ اللَّهَ وَأَتُوبُ إِلَيْهِ',
  'لَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِاللَّهِ',
  'حَسْبُنَا اللَّهُ وَنِعْمَ الْوَكِيلُ',
  'اللَّهُمَّ صَلِّ عَلَى مُحَمَّدٍ',
  'مَا شَاءَ اللَّهُ',
  'تَبَارَكَ اللَّهُ',
  'بِسْمِ اللَّهِ',
  'الْحَمْدُ لِلَّهِ رَبِّ الْعَالَمِينَ',
  'لَا إِلَهَ إِلَّا اللَّهُ وَحْدَهُ',
  'سُبْحَانَ الْمَلِكِ الْقُدُّوسِ',
  'اللَّهُمَّ لَكَ الْحَمْدُ',
  'عَلَى اللَّهِ تَوَكَّلْتُ',
  'رَبِّ اغْفِرْ لِي',
  'يَا حَيُّ يَا قَيُّومُ',
  'اللَّهُمَّ اغْفِرْ لِي وَارْحَمْنِي',
  'اللَّهُمَّ إِنِّي أَسْأَلُكَ الْجَنَّةَ',
  'اللَّهُمَّ أَجِرْنِي مِنَ النَّارِ',
  'رَبَّنَا تَقَبَّلْ مِنَّا',
  'رَبِّ زِدْنِي عِلْمًا',
  'اللَّهُمَّ بَارِكْ لَنَا',
  'اللَّهُمَّ اهْدِنِي',
  'اللَّهُمَّ ارْزُقْنِي حَلَالًا طَيِّبًا',
  'اللَّهُمَّ اشْفِ مَرْضَانَا',
  'اللَّهُمَّ ارْحَمْ وَالِدَيَّ',
  'اللَّهُمَّ أَنْتَ السَّلَامُ',
  'رَبِّ اشْرَحْ لِي صَدْرِي',
  'اللَّهُمَّ أَعِنِّي عَلَى ذِكْرِكَ',
  'اللَّهُمَّ اجْعَلْنِي مِنَ التَّوَّابِينَ',
  'إِنَّا لِلَّهِ وَإِنَّا إِلَيْهِ رَاجِعُونَ',
  'رَبَّنَا آتِنَا فِي الدُّنْيَا حَسَنَةً',
  'اللَّهُمَّ أَصْلِحْ لِي شَأْنِي كُلَّهُ',
  'اللَّهُمَّ ثَبِّتْ قَلْبِي عَلَى دِينِكَ',
  'سُبْحَانَ اللَّهِ وَبِحَمْدِهِ عَدَدَ خَلْقِهِ',
];

/// The phrase at [index], wrapping round the list.
///
/// Stepping through in order rather than picking at random: random
/// repeats, and a banner that shows the same dhikr twice in a row reads as
/// broken. The caller persists the index so the rotation also survives the
/// app being closed instead of restarting at the top every launch.
String dhikrPhrase(int index) =>
    kDhikrPhrases[index % kDhikrPhrases.length];
