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
    'pushing the memorization screen mid-swipe, before the page '
    'transition settles, throws no exception',
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

      await tester.drag(pageView, const Offset(-350, 0));
      await tester.pump(const Duration(milliseconds: 20));

      final memorizationButton = find.byIcon(Icons.school_rounded);
      expect(memorizationButton, findsOneWidget);
      await tester.tap(memorizationButton);
      await tester.pump(const Duration(milliseconds: 20));
      await tester.pump(const Duration(milliseconds: 400));

      expect(tester.takeException(), isNull);

      // Pop back out of the memorization screen while the reader's own
      // swipe transition from above may still be settling underneath. Both
      // the reader and the memorization screen are mounted at once here
      // (pushing a route doesn't unmount the one beneath it), so there are
      // two BackButtons in the tree — .last is the topmost, visible one.
      final backButton = find.byType(BackButton);
      expect(backButton, findsNWidgets(2));
      await tester.tap(backButton.last);
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(tester.takeException(), isNull);
    },
  );
}
