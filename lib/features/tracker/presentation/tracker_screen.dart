import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/azkar/azkar_data.dart';
import '../../../core/azkar/azkar_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/tracker/tracker_providers.dart';
import '../../../shared/widgets/khatim_pattern.dart';
import '../../../shared/widgets/sub_screen_header.dart';
import '../../azkar/presentation/azkar_screen.dart';

class TrackerScreen extends ConsumerStatefulWidget {
  final void Function(int navIndex)? onNavigate;

  const TrackerScreen({super.key, this.onNavigate});

  @override
  ConsumerState<TrackerScreen> createState() => _TrackerScreenState();
}

class _TrackerScreenState extends ConsumerState<TrackerScreen> {
  static const _arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
  static String _ar(int n) =>
      n.toString().split('').map((d) => _arabicDigits[int.parse(d)]).join();

  static const _prayerKeys = [
    'prayers.fajr',
    'prayers.dhuhr',
    'prayers.asr',
    'prayers.maghrib',
    'prayers.isha',
  ];

  // Sat..Fri single-letter labels — matches weekPrayerCompletionProvider's
  // Saturday-first week.
  static const _dayLetters = ['س', 'ح', 'ن', 'ث', 'ر', 'خ', 'ج'];

  bool _checkedInitialCelebration = false;

