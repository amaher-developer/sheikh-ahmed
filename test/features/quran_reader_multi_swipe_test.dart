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

class FakeQuranTextService extends QuranTextService {
  FakeQuranTextService(super.prefs);

  @override
  Future<List<Ayah>> fetchSurah(int surahNumber, {bool includeTranslation = false}) async {
    return List.generate(30, (i) {
      final n = i + 1;
      return Ayah(numberInSurah: n, text: 'نص الآية رقم $n ' * 6, juz: 1, page: 1 + i ~/ 8);
    });
  }
}

void main() {
  testWidgets(
    'rapidly swiping through several surahs one after another (not '
    'letting each settle) throws no exception',
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

      await tester.tap(find.text('القرآن').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Scrolled to rather than assumed on screen: the surah list is a
      // lazy SliverList, so a row only exists in the tree once it is near
      // the viewport — and anything added above the list (the offline
      // download card) pushes it out of the built range.
      await tester.scrollUntilVisible(
        // Unfiltered: a .first finder throws rather than reporting empty
        // while the target has not been built yet, which is precisely the
        // state scrollUntilVisible exists to resolve.
        find.text('البقرة'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      await tester.tap(find.text('البقرة').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);

      // The surah pager specifically: in Mus'haf mode each surah also
      // contains its own PageView for the printed pages.
      final pageView = find.byKey(const ValueKey('surahPageView'));
      expect(pageView, findsOneWidget);

      // Swipe forward several times back-to-back, each swipe landing while
      // the previous page's transition/scroll may still be settling — the
      // real-world equivalent of quickly flicking through several surahs.
      for (var i = 0; i < 6; i++) {
        await tester.drag(pageView, const Offset(-350, 0));
        await tester.pump(const Duration(milliseconds: 40));
        expect(
          tester.takeException(),
          isNull,
          reason: 'threw after forward swipe #$i',
        );
      }

      // A couple of pumps to let things settle, then swipe backward a few
      // times the same way.
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      for (var i = 0; i < 4; i++) {
        await tester.drag(pageView, const Offset(350, 0));
        await tester.pump(const Duration(milliseconds: 40));
        expect(
          tester.takeException(),
          isNull,
          reason: 'threw after backward swipe #$i',
        );
      }

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Also exercise the AppBar actions (bookmark, font size) interleaved
      // with a swipe, in case a tap mid-transition is part of the trigger.
      final bookmarkIcon = find.byIcon(Icons.bookmark_border_rounded);
      if (bookmarkIcon.evaluate().isNotEmpty) {
        await tester.tap(bookmarkIcon.first);
        await tester.pump();
      }
      await tester.drag(pageView, const Offset(-350, 0));
      await tester.pump(const Duration(milliseconds: 40));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
