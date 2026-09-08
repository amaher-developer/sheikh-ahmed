import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sheikh_ahmed_app/core/prayer/prayer_providers.dart'
    show sharedPreferencesProvider;
import 'package:sheikh_ahmed_app/core/quran/quran_providers.dart';
import 'package:sheikh_ahmed_app/core/theme/app_text_styles.dart';
import 'package:sheikh_ahmed_app/features/quran/presentation/reading_settings_sheet.dart';

/// Opens the sheet over a bare scaffold and hands back the container so the
/// stored settings can be read after tapping.
Future<ProviderContainer> _open(
  WidgetTester tester, {
  Map<String, Object> prefs = const {},
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  await tester.runAsync(() => EasyLocalization.ensureInitialized());
  final stored = await tester.runAsync(() => SharedPreferences.getInstance());

  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(stored!)],
  );
  addTearDown(container.dispose);

  final app = EasyLocalization(
    supportedLocales: const [Locale('ar'), Locale('en')],
    path: 'assets/translations',
    fallbackLocale: const Locale('ar'),
    startLocale: const Locale('ar'),
    child: UncontrolledProviderScope(
      container: container,
      child: Builder(
        builder: (context) => MaterialApp(
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          locale: context.locale,
          home: const Scaffold(body: ReadingSettingsSheet()),
        ),
      ),
    ),
  );

  // Pumped inside runAsync so the localization delegate's asset load can
  // complete; under the fake clock alone it never does after the first test
  // in a file, and the sheet is then never built.
  await tester.runAsync(() async {
    await tester.pumpWidget(app);
    await Future<void>.delayed(const Duration(milliseconds: 20));
  });
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  return container;
}

void main() {
  testWidgets('it opens on the printed Mus\'haf, which is the default', (
    tester,
  ) async {
    final container = await _open(tester);

    expect(container.read(printedMushafProvider), isTrue);
    expect(find.text('المصحف المطبوع'), findsOneWidget);
    expect(find.text('نص قابل للتخصيص'), findsOneWidget);
  });

  testWidgets('the font controls are inert while the printed page is on', (
    tester,
  ) async {
    // They cannot do anything there — one pre-shaped font per page, no
    // second face and no bold — so they must not accept a tap and quietly
    // change nothing.
    await _open(tester);

    final ignoring = tester.widget<IgnorePointer>(
      find.byKey(const ValueKey('quranFontControls')),
    );
    expect(ignoring.ignoring, isTrue);
  });

  testWidgets('choosing the text layout turns the font controls on', (
    tester,
  ) async {
    final container = await _open(tester);

    await tester.tap(find.text('نص قابل للتخصيص'));
    await tester.pump();

    expect(container.read(printedMushafProvider), isFalse);
    final ignoring = tester.widget<IgnorePointer>(
      find.byKey(const ValueKey('quranFontControls')),
    );
    expect(ignoring.ignoring, isFalse);
  });

  testWidgets('the size slider stores whole points, not fractions', (
    tester,
  ) async {
    final container = await _open(tester, prefs: {'quran.printedMushaf': false});

    final slider = tester.widget<Slider>(find.byType(Slider));
    expect(slider.min, kMinQuranFontSize);
    expect(slider.max, kMaxQuranFontSize);
    // 21.7pt is not a size anyone means to pick.
    expect(slider.divisions, (kMaxQuranFontSize - kMinQuranFontSize).round());

    container.read(quranFontSizeProvider.notifier).set(31);
    await tester.pump();
    expect(container.read(quranFontSizeProvider), 31);
  });

  testWidgets('picking a face stores it and applies it to Quranic text', (
    tester,
  ) async {
    final container = await _open(tester, prefs: {'quran.printedMushaf': false});

    await tester.tap(find.text('أميري'));
    await tester.pump();

    expect(container.read(quranReadingStyleProvider).family, 'AmiriQuran');
    // The face lives in a mutable static that every Quranic Text reads.
    expect(AppTextStyles.mushafFamily, 'AmiriQuran');
  });

  testWidgets('bold is offered on the face that has one, and only there', (
    tester,
  ) async {
    // AmiriQuran ships a single weight, and a synthesised bold turns dense
    // Uthmani diacritics to mush — so the switch has to be off there, not
    // just ineffective.
    final container = await _open(
      tester,
      prefs: {'quran.printedMushaf': false, 'quran.font': 'AmiriQuran'},
    );

    expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNull);
    expect(find.textContaining('أميري'), findsWidgets);

    await tester.tap(find.text('شهرزاد'));
    await tester.pump();

    expect(container.read(quranReadingStyleProvider).family, 'ScheherazadeNew');
    expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNotNull);
  });

  testWidgets('turning bold on stores it and reaches the text style', (
    tester,
  ) async {
    final container = await _open(tester, prefs: {'quran.printedMushaf': false});

    await tester.tap(find.byType(Switch));
    await tester.pump();

    expect(container.read(quranReadingStyleProvider).bold, isTrue);
    expect(AppTextStyles.mushafBold, isTrue);
    expect(
      AppTextStyles.mushaf().fontWeight,
      FontWeight.w700,
      reason: 'ScheherazadeNew ships a real bold',
    );
  });

  testWidgets('bold never reaches a face with no bold weight', (tester) async {
    // The guard is in the style itself, not only in the sheet: a stored
    // bold plus a later switch to Amiri would otherwise smear.
    await _open(
      tester,
      prefs: {
        'quran.printedMushaf': false,
        'quran.font': 'AmiriQuran',
        'quran.fontBold': true,
      },
    );

    expect(AppTextStyles.mushaf().fontWeight, FontWeight.w400);
  });

  testWidgets('the preview says why the printed page has none', (
    tester,
  ) async {
    // Showing a sample in some other font would be a different typesetting
    // pretending to be the page.
    await _open(tester);
    expect(find.textContaining('خطٌ خاص بكل صفحة'), findsOneWidget);

    await tester.tap(find.text('نص قابل للتخصيص'));
    await tester.pump();
    expect(find.textContaining('وَنُنَزِّلُ'), findsOneWidget);
  });
}
