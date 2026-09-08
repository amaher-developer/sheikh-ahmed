import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../prayer/prayer_providers.dart' show sharedPreferencesProvider;

/// One word of a verse, with its own recording.
///
/// Separate from [MushafWord], which carries the printed page's pre-shaped
/// glyph and nothing readable. A learner working through a verse word by
/// word needs the word as text and a clip of it being recited — neither of
/// which the page data has.
class SpokenWord {
  /// The word as ordinary Uthmani text.
  final String text;

  /// The clip, absolute. Null for a word the reciter has no recording of.
  final String? audioUrl;

  const SpokenWord({required this.text, required this.audioUrl});

  Map<String, dynamic> toJson() => {'t': text, if (audioUrl != null) 'a': audioUrl};

  factory SpokenWord.fromJson(Map<String, dynamic> j) => SpokenWord(
    text: j['t'] as String,
    audioUrl: j['a'] as String?,
  );
}

class WordAudioException implements Exception {}

/// The words of one verse, each with a recording of it.
class WordAudioService {
  final SharedPreferences _prefs;

  WordAudioService(this._prefs);

  /// Where the API's relative `audio_url` values are served from.
  static const _cdn = 'https://audio.qurancdn.com/';

  String _key(String verseKey) => 'quran.words.v1.$verseKey';

  Future<List<SpokenWord>> fetch(String verseKey) async {
    final stored = _prefs.getString(_key(verseKey));
    if (stored != null) {
      try {
        return [
          for (final w in jsonDecode(stored) as List)
            SpokenWord.fromJson(w as Map<String, dynamic>),
        ];
      } catch (_) {
        await _prefs.remove(_key(verseKey));
      }
    }

    final uri = Uri.parse(
      'https://api.quran.com/api/v4/verses/by_key/$verseKey'
      '?words=true&word_fields=audio_url,text_uthmani,char_type_name',
    );

    http.Response response;
    try {
      response = await http.get(uri).timeout(const Duration(seconds: 20));
    } catch (_) {
      throw WordAudioException();
    }
    if (response.statusCode != 200) throw WordAudioException();

    final List<SpokenWord> words;
    try {
      words = parseResponse(jsonDecode(response.body));
    } catch (_) {
      throw WordAudioException();
    }
    if (words.isEmpty) throw WordAudioException();

    await _prefs.setString(
      _key(verseKey),
      jsonEncode([for (final w in words) w.toJson()]),
    );
    return words;
  }

  /// Split out from the fetch so the mapping can be tested without a network.
  static List<SpokenWord> parseResponse(dynamic body) {
    final verse = (body as Map<String, dynamic>)['verse'] as Map<String, dynamic>;
    final words = <SpokenWord>[];

    for (final w in verse['words'] as List<dynamic>) {
      final word = w as Map<String, dynamic>;
      // The closing rosette is a "word" in the source, but it is the verse
      // number, not a word of the verse — reading it aloud in a word-by-word
      // drill would be nonsense, and it has no recording anyway.
      if (word['char_type_name'] != 'word') continue;

      final text = (word['text_uthmani'] as String?)?.trim();
      if (text == null || text.isEmpty) continue;

      final relative = word['audio_url'] as String?;
      words.add(
        SpokenWord(
          text: text,
          // A word with no clip is kept rather than dropped: it is still part
          // of the verse and must appear in its place, just without a tap.
          audioUrl: relative == null || relative.isEmpty
              ? null
              : (relative.startsWith('http') ? relative : '$_cdn$relative'),
        ),
      );
    }

    return words;
  }
}

final wordAudioServiceProvider = Provider<WordAudioService>((ref) {
  return WordAudioService(ref.watch(sharedPreferencesProvider));
});

/// The words of [verseKey] ("2:255"), fetched once and cached.
final wordAudioProvider = FutureProvider.family<List<SpokenWord>, String>((
  ref,
  verseKey,
) {
  return ref.watch(wordAudioServiceProvider).fetch(verseKey);
});
