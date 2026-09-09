/// Reciters available for full-surah audio.
///
/// Written in a considered order — the ones most people are looking for
/// first — because that is the order the picker shows them in.
///
/// Every URL here was verified reachable before shipping, the same way the
/// radio stations were: a ranged request that must come back 206, for the
/// whole-surah server **and** the everyayah folder, on al-Fatiha, al-Baqara
/// and an-Nas. Both are checked because they are different hosts serving
/// different things, and a reciter present on one is not necessarily on the
/// other — shipping one without the other gives a voice that plays a surah
/// but goes silent on "play from this ayah".
class Reciter {
  final String id;
  final String nameKey;
  final String server;

  /// everyayah.com's per-reciter folder name, for single-ayah files (e.g.
  /// "001001.mp3" = surah 1 ayah 1) — used only for "play from this ayah"
  /// (see ayah_audio.dart), since mp3quran.net only serves whole surahs.
  /// Verified reachable the same way as [server].
  final String everyAyahFolder;

  const Reciter({
    required this.id,
    required this.nameKey,
    required this.server,
    required this.everyAyahFolder,
  });

  String audioUrl(int surahNumber) =>
      '$server${surahNumber.toString().padLeft(3, '0')}.mp3';

  String ayahAudioUrl(int surahNumber, int ayahNumber) =>
      'https://everyayah.com/data/$everyAyahFolder/'
      '${surahNumber.toString().padLeft(3, '0')}'
      '${ayahNumber.toString().padLeft(3, '0')}.mp3';
}

const kReciters = <Reciter>[
  Reciter(
    id: 'afs',
    nameKey: 'reciters.afs',
    server: 'https://server8.mp3quran.net/afs/',
    everyAyahFolder: 'Alafasy_128kbps',
  ),
  Reciter(
    id: 'sds',
    nameKey: 'reciters.sds',
    server: 'https://server11.mp3quran.net/sds/',
    everyAyahFolder: 'Abdurrahmaan_As-Sudais_192kbps',
  ),
  Reciter(
    id: 'shur',
    nameKey: 'reciters.shur',
    server: 'https://server7.mp3quran.net/shur/',
    everyAyahFolder: 'Saood_ash-Shuraym_128kbps',
  ),
  Reciter(
    id: 'basit',
    nameKey: 'reciters.basit',
    server: 'https://server7.mp3quran.net/basit/',
    everyAyahFolder: 'Abdul_Basit_Murattal_192kbps',
  ),
  Reciter(
    id: 'husr',
    nameKey: 'reciters.husr',
    server: 'https://server13.mp3quran.net/husr/',
    everyAyahFolder: 'Husary_128kbps',
  ),
  Reciter(
    id: 'minsh',
    nameKey: 'reciters.minsh',
    server: 'https://server10.mp3quran.net/minsh/',
    everyAyahFolder: 'Minshawy_Murattal_128kbps',
  ),
  Reciter(
    id: 'maher',
    nameKey: 'reciters.maher',
    server: 'https://server12.mp3quran.net/maher/',
    everyAyahFolder: 'MaherAlMuaiqly128kbps',
  ),
  Reciter(
    id: 's_gmd',
    nameKey: 'reciters.s_gmd',
    server: 'https://server7.mp3quran.net/s_gmd/',
    everyAyahFolder: 'Ghamadi_40kbps',
  ),
  Reciter(
    id: 'shatri',
    nameKey: 'reciters.shatri',
    server: 'https://server11.mp3quran.net/shatri/',
    everyAyahFolder: 'Abu_Bakr_Ash-Shaatree_128kbps',
  ),
  Reciter(
    id: 'ajm',
    nameKey: 'reciters.ajm',
    server: 'https://server10.mp3quran.net/ajm/',
    everyAyahFolder: 'ahmed_ibn_ali_al_ajamy_128kbps',
  ),
  Reciter(
    id: 'qtm',
    nameKey: 'reciters.qtm',
    server: 'https://server6.mp3quran.net/qtm/',
    everyAyahFolder: 'Nasser_Alqatami_128kbps',
  ),
  Reciter(
    id: 'hani',
    nameKey: 'reciters.hani',
    server: 'https://server8.mp3quran.net/hani/',
    everyAyahFolder: 'Hani_Rifai_192kbps',
  ),
  Reciter(
    id: 'yasser',
    nameKey: 'reciters.yasser',
    server: 'https://server11.mp3quran.net/yasser/',
    everyAyahFolder: 'Yasser_Ad-Dussary_128kbps',
  ),
  Reciter(
    id: 'frs_a',
    nameKey: 'reciters.frs_a',
    server: 'https://server8.mp3quran.net/frs_a/',
    everyAyahFolder: 'Fares_Abbad_64kbps',
  ),
  Reciter(
    id: 'ayyub',
    nameKey: 'reciters.ayyub',
    server: 'https://server8.mp3quran.net/ayyub/',
    everyAyahFolder: 'Muhammad_Ayyoub_128kbps',
  ),
  Reciter(
    id: 'hthfi',
    nameKey: 'reciters.hthfi',
    server: 'https://server9.mp3quran.net/hthfi/',
    everyAyahFolder: 'Hudhaify_128kbps',
  ),
  Reciter(
    id: 'jbrl',
    nameKey: 'reciters.jbrl',
    server: 'https://server8.mp3quran.net/jbrl/',
    everyAyahFolder: 'Muhammad_Jibreel_128kbps',
  ),
  Reciter(
    id: 'bsfr',
    nameKey: 'reciters.bsfr',
    server: 'https://server6.mp3quran.net/bsfr/',
    everyAyahFolder: 'Abdullah_Basfar_192kbps',
  ),
  Reciter(
    id: 'mtrod',
    nameKey: 'reciters.mtrod',
    server: 'https://server8.mp3quran.net/mtrod/',
    everyAyahFolder: 'Abdullah_Matroud_128kbps',
  ),
  Reciter(
    id: 'bu_khtr',
    nameKey: 'reciters.bu_khtr',
    server: 'https://server8.mp3quran.net/bu_khtr/',
    everyAyahFolder: 'Salaah_AbdulRahman_Bukhatir_128kbps',
  ),
  Reciter(
    id: 'jhn',
    nameKey: 'reciters.jhn',
    server: 'https://server13.mp3quran.net/jhn/',
    everyAyahFolder: 'Abdullaah_3awwaad_Al-Juhaynee_128kbps',
  ),
];

// kReciters[0] isn't usable in a const context (const list indexing isn't
// a constant expression in Dart), so this is `final` rather than `const`.
final kDefaultReciter = kReciters.first;

Reciter findReciter(String? id) {
  if (id == null) return kDefaultReciter;
  for (final reciter in kReciters) {
    if (reciter.id == id) return reciter;
  }
  return kDefaultReciter;
}
