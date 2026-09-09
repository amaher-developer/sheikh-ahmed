import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sheikh_ahmed_app/core/azkar/azkar_data.dart';
import 'package:sheikh_ahmed_app/core/quran/surah_meta.dart';

void main() {
  final ruqyah = kAzkarCategories.firstWhere((c) => c.id == 'ruqyah');

  Map<String, dynamic> translations(String lang) =>
      jsonDecode(File('assets/translations/$lang.json').readAsStringSync())
          as Map<String, dynamic>;

  group('the ruqyah list', () {
    test('is a category of its own, not folded into another', () {
      // It is read as a sitting from beginning to end, so the counter has to
      // track a place in it — which only works if it is one list.
      expect(ruqyah.titleKey, 'azkar_screen.ruqyah');
      expect(ruqyah.items.length, greaterThan(20));
    });

    test('opens with al-Fatiha and the Baqara passages, in order', () {
      final first = ruqyah.items.take(4).toList();
      expect(first[0].quranRefs.single.surahNumber, 1);
      expect(first[1].quranRefs.single.surahNumber, 2);
      expect(first[1].quranRefs.single.fromAyah, 1);
      expect(first[1].quranRefs.single.toAyah, 5);
      // Ayat al-Kursi.
      expect(first[2].quranRefs.single.fromAyah, 255);
      // The last two of al-Baqara.
      expect(first[3].quranRefs.single.fromAyah, 285);
      expect(first[3].quranRefs.single.toAyah, 286);
    });

    test('closes the recitation with the three, three times each', () {
      // Separate items, as in the morning and evening lists: bundling them
      // makes three taps stand for nine recitations.
      // Length checked before reading .single: the six verses of healing
      // are one item with six references, and .single throws on it.
      final three = ruqyah.items.where(
        (i) =>
            i.quranRefs.length == 1 &&
            const [112, 113, 114].contains(i.quranRefs.single.surahNumber),
      ).toList();

      expect(three.map((i) => i.quranRefs.single.surahNumber), [112, 113, 114]);
      expect(three.every((i) => i.count == 3), isTrue);
    });

    test('carries the prophetic supplications as text, not as references', () {
      // These are said, not read from the Mus\'haf, so they are their own
      // text and must work with no connection.
      final duas = ruqyah.items.where((i) => i.quranRefs.isEmpty).toList();
      expect(duas.length, greaterThanOrEqualTo(9));
      expect(
        duas.any((i) => i.textAr.contains('بِسْمِ اللَّهِ أَرْقِيكَ')),
        isTrue,
      );
      expect(
        duas.any((i) => i.textAr.contains('اشْفِ أَنْتَ الشَّافِي')),
        isTrue,
      );
      expect(
        duas.any((i) => i.textAr.contains('رَبَّ الْعَرْشِ الْعَظِيمِ')),
        isTrue,
      );
    });

    test('the counted supplications keep their traditional counts', () {
      AzkarItem byId(String id) =>
          ruqyah.items.firstWhere((i) => i.id == id);

      // Seven for "أسأل الله العظيم ربّ العرش العظيم أن يشفيك", three for
      // the ruqyah of Jibril. A wrong count here is a wrong dhikr.
      expect(byId('r17').count, 7);
      expect(byId('r17').countLabel, 'azkar_count.seven_times');
      expect(byId('r15').count, 3);
      expect(byId('r23').count, 7);
      expect(byId('r24').count, 1);
    });
  });

  group('its references', () {
    test('every passage is inside the surah it names', () {
      // A range running off the end of a surah would fetch nothing and show
      // the reader an instruction with no verses under it.
      for (final item in ruqyah.items) {
        for (final ref in item.quranRefs) {
          final surah = surahByNumber(ref.surahNumber);
          expect(ref.fromAyah, greaterThanOrEqualTo(1), reason: item.id);
          expect(ref.toAyah, lessThanOrEqualTo(surah.ayahCount),
              reason: '${item.id} — ${surah.name} has ${surah.ayahCount}');
          expect(ref.fromAyah, lessThanOrEqualTo(ref.toAyah), reason: item.id);
        }
      }
    });

    test('each one gets a citation the reader can look up', () {
      // The instruction names the passage but never says where it sits, and
      // when the verses cannot be fetched the instruction is all that is
      // left on screen.
      for (final item in ruqyah.items.where((i) => i.quranRefs.isNotEmpty)) {
        expect(quranRefLabel(item, arabic: true), isNotEmpty, reason: item.id);
        expect(quranRefLabel(item, arabic: false), isNotEmpty, reason: item.id);
      }
    });

    test('the closing verses land where they should', () {
      AzkarItem byId(String id) =>
          ruqyah.items.firstWhere((i) => i.id == id);

      expect(quranRefLabel(byId('r12'), arabic: false), 'Al-Hashr 21-24');
      expect(quranRefLabel(byId('r8'), arabic: true), 'طه ٦٩');
    });
  });

  group('its labels', () {
    test('every item resolves to a string in both languages', () {
      // An item whose key is missing renders the key itself — the reader
      // would see "azkar_items.jinn_opening" where the instruction goes.
      for (final lang in ['ar', 'en']) {
        final t = translations(lang);
        for (final item in ruqyah.items.where((i) => i.isLabelKey)) {
          final parts = item.textAr.split('.');
          final section = t[parts[0]] as Map<String, dynamic>?;
          expect(section, isNotNull, reason: '$lang ${item.textAr}');
          expect(section![parts[1]], isNotNull,
              reason: '$lang ${item.textAr}');
        }
        expect(
          (t['azkar_screen'] as Map<String, dynamic>)['ruqyah'],
          isNotNull,
          reason: lang,
        );
      }
    });

    test('the supplications are Arabic text, never a key', () {
      // isLabelKey is derived from having references, so a dua that
      // accidentally carried one would print its key instead of the dhikr.
      for (final item in ruqyah.items.where((i) => i.quranRefs.isEmpty)) {
        expect(item.isLabelKey, isFalse, reason: item.id);
        expect(item.textAr.startsWith('azkar_'), isFalse, reason: item.id);
      }
    });
  });

  test('no two azkar items anywhere share an id', () {
    // Progress is stored per item id, so a collision would make two
    // different azkar count each other up.
    final ids = kAzkarCategories.expand((c) => c.items).map((i) => i.id);
    expect(ids.toSet().length, ids.length);
  });

  test('the category has an icon of its own', () {
    final screen = File(
      'lib/features/azkar/presentation/azkar_screen.dart',
    ).readAsStringSync();
    // Without one it falls back to a plain circle while every other chip
    // carries a real icon.
    expect(screen.contains("'ruqyah': Icons."), isTrue);
  });
}
