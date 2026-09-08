import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sheikh_ahmed_app/core/quran/word_audio_service.dart';

dynamic body(String words) => jsonDecode('{"verse":{"words":[$words]}}');

const _hamd =
    '{"char_type_name":"word","text_uthmani":"ٱلْحَمْدُ",'
    '"audio_url":"wbw/001_002_001.mp3"}';
const _lillah =
    '{"char_type_name":"word","text_uthmani":"لِلَّهِ",'
    '"audio_url":"wbw/001_002_002.mp3"}';
const _marker =
    '{"char_type_name":"end","text_uthmani":"٢","audio_url":null}';

void main() {
  group('word audio', () {
    test('relative clip paths are made absolute against the CDN', () {
      final words = WordAudioService.parseResponse(body('$_hamd,$_lillah'));

      expect(words, hasLength(2));
      expect(words.first.text, 'ٱلْحَمْدُ');
      expect(
        words.first.audioUrl,
        'https://audio.qurancdn.com/wbw/001_002_001.mp3',
      );
    });

    test('an already-absolute URL is left alone', () {
      final words = WordAudioService.parseResponse(
        body('{"char_type_name":"word","text_uthmani":"قُلْ",'
            '"audio_url":"https://verses.quran.com/wbw/112_001_001.mp3"}'),
      );
      expect(
        words.single.audioUrl,
        'https://verses.quran.com/wbw/112_001_001.mp3',
      );
    });

    test('the verse-number rosette is not a word of the verse', () {
      // The source calls it a word. Reading it aloud in a word-by-word
      // drill would recite the verse number as if it were revelation.
      final words = WordAudioService.parseResponse(
        body('$_hamd,$_lillah,$_marker'),
      );
      expect(words, hasLength(2));
      expect(words.map((w) => w.text), isNot(contains('٢')));
    });

    test('a word with no recording still appears, in its place', () {
      // Dropping it would silently remove a word from the middle of the
      // verse — worse than showing one that cannot be tapped.
      final words = WordAudioService.parseResponse(
        body('$_hamd,'
            '{"char_type_name":"word","text_uthmani":"رَبِّ","audio_url":null},'
            '$_lillah'),
      );

      expect(words, hasLength(3));
      expect(words[1].text, 'رَبِّ');
      expect(words[1].audioUrl, isNull);
      expect(words[2].text, 'لِلَّهِ');
    });

    test('an empty clip path counts as no recording, not an empty URL', () {
      final words = WordAudioService.parseResponse(
        body('{"char_type_name":"word","text_uthmani":"رَبِّ","audio_url":""}'),
      );
      expect(words.single.audioUrl, isNull);
    });

    test('a word with no text is skipped rather than rendered blank', () {
      final words = WordAudioService.parseResponse(
        body('$_hamd,{"char_type_name":"word","text_uthmani":"  "}'),
      );
      expect(words, hasLength(1));
    });

    test('a cached word survives the round trip', () {
      const word = SpokenWord(text: 'رَبِّ', audioUrl: 'https://x/y.mp3');
      final back = SpokenWord.fromJson(
        jsonDecode(jsonEncode(word.toJson())) as Map<String, dynamic>,
      );
      expect(back.text, word.text);
      expect(back.audioUrl, word.audioUrl);

      const silent = SpokenWord(text: 'رَبِّ', audioUrl: null);
      final silentBack = SpokenWord.fromJson(
        jsonDecode(jsonEncode(silent.toJson())) as Map<String, dynamic>,
      );
      expect(silentBack.audioUrl, isNull);
    });
  });
}
