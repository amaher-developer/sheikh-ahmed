import 'dart:async';

import 'package:audio_service/audio_service.dart';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/adhan/adhan_providers.dart';
import 'core/adhan/adhan_scheduler.dart';
import 'core/adhan/adhan_watcher.dart';
import 'core/app_restart.dart';
import 'core/app_shell.dart';
import 'core/audio/audio_providers.dart';
import 'core/audio/quran_audio_handler.dart';
import 'core/prayer/prayer_providers.dart';
import 'core/quran/mushaf_page_service.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  // Loaded once here so prayerSettingsProvider (and anything downstream)
  // can read/write it synchronously instead of every consumer awaiting it.
  final prefs = await SharedPreferences.getInstance();

  // Must run before runApp — this is what makes radio/Quran playback
  // survive backgrounding and puts real controls on the lock screen and
  // system notification instead of only working while the app is open.
  final audioHandler = await AudioService.init(
    builder: () => QuranAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.sheikhahmed.sheikh_ahmed_app.audio',
      androidNotificationChannelName: 'تشغيل الصوت',
      androidNotificationOngoing: true,
      // Explicit, not left to audio_service's own default (which happens
      // to be the same icon) — so the background playback notification
      // reads as this app's own icon, not a generic system one.
      androidNotificationIcon: 'mipmap/ic_launcher',
    ),
  );

  // Local notifications deliver the adhan/azkar/wird reminders when the
  // app isn't open; the in-app AdhanWatcher covers the adhan foreground
  // case. `initialize()` alone does *not* ask for permission on Android
  // 13+ — without the explicit requestNotificationsPermission() call
  // below, every notification here is silently dropped by the OS, with no
  // error anywhere in the app to reveal why.
  final notifications = FlutterLocalNotificationsPlugin();
  await notifications.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: true,
        requestSoundPermission: true,
      ),
    ),
  );
  final android = notifications
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();
  await android?.requestNotificationsPermission();
  // Exact alarms are a separate matter from the notification permission
  // above, and just as consequential: without them every reminder is
  // scheduled inexactly and Android may hold it until the device next leaves
  // Doze, which is why reminders could once go a whole day without arriving.
  //
  // Only *detected* here, never requested. Asking opens a full system
  // settings screen, and doing that during startup — before the user has even
  // seen the app — reads as an ambush and mostly gets refused. The offer
  // lives in Settings instead, where it can say what it is for; see
  // exactAlarmsAllowedProvider, which re-checks on every resume.
  if (android != null) {
    final canScheduleExact = await android.canScheduleExactNotifications();
    if (canScheduleExact == false) AdhanScheduler.useInexactAlarms();
  }
  await notifications
      .resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin
      >()
      ?.requestPermissions(alert: true, badge: true, sound: true);
  // The adhan channel is created in AdhanRescheduler.run() rather than
  // here: it needs the selected voice and that voice's translated name,
  // and neither the provider graph nor easy_localization's strings exist
  // yet at this point.
  AdhanScheduler.ensureTimezonesInitialised();

  // Android only draws app content behind the system bars on its own from
  // Android 15 (targetSdk 35+). Below that the bars stay opaque unless the
  // app opts in — which is exactly what Play Console reports as "edge-to-edge
  // may not display for all users". Asking for it explicitly makes the layout
  // identical on every version instead of only the newest ones.
  //
  // Safe to request unconditionally because the app is already inset-correct:
  // SubScreenHeader and the home header both pad their content by
  // MediaQuery.padding.top (deliberately letting the green fill run under the
  // bar), and AppShell puts the bottom nav inside a SafeArea. Without that,
  // this line would push content under the clock and the gesture bar.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // Fire-and-forget: the printed pages used to be kept in preferences, and
  // a device that had read a few hundred of them is parsing megabytes of
  // XML on every cold start until those keys are gone. Not awaited — the
  // app has no reason to wait on a cleanup nothing reads.
  unawaited(MushafPageService(prefs).purgeLegacyStorage());

  runApp(
    EasyLocalization(
      supportedLocales: const [Locale('ar'), Locale('en')],
      path: 'assets/translations',
      fallbackLocale: const Locale('ar'),
      startLocale: const Locale('ar'),
      child: ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          audioHandlerProvider.overrideWithValue(audioHandler),
          notificationsPluginProvider.overrideWithValue(notifications),
        ],
        child: const AppRestart(child: SheikhAhmedApp()),
      ),
    ),
  );
}

class SheikhAhmedApp extends ConsumerWidget {
  const SheikhAhmedApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    // Most screens in this app read AppColors.xxx as static fields rather
    // than through Theme.of(context), so switching MaterialApp's themeMode
    // alone wouldn't repaint them. Resolving the effective brightness here
    // and mutating AppColors before building the child tree makes those
    // screens respond to dark mode too — see app_colors.dart.
    final systemBrightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    final isDark = switch (themeMode) {
      ThemeMode.dark => true,
      ThemeMode.light => false,
      ThemeMode.system => systemBrightness == Brightness.dark,
    };
    AppColors.applyBrightness(isDark);

    return MaterialApp(
      title: 'Sheikh Ahmed',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeMode,
      // Every screen puts AppColors.primary (dark green) full-bleed behind the
      // status bar — home and sub-screens alike — so status bar icons stay
      // light in both themes. The nav bar sits over the page background
      // instead, so its icons do follow the theme.
      home: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarIconBrightness:
              isDark ? Brightness.light : Brightness.dark,
        ),
        child: const AdhanWatcher(child: AppShell()),
      ),
    );
  }
}
