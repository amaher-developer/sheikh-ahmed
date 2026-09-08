import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  Future<List<Ayah>> fetchSurah(
    int surahNumber, {
    bool includeTranslation = false,
  }) async {
    return List.generate(20, (i) {
      final n = i + 1;
      return Ayah(
        numberInSurah: n,
        text: 'نص الآية رقم $n ' * 4,
        juz: 1,
        page: 1 + i ~/ 8,
      );
    });
  }
}

/// The font families actually rendered for Quranic text on screen.
Set<String?> _mushafFamilies(WidgetTester tester) {
  return tester
      .widgetList<RichText>(find.byType(RichText))
      .map((r) => r.text.style?.fontFamily)
      .where((f) => f == 'ScheherazadeNew' || f == 'AmiriQuran')
      .toSet();
}

void main() {
  testWidgets(
    'switching the Quran font repaints the reader immediately, without '
    'needing a font-size change to force it',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.runAsync(() => EasyLocalization.ensureInitialized());
      final prefs = await tester.runAsync(
        () => SharedPreferences.getInstance(),
      );

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
      await tester.pump(const Duration(milliseconds: 400));
      // Two steps now, not one: the screen first resolves whether the
      // printed Mus'haf page can be drawn, and only then builds the
      // fallback reader, whose own surah fetch starts there.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        _mushafFamilies(tester),
        {'ScheherazadeNew'},
        reason: 'the default face should be rendering to begin with',
      );

      // Drive the setting the way the sheet does, rather than through the
      // popup-menu route (awkward to pump reliably) — the bug was never in
      // the sheet. The setting stored and applied correctly all along; what
      // was missing was anything rebuilding to show it, so this asserts
      // exactly that: change the provider, pump, and the reader must
      // already be painting the new face without a font-size change to
      // force the repaint.
      final container = ProviderScope.containerOf(
        tester.element(find.byType(SheikhAhmedApp)),
      );
      await container
          .read(quranReadingStyleProvider.notifier)
          .setFamily('AmiriQuran');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        _mushafFamilies(tester),
        {'AmiriQuran'},
        reason: 'the reader must repaint on the font change alone',
      );
    },
  );
}
