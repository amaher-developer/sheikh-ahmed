import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sheikh_ahmed_app/core/quran/mushaf_page_data.dart';
import 'package:sheikh_ahmed_app/core/quran/mushaf_providers.dart';
import 'package:sheikh_ahmed_app/features/quran/presentation/mushaf_page_view.dart';

/// A page whose fifteen lines are as wide as a real one, with a surah
/// heading and its basmala in the gap the printed page leaves for them.
MushafPageData _page106() {
  final words = <MushafWord>[];

  void line(int n, int surah, int ayah, int count) {
    for (var i = 0; i < count; i++) {
      words.add(
        MushafWord(
          // Ordinary Arabic rather than a glyph code: the real page font is
          // downloaded at runtime and is not here, and a page of tofu boxes
          // would measure nothing like a page of words.
          glyph: 'كلمة',
          line: n,
          surah: surah,
          ayah: ayah,
          isEnd: false,
          isJalalah: false,
        ),
      );
    }
  }

  // An-Nisa runs out on line 5; al-Maida opens on line 8. Six and seven are
  // the heading and its basmala, and are blank in the source.
  for (var n = 1; n <= 5; n++) {
    line(n, 4, 170 + n, 7);
  }
  for (var n = 8; n <= 15; n++) {
    line(n, 5, n == 8 ? 1 : n - 7, 7);
  }

  return MushafPageData(
    page: 106,
    words: words,
    verseKeys: const ['4:171', '5:1'],
    juz: 6,
  );
}

Future<void> _pumpPage(
  WidgetTester tester,
  MushafPageData page, {
  Size size = const Size(360, 720),
}) async {
  SharedPreferences.setMockInitialValues({});
  await tester.runAsync(() => EasyLocalization.ensureInitialized());

  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final app = EasyLocalization(
    supportedLocales: const [Locale('ar'), Locale('en')],
    path: 'assets/translations',
    fallbackLocale: const Locale('ar'),
    startLocale: const Locale('ar'),
    child: ProviderScope(
      overrides: [
        mushafPageProvider(page.page).overrideWith((ref) async => page),
        mushafFontProvider(page.page).overrideWith((ref) async {}),
      ],
      child: Builder(
        builder: (context) => MaterialApp(
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          locale: context.locale,
          home: Scaffold(body: MushafPageView(page: page.page)),
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

/// The Column holding the page's printed rows, found by how many it has.
///
/// Matched on the exact count rather than "more than a few": the page is
/// built out of nested Columns and a loose match picks up the wrong one.
Column _rowColumn(WidgetTester tester, int rows) {
  return tester
      .widgetList<Column>(find.byType(Column))
      .firstWhere((c) => c.children.length == rows);
}

void main() {
  testWidgets('a page with a surah heading and basmala lays out without '
      'overflowing', (tester) async {
    // The heading and the basmala are two extra rows the fifteen lines were
    // never measured against — exactly the shape of the two overflows this
    // page has already produced.
    await _pumpPage(tester, _page106());

    expect(tester.takeException(), isNull);
    expect(find.textContaining('سورة'), findsOneWidget);
    expect(find.textContaining('بِسْمِ'), findsOneWidget);
  });

  testWidgets('the header names the surah, the juz and the hizb', (
    tester,
  ) async {
    await _pumpPage(tester, _page106());

    // Page 106 opens in an-Nisa, juz 6. Al-Maida 1 is where hizb 12 begins,
    // but the header names where the page *starts*, not where it ends.
    expect(find.textContaining('النساء'), findsOneWidget);
    expect(find.textContaining('الجزء ٦'), findsOneWidget);
    expect(find.textContaining('الحزب'), findsOneWidget);
  });

  testWidgets('a page with a prostration on it is marked', (tester) async {
    // As-Sajda 15. A reciter needs to see it before reaching the bottom of
    // the page, so it is on the page rather than only in the verse.
    final page = MushafPageData(
      page: 416,
      juz: 21,
      verseKeys: const ['32:12'],
      words: [
        for (var n = 1; n <= 15; n++)
          for (var i = 0; i < 7; i++)
            MushafWord(
              glyph: 'كلمة',
              line: n,
              surah: 32,
              ayah: 11 + n,
              isEnd: false,
              isJalalah: false,
            ),
      ],
    );

    await _pumpPage(tester, page);

    expect(tester.takeException(), isNull);
    expect(find.text('۩'), findsOneWidget);
  });

  testWidgets('a page with no prostration carries no mark', (tester) async {
    await _pumpPage(tester, _page106());
    expect(find.text('۩'), findsNothing);
  });

  testWidgets('a page that opens a surah still fills its height', (
    tester,
  ) async {
    // Page 106 carries thirteen lines of verse and spends its other two
    // slots on the heading and the basmala. Counting only the thirteen
    // called it a short page and centred it, leaving the text bunched in
    // the middle with white above and below — next to a neighbouring full
    // page spread over the whole height, that is the page that looked
    // squashed.
    await _pumpPage(tester, _page106());

    expect(_rowColumn(tester, 15).mainAxisAlignment, MainAxisAlignment.spaceEvenly);
  });

  testWidgets('a genuinely short page is still centred, not stretched', (
    tester,
  ) async {
    // Al-Fatiha sits in a decorative frame of eight lines rather than on
    // the fifteen-line grid, and it is one of only two pages that do.
    // Spreading eight lines down a phone screen leaves gaps between them
    // you could park a line in.
    final page = MushafPageData(
      page: 1,
      juz: 1,
      verseKeys: const ['1:1'],
      words: [
        for (var n = 2; n <= 8; n++)
          for (var i = 0; i < 4; i++)
            MushafWord(
              glyph: 'كلمة',
              line: n,
              surah: 1,
              ayah: n - 1,
              isEnd: false,
              isJalalah: false,
            ),
      ],
    );

    await _pumpPage(tester, page);

    // Seven lines and the heading above them: eight rows, no padding out
    // to fifteen and no empty lines underneath.
    expect(_rowColumn(tester, 8).mainAxisAlignment, MainAxisAlignment.center);
  });

  testWidgets('a page whose last line is empty still fills its height', (
    tester,
  ) async {
    // Page 594: al-Balad ends on line 14 and line 15 is left blank. That
    // blank used to be dropped, which made a full page look like a short
    // one and centred it — the text pushed down from the top with a band
    // of white above it.
    final page = MushafPageData(
      page: 594,
      juz: 30,
      verseKeys: const ['90:1'],
      words: [
        for (var n = 1; n <= 14; n++)
          for (var i = 0; i < 6; i++)
            MushafWord(
              glyph: 'كلمة',
              line: n,
              surah: 90,
              ayah: n + 1,
              isEnd: false,
              isJalalah: false,
            ),
      ],
    );

    await _pumpPage(tester, page);

    expect(
      _rowColumn(tester, 15).mainAxisAlignment,
      MainAxisAlignment.spaceEvenly,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a narrow screen still fits the page', (tester) async {
    // The header gained the hizb and the sajda mark, both of which take
    // width from the surah name on the other side.
    await _pumpPage(tester, _page106(), size: const Size(320, 640));
    expect(tester.takeException(), isNull);
  });
}
