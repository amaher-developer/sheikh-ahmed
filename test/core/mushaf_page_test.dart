import 'dart:io';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sheikh_ahmed_app/core/quran/mushaf_page_data.dart';
import 'package:sheikh_ahmed_app/core/quran/mushaf_page_service.dart';

void main() {
  group('lafz al-jalalah detection', () {
    test('matches every case ending', () {
      // The same word appears as ٱللَّهُ, ٱللَّهَ and ٱللَّهِ on one page. A literal
      // match would colour only one of the three.
      for (final form in ['ٱللَّهُ', 'ٱللَّهَ', 'ٱللَّهِ']) {
        expect(isLafzAlJalalah(form), isTrue, reason: form);
      }
    });

    test('matches attached prepositions and conjunctions', () {
      expect(isLafzAlJalalah('بِٱللَّهِ'), isTrue);
      expect(isLafzAlJalalah('وَٱللَّهُ'), isTrue);
    });

    test('leaves lookalikes alone', () {
      // These share letters with the divine name and appear on the same page;
      // colouring them red would be a visible error in the text.
      for (final word in ['إِلَٰهَ', 'لَهَا', 'لَهُۥ', 'ٱلظَّٰلِمُونَ']) {
        expect(isLafzAlJalalah(word), isFalse, reason: word);
      }
    });
  });

  group('page parsing', () {
    final body = jsonDecode('''
    {"verses":[{"verse_key":"2:253","words":[
      {"code_v1":"A","line_number":1,"text_uthmani":"تِلْكَ","char_type_name":"word"},
      {"code_v1":"B","line_number":1,"text_uthmani":"ٱللَّهُ","char_type_name":"word"},
      {"code_v1":"C","line_number":2,"text_uthmani":"٢٥٣","char_type_name":"end"}
    ]}]}
    ''');

    test('keeps words in order and tags them', () {
      final page = MushafPageService.parseResponse(42, body);
      expect(page.page, 42);
      expect(page.verseKeys, ['2:253']);
      expect(page.words.map((w) => w.glyph), ['A', 'B', 'C']);
      expect(page.words[1].isJalalah, isTrue);
      expect(page.words[2].isEnd, isTrue);
      expect(page.words[0].isJalalah, isFalse);
    });

    test('groups words into printed lines, in order', () {
      final page = MushafPageService.parseResponse(42, body);
      expect(page.lines, hasLength(2));
      expect(page.lines[0].map((w) => w.glyph), ['A', 'B']);
      expect(page.lines[1].map((w) => w.glyph), ['C']);
    });

    test('survives a round trip through storage', () {
      // Pages are cached as JSON; a shape that does not round-trip would mean
      // every page silently refetched on every open.
      final page = MushafPageService.parseResponse(42, body);
      final back = MushafPageData.fromJson(jsonDecode(jsonEncode(page.toJson())));
      expect(back.words.map((w) => w.glyph), page.words.map((w) => w.glyph));
      expect(back.words[1].isJalalah, isTrue);
      expect(back.words[2].isEnd, isTrue);
      expect(back.lines, hasLength(2));
    });
  });

  group('font source', () {
    test('the font generation matches the glyph generation', () {
      // v1 fonts and v2 glyph codes both map the same codepoints, so nothing
      // fails loudly when they are mismatched — the page just renders as
      // broken, disconnected letters with whole lines blank. This pins the
      // pairing so a future URL edit cannot quietly undo it.
      final service = File(
        'lib/core/quran/mushaf_font_service.dart',
      ).readAsStringSync();
      final pages = File(
        'lib/core/quran/mushaf_page_service.dart',
      ).readAsStringSync();

      expect(service.contains('hafs/v1/ttf'), isTrue);
      expect(pages.contains('code_v1'), isTrue);
      expect(pages.contains('code_v2'), isFalse);
    });

    test('fonts come from quran.com, not a raw GitHub URL', () {
      // The identical bytes are on raw.githubusercontent, but that is not a
      // CDN and is not an appropriate host for a published app's traffic.
      final service = File(
        'lib/core/quran/mushaf_font_service.dart',
      ).readAsStringSync();
      expect(service.contains("'https://quran.com/fonts/"), isTrue);
      expect(service.contains('raw.githubusercontent.com'), isFalse);
    });
  });

  group("the printed Mus'haf is the reader, not an option", () {
    final reader = File(
      'lib/features/quran/presentation/surah_reader_screen.dart',
    ).readAsStringSync();

    test('it is what the reader opens in, not one of two options', () {
      // It replaces the old reader rather than sitting beside it: the bar
      // carries no switch between them, and the stored default is the
      // printed page.
      expect(reader.contains("value: 'printed'"), isFalse);
      expect(reader.contains("value: 'mode'"), isFalse);

      final providers = File(
        'lib/core/quran/quran_providers.dart',
      ).readAsStringSync();
      expect(providers.contains('loadPrintedMushaf() => _prefs'), isTrue);
      expect(providers.contains("getBool(_kPrintedMushaf) ?? true"), isTrue);
    });

    test('the way out of it is the reading settings, and only that', () {
      // The printed page has one pre-shaped font per page and a fixed
      // fifteen-line grid, so a reader who needs a larger, different or
      // bold face has to be able to leave it — through the settings sheet,
      // where the reason is explained, rather than a bare toggle.
      expect(reader.contains('printedMushafProvider'), isTrue);
      expect(reader.contains('showReadingSettings(context)'), isTrue);

      final sheet = File(
        'lib/features/quran/presentation/reading_settings_sheet.dart',
      ).readAsStringSync();
      expect(sheet.contains('printedMushafProvider'), isTrue);
      expect(sheet.contains('quranReadingStyleProvider'), isTrue);
      expect(sheet.contains('quranFontSizeProvider'), isTrue);
    });

    test('the font controls are disabled while the printed page is on', () {
      // They do nothing there, and a control that silently does nothing is
      // worse than one that shows it cannot.
      final sheet = File(
        'lib/features/quran/presentation/reading_settings_sheet.dart',
      ).readAsStringSync();
      expect(sheet.contains('IgnorePointer('), isTrue);
      expect(sheet.contains('ignoring: printed'), isTrue);
    });

    test('pages turn right to left in both languages', () {
      // A horizontal PageView already takes its direction from the ambient
      // Directionality, so in Arabic it was turning the right way and
      // reverse: true flipped it back. Pinning the direction instead also
      // keeps it right in the English UI, where the app is left to right.
      final block = reader.substring(
        reader.indexOf('class _PrintedMushafState'),
        reader.indexOf("/// The frame of a Mus'haf page with nothing in it yet."),
      );
      // Comments stripped first: the one above the pager explains why
      // reverse is not used, and naming it there is not using it.
      final code = block
          .split('\n')
          .where((l) => !l.trimLeft().startsWith('//'))
          .join('\n');
      expect(code.contains('reverse:'), isFalse);
      expect(code.contains('material.TextDirection.rtl'), isTrue);
    });

    test('one pager for the whole book, not one per surah', () {
      // Two pagers on the same axis do not hand a gesture to one
      // another, so at the last page of a surah the inner one had
      // nowhere left to go and the swipe died — the reader was stuck at
      // every surah boundary.
      final block = reader.substring(
        reader.indexOf('class _PrintedMushafState'),
        reader.indexOf("/// The frame of a Mus'haf page with nothing in it yet."),
      );
      expect(block.contains('itemCount: MushafPageService.totalPages'), isTrue);

      // And the fallback reader no longer carries a printed pager of its
      // own for the outer one to fight with.
      expect(reader.split('printedMushafPages'), hasLength(2));
    });

    test('the page carries its number and its surah', () {
      // A page with neither is the one thing on screen that cannot say
      // where in the book it is: the printed pages have no other marker.
      final view = File(
        'lib/features/quran/presentation/mushaf_page_view.dart',
      ).readAsStringSync();

      expect(view.contains('_PageLabel'), isTrue);
      expect(view.contains('toArabicDigits'), isTrue,
          reason: 'the number follows the language, like every other digit');
      expect(view.contains('surahDisplayName'), isTrue);
    });

    test('the reader waits for the printed page rather than swapping', () {
      // It used to draw the app's own text immediately and let the
      // printed page replace it a moment later. On the phone that read
      // as a fault: you saw one setting of the Quran, then watched it be
      // exchanged for another. An empty page frame is shown instead.
      expect(reader.contains('_MushafLoading'), isTrue);
      expect(reader.contains('printedState.isLoading'), isTrue);
    });

    test('but it does not wait forever', () {
      // The reason the old behaviour existed: a reader with no
      // connection must not be left with a spinner and no Quran. The
      // fallback still happens, on an error or after a bounded wait.
      expect(reader.contains('printedState.hasError'), isTrue);
      expect(reader.contains('_printedGiveUpAfter'), isTrue);
      expect(reader.contains('_surahPager()'), isTrue);
    });
  });
}
