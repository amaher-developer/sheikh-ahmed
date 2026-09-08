import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
// Prefixed because easy_localization re-exports intl, whose TextDirection
// shadows Flutter's enum of the same name.
import 'package:flutter/material.dart' as material;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/prayer/prayer_providers.dart';
import '../../../core/prayer/prayer_times_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/arabic_numerals.dart';
import '../../../shared/widgets/khatim_pattern.dart';
import '../../../shared/widgets/sub_screen_header.dart';

/// The month's imsakiya.
///
/// Built around what the table is actually for rather than as a grid of every
/// time: a fasting day runs from imsak to maghrib, so those two get the space
/// and the rest sit underneath in a quieter row. The first version of this
/// screen was eight equal columns at 10.5px, which fit on a phone only in the
/// sense that nothing overflowed.
///
/// Computed on the device from the user's own location and calculation
/// method, so it stays right wherever they are and never goes stale the way a
/// printed table does.
class ImsakiyaScreen extends ConsumerStatefulWidget {
  const ImsakiyaScreen({super.key});

  @override
  ConsumerState<ImsakiyaScreen> createState() => _ImsakiyaScreenState();
}

class _ImsakiyaScreenState extends ConsumerState<ImsakiyaScreen> {
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  void _shiftMonth(int delta) =>
      setState(() => _month = DateTime(_month.year, _month.month + delta));

  @override
  Widget build(BuildContext context) {
    final isArabic = context.locale.languageCode == 'ar';
    final key = '${_month.year}-${_month.month.toString().padLeft(2, '0')}';
    final days = ref.watch(monthlyPrayerTimesProvider(key));
    final now = DateTime.now();
    final isThisMonth = now.year == _month.year && now.month == _month.month;

    String n(int v) => isArabic ? toArabicDigits('$v') : '$v';

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: SubScreenHeader(
            bottomPadding: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SubScreenTitleRow(title: 'imsakiya.title'.tr()),
                const SizedBox(height: 16),
                _MonthSwitcher(
                  label: '${'months.m${_month.month}'.tr()} ${n(_month.year)}',
                  onPrevious: () => _shiftMonth(-1),
                  onNext: () => _shiftMonth(1),
                ),
              ],
            ),
          ),
        ),

        // Today's fasting window, lifted out of the list. On the current
        // month this is the one row anybody opens the screen for.
        if (isThisMonth && now.day <= days.length)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 4),
              child: _TodayCard(
                day: days[now.day - 1],
                dayNumber: now.day,
                isArabic: isArabic,
              ),
            ),
          ),

        SliverPadding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
          sliver: SliverList.separated(
            itemCount: days.length,
            separatorBuilder: (_, _) => const SizedBox(height: 9),
            itemBuilder: (context, i) => _DayCard(
              day: days[i],
              dayNumber: i + 1,
              month: _month,
              isToday: isThisMonth && now.day == i + 1,
              isArabic: isArabic,
            ),
          ),
        ),
      ],
    );
  }
}

class _MonthSwitcher extends StatelessWidget {
  final String label;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const _MonthSwitcher({
    required this.label,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    // Pinned to LTR: these step along a timeline, and a timeline does not
    // mirror the way reading order does — "back a month" stays on the left in
    // both languages.
    return Directionality(
      textDirection: material.TextDirection.ltr,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            _Arrow(icon: Icons.chevron_left_rounded, onTap: onPrevious),
            Expanded(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
            _Arrow(icon: Icons.chevron_right_rounded, onTap: onNext),
          ],
        ),
      ),
    );
  }
}

class _Arrow extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _Arrow({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(7),
        child: Icon(icon, size: 20, color: Colors.white),
      ),
    );
  }
}

/// The fasting window for today, in the app's primary green.
class _TodayCard extends StatelessWidget {
  final DailyPrayerTimes day;
  final int dayNumber;
  final bool isArabic;

  const _TodayCard({
    required this.day,
    required this.dayNumber,
    required this.isArabic,
  });

