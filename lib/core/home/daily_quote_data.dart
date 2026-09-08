/// A short Quranic verse or a well-known hadith, shown on the home screen.
enum DailyQuoteType { ayah, hadith }

class DailyQuote {
  final DailyQuoteType type;
  final String text;

  /// "السورة: رقم الآية" for an ayah, or the attribution ("متفق عليه",
  /// "رواه مسلم", ...) for a hadith.
  final String reference;

  const DailyQuote({
    required this.type,
    required this.text,
    required this.reference,
  });
}

/// Short, widely-known verses and hadiths only — this is a daily home-screen
/// highlight, not a reference collection, so everything here is something
/// commonly memorized/cited rather than needing its own citation apparatus.
const List<DailyQuote> kDailyQuotes = [
  DailyQuote(
    type: DailyQuoteType.ayah,
    text: 'وَمَن يَتَّقِ اللَّهَ يَجْعَل لَّهُ مَخْرَجًا',
    reference: 'الطلاق: ٢',
  ),
  DailyQuote(
    type: DailyQuoteType.ayah,
    text: 'إِنَّ مَعَ الْعُسْرِ يُسْرًا',
    reference: 'الشرح: ٦',
  ),
  DailyQuote(
    type: DailyQuoteType.ayah,
    text: 'فَاذْكُرُونِي أَذْكُرْكُمْ وَاشْكُرُوا لِي وَلَا تَكْفُرُونِ',
    reference: 'البقرة: ١٥٢',
  ),
  DailyQuote(
    type: DailyQuoteType.ayah,
    text: 'إِنَّ اللَّهَ مَعَ الصَّابِرِينَ',
    reference: 'البقرة: ١٥٣',
  ),
  DailyQuote(
    type: DailyQuoteType.ayah,
    text: 'رَبَّنَا آتِنَا فِي الدُّنْيَا حَسَنَةً وَفِي الْآخِرَةِ حَسَنَةً وَقِنَا عَذَابَ النَّارِ',
    reference: 'البقرة: ٢٠١',
  ),
  DailyQuote(
    type: DailyQuoteType.ayah,
    text: 'وَقُل رَّبِّ زِدْنِي عِلْمًا',
    reference: 'طه: ١١٤',
  ),
  DailyQuote(
    type: DailyQuoteType.ayah,
    text: 'أَلَا بِذِكْرِ اللَّهِ تَطْمَئِنُّ الْقُلُوبُ',
    reference: 'الرعد: ٢٨',
  ),
  DailyQuote(
    type: DailyQuoteType.ayah,
    text: 'وَقُل رَّبِّ اغْفِرْ وَارْحَمْ وَأَنتَ خَيْرُ الرَّاحِمِينَ',
    reference: 'المؤمنون: ١١٨',
  ),
  DailyQuote(
    type: DailyQuoteType.ayah,
    text: 'إِنَّمَا الْمُؤْمِنُونَ إِخْوَةٌ',
    reference: 'الحجرات: ١٠',
  ),
  DailyQuote(
    type: DailyQuoteType.ayah,
    text: 'وَتَعَاوَنُوا عَلَى الْبِرِّ وَالتَّقْوَىٰ',
    reference: 'المائدة: ٢',
  ),
  DailyQuote(
    type: DailyQuoteType.ayah,
    text: 'رَبِّ اشْرَحْ لِي صَدْرِي وَيَسِّرْ لِي أَمْرِي',
    reference: 'طه: ٢٥-٢٦',
  ),
  DailyQuote(
    type: DailyQuoteType.ayah,
    text: 'وَقُل رَّبِّ ارْحَمْهُمَا كَمَا رَبَّيَانِي صَغِيرًا',
    reference: 'الإسراء: ٢٤',
  ),
  DailyQuote(
    type: DailyQuoteType.ayah,
    text: 'وَبَشِّرِ الصَّابِرِينَ',
    reference: 'البقرة: ١٥٥',
  ),
  DailyQuote(
    type: DailyQuoteType.ayah,
    text: 'وَهُوَ مَعَكُمْ أَيْنَ مَا كُنتُمْ',
    reference: 'الحديد: ٤',
  ),
  DailyQuote(
    type: DailyQuoteType.hadith,
    text: 'الدِّينُ النَّصِيحَةُ',
    reference: 'رواه مسلم',
  ),
  DailyQuote(
    type: DailyQuoteType.hadith,
    text: 'مَنْ لَا يَرْحَمْ لَا يُرْحَمْ',
    reference: 'متفق عليه',
  ),
  DailyQuote(
    type: DailyQuoteType.hadith,
    text: 'الْمُسْلِمُ مَنْ سَلِمَ الْمُسْلِمُونَ مِنْ لِسَانِهِ وَيَدِهِ',
    reference: 'متفق عليه',
  ),
  DailyQuote(
    type: DailyQuoteType.hadith,
    text: 'خَيْرُكُمْ مَنْ تَعَلَّمَ الْقُرْآنَ وَعَلَّمَهُ',
    reference: 'رواه البخاري',
  ),
  DailyQuote(
    type: DailyQuoteType.hadith,
    text: 'الْكَلِمَةُ الطَّيِّبَةُ صَدَقَةٌ',
    reference: 'متفق عليه',
  ),
  DailyQuote(
    type: DailyQuoteType.hadith,
    text: 'تَبَسُّمُكَ فِي وَجْهِ أَخِيكَ صَدَقَةٌ',
    reference: 'رواه الترمذي',
  ),
  DailyQuote(
    type: DailyQuoteType.hadith,
    text: 'الطُّهُورُ شَطْرُ الْإِيمَانِ',
    reference: 'رواه مسلم',
  ),
  DailyQuote(
    type: DailyQuoteType.hadith,
    text: 'إِنَّمَا الْأَعْمَالُ بِالنِّيَّاتِ',
    reference: 'متفق عليه',
  ),
  DailyQuote(
    type: DailyQuoteType.hadith,
    text: 'لَا يُؤْمِنُ أَحَدُكُمْ حَتَّى يُحِبَّ لِأَخِيهِ مَا يُحِبُّ لِنَفْسِهِ',
    reference: 'متفق عليه',
  ),
  DailyQuote(
    type: DailyQuoteType.hadith,
    text: 'مَنْ كَانَ يُؤْمِنُ بِاللَّهِ وَالْيَوْمِ الْآخِرِ فَلْيَقُلْ خَيْرًا أَوْ لِيَصْمُتْ',
    reference: 'متفق عليه',
  ),
  DailyQuote(
    type: DailyQuoteType.hadith,
    text: 'الْمُؤْمِنُ الْقَوِيُّ خَيْرٌ وَأَحَبُّ إِلَى اللَّهِ مِنَ الْمُؤْمِنِ الضَّعِيفِ',
    reference: 'رواه مسلم',
  ),
  DailyQuote(
    type: DailyQuoteType.hadith,
    text: 'مَنْ سَلَكَ طَرِيقًا يَلْتَمِسُ فِيهِ عِلْمًا سَهَّلَ اللَّهُ لَهُ بِهِ طَرِيقًا إِلَى الْجَنَّةِ',
    reference: 'رواه مسلم',
  ),
  DailyQuote(
    type: DailyQuoteType.hadith,
    text: 'الدُّعَاءُ هُوَ الْعِبَادَةُ',
    reference: 'رواه الترمذي وأبو داود',
  ),
  DailyQuote(
    type: DailyQuoteType.hadith,
    text: 'إِنَّ اللَّهَ رَفِيقٌ يُحِبُّ الرِّفْقَ',
    reference: 'رواه مسلم',
  ),
  // Everything below was added to lengthen the rotation: at 29 entries the
  // card came back round every 29 days, which reads as a fixed message
  // rather than a daily one. Deliberately weighted toward short, widely
  // memorized ayat over hadith — an ayah's reference is verifiable against
  // the Mus'haf, whereas a misattributed hadith is a far worse error to
  // ship, so only very well-known ones are included.
  DailyQuote(
    type: DailyQuoteType.ayah,
    text: 'وَعَسَىٰ أَن تَكْرَهُوا شَيْئًا وَهُوَ خَيْرٌ لَّكُمْ',
    reference: 'البقرة: ٢١٦',
  ),
  DailyQuote(
    type: DailyQuoteType.ayah,
    text: 'لَا يُكَلِّفُ اللَّهُ نَفْسًا إِلَّا وُسْعَهَا',
    reference: 'البقرة: ٢٨٦',
  ),
  DailyQuote(
    type: DailyQuoteType.ayah,
    text: 'فَإِنِّي قَرِيبٌ ۖ أُجِيبُ دَعْوَةَ الدَّاعِ إِذَا دَعَانِ',
    reference: 'البقرة: ١٨٦',
  ),
  DailyQuote(
    type: DailyQuoteType.ayah,
    text: 'وَاسْتَعِينُوا بِالصَّبْرِ وَالصَّلَاةِ',
    reference: 'البقرة: ٤٥',
  ),
  DailyQuote(
    type: DailyQuoteType.ayah,
    text: 'إِنَّ اللَّهَ يُحِبُّ التَّوَّابِينَ وَيُحِبُّ الْمُتَطَهِّرِينَ',
    reference: 'البقرة: ٢٢٢',
  ),
  DailyQuote(
    type: DailyQuoteType.ayah,
    text: 'وَقُولُوا لِلنَّاسِ حُسْنًا',
    reference: 'البقرة: ٨٣',
  ),
  DailyQuote(
    type: DailyQuoteType.ayah,
    text: 'حَسْبُنَا اللَّهُ وَنِعْمَ الْوَكِيلُ',
    reference: 'آل عمران: ١٧٣',
  ),
  DailyQuote(
    type: DailyQuoteType.ayah,
    text: 'وَاللَّهُ يُحِبُّ الْمُحْسِنِينَ',
    reference: 'آل عمران: ١٣٤',
  ),
  DailyQuote(
    type: DailyQuoteType.ayah,
    text: 'كُلُّ نَفْسٍ ذَائِقَةُ الْمَوْتِ',
    reference: 'آل عمران: ١٨٥',
  ),
  DailyQuote(
    type: DailyQuoteType.ayah,
    text: 'إِنَّ اللَّهَ لَا يَظْلِمُ مِثْقَالَ ذَرَّةٍ',
    reference: 'النساء: ٤٠',
  ),
  DailyQuote(
    type: DailyQuoteType.ayah,
    text: 'إِنَّ اللَّهَ لَا يُضِيعُ أَجْرَ الْمُحْسِنِينَ',
    reference: 'التوبة: ١٢٠',
  ),
  DailyQuote(
    type: DailyQuoteType.ayah,
    text: 'إِنَّ الْحَسَنَاتِ يُذْهِبْنَ السَّيِّئَاتِ',
    reference: 'هود: ١١٤',
  ),
  DailyQuote(
    type: DailyQuoteType.ayah,
    text: 'إِنَّ رَبِّي قَرِيبٌ مُّجِيبٌ',
    reference: 'هود: ٦١',
  ),
  DailyQuote(
    type: DailyQuoteType.ayah,
    text: 'وَمَا تَوْفِيقِي إِلَّا بِاللَّهِ',
    reference: 'هود: ٨٨',
  ),
  DailyQuote(
    type: DailyQuoteType.ayah,
    text: 'وَاعْبُدْ رَبَّكَ حَتَّىٰ يَأْتِيَكَ الْيَقِينُ',
    reference: 'الحجر: ٩٩',
  ),
  DailyQuote(
    type: DailyQuoteType.ayah,
    text: 'إِنَّ اللَّهَ يَأْمُرُ بِالْعَدْلِ وَالْإِحْسَانِ',
    reference: 'النحل: ٩٠',
  ),
  DailyQuote(
    type: DailyQuoteType.ayah,
    text: 'وَقَضَىٰ رَبُّكَ أَلَّا تَعْبُدُوا إِلَّا إِيَّاهُ وَبِالْوَالِدَيْنِ إِحْسَانًا',
    reference: 'الإسراء: ٢٣',
  ),
  DailyQuote(
    type: DailyQuoteType.ayah,
    text: 'وَاذْكُر رَّبَّكَ إِذَا نَسِيتَ',
    reference: 'الكهف: ٢٤',
  ),
  DailyQuote(
    type: DailyQuoteType.ayah,
    text: 'إِنَّ الصَّلَاةَ تَنْهَىٰ عَنِ الْفَحْشَاءِ وَالْمُنكَرِ',
    reference: 'العنكبوت: ٤٥',
  ),
  DailyQuote(
    type: DailyQuoteType.ayah,
    text: 'إِنَّمَا يُوَفَّى الصَّابِرُونَ أَجْرَهُم بِغَيْرِ حِسَابٍ',
    reference: 'الزمر: ١٠',
  ),
  DailyQuote(
    type: DailyQuoteType.ayah,
    text: 'إِنَّ أَكْرَمَكُمْ عِندَ اللَّهِ أَتْقَاكُمْ',
    reference: 'الحجرات: ١٣',
  ),
  DailyQuote(
    type: DailyQuoteType.ayah,
    text: 'وَمَن يَتَوَكَّلْ عَلَى اللَّهِ فَهُوَ حَسْبُهُ',
    reference: 'الطلاق: ٣',
  ),
  DailyQuote(
    type: DailyQuoteType.ayah,
    text: 'فَاصْبِرْ صَبْرًا جَمِيلًا',
    reference: 'المعارج: ٥',
  ),
  DailyQuote(
    type: DailyQuoteType.ayah,
    text: 'وَأَن لَّيْسَ لِلْإِنسَانِ إِلَّا مَا سَعَىٰ',
    reference: 'النجم: ٣٩',
  ),
  DailyQuote(
    type: DailyQuoteType.ayah,
    text: 'فَمَن يَعْمَلْ مِثْقَالَ ذَرَّةٍ خَيْرًا يَرَهُ',
    reference: 'الزلزلة: ٧',
  ),
  DailyQuote(
    type: DailyQuoteType.hadith,
    text: 'إِنَّمَا الأَعْمَالُ بِالنِّيَّاتِ',
    reference: 'متفق عليه',
  ),
  DailyQuote(
    type: DailyQuoteType.hadith,
    text: 'مَنْ كَانَ يُؤْمِنُ بِاللَّهِ وَالْيَوْمِ الآخِرِ فَلْيَقُلْ خَيْرًا أَوْ لِيَصْمُتْ',
    reference: 'متفق عليه',
  ),
  DailyQuote(
    type: DailyQuoteType.hadith,
    text: 'الطُّهُورُ شَطْرُ الإِيمَانِ',
    reference: 'رواه مسلم',
  ),
  DailyQuote(
    type: DailyQuoteType.hadith,
    text: 'اتَّقِ اللَّهَ حَيْثُمَا كُنْتَ',
    reference: 'رواه الترمذي',
  ),
  DailyQuote(
    type: DailyQuoteType.hadith,
    text: 'مَنْ لَا يَشْكُرُ النَّاسَ لَا يَشْكُرُ اللَّهَ',
    reference: 'رواه الترمذي',
  ),
];

/// Picks the day's quote deterministically from the calendar date — cycling
/// through the whole list in order rather than reseeding random per day,
/// so nothing repeats until every item has been shown once. Stable across
/// rebuilds on the same day; moves on the next.
DailyQuote dailyQuote(DateTime date) {
  final epochDay =
      DateTime(date.year, date.month, date.day).millisecondsSinceEpoch ~/
      Duration.millisecondsPerDay;
  final index = epochDay % kDailyQuotes.length;
  return kDailyQuotes[index];
}
