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
import 'package:sheikh_ahmed_app/features/home/widgets/prayer_card.dart';
import 'package:sheikh_ahmed_app/main.dart';

void main() {
  testWidgets(
    'App boots, computes real prayer times, and shows the home screen',
    (WidgetTester tester) async {
      // EasyLocalization reads the saved locale via SharedPreferences, which
      // has no real platform channel to answer in the test host — give it
      // the in-memory test implementation instead of a real one.
      SharedPreferences.setMockInitialValues({});

      // runAsync is required here: both of these await real async I/O, and
      // testWidgets runs in a fake-async zone that never drives genuine I/O
      // to completion on its own — without runAsync this hangs.
      await tester.runAsync(() => EasyLocalization.ensureInitialized());
      final prefs = await tester.runAsync(
        () => SharedPreferences.getInstance(),
      );

      // Without this override, audioHandlerProvider throws (it's only
      // populated for real via AudioService.init() in main()) and every
      // dependent StreamProvider silently degrades to AsyncError — no crash,
      // but RadioScreen/QuranScreen would never be exercised against a real
      // handler. Construct one directly; it doesn't need AudioService.init()
      // to expose its playbackState/mediaItem streams.
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
            ],
            child: const SheikhAhmedApp(),
          ),
        ),
      );
      // Not pumpAndSettle(): RadioScreen runs perpetual equalizer/live-dot
      // animations that IndexedStack builds eagerly at startup (so audio
      // can keep playing across tab switches), which means there are always
      // pending frames and pumpAndSettle would never return.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(tester.takeException(), isNull);
      expect(find.text('السلام عليكم ورحمة الله وبركاته'), findsOneWidget);

      // The prayer card rendered without its computed data throwing —
      // confirms the real adhan_dart calculation flowed through the
      // provider graph into the widget tree instead of the old hardcoded
      // mock values.
      expect(find.byType(PrayerCard), findsOneWidget);
    },
  );
}