  void _maybeCelebrate() {
    final repo = ref.read(trackerRepositoryProvider);
    if (repo.celebratedToday()) return;
    if (!ref.read(dailyWirdCompleteTodayProvider)) return;
    repo.markCelebratedToday();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _showCelebration(context);
    });
  }

  void _showCelebration(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => const _WirdCompleteDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ref.listen only fires on *changes* — this one-time check catches the
    // case where the wird was already complete before this screen opened
    // (e.g. the last item was finished from the Azkar tab, then the user
    // navigates here), which a listener registered just now would miss.
    if (!_checkedInitialCelebration) {
      _checkedInitialCelebration = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeCelebrate());
    }
    ref.listen<bool>(dailyWirdCompleteTodayProvider, (previous, next) {
      if (next && previous == false) _maybeCelebrate();
    });

    final week = ref.watch(weekPrayerCompletionProvider);
    final streak = ref.watch(prayerStreakProvider);
    final todayPrayers = ref.watch(todayPrayersProvider);
    final todaySaturdayIndex = saturdayWeekIndex(DateTime.now());
    final azkarProgress = ref.watch(azkarProgressProvider);
    final readQuranToday = ref.watch(quranWirdDoneTodayProvider);
    final nightRakahs = ref.watch(nightRakahsProvider);

    final morningAzkar = kAzkarCategories.firstWhere((c) => c.id == 'morning');
    final eveningAzkar = kAzkarCategories.firstWhere((c) => c.id == 'evening');
    final morningProgress = azkarCategoryProgress(morningAzkar, azkarProgress);
    final eveningProgress = azkarCategoryProgress(eveningAzkar, azkarProgress);
    final nightProgress = nightRakahs / kNightPrayerTargetRakahs;

    void openAzkar([String? categoryId]) => Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AzkarScreen(initialCategoryId: categoryId),
      ),
    );

    final wirdItems = [
      _WirdRow(
        icon: Icons.menu_book_rounded,
        titleKey: 'tracker_screen.quran_reading',
        subtitle: readQuranToday
            ? 'tracker_screen.done_today'.tr()
            : 'tracker_screen.not_started'.tr(),
        progress: readQuranToday ? 1.0 : 0.0,
        // Opens the Quran tab (the "go read" action) — separate from
        // checked, below, which is the direct "mark it done" toggle. Two
        // affordances because unlike the other rows this one has no
        // natural single interaction: azkar rows navigate to a real
        // checklist, night prayer increments a real count, but Quran
        // reading previously only auto-completed when the reader saved a
        // position, with no way to check it off directly (e.g. after
        // reading from a physical Mus'haf).
        onTap: () => widget.onNavigate?.call(1),
        checked: readQuranToday,
        onCheckToggle: () =>
            ref.read(manualQuranReadTodayProvider.notifier).toggle(),
      ),
      _WirdRow(
        icon: Icons.wb_twilight_rounded,
        titleKey: 'tracker_screen.morning_azkar',
        subtitle: morningProgress >= 1
            ? 'tracker_screen.done_today'.tr()
            : '${_ar((morningProgress * morningAzkar.items.length).round())} ${'azkar_screen.of'.tr()} ${_ar(morningAzkar.items.length)}',
        progress: morningProgress,
        gold: true,
        onTap: () => openAzkar('morning'),
      ),
      _WirdRow(
        icon: Icons.nights_stay_rounded,
        titleKey: 'tracker_screen.evening_azkar',
        subtitle: eveningProgress >= 1
            ? 'tracker_screen.done_today'.tr()
            : (eveningProgress <= 0
                  ? 'tracker_screen.not_started'.tr()
                  : '${_ar((eveningProgress * eveningAzkar.items.length).round())} ${'azkar_screen.of'.tr()} ${_ar(eveningAzkar.items.length)}'),
        progress: eveningProgress,
        onTap: () => openAzkar('evening'),
      ),
      _WirdRow(
        icon: Icons.dark_mode_rounded,
        titleKey: 'tracker_screen.night_prayer',
        subtitle:
            '${_ar(nightRakahs)} ${'tracker_screen.rakahs_of'.tr()} ${_ar(kNightPrayerTargetRakahs)}',
        progress: nightProgress,
        gold: true,
        onTap: () => ref.read(nightRakahsProvider.notifier).addTwo(),
      ),
    ];

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: SubScreenHeader(
            bottomPadding: 56,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'tracker_screen.title'.tr(),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1.6,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.local_fire_department_rounded,
                            size: 14,
                            color: AppColors.goldLight,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${_ar(streak)} ${'tracker_screen.day_streak'.tr()}',
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                Row(
                  children: List.generate(7, (i) {
                    final done = week[i];
                    final today = i == todaySaturdayIndex;
                    final dayLetter = _dayLetters[i];
                    return Expanded(
                      child: Column(
                        children: [
                          Text(
                            dayLetter,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.textOnPrimaryMuted,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: done
                                  ? AppColors.goldLight
                                  : (today
                                        ? Colors.white
                                        : Colors.white.withValues(alpha: 0.13)),
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: done
                                ? const Icon(
                                    Icons.check_rounded,
                                    size: 14,
                                    color: AppColors.primary,
                                  )
                                : (today
                                      ? const Icon(
                                          Icons.circle,
                                          size: 8,
                                          color: AppColors.primary,
                                        )
                                      : null),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryDark.withValues(alpha: 0.10),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'tracker_screen.today_prayers'.tr(),
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                              height: 1.6,
                            ),
                          ),
                          Text(
                            '${_ar(todayPrayers.length)} ${'azkar_screen.of'.tr()} ${_ar(_prayerKeys.length)}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.gold,
                              height: 1.6,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: List.generate(_prayerKeys.length, (i) {
                          final done = todayPrayers.contains(i);
                          // Expanded: five fixed items in a plain Row can
                          // overflow horizontally under a larger system
                          // font scale (see prayer_card.dart for the
                          // same fix applied to the home screen).
                          return Expanded(
                            child: GestureDetector(
                              onTap: () =>
                                  ref.read(todayPrayersProvider.notifier).toggle(i),
                              child: Column(
                                children: [
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    width: 34,
                                    height: 34,
                                    decoration: BoxDecoration(
                                      color: done
                                          ? AppColors.primary
                                          : AppColors.chipBg,
                                      borderRadius: BorderRadius.circular(11),
                                    ),
                                    child: Icon(
                                      done
                                          ? Icons.check_rounded
                                          : Icons.add_rounded,
                                      size: 16,
                                      color: done
                                          ? Colors.white
                                          : AppColors.iconMuted,
                                    ),
                                  ),
                                  const SizedBox(height: 7),
                                  Text(
                                    _prayerKeys[i].tr(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 9.5,
                                      color: done
                                          ? AppColors.primary
                                          : AppColors.textSecondary,
                                      fontWeight: done
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                      height: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                ),
                const OrnamentDivider(),
                Text(
                  'tracker_screen.daily_wird'.tr(),
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 12),
                ...wirdItems.map(
                  (w) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: GestureDetector(
                      onTap: w.onTap,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 15,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryDark.withValues(
                                alpha: 0.05,
                              ),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: w.gold
                                    ? AppColors.goldTint
                                    : AppColors.primaryTint,
                                borderRadius: BorderRadius.circular(11),
                              ),
                              child: Icon(
                                w.icon,
                                size: 18,
                                color: w.gold
                                    ? AppColors.gold
                                    : AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 13),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    w.titleKey.tr(),
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                      height: 1.6,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    w.subtitle,
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      color: AppColors.textSecondary,
                                      height: 1.6,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(3),
                                    child: TweenAnimationBuilder<double>(
                                      tween: Tween(
                                        begin: 0,
                                        end: w.progress.clamp(0, 1),
                                      ),
                                      duration: const Duration(
                                        milliseconds: 300,
                                      ),
                                      curve: Curves.easeOutCubic,
                                      builder: (context, value, _) =>
                                          LinearProgressIndicator(
                                            value: value,
                                            minHeight: 4,
                                            backgroundColor: AppColors.chipBg,
                                            valueColor:
                                                const AlwaysStoppedAnimation(
                                                  AppColors.gold,
                                                ),
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (w.onCheckToggle != null)
                              GestureDetector(
                                onTap: w.onCheckToggle,
                                child: Padding(
                                  padding: const EdgeInsets.only(
                                    right: 4,
                                    top: 2,
                                  ),
                                  child: Icon(
                                    (w.checked ?? false)
                                        ? Icons.check_circle_rounded
                                        : Icons.circle_outlined,
                                    size: 22,
                                    color: (w.checked ?? false)
                                        ? AppColors.primary
                                        : AppColors.iconMuted,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _WirdRow {
  final IconData icon;
  final String titleKey;
  final String subtitle;
  final double progress;
  final bool gold;
  final VoidCallback onTap;

  /// When set (alongside [onCheckToggle]), a checkbox is drawn on this row
  /// as a second, independent tap target for directly marking it done —
  /// see the Quran reading row's comment for why it needs one and the
  /// others don't.
  final bool? checked;
  final VoidCallback? onCheckToggle;

  _WirdRow({
    required this.icon,
    required this.titleKey,
    required this.subtitle,
    required this.progress,
    required this.onTap,
    this.gold = false,
    this.checked,
    this.onCheckToggle,
  });
}

/// Celebration shown once per day the moment the whole daily wird (Quran
/// reading, morning + evening azkar, night prayer) is completed.
class _WirdCompleteDialog extends StatelessWidget {
  const _WirdCompleteDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.85, end: 1),
        duration: const Duration(milliseconds: 380),
        curve: Curves.elasticOut,
        builder: (context, scale, child) =>
            Transform.scale(scale: scale, child: child),
        child: Container(
          padding: const EdgeInsets.fromLTRB(28, 32, 28, 26),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppColors.primary, AppColors.primaryDark],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryDark.withValues(alpha: 0.35),
                blurRadius: 40,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.gold, AppColors.goldLight],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.gold.withValues(alpha: 0.5),
                      blurRadius: 24,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.emoji_events_rounded,
                  size: 38,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'tracker_screen.wird_complete_title'.tr(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'tracker_screen.wird_complete_body'.tr(),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  color: Colors.white.withValues(alpha: 0.85),
                  height: 1.8,
                ),
              ),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    'tracker_screen.wird_complete_dismiss'.tr(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
