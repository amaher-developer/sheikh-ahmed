import 'dart:io';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../storage/backup_exclusion.dart';

class MushafFontException implements Exception {}

/// Supplies the per-page font a printed Mus'haf page needs.
///
/// The King Fahd Complex publishes one font per page — 604 of them — whose
/// glyphs are pre-shaped to fill that page's fifteen lines. It is the only way
/// to reproduce the printed page; no single font can, because the shaping is
/// what makes each line end where it ends on paper.
///
/// They are fetched on demand rather than bundled. Measured on the real files,
/// they average around 120 KB, so shipping all 604 would add roughly 72 MB to
/// an app that is already 72 MB. One page is a fast download and is then kept
/// on disk forever, so a page costs its font once.
class MushafFontService {
  MushafFontService();

  /// Pages whose font is registered with the engine in this process. Loading
  /// the same family twice is wasteful but harmless; this makes it cheap to
  /// call [ensureLoaded] on every build.
  final Set<int> _loaded = {};

  /// In-flight loads, so a page scrolled past and back does not start a
  /// second download of the same font.
  final Map<int, Future<void>> _pending = {};

  static String familyFor(int page) => 'QCF_P${_pad(page)}';

  static String _pad(int page) => page.toString().padLeft(3, '0');

  /// The **v1** page fonts, and this must stay in step with the `code_v1`
  /// glyphs [MushafPageService] fetches.
  ///
  /// There are two generations of these fonts, and both map the same
  /// codepoints — a cmap check passes for either — but they map them to
  /// different glyphs. Pairing v1 fonts with code_v2 text (or the reverse)
  /// renders as broken, disconnected letters with whole lines blank: it looks
  /// like a font that failed to load rather than a mismatched one, which is
  /// what makes it worth this comment. Verified by rendering page 42 with
  /// both pairings and comparing against the printed page.
  ///
  /// v1 over v2 because it is a third of the size — 122 KB a page against
  /// 360 KB — for a page that looks the same. Served from quran.com rather
  /// than the GitHub raw URL that carries the identical bytes: raw.github
  /// is not a CDN and is not an appropriate host for a published app.
  static String urlFor(int page) =>
      'https://quran.com/fonts/quran/hafs/v1/ttf/p$page.ttf';

  Future<Directory> _dir() async {
    final dir = Directory(
      '${(await getApplicationDocumentsDirectory()).path}/mushaf_fonts',
    );
    if (!await dir.exists()) await dir.create(recursive: true);
    await BackupExclusion.excludeDirectory(dir);
    return dir;
  }

  Future<File> fileFor(int page) async =>
      File('${(await _dir()).path}/QCF_P${_pad(page)}.ttf');

  Future<bool> isDownloaded(int page) async => (await fileFor(page)).exists();

  /// The pages whose font is already on disk.
  ///
  /// The page numbers rather than a count, so the offline card can ask
  /// which pages have *both* halves stored — a font with no layout is not
  /// a readable page, and counting the two separately reported a Mus'haf
  /// as ready that could not be opened.
  Future<Set<int>> downloadedPages() async {
    final dir = await _dir();
    final pages = <int>{};
    for (final file in dir.listSync().whereType<File>()) {
      final name = file.uri.pathSegments.last;
      if (!name.startsWith('QCF_P') || !name.endsWith('.ttf')) continue;
      final n = int.tryParse(name.substring(5, name.length - 4));
      if (n != null) pages.add(n);
    }
    return pages;
  }

  /// How many page fonts are already on disk, for the offline card.
  Future<int> downloadedCount() async => (await downloadedPages()).length;

  /// Downloads [page]'s font if it isn't already stored, then registers it
  /// with the engine so `fontFamily: familyFor(page)` resolves.
  Future<void> ensureLoaded(int page) {
    if (_loaded.contains(page)) return Future.value();
    return _pending[page] ??= _load(page).whenComplete(() {
      _pending.remove(page);
    });
  }

  Future<void> _load(int page) async {
    final file = await fileFor(page);
    if (!await file.exists()) await download(page);

    final bytes = await file.readAsBytes();
    // A truncated or HTML error body written to disk would fail here rather
    // than render as blank glyphs, which is the failure that would be
    // impossible to diagnose from the screen.
    if (bytes.lengthInBytes < 4096) {
      await file.delete();
      throw MushafFontException();
    }

    final loader = FontLoader(familyFor(page))
      ..addFont(Future.value(ByteData.sublistView(bytes)));
    await loader.load();
    _loaded.add(page);
  }

  /// Fetches the font to disk without registering it — used by the bulk
  /// "download the whole Mus'haf" run, which has no reason to register 604
  /// font families in the engine.
  Future<void> download(int page) async {
    final file = await fileFor(page);
    if (await file.exists()) return;
    final part = File('${file.path}.part');

    final client = http.Client();
    try {
      final response = await client.get(Uri.parse(urlFor(page)));
      if (response.statusCode != 200 || response.bodyBytes.length < 4096) {
        throw MushafFontException();
      }
      // Written to .part and renamed, so an interrupted download can never
      // leave a half-file that isDownloaded would treat as usable.
      await part.writeAsBytes(response.bodyBytes, flush: true);
      await part.rename(file.path);
    } on MushafFontException {
      rethrow;
    } catch (_) {
      throw MushafFontException();
    } finally {
      client.close();
    }
  }
}
