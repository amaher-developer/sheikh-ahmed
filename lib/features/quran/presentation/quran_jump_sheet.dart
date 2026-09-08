import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/quran/hizb_meta.dart';
import '../../../core/quran/juz_meta.dart';
import '../../../core/quran/page_starts.dart';
import '../../../core/quran/surah_meta.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/arabic_numerals.dart';

/// Where a jump lands: the verse to open the reader at.
class JumpTarget {
  final int surahNumber;
  final int ayahNumber;

  const JumpTarget(this.surahNumber, this.ayahNumber);
}

/// The three ways a Mus'haf is addressed by the people who use one.
enum _JumpBy { page, juz, hizb }

/// Asks where to go, and returns the verse to open there — or null if the
/// reader backed out.
///
/// A Mus'haf reader who wants a particular place almost never wants a surah:
/// they want a page they remember, the juz they are on this Ramadan, or the
/// hizb their halaqa is at. All three resolve to a verse, which is the only
/// thing the reader itself understands.
Future<JumpTarget?> showQuranJumpSheet(BuildContext context) {
  return showModalBottomSheet<JumpTarget>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _JumpSheet(),
  );
}

class _JumpSheet extends StatefulWidget {
  const _JumpSheet();

  @override
  State<_JumpSheet> createState() => _JumpSheetState();
}

class _JumpSheetState extends State<_JumpSheet> {
  _JumpBy _by = _JumpBy.page;

  /// The typed page number, for the field that sits above the page grid.
  final _pageField = TextEditingController();

  @override
  void dispose() {
    _pageField.dispose();
    super.dispose();
  }

  void _go(JumpTarget target) {
    HapticFeedback.selectionClick();
    Navigator.of(context).pop(target);
  }

