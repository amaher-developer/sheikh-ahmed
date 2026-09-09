import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sheikh_ahmed_app/core/azkar/azkar_data.dart';
import 'package:sheikh_ahmed_app/core/duas/dua_data.dart';

void main() {
  Map<String, dynamic> translations(String lang) =>
      jsonDecode(File('assets/translations/$lang.json').readAsStringSync())
          as Map<String, dynamic>;

  group('the supplications stand on their own', () {
    test('they are not a category inside the azkar', () {
      // An azkar list is bound to an occasion and is meant to be finished
      // each day, which is why that screen counts a daily progress. Du'as
      // are neither, and under the azkar the app reported "3 of 18 today"
      // over a list nobody is meant to complete.
      expect(kAzkarCategories.any((c) => c.id == 'duas'), isFalse);
    });

    test('the screen shows no daily progress', () {
      final screen = File(
        'lib/features/duas/presentation/duas_screen.dart',
      ).readAsStringSync();

      expect(screen.contains('daily_progress'), isFalse);
      expect(screen.contains('azkarProgressProvider'), isFalse);
    });

    test('it is reachable from the home screen', () {
      final home = File(
        'lib/features/home/presentation/home_screen.dart',
      ).readAsStringSync();

      expect(home.contains('DuasScreen()'), isTrue);
      expect(home.contains("titleKey: 'home.duas'"), isTrue);
    });
  });

  group('the groups', () {
    test('there are enough of them, and enough in each', () {
      // A library, not a sampler. A group with one or two entries is a
      // tab that was not worth the tap.
      expect(kDuaGroups.length, greaterThanOrEqualTo(8));
      expect(kAllDuas.length, greaterThanOrEqualTo(60));
      for (final group in kDuaGroups) {
        expect(group.duas.length, greaterThanOrEqualTo(4),
            reason: group.id);
      }
    });

    test('they cover distinct subjects, not one theme repeated', () {
      // The point of grouping. If they collapsed onto one subject the
      // screen would be a flat list wearing tabs.
      final ids = kDuaGroups.map((g) => g.id).toList();
      expect(ids, contains('guidance'));
      expect(ids, contains('distress'));
      expect(ids, contains('provision'));
      expect(ids, contains('istighfar'));
      expect(ids, contains('tawbah'));
      expect(ids, contains('family'));
      expect(ids.toSet().length, ids.length);
    });

    test('the ones people look for are where they would look', () {
      String textsOf(String id) =>
          kDuaGroups.firstWhere((g) => g.id == id).duas
              .map((d) => d.textAr)
              .join(' ');

      expect(textsOf('distress'), contains('الْعَرْشِ الْعَظِيمِ'));
      expect(textsOf('distress'), contains('الْهَمِّ وَالْحَزَنِ'));
      expect(textsOf('family'), contains('رَبِّ ارْحَمْهُمَا'));
      expect(textsOf('istighfar'), contains('التَّوَّابُ الرَّحِيمُ'));
      expect(textsOf('provision'), contains('رِزْقًا طَيِّبًا'));
      expect(textsOf('guidance'), contains('ثَبِّتْ قَلْبِي عَلَى دِينِكَ'));
    });
  });

  group('the du\'as themselves', () {
    test('no two share an id', () {
      final ids = kAllDuas.map((d) => d.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('each is Arabic text, never a translation key', () {
      // This is what the user says aloud; it does not change with the
      // interface language, and a key here would print on screen.
      for (final dua in kAllDuas) {
        expect(dua.textAr, isNotEmpty, reason: dua.id);
        expect(dua.textAr.startsWith('duas_'), isFalse, reason: dua.id);
        expect(RegExp(r'[a-zA-Z]').hasMatch(dua.textAr), isFalse,
            reason: dua.id);
      }
    });

    test('most carry no count at all', () {
      // A "0 / 1" under every du'a would turn asking into box-ticking.
      // Only the ones traditionally repeated get a counter.
      final counted = kAllDuas.where((d) => d.count > 1).toList();
      expect(counted, isNotEmpty);
      expect(counted.length / kAllDuas.length, lessThan(0.25));
    });

    test('the repeated ones keep their traditional counts', () {
      final istighfar = kAllDuas.firstWhere(
        (d) => d.textAr.contains('التَّوَّابُ الرَّحِيمُ'),
      );
      expect(istighfar.count, 100);

      final hasbuna = kAllDuas.firstWhere(
        (d) => d.textAr.contains('حَسْبُنَا اللَّهُ'),
      );
      expect(hasbuna.count, 7);
    });

    test('a count is never zero or negative', () {
      for (final dua in kAllDuas) {
        expect(dua.count, greaterThanOrEqualTo(1), reason: dua.id);
      }
    });
  });

  test('every group title resolves in both languages', () {
    for (final lang in ['ar', 'en']) {
      final t = translations(lang);
      final section = t['duas_screen'] as Map<String, dynamic>?;
      expect(section, isNotNull, reason: lang);
      expect(section!['title'], isNotNull, reason: lang);
      expect(section['subtitle'], isNotNull, reason: lang);

      for (final group in kDuaGroups) {
        final key = group.titleKey.split('.').last;
        expect(section[key], isNotNull, reason: '$lang ${group.titleKey}');
      }

      final home = t['home'] as Map<String, dynamic>;
      expect(home['duas'], isNotNull, reason: lang);
      expect(home['duas_sub'], isNotNull, reason: lang);
    }
  });
}
