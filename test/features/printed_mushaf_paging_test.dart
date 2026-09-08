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
import 'package:sheikh_ahmed_app/core/quran/mushaf_page_data.dart';
import 'package:sheikh_ahmed_app/core/quran/mushaf_providers.dart';
import 'package:sheikh_ahmed_app/core/quran/page_starts.dart';
import 'package:sheikh_ahmed_app/core/quran/surah_meta.dart';
import 'package:sheikh_ahmed_app/features/quran/presentation/surah_reader_screen.dart';

const _pager = ValueKey('printedMushafPages');

/// A page of fifteen plausible lines, belonging to whichever surah really
/// opens that page — so the header and the app bar can be checked against
/// the actual Mus'haf rather than against invented data.
MushafPageData _fakePage(int page) {
  final start = pageStartFor(page)!;
  return MushafPageData(
    page: page,
    juz: 1,
    verseKeys: ['${start.surahNumber}:${start.ayahNumber}'],
    words: [
      for (var line = 1; line <= 15; line++)
        for (var w = 0; w < 6; w++)
          MushafWord(
            glyph: 'كلمة',
            line: line,
            surah: start.surahNumber,
            // Never ayah 1, so no page under test sprouts a surah heading
            // it would not really have.
            ayah: start.ayahNumber + line,
            isEnd: false,
            isJalalah: false,
          ),
    ],
  );
}

Future<void> _openReader(
  WidgetTester tester,
  Surah surah, {
  int? startAyah,
  Locale locale = const Locale('ar'),
}) async {
  SharedPreferences.setMockInitialValues({});
  await tester.runAsync(() => EasyLocalization.ensureInitialized());
  final prefs = await tester.runAsync(() => SharedPreferences.getInstance());

  final audioHandler = QuranAudioHandler();
  addTearDown(audioHandler.stop);

  final app = EasyLocalization(
    supportedLocales: const [Locale('ar'), Locale('en')],
    path: 'assets/translations',
    fallbackLocale: const Locale('ar'),
    startLocale: locale,
    child: ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs!),
        audioHandlerProvider.overrideWithValue(audioHandler),
        notificationsPluginProvider.overrideWithValue(
          FlutterLocalNotificationsPlugin(),
        ),
        // The printed page and its font both resolve, so the reader is in
        // printed mode — which is what these tests are about.
        mushafPageProvider.overrideWith((ref, page) async => _fakePage(page)),
        mushafFontProvider.overrideWith((ref, page) async {}),
      ],
      child: Builder(
        builder: (context) => MaterialApp(
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          locale: context.locale,
          home: SurahReaderScreen(surah: surah, startAyah: startAyah),
        ),
      ),
    ),
  );

  await tester.runAsync(() async {
    await tester.pumpWidget(app);
    await Future<void>.delayed(const Duration(milliseconds: 20));
  });
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

/// The page number showing, 1-based.
int _currentPage(WidgetTester tester) {
  final controller = tester.widget<PageView>(find.byKey(_pager)).controller!;
  return controller.page!.round() + 1;
}

/// Turns one page onward.
///
/// The pager is pinned RTL, so its scroll axis points left and advancing it
/// means dragging rightward — the direction a hand turns a page in a Mus'haf.
Future<void> _turnPage(WidgetTester tester) async {
  await tester.fling(find.byKey(_pager), const Offset(500, 0), 1500);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

void main() {
  testWidgets('the printed reader is one pager over the whole book', (
    tester,
  ) async {
    await _openReader(tester, surahByNumber(1));

    final pager = tester.widget<PageView>(find.byKey(_pager));
    // 604 pages, not the single page that belongs to al-Fatiha.
    expect(pager.childrenDelegate.estimatedChildCount, 604);
  });

  testWidgets('it opens on the page the starting verse is printed on', (
    tester,
  ) async {
    // Al-Baqara 142 is on page 22. Opening at the surah's first page and
    // ignoring the verse asked for was the old behaviour.
    await _openReader(tester, surahByNumber(2), startAyah: 142);

    expect(_currentPage(tester), 22);
  });

  testWidgets('turning past the end of a surah keeps going', (tester) async {
    // The bug this replaced: one pager per surah nested inside another, and
    // two pagers on the same axis do not hand a gesture to one another — so
    // at the last page of a surah the swipe simply died. Al-Fatiha is one
    // page; page 2 belongs to al-Baqara.
    await _openReader(tester, surahByNumber(1));
    expect(_currentPage(tester), 1);

    await _turnPage(tester);
    expect(_currentPage(tester), 2);

    await _turnPage(tester);
    expect(_currentPage(tester), 3);

    await _turnPage(tester);
    expect(_currentPage(tester), 4);
  });

  testWidgets('the app bar follows the page across the surah boundary', (
    tester,
  ) async {
    await _openReader(tester, surahByNumber(1));
    expect(find.text('الفاتحة'), findsWidgets);

    await _turnPage(tester);
    // Page 2 opens al-Baqara, so that is what the bar names now.
    expect(_currentPage(tester), 2);
    expect(find.text('البقرة'), findsWidgets);
  });

  testWidgets('English keeps the reader that shows the translation', (
    tester,
  ) async {
    // The printed page is a photograph of the Arabic, and a fifteen-line
    // grid has nowhere to put a translation — an English reader got a
    // page they could not read. The app's own layout, verse by verse
    // with the translation underneath, is what English had before.
    await _openReader(tester, surahByNumber(1), locale: const Locale('en'));

    expect(find.byKey(_pager), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Arabic still gets the printed page', (tester) async {
    await _openReader(tester, surahByNumber(1));
    expect(find.byKey(_pager), findsOneWidget);
  });

  testWidgets('no spinner and no second layout once the page is in hand', (
    tester,
  ) async {
    // The reader used to draw the app's own text first and swap the printed
    // page in behind it, which looked like a rendering fault.
    await _openReader(tester, surahByNumber(1));

    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
