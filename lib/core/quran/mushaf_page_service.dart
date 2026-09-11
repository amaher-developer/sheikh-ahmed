import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../storage/backup_exclusion.dart';
import 'mushaf_page_data.dart';

class MushafPageException implements Exception {}

/// The glyph layout of one printed Mus'haf page.
///
/// Separate from [QuranTextService], which serves readable Uthmani text for
/// the flowing reader, the tafsir sheet and search. This one serves the
/// pre-shaped glyph codes that only that page's own font can render, together
/// with the line each word sits on — the two things needed to reproduce the
/// printed page and useless for anything else.
class MushafPageService {
  final SharedPreferences _prefs;

  MushafPageService(this._prefs);

  final Map<int, MushafPageData> _cache = {};

  static const totalPages = 604;

  /// One file per page, alongside the page fonts.
  ///
  /// These used to live in SharedPreferences. That was fine while only the
  /// pages someone had actually opened were stored, and wrong the moment the
  /// whole Mus'haf could be downloaded: 604 pages is a few megabytes, and
  /// Android parses the entire preferences file into memory on every cold
  /// start. A page is a file, like its font.
  ///
  /// `v4` is a cache generation. v2 gave each word the verse it belongs to,
  /// v3 gave the page its juz, v4 moved off preferences. Anything stored
  /// under an older one is missing a field this reader expects or is in the
  /// wrong place, so it is dropped rather than read back wrong.
  Future<Directory> _dir() async {
    final dir = Directory(
      '${(await getApplicationDocumentsDirectory()).path}/mushaf_pages_v4',
    );
    if (!await dir.exists()) await dir.create(recursive: true);
    await BackupExclusion.excludeDirectory(dir);
    return dir;
  }

  Future<File> _fileFor(int page) async =>
      File('${(await _dir()).path}/p${page.toString().padLeft(3, '0')}.json');

  /// Removes the preferences entries the old storage left behind.
  ///
  /// Run once, in the background: a device that had opened a few hundred
  /// pages under v3 is carrying that weight in its preferences file forever
  /// otherwise, and nothing reads those keys any more.
  Future<void> purgeLegacyStorage() async {
    final stale = _prefs.getKeys().where(
      (k) => k.startsWith('mushaf.page.v'),
    ).toList();
    for (final key in stale) {
      await _prefs.remove(key);
    }
  }

  /// The pages whose layout is stored on this device.
  Future<Set<int>> cachedPages() async {
    final dir = await _dir();
    final pages = <int>{};
    for (final entry in dir.listSync().whereType<File>()) {
      final name = entry.uri.pathSegments.last;
      if (!name.startsWith('p') || !name.endsWith('.json')) continue;
      final n = int.tryParse(name.substring(1, name.length - 5));
      if (n != null) pages.add(n);
    }
    return pages;
  }

  Future<int> cachedPageCount() async => (await cachedPages()).length;

  Future<MushafPageData> fetchPage(int page) async {
    final memo = _cache[page];
    if (memo != null) return memo;

    final file = await _fileFor(page);
    if (await file.exists()) {
      try {
        final parsed = MushafPageData.fromJson(
          jsonDecode(await file.readAsString()) as Map<String, dynamic>,
        );
        return _cache[page] = parsed;
      } catch (_) {
        // A stored page that no longer parses is treated as absent rather
        // than fatal — the page is simply fetched again.
        await file.delete();
      }
    }

    final uri = Uri.parse(
      'https://api.quran.com/api/v4/verses/by_page/$page'
      '?words=true&per_page=50'
      '&fields=juz_number'
      '&word_fields=code_v1,line_number,text_uthmani,char_type_name',
    );

    http.Response response;
    try {
      response = await http.get(uri).timeout(const Duration(seconds: 20));
    } catch (_) {
      throw MushafPageException();
    }
    if (response.statusCode != 200) throw MushafPageException();

    final MushafPageData data;
    try {
      data = parseResponse(page, jsonDecode(response.body));
    } catch (_) {
      throw MushafPageException();
    }
    if (data.words.isEmpty) throw MushafPageException();

    // Written to .part and renamed, so an interrupted write can never leave
    // a truncated file that [cachedPages] would count as a stored page.
    final part = File('${file.path}.part');
    await part.writeAsString(jsonEncode(data.toJson()), flush: true);
    await part.rename(file.path);
    return _cache[page] = data;
  }

  /// Split out from the fetch so the mapping can be tested without a network.
  static MushafPageData parseResponse(int page, dynamic body) {
    final verses = (body as Map<String, dynamic>)['verses'] as List<dynamic>;
    final words = <MushafWord>[];
    final keys = <String>[];
    var juz = 0;

    for (final v in verses) {
      final verse = v as Map<String, dynamic>;
      final key = verse['verse_key'] as String;
      keys.add(key);
      // "2:255" — surah then ayah.
      final parts = key.split(':');
      final surahNumber = int.parse(parts[0]);
      final ayahNumber = int.parse(parts[1]);
      // The first verse decides, the way the printed header does.
      if (juz == 0) juz = (verse['juz_number'] as num?)?.toInt() ?? 0;
      for (final w in verse['words'] as List<dynamic>) {
        final word = w as Map<String, dynamic>;
        final glyph = word['code_v1'] as String?;
        // A word with no glyph cannot be drawn by the page font; skipping it
        // would silently drop text, so treat the page as unusable instead.
        if (glyph == null) throw MushafPageException();
        words.add(
          MushafWord(
            glyph: glyph,
            line: (word['line_number'] as num?)?.toInt() ?? 1,
            isEnd: word['char_type_name'] == 'end',
            surah: surahNumber,
            ayah: ayahNumber,
            isJalalah: isLafzAlJalalah((word['text_uthmani'] as String?) ?? ''),
          ),
        );
      }
    }

    return MushafPageData(
      page: page,
      words: words,
      verseKeys: keys,
      juz: juz,
    );
  }
}
