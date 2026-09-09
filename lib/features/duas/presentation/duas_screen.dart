import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/duas/dua_data.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/arabic_numerals.dart';
import '../../../shared/widgets/khatim_pattern.dart';
import '../../../shared/widgets/sub_screen_header.dart';

/// أدعية مأثورة, on their own screen.
///
/// Deliberately not a tab inside the azkar. That screen counts a daily
/// progress across a list you are meant to finish — right for أذكار الصباح,
/// wrong here: a du'a is asked when it is needed, and reporting "3 of 18
/// today" over supplications says something untrue about them.
///
/// So this screen has no progress bar and no daily reset. What it has
/// instead is themes, because the only question a reader arrives with is
/// "which one do I want" — and eighteen in a flat list does not answer it.
class DuasScreen extends StatefulWidget {
  const DuasScreen({super.key});

  @override
  State<DuasScreen> createState() => _DuasScreenState();
}

class _DuasScreenState extends State<DuasScreen> {
  int _groupIndex = 0;

  DuaGroup get _group => kDuaGroups[_groupIndex];

  @override
  Widget build(BuildContext context) {
    final arabic = context.locale.languageCode == 'ar';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: SubScreenHeader(
              bottomPadding: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SubScreenTitleRow(title: 'duas_screen.title'.tr()),
                  const SizedBox(height: 14),
                  Text(
                    'duas_screen.subtitle'.tr(),
                    style: const TextStyle(
                      fontSize: 11.5,
                      height: 1.7,
                      color: AppColors.textOnPrimaryMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // No negative offset pulling these up under the header: the
          // header paints over them and the row disappeared behind its
          // rounded bottom edge.
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(0, 14, 0, 4),
            sliver: SliverToBoxAdapter(
              child: SizedBox(
                height: 44,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: kDuaGroups.length,
                  itemBuilder: (context, i) {
                    final active = i == _groupIndex;
                    return Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _groupIndex = i);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 11,
                          ),
                          decoration: BoxDecoration(
                            color: active
                                ? AppColors.primary
                                : AppColors.surface,
                            borderRadius: BorderRadius.circular(22),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primaryDark.withValues(
                                  alpha: 0.05,
                                ),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: Text(
                            kDuaGroups[i].titleKey.tr(),
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: active
                                  ? Colors.white
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
            sliver: SliverList.builder(
              itemCount: _group.duas.length,
              itemBuilder: (context, i) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _DuaCard(dua: _group.duas[i], arabic: arabic),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One supplication, with a counter only where one belongs.
///
/// Most du'as carry no number at all, so most cards show none — a "0 / 1"
/// under every one of them would turn asking into box-ticking, which is the
/// thing this screen exists to avoid. The two that are traditionally
/// repeated keep their count, and those get a tappable circle.
class _DuaCard extends StatefulWidget {
  final Dua dua;
  final bool arabic;

  const _DuaCard({required this.dua, required this.arabic});

  @override
  State<_DuaCard> createState() => _DuaCardState();
}

class _DuaCardState extends State<_DuaCard> {
  int _said = 0;

  bool get _counted => widget.dua.count > 1;

  void _tap() {
    if (!_counted) return;
    HapticFeedback.selectionClick();
    // Wraps rather than sticking at the top, so a second round needs no
    // reset button. The count is not persisted: it is a tally for this
    // sitting, not a daily record — see the class comment.
    setState(() => _said = _said >= widget.dua.count ? 0 : _said + 1);
  }

  @override
  Widget build(BuildContext context) {
    String n(int v) => widget.arabic ? toArabicDigits('$v') : '$v';
    final done = _counted && _said >= widget.dua.count;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _tap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        decoration: BoxDecoration(
          color: done ? AppColors.ayahBg : AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: done ? AppColors.primary : AppColors.border,
            width: done ? 1.4 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryDark.withValues(alpha: 0.04),
              blurRadius: 14,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.dua.textAr,
              textAlign: TextAlign.center,
              style: AppTextStyles.mushaf(fontSize: 19, height: 2.1)
                  .copyWith(color: AppColors.textPrimary),
            ),
            if (_counted) ...[
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  KhatimGlyph(
                    size: 12,
                    color: AppColors.gold,
                    strokeWidth: 1.6,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${n(_said)} / ${n(widget.dua.count)}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: done ? AppColors.primary : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  KhatimGlyph(
                    size: 12,
                    color: AppColors.gold,
                    strokeWidth: 1.6,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
