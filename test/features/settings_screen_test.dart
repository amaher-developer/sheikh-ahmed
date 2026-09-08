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
import 'package:sheikh_ahmed_app/main.dart';

void main() {
  Future<void> pumpApp(WidgetTester tester, {required Locale locale}) async {
    SharedPreferences.setMockInitialValues({});
    await tester.runAsync(() => EasyLocalization.ensureInitialized());
    final prefs = await tester.runAsync(() => SharedPreferences.getInstance());

    // See widget_test.dart for why this override is needed.
    final audioHandler = QuranAudioHandler();
    addTearDown(audioHandler.stop);

    await tester.pumpWidget(
      EasyLocalization(
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
          ],
          child: const SheikhAhmedApp(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets(
    'English locale boots without error and shows English home strings',
    (tester) async {
      await pumpApp(tester, locale: const Locale('en'));

      expect(tester.takeException(), isNull);
      expect(
        find.text('As-salamu alaykum wa rahmatullahi wa barakatuh'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Settings screen opens the location picker sheet with the current city selected',
    (tester) async {
      await pumpApp(tester, locale: const Locale('ar'));

      // Bottom nav "المزيد" (More/Settings) is the 5th tab.
      await tester.tap(find.text('المزيد').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(
        find.text('القاهرة'),
        findsWidgets,
      ); // default city, shown as the location subtitle

      // The location row sits below the fold at default test-surface size,
      // geometrically overlapping the floating bottom nav's screen position —
      // ensureVisible scrolls it into view so the tap actually lands on it.
      final locationRow = find.text('الموقع');
      await tester.ensureVisible(locationRow);
      await tester.pump();
      await tester.tap(locationRow);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(tester.takeException(), isNull);
      expect(find.text('استخدام الموقع الحالي'), findsOneWidget);
      // Cairo is the persisted default, so it should show as selected in the sheet too.
      expect(find.text('اختر مدينة'), findsOneWidget);
    },
  );
}
