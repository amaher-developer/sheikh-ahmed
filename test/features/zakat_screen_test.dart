import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sheikh_ahmed_app/features/zakat/presentation/zakat_screen.dart';

Future<void> _pushZakatScreenTheRealWay(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  await tester.runAsync(() => EasyLocalization.ensureInitialized());

  await tester.pumpWidget(
    EasyLocalization(
      supportedLocales: const [Locale('ar'), Locale('en')],
      path: 'assets/translations',
      fallbackLocale: const Locale('ar'),
      startLocale: const Locale('ar'),
      child: Builder(
        builder: (context) => MaterialApp(
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          locale: context.locale,
          // Root screen deliberately mimics HomeScreen: a Scaffold at the
          // app-shell level, then ZakatScreen pushed as a *bare*
          // MaterialPageRoute with no Scaffold of its own — exactly what
          // home_screen.dart and settings_screen.dart do.
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ZakatScreen()),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));

  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  // Both scenarios share one pump: running two separate EasyLocalization
  // app trees in the same test file is flaky (its controller is a process
  // singleton that doesn't reliably reset between tests).
  testWidgets(
    'ZakatScreen survives real navigation (no Scaffold wrapper — see '
    'home_screen.dart / settings_screen.dart) and calculates correctly',
    (tester) async {
      await _pushZakatScreenTheRealWay(tester);

      expect(
        tester.takeException(),
        isNull,
        reason:
            'TextField requires a Material ancestor; ZakatScreen has no '
            'Scaffold of its own, so pushing it bare throws '
            '"No Material widget found" at runtime.',
      );

      final fields = find.byType(TextField);
      expect(fields, findsNWidgets(4));

      await tester.enterText(fields.at(2), '100'); // gold price
      await tester.pump();
      await tester.enterText(fields.at(0), '20000'); // cash
      await tester.pump();

      expect(tester.takeException(), isNull);
      // nisab = 85g * 100 = 8500; cash 20000 is above it, so 2.5% is due.
      expect(find.text('500.00'), findsOneWidget);
    },
  );
}
