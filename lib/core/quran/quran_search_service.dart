import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

/// One verse matching a search.
class AyahHit {
  final int surah;
  final int ayah;

  /// The verse text, plain. Not the Mus'haf glyphs: those only render in
  /// their own page's font, which a results list has no business fetching.
  final String text;

  const AyahHit({
    required this.surah,
    required this.ayah,
    required this.text,
  });

  String get verseKey => '$surah:$ayah';
}

class QuranSearchException implements Exception {}

/// Searches the text of the Quran.
///
/// Server-side rather than over the surahs cached on the device: the cache
/// holds only what has been opened, so a local search would quietly miss most
/// of the Quran and give an answer that looks complete. It also means the
/// search is diacritic-insensitive without this app having to normalise
/// Uthmani orthography itself, which is where a hand-rolled version goes
/// wrong — الرحمن and ٱلرَّحۡمَٰن are the same word to a reader and different
/// strings to a computer.
class QuranSearchService {
  const QuranSearchService();

  static const _maxResults = 40;

  Future<List<AyahHit>> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];

    final uri = Uri.parse(
      'https://api.quran.com/api/v4/search'
      '?q=${Uri.encodeQueryComponent(trimmed)}&size=$_maxResults',
    );

    http.Response response;
    try {
      response = await http.get(uri).timeout(const Duration(seconds: 15));
    } catch (_) {
      throw QuranSearchException();
    }
    if (response.statusCode != 200) throw QuranSearchException();

    try {
      return parseResults(jsonDecode(response.body));
    } catch (_) {
      throw QuranSearchException();
    }
  }

  /// Split out from the fetch so the mapping can be tested without a network.
  static List<AyahHit> parseResults(dynamic body) {
    final search = (body as Map<String, dynamic>)['search'];
    final results = (search as Map<String, dynamic>)['results'] as List<dynamic>;

    final hits = <AyahHit>[];
    for (final r in results) {
      final row = r as Map<String, dynamic>;
      final key = row['verse_key'] as String?;
      if (key == null) continue;
      final parts = key.split(':');
      if (parts.length != 2) continue;
      final surah = int.tryParse(parts[0]);
      final ayah = int.tryParse(parts[1]);
      if (surah == null || ayah == null) continue;

      // `text` carries the match wrapped in <em> tags. Stripped rather than
      // rendered: the list shows the verse, and a half-highlighted word in a
      // font that does not shape Uthmani properly reads worse than plain.
      final text = (row['text'] as String? ?? '')
          .replaceAll(RegExp('<[^>]+>'), '')
          .trim();

      hits.add(AyahHit(surah: surah, ayah: ayah, text: text));
    }
    return hits;
  }
}

final quranSearchServiceProvider = Provider<QuranSearchService>((ref) {
  return const QuranSearchService();
});

/// Results for one query.
///
/// Keyed on the query, so Riverpod caches each one and going back to a search
/// already made costs nothing. The screen debounces before it gets here — a
/// family keyed on every keystroke would fire a request per letter.
final quranSearchProvider = FutureProvider.family<List<AyahHit>, String>((
  ref,
  query,
) {
  return ref.watch(quranSearchServiceProvider).search(query);
});
