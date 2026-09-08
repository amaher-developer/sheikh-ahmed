import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sheikh_ahmed_app/features/quran/presentation/quran_jump_sheet.dart';

/// What the sheet handed back, and whether it has closed yet.
class _Result {
  JumpTarget? target;
  bool closed = false;
}

/// Opens the jump sheet over a bare scaffold.
Future<_Result> _open(WidgetTester tester) async {
  // ensureInitialized reads shared_preferences for the saved locale, which
  // has no implementation in a widget test until it is mocked.
  SharedPreferences.setMockInitialValues({});
  await tester.runAsync(() => EasyLocalization.ensureInitialized());
  final result = _Result();

  final app = EasyLocalization(
    supportedLocales: const [Locale('ar'), Locale('en')],
    path: 'assets/translations',
    fallbackLocale: const Locale('ar'),
    startLocale: const Locale('ar'),
    child: Builder(
      builder: (context) => MaterialApp(
        localizationsDelegates: context.localizationDelegates,
        supportedLocales: context.supportedLocales,
        locale: context.locale,
        home: Builder(
          builder: (inner) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  result.target = await showQuranJumpSheet(inner);
                  result.closed = true;
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );

  // Pumped inside runAsync so the localization delegate's asset load — a
  // real file read — can actually complete. Under the fake clock alone it
  // never does after the first test in a file: Localizations then renders
  // SizedBox.shrink and none of the sheet exists to be found.
  await tester.runAsync(() async {
    await tester.pumpWidget(app);
    await Future<void>.delayed(const Duration(milliseconds: 20));
  });
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));

  await tester.tap(find.text('open'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  return result;
}

/// Types a page number into the field and presses the go button.
Future<void> _goToPage(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.tap(find.text('انتقال'));
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('opens on the page grid with a field to type a page number', (
    tester,
  ) async {
    await _open(tester);

    expect(find.text('الانتقال إلى'), findsOneWidget);
    expect(find.text('صفحة'), findsOneWidget);
    expect(find.text('جزء'), findsOneWidget);
    expect(find.text('حزب'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('typing a page number returns the verse that page opens on', (
    tester,
  ) async {
    final result = await _open(tester);

    // Page 293 is where al-Kahf begins — but the page itself opens on
    // al-Isra 105, and that is the verse the reader must be taken to.
    await _goToPage(tester, '293');

    expect(result.target, isNotNull);
    expect(result.target!.surahNumber, 17);
    expect(result.target!.ayahNumber, 105);
  });

  testWidgets('an Arabic-Indic page number is accepted, not rejected', (
    tester,
  ) async {
    // The app runs in Arabic by default, so this is what an Arabic keypad
    // actually produces — int.tryParse rejects it without normalising.
    final result = await _open(tester);

    await _goToPage(tester, '٢٢');

    // Page 22 opens juz 2, at al-Baqara 142.
    expect(result.target, isNotNull);
    expect(result.target!.surahNumber, 2);
    expect(result.target!.ayahNumber, 142);
  });

  testWidgets('a page number outside the Mus\'haf is refused, not obeyed', (
    tester,
  ) async {
    final result = await _open(tester);

    await _goToPage(tester, '900');

    expect(result.closed, isFalse, reason: 'the sheet should stay open');
    expect(result.target, isNull);
    expect(find.textContaining('٦٠٤'), findsWidgets);
  });

  testWidgets('the hizb tab lists quarters, not only the sixty hizbs', (
    tester,
  ) async {
    await _open(tester);

    await tester.tap(find.text('حزب'));
    await tester.pump(const Duration(milliseconds: 400));

    // Hizb 1 and its three quarters are all reachable; a list of hizbs
    // alone would show the first and none of the others.
    expect(find.text('الحزب ١'), findsOneWidget);
    expect(find.text('ربع الحزب ١'), findsOneWidget);
    expect(find.text('نصف الحزب ١'), findsOneWidget);
    expect(find.text('ثلاثة أرباع الحزب ١'), findsOneWidget);
  });

  testWidgets('the juz tab says where each juz lands before it is tapped', (
    tester,
  ) async {
    final result = await _open(tester);

    await tester.tap(find.text('جزء'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('الجزء ١'), findsOneWidget);
    // Juz 2 begins at al-Baqara 142, on page 22.
    expect(find.textContaining('البقرة · ١٤٢'), findsOneWidget);
    expect(find.textContaining('صفحة ٢٢'), findsOneWidget);

    await tester.tap(find.text('الجزء ٢'));
    await tester.pump(const Duration(milliseconds: 400));

    expect(result.target!.surahNumber, 2);
    expect(result.target!.ayahNumber, 142);
  });
}
