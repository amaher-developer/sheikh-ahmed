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

/// Long enough (60 ayahs) that flinging the reader actually produces a
/// multi-frame ballistic scroll settle, not an instant snap-to-end.
class FakeQuranTextService extends QuranTextService {
  FakeQuranTextService(super.prefs);

  @override
  Future<List<Ayah>> fetchSurah(int surahNumber, {bool includeTranslation = false}) async {
    return List.generate(60, (i) {
      final n = i + 1;
      return Ayah(numberInSurah: n, text: 'نص الآية رقم $n ' * 8, juz: 1, page: 1 + i ~/ 8);
    });
  }
}

void main() {
  testWidgets(
    'flinging the reader (fast scroll + ballistic settle) and swiping '
    'between surahs mid-fling throws no exception',
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
      // Two steps now, not one: the screen first resolves whether the
      // printed Mus'haf page can be drawn, and only then builds the
      // fallback reader, whose own surah fetch starts there.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);

      final scrollable = find.byType(SingleChildScrollView);
      expect(scrollable, findsOneWidget);

      // A real fling, not a drag: leaves a BallisticScrollActivity running
      // that keeps ticking across several subsequent pump()s — the exact
      // shape of the reported crash (AnimationController driving a
      // BallisticScrollActivity).
      await tester.fling(scrollable, const Offset(0, -600), 3000);
      // Pump in small steps (not pumpAndSettle) so the ballistic activity
      // is still mid-flight for the next actions below, instead of having
      // already fully settled.
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(tester.takeException(), isNull);

      // Swipe to the next surah (PageView) while the inner list's fling
      // from above may still be settling — the scenario most likely to
      // race the old page's Scrollable being torn down against its still-
      // running scroll animation.
      // The surah pager specifically: in Mus'haf mode each surah also
      // contains its own PageView for the printed pages.
      final pageView = find.byKey(const ValueKey('surahPageView'));
      expect(pageView, findsOneWidget);
      await tester.fling(pageView, const Offset(-400, 0), 1500);
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(tester.takeException(), isNull);

      // Let everything fully settle and confirm one last time.
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
