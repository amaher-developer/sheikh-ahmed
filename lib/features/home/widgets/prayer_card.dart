import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class PrayerTime {
  final String labelKey;
  final String time;
  const PrayerTime(this.labelKey, this.time);
}

class PrayerCard extends StatelessWidget {
  final String nextPrayerKey;
  final String nextPrayerTime;
  final String countdown;
  final double progress; // 0..1, elapsed fraction until next prayer
  final List<PrayerTime> times;
  final int activeIndex;

  const PrayerCard({
    super.key,
    required this.nextPrayerKey,
    required this.nextPrayerTime,
    required this.countdown,
    required this.progress,
    required this.times,
    required this.activeIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryTint,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 5,
                            height: 5,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'home.next_prayer'.tr(),
                            style: AppTextStyles.label.copyWith(
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(nextPrayerKey.tr(), style: AppTextStyles.heading),
                    const SizedBox(height: 8),
                    Text(
                      '$nextPrayerTime · $countdown',
                      style: AppTextStyles.accent,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 70,
                height: 70,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 70,
                      height: 70,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 7,
                        backgroundColor: AppColors.chipBg,
                        valueColor: const AlwaysStoppedAnimation(
                          AppColors.primary,
                        ),
                      ),
                    ),
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        shape: BoxShape.circle,
                      ),
                      // FittedBox instead of a bare Column: a large system
                      // font scale must never overflow this fixed 56px
                      // circle — scale the content down instead of clipping it.
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.wb_sunny_rounded,
                                size: 17,
                                color: AppColors.gold,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${(progress * 100).round()}%',
                                style: AppTextStyles.label.copyWith(
                                  fontSize: 9.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(height: 1),
          const SizedBox(height: 16),
          Row(
            children: List.generate(times.length, (i) {
              final t = times[i];
              final active = i == activeIndex;
              // Expanded: five fixed-intrinsic-width columns in a plain Row
              // can sum to more than the available width under a larger
              // system font scale, overflowing the whole row. Expanded
              // forces them to share the width and lets each Text ellipsize
              // in its own slot instead.
              return Expanded(
                child: Column(
                  children: [
                    Text(
                      t.labelKey.tr(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.label.copyWith(
                        color: active
                            ? AppColors.gold
                            : AppColors.textSecondary,
                        fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      t.time,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                        color: active
                            ? AppColors.gold
                            : AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
