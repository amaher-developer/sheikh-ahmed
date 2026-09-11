import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/home/daily_quote_data.dart';
import '../../../core/home/quick_access_usage.dart';
import '../../../core/home/weekly_mission_providers.dart';
import '../../../core/adhan/exact_alarm_providers.dart';
import '../../../core/prayer/prayer_providers.dart';
import '../../../core/prayer/prayer_settings.dart';
import '../../../core/prayer/prayer_times_service.dart';
import '../../../core/share/share_app.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/arabic_numerals.dart';
import '../../../shared/widgets/khatim_pattern.dart';
import '../../azkar/presentation/azkar_screen.dart';
import '../../duas/presentation/duas_screen.dart';
import '../../prayer/presentation/imsakiya_screen.dart';
import '../../qibla/presentation/qibla_screen.dart';
import '../../../core/widget/azkar_widget_channel.dart';
import '../../tasbeeh/presentation/tasbeeh_screen.dart';
import '../../zakat/presentation/zakat_screen.dart';
import '../../../core/ramadan/ramadan_providers.dart';
import '../widgets/ramadan_header.dart';
import '../widgets/prayer_card.dart';
import '../widgets/quick_access_grid.dart';

class HomeScreen extends ConsumerWidget {
  final void Function(int navIndex)? onNavigate;

  const HomeScreen({super.key, this.onNavigate});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isArabic = context.locale.languageCode == 'ar';
    final today = ref.watch(todayPrayerTimesProvider);
    final next = ref.watch(nextPrayerProvider);
    final settings = ref.watch(prayerSettingsProvider);
    final ramadan = ref.watch(ramadanStatusProvider);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          // The Ramadan header replaces the ordinary one for the month,
          // and only for the month — nothing below it changes, so the
          // rest of the screen stays as legible as it is the rest of the
          // year.
          child: ramadan.isRamadan
              ? RamadanHeader(
                  status: ramadan,
                  times: today,
                  isArabic: isArabic,
                )
              : _Header(
                  settings: settings,
                  isArabic: isArabic,
                  onNavigate: onNavigate,
                ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Shown only while Android is refusing exact alarms, and it
                // disappears by itself the moment the permission is granted —
                // no dismiss button and no "already seen" flag to persist.
                // The adhan is the whole point of this app and without that
                // permission it cannot play in full at the right minute, so
                // this belongs in front of the user rather than buried in
                // Settings.
                if (!ref.watch(exactAlarmsAllowedProvider)) ...[
                  const _ExactAlarmBanner(),
                  const SizedBox(height: 14),
                ],
                PrayerCard(
                  nextPrayerKey: next.labelKey,
                  nextPrayerTime: formatClockTime(
                    next.prayerTime,
                    arabicDigits: isArabic,
                  ),
                  countdown: _formatCountdown(next.countdown),
                  progress: next.progress,
                  activeIndex: next.prayerIndex,
                  times: [
                    for (var i = 0; i < DailyPrayerTimes.labelKeys.length; i++)
                      PrayerTime(
                        DailyPrayerTimes.labelKeys[i],
                        formatClockTime(
                          today.ordered[i],
                          arabicDigits: isArabic,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                if (ramadan.isRamadan) ...[
                  _RamadanNightRow(times: today, isArabic: isArabic),
                  const SizedBox(height: 14),
                ],
                _ExtraTimesRow(times: today, isArabic: isArabic),
                const OrnamentDivider(),
                _AyahCard(),
                const SizedBox(height: 16),
                const _WeeklyMissionCard(),
                const SizedBox(height: 24),
                Text('home.quick_access'.tr(), style: AppTextStyles.subtitle),
                const SizedBox(height: 12),
                QuickAccessGrid(
                  // Ordered by how often each has actually been opened,
                  // most-used first. The order they are written below is
                  // the considered default and breaks ties, so a fresh
                  // install still gets a sensible arrangement instead of
                  // an arbitrary one.
                  items: _orderedQuickAccess(ref, [
                    QuickAccessItem(
                      icon: Icons.local_fire_department_rounded,
                      titleKey: 'home.azkar',
                      subtitleKey: 'home.azkar_sub',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const AzkarScreen()),
                      ),
                    ),
                    QuickAccessItem(
                      icon: Icons.volunteer_activism_rounded,
                      titleKey: 'home.duas',
                      subtitleKey: 'home.duas_sub',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const DuasScreen()),
                      ),
                    ),
                    QuickAccessItem(
                      icon: Icons.menu_book_rounded,
                      titleKey: 'home.quran',
                      subtitleKey: 'home.quran_sub',
                      gold: true,
                      onTap: () => onNavigate?.call(1),
                    ),
                    QuickAccessItem(
                      icon: Icons.podcasts_rounded,
                      titleKey: 'home.radio',
                      subtitleKey: 'home.radio_sub',
                      onTap: () => onNavigate?.call(2),
                    ),
                    QuickAccessItem(
                      icon: Icons.checklist_rounded,
                      titleKey: 'home.tracker',
                      subtitleKey: 'home.tracker_sub',
                      gold: true,
                      onTap: () => onNavigate?.call(3),
                    ),
                    QuickAccessItem(
                      icon: Icons.calendar_month_rounded,
                      titleKey: 'home.imsakiya',
                      subtitleKey: 'home.imsakiya_sub',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ImsakiyaScreen(),
                        ),
                      ),
                    ),
                    QuickAccessItem(
                      icon: Icons.explore_rounded,
                      titleKey: 'home.qibla',
                      subtitleKey: 'home.qibla_sub',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const QiblaScreen()),
                      ),
                    ),
                    QuickAccessItem(
                      icon: Icons.paid_rounded,
                      titleKey: 'home.zakat',
                      subtitleKey: 'home.zakat_sub',
                      gold: true,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ZakatScreen()),
                      ),
                    ),
                    QuickAccessItem(
                      icon: Icons.radio_button_checked_rounded,
                      titleKey: 'home.tasbeeh',
                      subtitleKey: 'home.tasbeeh_sub',
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const TasbeehScreen()),
                      ),
                    ),
                    // Moved out of Settings: adding a home-screen widget is
                    // something people look for on the home screen, not
                    // buried in a settings list. Shown on every Android
                    // device (unlike the old Settings row, which hid itself
                    // when pinning was unsupported) because a hole in a grid
                    // reads worse than a tile that explains itself — the
                    // tap falls back to instructions when the launcher
                    // can't pin. Not on iOS: the widget only exists on
                    // Android, so there the tile could only point at a
                    // widget that isn't there.
                    if (AzkarWidgetChannel.isSupported)
                      QuickAccessItem(
                        icon: Icons.widgets_rounded,
                        titleKey: 'home.widget',
                        subtitleKey: 'home.widget_sub',
                        gold: true,
                        onTap: () => _addWidget(context),
                      ),
                  ]),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Taraweeh and qiyam — the two Ramadan night prayers.
