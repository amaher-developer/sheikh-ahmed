import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/tasbeeh/tasbeeh_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/khatim_pattern.dart';
import '../../../shared/widgets/sub_screen_header.dart';

/// A digital prayer-bead counter. Unlike the Azkar screen — which walks a
/// fixed list toward completing a set of adhkar — this is open-ended: one
/// phrase, tapped as many times as the user wants, with the tally kept per
/// phrase so switching between them doesn't lose a part-finished round.
class TasbeehScreen extends ConsumerStatefulWidget {
  const TasbeehScreen({super.key});

  @override
  ConsumerState<TasbeehScreen> createState() => _TasbeehScreenState();
}

class _TasbeehScreenState extends ConsumerState<TasbeehScreen> {
  static const _arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];

  /// The counter is the one place in this app where Arabic-Indic digits
  /// matter regardless of locale — a tasbeeh reads as beads, not as a
  /// number field — but the English UI should still show 33, not ٣٣.
  String _digits(int n) {
    if (context.locale.languageCode != 'ar') return '$n';
    return n.toString().split('').map((d) => _arabicDigits[int.parse(d)]).join();
  }

  /// Targets offered as chips: the three that make up the after-prayer
  /// tasbih, the hundred of the common daily adhkar, and a free-count mode
  /// for anyone who just wants to keep tapping.
  static const _targets = [33, 100, 500, 1000];

  void _increment() {
    final notifier = ref.read(tasbeehProvider.notifier);
    final before = ref.read(tasbeehProvider);
    // Fires *before* the state updates so the "you just completed a round"
    // buzz lands on the tap that crossed the target, not the one after.
    final willComplete =
        before.target > 0 && before.count + 1 == before.target;
    if (willComplete) {
      HapticFeedback.heavyImpact();
    } else {
      HapticFeedback.selectionClick();
    }
    notifier.increment();
  }

  Future<void> _confirmReset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('tasbeeh.reset_title'.tr(), style: AppTextStyles.title),
        content: Text('tasbeeh.reset_body'.tr(), style: AppTextStyles.body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('tasbeeh.cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'tasbeeh.reset'.tr(),
              style: const TextStyle(color: AppColors.textDanger),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) ref.read(tasbeehProvider.notifier).reset();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(tasbeehProvider);
    final notifier = ref.read(tasbeehProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: SubScreenHeader(
              bottomPadding: 54,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SubScreenTitleRow(
                    title: 'tasbeeh.title'.tr(),
                    trailing: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _confirmReset,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 10,
                        ),
                        child: Icon(
                          Icons.refresh_rounded,
                          size: 20,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'tasbeeh.lifetime_total'.tr(
                      namedArgs: {'count': _digits(state.lifetimeTotal)},
                    ),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textOnPrimaryMuted,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Transform.translate(
              offset: const Offset(0, -34),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _CounterCard(
                      text: state.phrase.textAr,
                      count: state.count,
                      countLabel: _digits(state.count),
                      target: state.target,
                      targetLabel: _digits(state.target),
                      onTap: _increment,
                    ),
                    const OrnamentDivider(),
                    Text(
                      'tasbeeh.choose_dhikr'.tr(),
                      style: AppTextStyles.subtitle,
                    ),
                    const SizedBox(height: 12),
                    ...kTasbeehPhrases.map((phrase) {
                      final selected = phrase.id == state.phraseId;
                      final done = state.counts[phrase.id] ?? 0;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: GestureDetector(
                          onTap: () => notifier.selectPhrase(phrase.id),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 15,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppColors.primaryTint
                                  : AppColors.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: selected
                                  ? const Border(
                                      right: BorderSide(
                                        color: AppColors.gold,
                                        width: 3,
                                      ),
                                    )
                                  : null,
                              boxShadow: selected
                                  ? null
                                  : [
                                      BoxShadow(
                                        color: AppColors.primaryDark
                                            .withValues(alpha: 0.05),
                                        blurRadius: 12,
                                      ),
                                    ],
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  selected
                                      ? Icons.radio_button_checked_rounded
                                      : Icons.radio_button_unchecked_rounded,
                                  size: 21,
                                  color: selected
                                      ? AppColors.primary
                                      : AppColors.iconMuted,
                                ),
                                const SizedBox(width: 13),
                                Expanded(
                                  child: Text(
                                    phrase.textAr,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textPrimary,
                                      height: 1.8,
                                    ),
                                  ),
                                ),
                                if (done > 0)
                                  Text(
                                    _digits(done),
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.gold,
                                      height: 1.5,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 14),
                    Text('tasbeeh.target'.tr(), style: AppTextStyles.subtitle),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final t in _targets)
                          _TargetChip(
                            label: _digits(t),
                            selected: state.target == t,
                            onTap: () => notifier.setTarget(t),
                          ),
                        _TargetChip(
                          label: 'tasbeeh.free_count'.tr(),
                          selected: !_targets.contains(state.target),
                          onTap: () => notifier.setTarget(0),
                        ),
                      ],
                    ),
                    const SizedBox(height: 90),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TargetChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TargetChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: selected
              ? null
              : [
                  BoxShadow(
                    color: AppColors.primaryDark.withValues(alpha: 0.05),
                    blurRadius: 8,
                  ),
                ],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : AppColors.textSecondary,
            height: 1.5,
          ),
        ),
      ),
    );
  }
}

/// The tap target itself. Intentionally the whole card rather than just the
/// ring — a tasbeeh is used without looking at the screen, so the hit area
/// should be as large as the design allows.
class _CounterCard extends StatelessWidget {
  final String text;
  final int count;
  final String countLabel;
  final int target;
  final String targetLabel;
  final VoidCallback onTap;

  const _CounterCard({
    required this.text,
    required this.count,
    required this.countLabel,
    required this.target,
    required this.targetLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // A zero target is "free count" — the ring then has nothing to fill
    // toward, so it stays empty rather than dividing by zero.
    final progress = target > 0 ? (count / target).clamp(0.0, 1.0) : 0.0;
    final isComplete = target > 0 && count >= target;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 22),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.surface, AppColors.primaryTint],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.28)),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryDark.withValues(alpha: 0.10),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                height: 2.0,
              ),
            ),
            const SizedBox(height: 26),
            SizedBox(
              width: 168,
              height: 168,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: progress),
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, _) => SizedBox(
                      width: 168,
                      height: 168,
                      child: CircularProgressIndicator(
                        value: value,
                        strokeWidth: 8,
                        strokeCap: StrokeCap.round,
                        backgroundColor: AppColors.primary.withValues(
                          alpha: 0.15,
                        ),
                        valueColor: AlwaysStoppedAnimation(
                          isComplete ? AppColors.gold : AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                  Container(
                    width: 138,
                    height: 138,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      shape: BoxShape.circle,
                    ),
                    // A large system font scale must never overflow the
                    // circle — scale the count down instead of clipping it.
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              countLabel,
                              style: TextStyle(
                                fontSize: 46,
                                fontWeight: FontWeight.w800,
                                color: isComplete
                                    ? AppColors.gold
                                    : AppColors.primary,
                                height: 1.1,
                              ),
                            ),
                            if (target > 0)
                              Text(
                                '${'azkar_screen.of'.tr()} $targetLabel',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                  height: 1.5,
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
            const SizedBox(height: 18),
            Text(
              isComplete
                  ? 'tasbeeh.round_complete'.tr()
                  : 'tasbeeh.tap_to_count'.tr(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: isComplete ? FontWeight.w700 : FontWeight.w400,
                color: isComplete ? AppColors.gold : AppColors.textMuted,
                height: 1.7,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
