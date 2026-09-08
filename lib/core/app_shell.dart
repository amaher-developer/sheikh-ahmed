import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'adhan/adhan_playing_providers.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/quran/presentation/quran_screen.dart';
import '../features/radio/presentation/radio_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/tracker/presentation/tracker_screen.dart';
import '../shared/widgets/app_bottom_nav.dart';
import 'theme/app_colors.dart';

/// Root shell: an IndexedStack behind the floating bottom nav, matching
/// the mockups where the nav bar overlays screen content rather than
/// sitting in a fixed Scaffold.bottomNavigationBar slot.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _index = 0;

  void _navigate(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          IndexedStack(
            index: _index,
            children: [
              for (final (i, screen) in <Widget>[
                HomeScreen(onNavigate: _navigate),
                const QuranScreen(),
                const RadioScreen(),
                TrackerScreen(onNavigate: _navigate),
                const SettingsScreen(),
              ].indexed)
                // IndexedStack keeps every tab mounted (deliberately — it's
                // what lets playback and scroll position survive a tab
                // switch) but it does *not* stop their tickers, and it
                // paints only the selected one. RadioScreen starts a
                // repeating equalizer and a blinking live-dot in initState,
                // so from launch the app was animating two controllers
                // forever for a screen most sessions never open — driving
                // frames, and battery, for pixels nobody sees. TickerMode
                // pauses animations on the tabs that aren't on screen; they
                // resume where they left off when their tab is selected.
                TickerMode(enabled: _index == i, child: screen),
            ],
          ),
        ],
      ),
      bottomNavigationBar: Container(
        color: Colors.transparent,
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Sits above the nav rather than on the home screen, so the
              // adhan can be stopped from whichever tab happens to be
              // open. It appears only while a player is actually
              // sounding, and disappears on its own when the call ends.
              if (ref.watch(adhanPlayingProvider).valueOrNull ?? false)
                const _StopAdhanBar(),
              AppBottomNav(
                currentIndex: _index.clamp(0, 4),
                onTap: _navigate,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The one control that reliably silences the adhan.
///
/// The service posts a notification carrying its own stop action, but that
/// means pulling down the shade and finding it among everything else. With
/// two players able to sound at once this was the difference between
/// stopping the adhan and stopping half of it.
class _StopAdhanBar extends ConsumerWidget {
  const _StopAdhanBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => stopAdhan(ref),
      child: Container(
        margin: const EdgeInsets.fromLTRB(18, 0, 18, 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryDark.withValues(alpha: 0.28),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.volume_up_rounded, size: 18, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'adhan.now_playing'.tr(),
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.stop_rounded, size: 15, color: Colors.white),
                  const SizedBox(width: 4),
                  Text(
                    'adhan.stop'.tr(),
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
