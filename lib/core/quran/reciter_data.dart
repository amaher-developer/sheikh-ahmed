/// Reciters available for full-surah audio. Every server URL here was
/// verified reachable (HTTP 206 on a ranged request) against mp3quran.net's
/// public `/api/v3/reciters` listing before shipping — same verification
/// approach as the radio stations.
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
