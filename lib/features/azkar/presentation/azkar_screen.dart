import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/material.dart' as material;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/azkar/azkar_data.dart';
import '../../../core/azkar/azkar_providers.dart';
import '../../../core/quran/quran_providers.dart';
import '../../../core/quran/quran_text_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/khatim_pattern.dart';
import '../../../shared/widgets/sub_screen_header.dart';

class AzkarScreen extends ConsumerStatefulWidget {
  /// Category id (see azkar_data.dart, e.g. 'evening') to open directly on
  /// — used by the worship tracker so tapping "evening azkar" doesn't land
  /// on the morning tab by default.
  final String? initialCategoryId;

  const AzkarScreen({super.key, this.initialCategoryId});

  @override
  ConsumerState<AzkarScreen> createState() => _AzkarScreenState();
}

class _AzkarScreenState extends ConsumerState<AzkarScreen> {
  late int _chipIndex = _initialChipIndex();
  String? _focusedItemId;
  final Map<String, Future<String>> _quranTextCache = {};

  int _initialChipIndex() {
    if (widget.initialCategoryId == null) return 0;
    final index = kAzkarCategories.indexWhere(
      (c) => c.id == widget.initialCategoryId,
    );
    return index >= 0 ? index : 0;
  }

  /// Fetches and joins the verse text for an item's [QuranRef]s (e.g. Ayat
  /// al-Kursi), using the same live Quran source and cache as the Quran
  /// tab rather than transcribing verses by hand. Cached per item so
  /// re-focusing an item doesn't re-fetch.
  Future<String> _quranRefText(AzkarItem item) {
    return _quranTextCache.putIfAbsent(item.id, () async {
      final service = ref.read(quranTextServiceProvider);
      final parts = <String>[];
      for (final r in item.quranRefs) {
        final List<Ayah> ayahs = await service.fetchSurah(r.surahNumber);
        parts.addAll(
          ayahs
              .where(
                (a) =>
                    a.numberInSurah >= r.fromAyah &&
                    a.numberInSurah <= r.toAyah,
              )
              .map((a) => a.text.trim()),
        );
      }
      return parts.join('  ۝  ');
    });
  }

  static const _arabicDigits = [
    '٠',
    '١',
    '٢',
    '٣',
    '٤',
    '٥',
    '٦',
    '٧',
    '٨',
    '٩',
  ];
  static String _ar(int n) =>
      n.toString().split('').map((d) => _arabicDigits[int.parse(d)]).join();

  /// An instruction item shows a translated label; a dhikr shows its own
  /// Arabic text untouched in either language.
  String _itemLabel(AzkarItem item) =>
      item.isLabelKey ? item.textAr.tr() : item.textAr;

  String _refLabel(AzkarItem item) => quranRefLabel(
    item,
    arabic: context.locale.languageCode == 'ar',
  );

  /// Steps the focused dhikr by [delta] within the current category.
  ///
  /// Focus is stored as an id rather than an index so it survives the
  /// category changing underneath it; stepping therefore resolves the
  /// current index first rather than keeping a counter of its own.
  void _moveFocus(int delta) {
    final items = _category.items;
    final current = items.indexWhere((i) => i.id == _focusedItemId);
    final from = current >= 0 ? current : 0;
    final next = from + delta;
    if (next < 0 || next >= items.length) return;
    HapticFeedback.selectionClick();
    setState(() => _focusedItemId = items[next].id);
  }

  AzkarCategory get _category => kAzkarCategories[_chipIndex];

