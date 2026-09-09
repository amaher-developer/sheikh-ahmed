import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sheikh_ahmed_app/core/azkar/azkar_data.dart';
import 'package:sheikh_ahmed_app/core/quran/surah_meta.dart';

void main() {
  AzkarCategory byId(String id) =>
      kAzkarCategories.firstWhere((c) => c.id == id);

  Map<String, dynamic> translations(String lang) =>
      jsonDecode(File('assets/translations/$lang.json').readAsStringSync())
          as Map<String, dynamic>;

  group('the new lists exist and are ordered as they are said', () {
    test('waking, food and adhan are all present', () {
      // Not the du'as: those moved to a screen of their own, and their
      // own tests cover them (duas_test.dart).
      for (final id in ['waking', 'food', 'adhan']) {
        expect(
          kAzkarCategories.any((c) => c.id == id),
          isTrue,
          reason: id,
        );
      }
    });

    test('waking opens with the dhikr said on opening the eyes', () {
      // It is the first thing said, before anything else, so it has to be
      // the first row rather than buried in the list.
      final first = byId('waking').items.first;
      expect(first.textAr, contains('أَحْيَانَا بَعْدَ مَا أَمَاتَنَا'));
    });

    test('waking ends with the passage recited on rising', () {
      // Al Imran 190-200, which the Prophet recited on waking — a reference,
      // so the verses come from the Quran source rather than being typed.
      final last = byId('waking').items.last;
      expect(last.quranRefs, hasLength(1));
      expect(last.quranRefs.single.surahNumber, 3);
      expect(last.quranRefs.single.fromAyah, 190);
      expect(last.quranRefs.single.toAyah, 200);
    });

    test('food carries the one said when the naming was forgotten', () {
      // "بسم الله أوّله وآخره" is said when the meal is already under way,
      // which is a different moment from the opening basmala — so it is its
      // own row rather than a note under it.
      final food = byId('food').items;
      expect(food.first.textAr, 'بِسْمِ اللَّهِ');
      expect(
        food.any((i) => i.textAr.contains('أَوَّلَهُ وَآخِرَهُ')),
        isTrue,
      );
    });

    test('food covers the meal, the host and the fast', () {
      final texts = byId('food').items.map((i) => i.textAr).join(' ');
      expect(texts, contains('أَطْعَمَنِي هَذَا وَرَزَقَنِيهِ'));
      expect(texts, contains('بَارِكْ لَهُمْ فِيمَا رَزَقْتَهُمْ'));
      expect(texts, contains('ذَهَبَ الظَّمَأُ'));
    });

    test('adhan starts with what to say while the muezzin calls', () {
      // The first row is an instruction, not a text: what you say is
      // whatever he just said, so there is nothing to print.
      final adhan = byId('adhan').items;
      expect(adhan.first.textAr, contains('مِثْلُ مَا يَقُولُ الْمُؤَذِّنُ'));
      expect(adhan.first.textAr, contains('لَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِاللَّهِ'));
    });

    test('adhan carries the du\'a said after it finishes', () {
      expect(
        byId('adhan').items.any(
          (i) => i.textAr.contains('الدَّعْوَةِ التَّامَّةِ'),
        ),
        isTrue,
      );
    });

  });

  group('the ruqyah after review', () {
    final ruqyah = byId('ruqyah');

    test('it carries the six verses of healing', () {
      // The list had every passage for protection and none of the ones that
      // name شفاء outright — the heart of a ruqyah recited over illness.
      final shifa = ruqyah.items.firstWhere((i) => i.quranRefs.length == 6);
      expect(
        shifa.quranRefs.map((r) => '${r.surahNumber}:${r.fromAyah}').toList(),
        ['9:14', '10:57', '16:69', '17:82', '26:80', '41:44'],
      );
      expect(shifa.count, 3);
    });

    test('they are read after the passages, before the three surahs', () {
      final ids = ruqyah.items.map((i) => i.id).toList();
      expect(ids.indexOf('r13b'), greaterThan(ids.indexOf('r13')));
      expect(ids.indexOf('r13b'), lessThan(ids.indexOf('r14a')));
    });
  });

  group('every list holds together', () {
    test('no two items anywhere share an id', () {
      // Progress is stored per item id, so a collision would make two
      // different azkar count each other up.
      final ids = kAzkarCategories.expand((c) => c.items).map((i) => i.id);
      expect(ids.toSet().length, ids.length);
    });

    test('every reference is inside the surah it names', () {
      for (final item in kAzkarCategories.expand((c) => c.items)) {
        for (final ref in item.quranRefs) {
          final surah = surahByNumber(ref.surahNumber);
          expect(ref.fromAyah, greaterThanOrEqualTo(1), reason: item.id);
          expect(ref.fromAyah, lessThanOrEqualTo(ref.toAyah), reason: item.id);
          expect(
            ref.toAyah,
            lessThanOrEqualTo(surah.ayahCount),
            reason: '${item.id} — ${surah.name} has ${surah.ayahCount}',
          );
        }
      }
    });

    test('a supplication is its own text, never a translation key', () {
      // isLabelKey is derived from having references, so a du'a that
      // accidentally carried one would print its key on screen.
      for (final item in kAzkarCategories.expand((c) => c.items)) {
        if (item.quranRefs.isNotEmpty) continue;
        expect(item.isLabelKey, isFalse, reason: item.id);
        expect(item.textAr.startsWith('azkar_'), isFalse, reason: item.id);
      }
    });

    test('every title and every label resolves in both languages', () {
      for (final lang in ['ar', 'en']) {
        final t = translations(lang);
        for (final category in kAzkarCategories) {
          final parts = category.titleKey.split('.');
          expect(
            (t[parts[0]] as Map<String, dynamic>?)?[parts[1]],
            isNotNull,
            reason: '$lang ${category.titleKey}',
          );
        }
        for (final item in kAzkarCategories.expand((c) => c.items)) {
          for (final key in [
            if (item.isLabelKey) item.textAr,
            item.countLabel,
          ]) {
            final parts = key.split('.');
            expect(
              (t[parts[0]] as Map<String, dynamic>?)?[parts[1]],
              isNotNull,
              reason: '$lang $key',
            );
          }
        }
      }
    });

    test('every category has an icon of its own', () {
      // Without one it falls back to a plain circle while every other chip
      // carries a real icon.
      final screen = File(
        'lib/features/azkar/presentation/azkar_screen.dart',
      ).readAsStringSync();
      for (final category in kAzkarCategories) {
        expect(
          screen.contains("'${category.id}': Icons."),
          isTrue,
          reason: category.id,
        );
      }
    });

    test('a stated count matches the label beside it', () {
      // "ثلاث مرات" over a counter that stops at one is a visible error.
      const expected = {
        'azkar_count.once': 1,
        'azkar_count.thrice': 3,
        'azkar_count.four_times': 4,
        'azkar_count.seven_times': 7,
        'azkar_count.ten_times': 10,
        'azkar_count.thirty_three': 33,
        'azkar_count.thirty_four': 34,
        'azkar_count.hundred': 100,
      };
      for (final item in kAzkarCategories.expand((c) => c.items)) {
        final want = expected[item.countLabel];
        expect(want, isNotNull, reason: '${item.id} ${item.countLabel}');
        expect(item.count, want, reason: item.id);
      }
    });
  });
}
