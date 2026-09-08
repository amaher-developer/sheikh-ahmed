import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sheikh_ahmed_app/core/adhan/adhan_providers.dart';
import 'package:sheikh_ahmed_app/core/audio/audio_providers.dart';
import 'package:sheikh_ahmed_app/core/audio/quran_audio_handler.dart';
import 'package:sheikh_ahmed_app/core/prayer/prayer_providers.dart';
import 'package:sheikh_ahmed_app/main.dart';

void main() {
  testWidgets('the app draws edge-to-edge with legible status bar icons', (
    tester,
  ) async {
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
          ],
          child: const SheikhAhmedApp(),
        ),
      ),
    );
    await tester.pump();

    // The app declares its own overlay style rather than leaving the bars to
    // the platform default. Without it, Android below 15 keeps opaque system
    // bars and the app is not edge-to-edge at all — the "may not display for
    // all users" report in Play Console.
    final region = tester
        .widgetList<AnnotatedRegion<SystemUiOverlayStyle>>(
          find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
        )
        .where((r) => r.value.statusBarColor == Colors.transparent);
    expect(
      region,
      isNotEmpty,
      reason: 'no transparent-status-bar AnnotatedRegion in the tree',
    );

    // Both headers paint AppColors.primary (dark green) full-bleed behind the
    // status bar, so the icons over it have to be light in either theme.
    // Getting this wrong renders the clock and battery invisible rather than
    // merely ugly, which is why it is worth pinning.
    expect(region.first.value.statusBarIconBrightness, Brightness.light);
    expect(region.first.value.systemNavigationBarColor, Colors.transparent);
  });
}
