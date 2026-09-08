/// The 114 surah names/ayah counts/revelation type — structural metadata
/// about the Mus'haf's table of contents, not verse text. The actual verse
/// text is fetched live per-surah (see quran_text_service.dart) rather than
/// stored here.
class Surah {
  final int number;
  final String name;

  /// Transliterated name, shown when the app is in English. The Arabic
  /// [name] used to be shown in both locales, which left the surah list
  /// unreadable for anyone who does not read Arabic.
  final String englishName;
  final bool meccan;
  final int ayahCount;
  bool favorite;

  Surah(
    this.number,
    this.name,
    this.englishName,
    this.meccan,
    this.ayahCount, {
    this.favorite = false,
  });
}

final List<Surah> kAllSurahs = [
  Surah(1, 'الفاتحة', 'Al-Faatiha', true, 7),
  Surah(2, 'البقرة', 'Al-Baqara', false, 286),
  Surah(3, 'آل عمران', 'Aal-i-Imraan', false, 200),
  Surah(4, 'النساء', 'An-Nisaa', false, 176),
  Surah(5, 'المائدة', 'Al-Maaida', false, 120),
  Surah(6, 'الأنعام', "Al-An'aam", true, 165),
  Surah(7, 'الأعراف', "Al-A'raaf", true, 206),
  Surah(8, 'الأنفال', 'Al-Anfaal', false, 75),
  Surah(9, 'التوبة', 'At-Tawba', false, 129),
  Surah(10, 'يونس', 'Yunus', true, 109),
  Surah(11, 'هود', 'Hud', true, 123),
  Surah(12, 'يوسف', 'Yusuf', true, 111),
  Surah(13, 'الرعد', "Ar-Ra'd", false, 43),
  Surah(14, 'إبراهيم', 'Ibrahim', true, 52),
  Surah(15, 'الحجر', 'Al-Hijr', true, 99),
  Surah(16, 'النحل', 'An-Nahl', true, 128),
  Surah(17, 'الإسراء', 'Al-Israa', true, 111),
  Surah(18, 'الكهف', 'Al-Kahf', true, 110),
  Surah(19, 'مريم', 'Maryam', true, 98),
  Surah(20, 'طه', 'Taa-Haa', true, 135),
  Surah(21, 'الأنبياء', 'Al-Anbiyaa', true, 112),
  Surah(22, 'الحج', 'Al-Hajj', false, 78),
  Surah(23, 'المؤمنون', 'Al-Muminoon', true, 118),
  Surah(24, 'النور', 'An-Noor', false, 64),
  Surah(25, 'الفرقان', 'Al-Furqaan', true, 77),
  Surah(26, 'الشعراء', "Ash-Shu'araa", true, 227),
  Surah(27, 'النمل', 'An-Naml', true, 93),
  Surah(28, 'القصص', 'Al-Qasas', true, 88),
  Surah(29, 'العنكبوت', 'Al-Ankaboot', true, 69),
  Surah(30, 'الروم', 'Ar-Room', true, 60),
  Surah(31, 'لقمان', 'Luqman', true, 34),
  Surah(32, 'السجدة', 'As-Sajda', true, 30),
  Surah(33, 'الأحزاب', 'Al-Ahzaab', false, 73),
  Surah(34, 'سبإ', 'Saba', true, 54),
  Surah(35, 'فاطر', 'Faatir', true, 45),
  Surah(36, 'يس', 'Yaseen', true, 83),
  Surah(37, 'الصافات', 'As-Saaffaat', true, 182),
  Surah(38, 'ص', 'Saad', true, 88),
  Surah(39, 'الزمر', 'Az-Zumar', true, 75),
  Surah(40, 'غافر', 'Ghafir', true, 85),
  Surah(41, 'فصلت', 'Fussilat', true, 54),
  Surah(42, 'الشورى', 'Ash-Shura', true, 53),
  Surah(43, 'الزخرف', 'Az-Zukhruf', true, 89),
  Surah(44, 'الدخان', 'Ad-Dukhaan', true, 59),
  Surah(45, 'الجاثية', 'Al-Jaathiya', true, 37),
  Surah(46, 'الأحقاف', 'Al-Ahqaf', true, 35),
  Surah(47, 'محمد', 'Muhammad', false, 38),
  Surah(48, 'الفتح', 'Al-Fath', false, 29),
  Surah(49, 'الحجرات', 'Al-Hujuraat', false, 18),
  Surah(50, 'ق', 'Qaaf', true, 45),
  Surah(51, 'الذاريات', 'Adh-Dhaariyat', true, 60),
  Surah(52, 'الطور', 'At-Tur', true, 49),
  Surah(53, 'النجم', 'An-Najm', true, 62),
  Surah(54, 'القمر', 'Al-Qamar', true, 55),
  Surah(55, 'الرحمن', 'Ar-Rahmaan', false, 78),
  Surah(56, 'الواقعة', 'Al-Waaqia', true, 96),
  Surah(57, 'الحديد', 'Al-Hadid', false, 29),
  Surah(58, 'المجادلة', 'Al-Mujaadila', false, 22),
  Surah(59, 'الحشر', 'Al-Hashr', false, 24),
  Surah(60, 'الممتحنة', 'Al-Mumtahana', false, 13),
  Surah(61, 'الصف', 'As-Saff', false, 14),
  Surah(62, 'الجمعة', "Al-Jumu'a", false, 11),
  Surah(63, 'المنافقون', 'Al-Munaafiqoon', false, 11),
  Surah(64, 'التغابن', 'At-Taghaabun', false, 18),
  Surah(65, 'الطلاق', 'At-Talaaq', false, 12),
  Surah(66, 'التحريم', 'At-Tahrim', false, 12),
  Surah(67, 'الملك', 'Al-Mulk', true, 30),
  Surah(68, 'القلم', 'Al-Qalam', true, 52),
  Surah(69, 'الحاقة', 'Al-Haaqqa', true, 52),
  Surah(70, 'المعارج', "Al-Ma'aarij", true, 44),
  Surah(71, 'نوح', 'Nooh', true, 28),
  Surah(72, 'الجن', 'Al-Jinn', true, 28),
  Surah(73, 'المزمل', 'Al-Muzzammil', true, 20),
  Surah(74, 'المدثر', 'Al-Muddaththir', true, 56),
  Surah(75, 'القيامة', 'Al-Qiyaama', true, 40),
  Surah(76, 'الإنسان', 'Al-Insaan', false, 31),
  Surah(77, 'المرسلات', 'Al-Mursalaat', true, 50),
  Surah(78, 'النبإ', 'An-Naba', true, 40),
  Surah(79, 'النازعات', "An-Naazi'aat", true, 46),
  Surah(80, 'عبس', 'Abasa', true, 42),
  Surah(81, 'التكوير', 'At-Takwir', true, 29),
  Surah(82, 'الانفطار', 'Al-Infitaar', true, 19),
  Surah(83, 'المطففين', 'Al-Mutaffifin', true, 36),
  Surah(84, 'الانشقاق', 'Al-Inshiqaaq', true, 25),
  Surah(85, 'البروج', 'Al-Burooj', true, 22),
  Surah(86, 'الطارق', 'At-Taariq', true, 17),
  Surah(87, 'الأعلى', "Al-A'laa", true, 19),
  Surah(88, 'الغاشية', 'Al-Ghaashiya', true, 26),
  Surah(89, 'الفجر', 'Al-Fajr', true, 30),
  Surah(90, 'البلد', 'Al-Balad', true, 20),
  Surah(91, 'الشمس', 'Ash-Shams', true, 15),
  Surah(92, 'الليل', 'Al-Lail', true, 21),
  Surah(93, 'الضحى', 'Ad-Dhuhaa', true, 11),
  Surah(94, 'الشرح', 'Ash-Sharh', true, 8),
  Surah(95, 'التين', 'At-Tin', true, 8),
  Surah(96, 'العلق', 'Al-Alaq', true, 19),
  Surah(97, 'القدر', 'Al-Qadr', true, 5),
  Surah(98, 'البينة', 'Al-Bayyina', false, 8),
  Surah(99, 'الزلزلة', 'Az-Zalzala', false, 8),
  Surah(100, 'العاديات', 'Al-Aadiyaat', true, 11),
  Surah(101, 'القارعة', "Al-Qaari'a", true, 11),
  Surah(102, 'التكاثر', 'At-Takaathur', true, 8),
  Surah(103, 'العصر', 'Al-Asr', true, 3),
  Surah(104, 'الهمزة', 'Al-Humaza', true, 9),
  Surah(105, 'الفيل', 'Al-Fil', true, 5),
  Surah(106, 'قريش', 'Quraish', true, 4),
  Surah(107, 'الماعون', "Al-Maa'un", true, 7),
  Surah(108, 'الكوثر', 'Al-Kawthar', true, 3),
  Surah(109, 'الكافرون', 'Al-Kaafiroon', true, 6),
  Surah(110, 'النصر', 'An-Nasr', false, 3),
  Surah(111, 'المسد', 'Al-Masad', true, 5),
  Surah(112, 'الإخلاص', 'Al-Ikhlaas', true, 4),
  Surah(113, 'الفلق', 'Al-Falaq', true, 5),
  Surah(114, 'الناس', 'An-Naas', true, 6),
];

/// The name to show for [surah] in the given locale.
String surahDisplayName(Surah surah, bool arabic) =>
    arabic ? surah.name : surah.englishName;

Surah surahByNumber(int number) =>
    kAllSurahs.firstWhere((s) => s.number == number);
