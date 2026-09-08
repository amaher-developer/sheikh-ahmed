import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:sheikh_ahmed_app/core/adhan/adhan_providers.dart';
import 'package:sheikh_ahmed_app/core/audio/audio_providers.dart';
import 'package:sheikh_ahmed_app/core/audio/quran_audio_handler.dart';
import 'package:sheikh_ahmed_app/core/prayer/prayer_providers.dart';
import 'package:sheikh_ahmed_app/core/quran/mushaf_providers.dart';
import 'package:sheikh_ahmed_app/core/quran/quran_providers.dart';
import 'package:sheikh_ahmed_app/core/quran/quran_text_service.dart';
import 'package:sheikh_ahmed_app/main.dart';

/// Avoids a real network call in the test: returns enough synthetic ayahs
/// (with real-looking length) that the reader actually needs to scroll,
/// so the reading-position tracker (which is driven by scroll fraction —
/// see ayah_position.dart) has something to estimate against.
class FakeQuranTextService extends QuranTextService {
  FakeQuranTextService(super.prefs);

  @override
  Future<List<Ayah>> fetchSurah(int surahNumber, {bool includeTranslation = false}) async {
    return List.generate(60, (i) {
      final n = i + 1;
      return Ayah(
        numberInSurah: n,
        text: 'نص الآية رقم $n ' * 8,
        juz: 1,
        page: 1 + i ~/ 8,
      );
    });
  }
}

void main() {
  testWidgets(
    'reading the reader screen and going back updates the "continue reading" '
    'position away from the hardcoded Al-Kahf default',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.runAsync(() => EasyLocalization.ensureInitialized());
      final prefs = await tester.runAsync(() => SharedPreferences.getInstance());

      final audioHandler = QuranAudioHandler();
      addTearDown(audioHandler.stop);

      await tester.pumpWidget(
        EasyLocalization(
          supportedLocales: const [Locale('ar'), Locale('en')],
          path: 'assets/translations',
          fallbackLocale: const Locale('ar'),
          startLocale: const Locale('ar'),
          child: ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs!),
              audioHandlerProvider.overrideWithValue(audioHandler),
              notificationsPluginProvider.overrideWithValue(
                FlutterLocalNotificationsPlugin(),
              ),
              // These tests are about the fallback reader — the app's own
              // text layout, which is what the screen shows when the
              // printed Mus'haf page cannot be fetched. Made explicit
              // rather than left to a network call that happens to fail:
              // under the fake clock it never resolves either way, and the
              // reader sat on its loading frame instead.
              mushafPageProvider.overrideWith(
                (ref, page) => Future<Never>.error(Exception('offline')),
              ),
              mushafFontProvider.overrideWith(
                (ref, page) => Future<Never>.error(Exception('offline')),
              ),
              quranTextServiceProvider.overrideWithValue(
                FakeQuranTextService(prefs),
              ),
            ],
            child: const SheikhAhmedApp(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Go to the Quran tab.
      await tester.tap(find.text('القرآن').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Sanity check: before any reading has ever been saved, the default
      // (quran_providers.dart: `_prefs.getInt(_kSurah) ?? 18`) is Al-Kahf,
      // so the "continue reading" card shows it — checked unscrolled, where
      // only the card's copy can be showing. The list itself is built
      // lazily now (see quran_screen.dart's SliverList.builder), and
      // Al-Kahf is the 18th of 114 surahs, off-screen until scrolled to;
      // scrolling that far would also scroll the card itself out of view,
      // so there's no single scroll position where both copies show at
      // once anymore — this only checks the card.
      expect(find.text('الكهف'), findsOneWidget);

      // Open a different, long surah (Al-Baqarah) from the list — tapping
      // the row (not the play button) is what opens SurahReaderScreen.
      // Scrolled to first: the list is lazy, so a row exists in the tree
      // only once it is near the viewport, and the offline-download card
      // above the list pushes it out of the built range.
      await tester.scrollUntilVisible(
        find.text('البقرة'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      await tester.tap(find.text('البقرة').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      // Two steps now, not one: the screen first resolves whether the
      // printed Mus'haf page can be drawn, and only then builds the
      // fallback reader, whose own surah fetch starts there.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(find.byType(SingleChildScrollView), findsOneWidget);

      // Scroll well into the surah so _furthestAyah advances past 1.
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -4000),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // The position must already be persisted from scrolling alone —
      // saving happens as _furthestAyah advances, not at dispose() (see
      // _savePosition's doc comment for why dispose() can't be used here).
      expect(prefs.getInt('quran.reading.surah'), 2);
      expect(
        prefs.getInt('quran.reading.ayah'),
        greaterThan(1),
        reason:
            'Scrolling well into the surah should have advanced '
            '_furthestAyah past the opening ayah and saved it immediately.',
      );

      // Now go back and confirm it sticks (i.e. nothing on the way out
      // reverts it) and the "continue reading" card reflects it.
      final backButton = find.byType(BackButton);
      expect(backButton, findsOneWidget);
      await tester.tap(backButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));

      expect(tester.takeException(), isNull);
      // The card moved on to Al-Baqarah — Al-Kahf (18th in the lazily
      // built list, unscrolled here) shows nowhere now.
      expect(find.text('الكهف'), findsNothing);
      expect(find.text('البقرة'), findsWidgets);
      expect(prefs.getInt('quran.reading.surah'), 2);
      expect(prefs.getInt('quran.reading.ayah'), greaterThan(1));
    },
  );
}