///
/// Both derived from times the app already computes rather than stored:
/// taraweeh follows Isha, and qiyam is the last third of the night, which
/// SunnahTimes gives measured maghrib to next fajr.
class _RamadanNightRow extends StatelessWidget {
  final DailyPrayerTimes times;
  final bool isArabic;

  const _RamadanNightRow({required this.times, required this.isArabic});

  /// Isha plus half an hour — long enough for the congregation to settle,
  /// which is when taraweeh actually starts in most mosques.
  static const _afterIsha = Duration(minutes: 30);

  @override
  Widget build(BuildContext context) {
    final entries = <(IconData, String, DateTime)>[
      (
        Icons.mosque_rounded,
        'ramadan.taraweeh',
        times.isha.add(_afterIsha),
      ),
      (Icons.nightlight_round, 'ramadan.qiyam', times.lastThird),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.goldTint,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          for (final (icon, key, at) in entries)
            Expanded(
              child: Column(
                children: [
                  Icon(icon, size: 17, color: AppColors.gold),
                  const SizedBox(height: 6),
                  Text(
                    key.tr(),
                    style: TextStyle(
                      fontSize: 10.5,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formatClockTime(at, arabicDigits: isArabic),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Sorts the tiles by usage and makes each one count its own taps.
///
/// The counting is wrapped around the callers' onTap here rather than
/// inside QuickAccessGrid so the grid stays a plain presentational widget
/// with no provider dependency of its own.
List<QuickAccessItem> _orderedQuickAccess(
  WidgetRef ref,
  List<QuickAccessItem> items,
) {
  final usage = ref.watch(quickAccessUsageProvider);
  final byKey = {for (final i in items) i.titleKey: i};
  final order = orderByUsage([for (final i in items) i.titleKey], usage);
  return [
    for (final key in order)
      if (byKey[key] case final item?)
        QuickAccessItem(
          icon: item.icon,
          titleKey: item.titleKey,
          subtitleKey: item.subtitleKey,
          gold: item.gold,
          onTap: () {
            ref.read(quickAccessUsageProvider.notifier).record(key);
            item.onTap();
          },
        ),
  ];
}

/// Asks the launcher to pin the azkar widget, falling back to telling the
/// user how to add it by hand — many third-party launchers, and every
/// device before Android 8, have no pin API at all.
Future<void> _addWidget(BuildContext context) async {
  final pinned = await AzkarWidgetChannel.pin();
  if (pinned || !context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('settings_screen.add_widget_failed'.tr())),
  );
}

class _Header extends ConsumerWidget {
  final PrayerSettings settings;
  final bool isArabic;
  final void Function(int navIndex)? onNavigate;

  const _Header({
    required this.settings,
    required this.isArabic,
    this.onNavigate,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The colored background stays full-bleed under the status bar (for the
    // immersive look), but the title/content must clear it — otherwise it
    // renders underneath the battery/clock area on real devices.
    final statusBarHeight = MediaQuery.of(context).padding.top;

    return ClipRRect(
      borderRadius: const BorderRadius.only(
        bottomLeft: Radius.circular(28),
        bottomRight: Radius.circular(28),
      ),
      child: Container(
        color: AppColors.primary,
        padding: EdgeInsets.fromLTRB(22, statusBarHeight + 16, 22, 46),
        child: Stack(
          children: [
            Positioned.fill(child: KhatimPattern(opacity: 0.15)),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Image.asset(
                            'assets/images/sheikh_avatar.png',
                            fit: BoxFit.cover,
                            // Decoded at ~2x the 38px display size, not
                            // the source's full 480px.
                            cacheWidth: 96,
                            cacheHeight: 96,
                          ),
                        ),
                        const SizedBox(width: 11),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'app_name'.tr(),
                              style: const TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                height: 1.4,
                              ),
                            ),
                            Text(
                              'app_tagline'.tr(),
                              style: const TextStyle(
                                fontSize: 9.5,
                                color: AppColors.textOnPrimaryMuted,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        _HeaderButton(
                          icon: Icons.ios_share_rounded,
                          onTap: () => shareApp(context),
                        ),
                        const SizedBox(width: 9),
                        _HeaderButton(
                          icon: Icons.notifications_outlined,
                          onTap: () => onNavigate?.call(4),
                        ),
                        const SizedBox(width: 9),
                        _HeaderButton(
                          icon: Icons.settings_outlined,
                          onTap: () => onNavigate?.call(4),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 26),
                Text(
                  'home.greeting'.tr(),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${_dateLabel(ref, isArabic)} · ${_locationLabel(settings)}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textOnPrimaryMuted,
                    height: 1.7,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _HeaderButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Icon(icon, size: 16, color: Colors.white),
      ),
    );
  }
}

class _AyahCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Deterministic per calendar day (see dailyQuote's doc comment) — same
    // card all day, moves on to the next one tomorrow, without needing any
    // stored state.
    final quote = dailyQuote(DateTime.now());
    final isHadith = quote.type == DailyQuoteType.hadith;

    return Padding(
      // Room for the avatar bubble to peek past the card's own edge
      // without being clipped by whatever sits below it on the page.
      padding: const EdgeInsets.only(bottom: 16),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.ayahBg,
              borderRadius: BorderRadius.circular(16),
              border: const Border(
                right: BorderSide(color: AppColors.gold, width: 3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      (isHadith ? 'home.hadith_of_day' : 'home.ayah_of_day')
                          .tr(),
                      style: AppTextStyles.label.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => shareText(
                        context,
                        '${quote.text} (${quote.reference})',
                      ),
                      child: Icon(
                        Icons.share_outlined,
                        size: 15,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  quote.text,
                  // Real Quranic text needs the Mus'haf face for its
                  // diacritics (see AppTextStyles.mushaf's doc comment) —
                  // hadith text isn't Uthmani-marked the same way, so it
                  // stays on the regular dhikr style used elsewhere.
                  style: isHadith
                      ? AppTextStyles.quranic
                      : AppTextStyles.mushaf(fontSize: 19, height: 1.9),
                ),
                const SizedBox(height: 10),
                // Extra bottom room so the reference line never sits under
                // the avatar bubble anchored to this corner below.
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Text(
                    quote.reference,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: AppColors.textSecondary,
                      height: 1.7,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // A small avatar peeking out of the bottom corner, like a chat
          // bubble's sender portrait — makes the card read as "the Sheikh
          // saying this" rather than a plain quote box.
          Positioned(
            bottom: -14,
            left: 14,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: AppColors.background,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryDark.withValues(alpha: 0.18),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: CircleAvatar(
                radius: 20,
                // Decoded at ~100px instead of the source's full 480px —
                // it's only ever displayed at a 40px diameter here.
                backgroundImage: ResizeImage(
                  const AssetImage('assets/images/sheikh_avatar.png'),
                  width: 100,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A specific good deed suggested for the week (see weekly_mission_data.dart
/// for why these are deliberately concrete, not vague), headed by the ayah
/// that inspired the feature — "race toward forgiveness from your Lord".
/// A new mission starts automatically every 7 days; "mark done" resets
/// itself the same way (see weeklyMissionCompletedProvider).
class _WeeklyMissionCard extends ConsumerWidget {
  const _WeeklyMissionCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mission = ref.watch(currentMissionProvider);
    final isDone = ref.watch(weeklyMissionCompletedProvider);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.gold.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'weekly_mission.section_title'.tr(),
            style: AppTextStyles.label.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'weekly_mission.header_ayah'.tr(),
            textAlign: TextAlign.center,
            style: AppTextStyles.mushaf(fontSize: 15, height: 1.9),
          ),
          const SizedBox(height: 4),
          Text(
            'weekly_mission.header_ayah_ref'.tr(),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primaryTint,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(mission.icon, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mission.titleKey.tr(),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      mission.detailKey.tr(),
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textSecondary,
                        height: 1.7,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: () => toggleWeeklyMissionCompleted(ref),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(
                color: isDone ? AppColors.primaryTint : AppColors.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isDone
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 17,
                    color: isDone ? AppColors.primary : Colors.white,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    (isDone ? 'weekly_mission.done' : 'weekly_mission.mark_done')
                        .tr(),
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: isDone ? AppColors.primary : Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _locationLabel(PrayerSettings settings) {
  if (settings.cityId != null) return 'cities.${settings.cityId}'.tr();
  return 'home.current_location'.tr();
}

/// Gregorian date (always available, computed locally) plus the Hijri date
/// once it's back from the network — see hijri_date_service.dart for why
/// the Hijri half isn't computed locally. Falls back to the Gregorian date
/// alone rather than showing an error if the fetch hasn't landed yet.
String _dateLabel(WidgetRef ref, bool isArabic) {
  final gregorian = formatGregorianDate(DateTime.now(), arabic: isArabic);
  final hijriAsync = ref.watch(todayHijriDateProvider);
  final hijri = hijriAsync.valueOrNull;
  if (hijri == null) return gregorian;

  final month = isArabic ? hijri.monthAr : hijri.monthEn;
  final day = isArabic ? toArabicDigits('${hijri.day}') : '${hijri.day}';
  final year = isArabic ? toArabicDigits('${hijri.year}') : '${hijri.year}';
  final hijriLabel = '$day $month $year${isArabic ? 'هـ' : ' AH'}';
  return '$hijriLabel · $gregorian';
}

String _formatCountdown(Duration countdown) {
  final clamped = countdown.isNegative ? Duration.zero : countdown;
  final hours = clamped.inHours;
  final minutes = clamped.inMinutes % 60;

  if (hours <= 0 && minutes <= 0) return 'home.now'.tr();
  if (hours <= 0) return 'home.in_minutes'.tr(namedArgs: {'m': '$minutes'});
  return 'home.in_hours_minutes'.tr(
    namedArgs: {'h': '$hours', 'm': '$minutes'},
  );
}

/// Prompts for the exact-alarm permission, without which the adhan cannot
/// play in full at the right minute.
///
/// The app cannot hold USE_EXACT_ALARM — Play reserves it for alarm-clock and
/// calendar apps — so SCHEDULE_EXACT_ALARM is the only route, and from
/// Android 13 that is off until the user turns it on themselves.
class _ExactAlarmBanner extends ConsumerWidget {
  const _ExactAlarmBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.goldTint,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.alarm_on_rounded, size: 20, color: AppColors.gold),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'home.exact_alarms_title'.tr(),
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'home.exact_alarms_body'.tr(),
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: ref
                      .read(exactAlarmsAllowedProvider.notifier)
                      .request,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'home.exact_alarms_action'.tr(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Sunrise, midnight and the last third of the night.
///
/// Separate from PrayerCard on purpose: none of these is a prayer and none
/// takes an adhan. Sunrise closes the Fajr window, and the other two mark
/// the night for qiyam — useful to see, wrong to be called to.
class _ExtraTimesRow extends StatelessWidget {
  final DailyPrayerTimes times;
  final bool isArabic;

  const _ExtraTimesRow({required this.times, required this.isArabic});

  @override
  Widget build(BuildContext context) {
    final entries = <(IconData, String, DateTime)>[
      (Icons.wb_twilight_rounded, 'prayers.sunrise', times.sunrise),
      (Icons.nightlight_round, 'prayers.midnight', times.midnight),
      (Icons.bedtime_rounded, 'prayers.last_third', times.lastThird),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          for (final (icon, key, at) in entries)
            Expanded(
              child: Column(
                children: [
                  Icon(icon, size: 17, color: AppColors.primary),
                  const SizedBox(height: 6),
                  Text(
                    key.tr(),
                    style: TextStyle(
                      fontSize: 10.5,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formatClockTime(at, arabicDigits: isArabic),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