  static const _categoryIcons = {
    'morning': Icons.wb_twilight_rounded,
    'evening': Icons.nights_stay_rounded,
    'sleep': Icons.bedtime_rounded,
    'prayer': Icons.mosque_rounded,
    'ruqyah': Icons.healing_rounded,
    'waking': Icons.wb_sunny_rounded,
    'food': Icons.restaurant_rounded,
    'adhan': Icons.campaign_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final progress = ref.watch(azkarProgressProvider);
    final notifier = ref.read(azkarProgressProvider.notifier);

    final doneInCategory = _category.items
        .where((item) => (progress[item.id] ?? 0) >= item.count)
        .length;
    final categoryProgress = doneInCategory / _category.items.length;

    final focusedItem = _category.items.firstWhere(
      (item) => item.id == _focusedItemId,
      orElse: () => _category.items.firstWhere(
        (item) => (progress[item.id] ?? 0) < item.count,
        orElse: () => _category.items.first,
      ),
    );
    final focusedCount = progress[focusedItem.id] ?? 0;
    final focusedIndex = _category.items.indexOf(focusedItem);

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
                  SubScreenTitleRow(title: _category.titleKey.tr()),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'azkar_screen.daily_progress'.tr(),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textOnPrimaryMuted,
                          height: 1.6,
                        ),
                      ),
                      Text(
                        '${_ar(doneInCategory)} ${'azkar_screen.of'.tr()} ${_ar(_category.items.length)}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: categoryProgress.clamp(0, 1)),
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, _) => LinearProgressIndicator(
                        value: value,
                        minHeight: 5,
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        valueColor: const AlwaysStoppedAnimation(
                          AppColors.goldLight,
                        ),
                      ),
                    ),
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
                  SizedBox(
                    height: 40,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: kAzkarCategories.length,
                      separatorBuilder: (context, i) =>
                          const SizedBox(width: 9),
                      itemBuilder: (context, i) {
                        final active = i == _chipIndex;
                        return GestureDetector(
                          onTap: () => setState(() {
                            _chipIndex = i;
                            _focusedItemId = null;
                          }),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 17,
                              vertical: 9,
                            ),
                            decoration: BoxDecoration(
                              color: active
                                  ? AppColors.primary
                                  : AppColors.surface,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: active
                                  ? null
                                  : [
                                      BoxShadow(
                                        color: AppColors.primaryDark.withValues(
                                          alpha: 0.05,
                                        ),
                                        blurRadius: 8,
                                      ),
                                    ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _categoryIcons[kAzkarCategories[i].id] ??
                                      Icons.circle,
                                  size: 14,
                                  color: active
                                      ? Colors.white
                                      : AppColors.primary,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  kAzkarCategories[i].titleKey.tr(),
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: active
                                        ? Colors.white
                                        : AppColors.textSecondary,
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 18),
                  focusedItem.quranRefs.isEmpty
                      ? _TasbihCard(
                          text: _itemLabel(focusedItem),
                          reference: _refLabel(focusedItem),
                          done: focusedCount,
                          countLabel: _ar(focusedCount),
                          target: focusedItem.count,
                          targetLabel: _ar(focusedItem.count),
                          position: focusedIndex + 1,
                          total: _category.items.length,
                          onPrevious: focusedIndex > 0 ? () => _moveFocus(-1) : null,
                          onNext: focusedIndex < _category.items.length - 1
                              ? () => _moveFocus(1)
                              : null,
                          onTap: () {
                            notifier.increment(focusedItem);
                            setState(() {});
                          },
                        )
                      : FutureBuilder<String>(
                          future: _quranRefText(focusedItem),
                          builder: (context, snapshot) => _TasbihCard(
                            text: snapshot.data ?? _itemLabel(focusedItem),
                            reference: _refLabel(focusedItem),
                            isQuranText: snapshot.hasData,
                            done: focusedCount,
                            countLabel: _ar(focusedCount),
                            target: focusedItem.count,
                            targetLabel: _ar(focusedItem.count),
                            position: focusedIndex + 1,
                            total: _category.items.length,
                            onPrevious:
                                focusedIndex > 0 ? () => _moveFocus(-1) : null,
                            onNext: focusedIndex < _category.items.length - 1
                                ? () => _moveFocus(1)
                                : null,
                            onTap: () {
                              notifier.increment(focusedItem);
                              setState(() {});
                            },
                          ),
                        ),
                  const OrnamentDivider(),
                  ..._category.items.map((item) {
                    final count = progress[item.id] ?? 0;
                    final done = count >= item.count;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: GestureDetector(
                        onTap: () => setState(() => _focusedItemId = item.id),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 15,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: item.id == focusedItem.id
                                ? AppColors.primaryTint
                                : AppColors.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: item.id == focusedItem.id
                                ? Border(
                                    right: BorderSide(
                                      color: AppColors.gold,
                                      width: 3,
                                    ),
                                  )
                                : null,
                            boxShadow: item.id == focusedItem.id
                                ? null
                                : [
                                    BoxShadow(
                                      color: AppColors.primaryDark.withValues(
                                        alpha: 0.05,
                                      ),
                                      blurRadius: 12,
                                    ),
                                  ],
                          ),
                          child: Row(
                            children: [
                              Icon(
                                done
                                    ? Icons.check_circle_rounded
                                    : Icons.circle_outlined,
                                size: 21,
                                color: done
                                    ? AppColors.primary
                                    : AppColors.iconMuted,
                              ),
                              const SizedBox(width: 13),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _itemLabel(item),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: done
                                            ? AppColors.textSecondary
                                            : AppColors.textPrimary,
                                        decoration: done
                                            ? TextDecoration.lineThrough
                                            : null,
                                        height: 1.7,
                                      ),
                                    ),
                                    if (_refLabel(item).isNotEmpty)
                                      Text(
                                        _refLabel(item),
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.primary,
                                          height: 1.7,
                                        ),
                                      ),
                                    const SizedBox(height: 4),
                                    Text(
                                      item.count > 1
                                          ? '${_ar(count)} / ${_ar(item.count)} · ${item.countLabel.tr()}'
                                          : item.countLabel.tr(),
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        color: AppColors.textSecondary,
                                        height: 1.6,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TasbihCard extends StatelessWidget {
  final String text;
  final bool isQuranText;

  /// Where the passage sits in the Mus'haf, e.g. "البقرة ٢٥٥". Empty for
  /// ordinary dhikr. Shown even when the verse text loaded, because the
  /// citation is what lets someone find or check it.
  final String reference;
  final int done;
  final String countLabel;
  final int target;
  final String targetLabel;
  final VoidCallback onTap;

  /// 1-based place in the category, shown between the arrows so it's
  /// clear how far through the set you are.
  final int position;
  final int total;

  /// Null at the ends of the list, which is what greys the arrow out.
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  const _TasbihCard({
    required this.text,
    this.isQuranText = false,
    this.reference = '',
    required this.done,
    required this.countLabel,
    required this.target,
    required this.targetLabel,
    required this.onTap,
    required this.position,
    required this.total,
    this.onPrevious,
    this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final progress = target > 0 ? (done / target).clamp(0.0, 1.0) : 0.0;
    final isComplete = done >= target;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 22),
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
            // Deliberately uncapped. A 4-line ellipsis used to cut the
            // longer adhkar — sayyid al-istighfar, the full "أصبحنا وأصبح
            // الملك لله" — off mid-sentence, which is exactly the kind of
            // half-a-dhikr the text itself was just corrected to stop
            // showing. The card sits in a scroll view, so it can simply
            // grow; long texts step down a size instead so they stay
            // readable without dominating the screen.
            style: isQuranText
                // Real Quranic text must use the Mus'haf face — Cairo lacks
                // the Uthmani marks the API returns.
                ? AppTextStyles.mushaf(fontSize: 19, height: 1.9)
                : TextStyle(
                    fontSize: text.length > 160 ? 14.5 : 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    height: text.length > 160 ? 1.95 : 2.1,
                  ),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: onTap,
            child: SizedBox(
              width: 128,
              height: 128,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Progress ring: fills as the dhikr is repeated, so the
                  // remaining count is readable at a glance.
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: progress),
                    duration: const Duration(milliseconds: 320),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, _) => SizedBox(
                      width: 128,
                      height: 128,
                      child: CircularProgressIndicator(
                        value: value,
                        strokeWidth: 6,
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
                    width: 104,
                    height: 104,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      shape: BoxShape.circle,
                    ),
                    // FittedBox: a large system font scale must never
                    // overflow this fixed circle — scale the count down
                    // instead of clipping it.
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isComplete)
                              Icon(
                                Icons.check_circle_rounded,
                                size: 30,
                                color: AppColors.gold,
                              )
                            else
                              Text(
                                countLabel,
                                style: const TextStyle(
                                  fontSize: 34,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary,
                                  height: 1.1,
                                ),
                              ),
                            Text(
                              '${'azkar_screen.of'.tr()} $targetLabel',
                              style: TextStyle(
                                fontSize: 10,
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
          ),
          const SizedBox(height: 14),
          // Pinned to LTR so this one row keeps a fixed layout in both
          // languages: previous on the left, next on the right, each
          // chevron pointing outward. Left to the ambient direction it
          // mirrored in Arabic and the two buttons swapped sides, which
          // read as reversed. Directionality also stops the chevrons
          // auto-mirroring (they carry matchTextDirection), so what is
          // named here is what is drawn.
          Directionality(
            // Prefixed: easy_localization re-exports intl, whose own TextDirection
            // shadows Flutter's enum in this file.
            textDirection: material.TextDirection.ltr,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _StepButton(
                  icon: Icons.chevron_left_rounded,
                  onTap: onPrevious,
                ),
                Text(
                  '${_AzkarScreenState._ar(position)} / ${_AzkarScreenState._ar(total)}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                    height: 1.6,
                  ),
                ),
                _StepButton(
                  icon: Icons.chevron_right_rounded,
                  onTap: onNext,
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'azkar_screen.tap_to_count'.tr(),
            style: TextStyle(
              fontSize: 10.5,
              color: AppColors.textMuted,
              height: 1.7,
            ),
          ),
        ],
      ),
    );
  }
}

/// A prev/next arrow under the counter. Disabled — and visibly so — at the
/// ends of the category rather than hidden, so the row doesn't shift as you
/// step through.
class _StepButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _StepButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: enabled ? AppColors.primaryTint : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 22,
          color: enabled ? AppColors.primary : AppColors.iconMuted,
        ),
      ),
    );
  }
}