  /// Jumps to whatever page number was typed, if it is one that exists.
  void _goToTypedPage() {
    final page = int.tryParse(normalizeArabicDigits(_pageField.text.trim()));
    final start = page == null ? null : pageStartFor(page);
    if (start == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('quran_screen.jump_page_invalid'.tr())),
      );
      return;
    }
    _go(JumpTarget(start.surahNumber, start.ayahNumber));
  }

  @override
  Widget build(BuildContext context) {
    final arabic = context.locale.languageCode == 'ar';

    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.4,
      maxChildSize: 0.94,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
              child: Row(
                children: [
                  Icon(
                    Icons.my_location_rounded,
                    size: 18,
                    color: AppColors.gold,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'quran_screen.jump_title'.tr(),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: _Segments(
                selected: _by,
                onChanged: (by) => setState(() => _by = by),
              ),
            ),
            if (_by == _JumpBy.page)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
                child: _PageField(
                  controller: _pageField,
                  onSubmit: _goToTypedPage,
                ),
              ),
            const SizedBox(height: 12),
            Expanded(
              child: switch (_by) {
                _JumpBy.page => _PageGrid(
                  controller: scrollController,
                  arabic: arabic,
                  onPick: _go,
                ),
                _JumpBy.juz => _JuzList(
                  controller: scrollController,
                  arabic: arabic,
                  onPick: _go,
                ),
                _JumpBy.hizb => _HizbList(
                  controller: scrollController,
                  arabic: arabic,
                  onPick: _go,
                ),
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// The page / juz / hizb switch.
class _Segments extends StatelessWidget {
  final _JumpBy selected;
  final ValueChanged<_JumpBy> onChanged;

  const _Segments({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const labels = {
      _JumpBy.page: 'quran_screen.jump_by_page',
      _JumpBy.juz: 'quran_screen.jump_by_juz',
      _JumpBy.hizb: 'quran_screen.jump_by_hizb',
    };

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.chipBg,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        children: [
          for (final by in _JumpBy.values)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(by),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: by == selected ? AppColors.primary : null,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    labels[by]!.tr(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: by == selected
                          ? Colors.white
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Type a page number rather than scroll 604 of them.
///
/// The grid below is for browsing; this is for the reader who already knows
/// they want page 293 and should not have to hunt for it.
class _PageField extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSubmit;

  const _PageField({required this.controller, required this.onSubmit});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.go,
            onSubmitted: (_) => onSubmit(),
            style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'quran_screen.jump_page_hint'.tr(),
              hintStyle: TextStyle(fontSize: 13, color: AppColors.textMuted),
              filled: true,
              fillColor: AppColors.chipBg,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(11),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        ElevatedButton(
          onPressed: onSubmit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(11),
            ),
          ),
          child: Text(
            'quran_screen.jump_go'.tr(),
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
        ),
      ],
    );
  }
}

class _PageGrid extends StatelessWidget {
  final ScrollController controller;
  final bool arabic;
  final ValueChanged<JumpTarget> onPick;

  const _PageGrid({
    required this.controller,
    required this.arabic,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 6,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1.25,
      ),
      itemCount: kPageStarts.length,
      itemBuilder: (context, i) {
        final start = kPageStarts[i];
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onPick(
            JumpTarget(start.surahNumber, start.ayahNumber),
          ),
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.chipBg,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              arabic ? toArabicDigits('${start.page}') : '${start.page}',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _JuzList extends StatelessWidget {
  final ScrollController controller;
  final bool arabic;
  final ValueChanged<JumpTarget> onPick;

  const _JuzList({
    required this.controller,
    required this.arabic,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
      itemCount: kJuzStarts.length,
      itemBuilder: (context, i) {
        final juz = kJuzStarts[i];
        final surah = surahByNumber(juz.surahNumber);
        return _JumpRow(
          number: arabic
              ? toArabicDigits('${juz.number}')
              : '${juz.number}',
          title: 'quran_screen.juz_n'.tr(namedArgs: {
            'n': arabic ? toArabicDigits('${juz.number}') : '${juz.number}',
          }),
          subtitle: _placeLabel(surah, juz.ayahNumber, arabic),
          onTap: () => onPick(JumpTarget(juz.surahNumber, juz.ayahNumber)),
        );
      },
    );
  }
}

class _HizbList extends StatelessWidget {
  final ScrollController controller;
  final bool arabic;
  final ValueChanged<JumpTarget> onPick;

  const _HizbList({
    required this.controller,
    required this.arabic,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    const quarterKeys = [
      'quran_screen.hizb_n',
      'quran_screen.hizb_quarter',
      'quran_screen.hizb_half',
      'quran_screen.hizb_three_quarters',
    ];

    return ListView.builder(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
      // All 240 quarters, not the 60 hizbs: a halaqa that meets at ربع
      // الحزب has no way to reach it from a list of hizbs alone.
      itemCount: kHizbQuarters.length,
      itemBuilder: (context, i) {
        final q = kHizbQuarters[i];
        final surah = surahByNumber(q.surahNumber);
        final n = arabic ? toArabicDigits('${q.hizb}') : '${q.hizb}';
        return _JumpRow(
          number: n,
          title: quarterKeys[q.quarter].tr(namedArgs: {'n': n}),
          subtitle: _placeLabel(surah, q.ayahNumber, arabic),
          onTap: () => onPick(JumpTarget(q.surahNumber, q.ayahNumber)),
        );
      },
    );
  }
}

/// "البقرة · ١٤٢ — صفحة ٢٢" — where the entry actually lands, so the reader
/// can recognise it before tapping.
String _placeLabel(Surah surah, int ayah, bool arabic) {
  String n(int v) => arabic ? toArabicDigits('$v') : '$v';
  final page = pageForAyah(surah.number, ayah);
  final name = surahDisplayName(surah, arabic);
  final where = '$name · ${n(ayah)}';
  if (page == null) return where;
  return '$where — ${'quran_screen.mushaf_page'.tr(namedArgs: {
    'page': n(page),
  })}';
}

class _JumpRow extends StatelessWidget {
  final String number;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _JumpRow({
    required this.number,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.chipBg,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.goldTint,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    number,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.gold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: AppColors.iconMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
