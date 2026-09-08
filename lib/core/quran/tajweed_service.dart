import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../prayer/prayer_providers.dart' show sharedPreferencesProvider;
import 'tajweed.dart';

class TajweedException implements Exception {}

/// The tajweed-marked text of one verse.
///
/// Fetched per verse rather than per page: the rules are shown for the verse
/// a reader taps, and pulling a whole page of markup to colour one line would
/// be most of a page of text nobody asked for.
class TajweedService {
  final SharedPreferences _prefs;

  TajweedService(this._prefs);

  final Map<String, List<TajweedSpan>> _cache = {};

  String _key(String verseKey) => 'quran.tajweed.v1.$verseKey';

  Future<List<TajweedSpan>> fetch(int surah, int ayah) async {
    final verseKey = '$surah:$ayah';

    final memo = _cache[verseKey];
    if (memo != null) return memo;

    final stored = _prefs.getString(_key(verseKey));
    if (stored != null) return _cache[verseKey] = parseTajweed(stored);

    final uri = Uri.parse(
      'https://api.quran.com/api/v4/verses/by_key/$verseKey'
      '?fields=text_uthmani_tajweed',
    );

    http.Response response;
    try {
      response = await http.get(uri).timeout(const Duration(seconds: 15));
    } catch (_) {
      throw TajweedException();
    }
    if (response.statusCode != 200) throw TajweedException();

    final String markup;
    try {
      final verse = (jsonDecode(response.body)
          as Map<String, dynamic>)['verse'] as Map<String, dynamic>;
      markup = verse['text_uthmani_tajweed'] as String;
    } catch (_) {
      throw TajweedException();
    }
    if (markup.isEmpty) throw TajweedException();

    // The markup is stored, not the parsed spans: it is the smaller of the
    // two and re-parsing it is trivial, so a colour or rule change later
    // needs no cache bump.
    await _prefs.setString(_key(verseKey), markup);
    return _cache[verseKey] = parseTajweed(markup);
  }
}

final tajweedServiceProvider = Provider<TajweedService>((ref) {
  return TajweedService(ref.watch(sharedPreferencesProvider));
});

/// The coloured spans of one verse, keyed "surah:ayah".
final tajweedProvider = FutureProvider.family<List<TajweedSpan>, String>((
  ref,
  verseKey,
) {
  final parts = verseKey.split(':');
  return ref
      .watch(tajweedServiceProvider)
      .fetch(int.parse(parts[0]), int.parse(parts[1]));
});