  @override
  Widget build(BuildContext context) {
    String t(DateTime at) => formatClockTime(at, arabicDigits: isArabic);
    final length = day.maghrib.difference(day.imsak);

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.22),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(child: KhatimPattern(opacity: 0.13)),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'imsakiya.today'.tr(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.75),
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _BigTime(
                      labelKey: 'prayers.imsak',
                      value: t(day.imsak),
                      icon: Icons.nights_stay_rounded,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 38,
                    color: Colors.white.withValues(alpha: 0.22),
                  ),
                  Expanded(
                    child: _BigTime(
                      labelKey: 'prayers.maghrib',
                      value: t(day.maghrib),
                      icon: Icons.wb_twilight_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'imsakiya.fast_length'.tr(
                  namedArgs: {
                    'hours': isArabic
                        ? toArabicDigits('${length.inHours}')
                        : '${length.inHours}',
                    'minutes': isArabic
                        ? toArabicDigits('${length.inMinutes % 60}')
                        : '${length.inMinutes % 60}',
                  },
                ),
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.8),
                  height: 1.6,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BigTime extends StatelessWidget {
  final String labelKey;
  final String value;
  final IconData icon;

  const _BigTime({
    required this.labelKey,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: Colors.white.withValues(alpha: 0.8)),
            const SizedBox(width: 6),
            Text(
              labelKey.tr(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontFeatures: [FontFeature.tabularFigures()],
            fontSize: 21,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            height: 1.3,
          ),
        ),
      ],
    );
  }
}

/// One day: imsak and maghrib given the weight, the five prayers underneath.
class _DayCard extends StatelessWidget {
  final DailyPrayerTimes day;
  final int dayNumber;
  final DateTime month;
  final bool isToday;
  final bool isArabic;

  const _DayCard({
    required this.day,
    required this.dayNumber,
    required this.month,
    required this.isToday,
    required this.isArabic,
  });

  @override
  Widget build(BuildContext context) {
    String t(DateTime at) => formatClockTime(at, arabicDigits: isArabic);
    final n = isArabic ? toArabicDigits('$dayNumber') : '$dayNumber';
    final weekday = DateTime(month.year, month.month, dayNumber).weekday;

    return Container(
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 11),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          // The only thing separating today from the rest — a filled card here
          // would fight the green hero card directly above it.
          color: isToday ? AppColors.gold : AppColors.border,
          width: isToday ? 1.6 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.05),
            blurRadius: 12,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isToday ? AppColors.goldTint : AppColors.primaryTint,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      n,
                      style: TextStyle(
                        fontFeatures: const [FontFeature.tabularFigures()],
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                        color: isToday ? AppColors.gold : AppColors.primary,
                      ),
                    ),
                    Text(
                      'weekdays.d$weekday'.tr(),
                      style: TextStyle(
                        fontSize: 8,
                        height: 1.3,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Pair(
                  labelKey: 'prayers.imsak',
                  value: t(day.imsak),
                  strong: true,
                ),
              ),
              Expanded(
                child: _Pair(
                  labelKey: 'prayers.maghrib',
                  value: t(day.maghrib),
                  strong: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final (key, at) in [
                ('prayers.fajr', day.fajr),
                ('prayers.sunrise', day.sunrise),
                ('prayers.dhuhr', day.dhuhr),
                ('prayers.asr', day.asr),
                ('prayers.isha', day.isha),
              ])
                Expanded(child: _Pair(labelKey: key, value: t(at))),
            ],
          ),
        ],
      ),
    );
  }
}

class _Pair extends StatelessWidget {
  final String labelKey;
  final String value;
  final bool strong;

  const _Pair({
    required this.labelKey,
    required this.value,
    this.strong = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          labelKey.tr(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: strong ? 10 : 9,
            fontWeight: strong ? FontWeight.w700 : FontWeight.w500,
            color: strong ? AppColors.primary : AppColors.textSecondary,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          style: TextStyle(
            // Tabular figures so the columns align down the list — with
            // proportional digits a stack of times reads as ragged even when
            // every cell is centred.
            fontFeatures: const [FontFeature.tabularFigures()],
            fontSize: strong ? 14 : 11,
            fontWeight: strong ? FontWeight.w700 : FontWeight.w600,
            color: AppColors.textPrimary,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}
