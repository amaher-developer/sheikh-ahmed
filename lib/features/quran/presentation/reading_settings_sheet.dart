import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/quran/quran_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/arabic_numerals.dart';

/// How the Quran is set: the printed page, or the app's own text with the
/// face, size and weight the reader chooses.
void showReadingSettings(BuildContext context) {
  HapticFeedback.selectionClick();
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const ReadingSettingsSheet(),
  );
}

class ReadingSettingsSheet extends ConsumerWidget {
  const ReadingSettingsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final printed = ref.watch(printedMushafProvider);
    final style = ref.watch(quranReadingStyleProvider);
    final size = ref.watch(quranFontSizeProvider);
    final arabic = context.locale.languageCode == 'ar';

    return SafeArea(
      child: SingleChildScrollView(
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(
                    Icons.text_fields_rounded,
                    size: 18,
                    color: AppColors.gold,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'quran_screen.reading_settings'.tr(),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              _SectionLabel('quran_screen.reading_layout'.tr()),
              const SizedBox(height: 8),
              _Choice(
                selected: printed,
                title: 'quran_screen.layout_printed'.tr(),
                subtitle: 'quran_screen.layout_printed_note'.tr(),
                onTap: printed
                    ? null
                    : ref.read(printedMushafProvider.notifier).toggle,
              ),
              const SizedBox(height: 8),
              _Choice(
                selected: !printed,
                title: 'quran_screen.layout_text'.tr(),
                subtitle: 'quran_screen.layout_text_note'.tr(),
                onTap: printed
                    ? ref.read(printedMushafProvider.notifier).toggle
                    : null,
              ),

              // Everything below sets the app's own text. On the printed page
              // none of it applies: that page is a fixed grid of fifteen
              // lines whose glyphs are pre-shaped in a font of its own — one
              // font per page, 604 of them, with no second face and no bold
              // weight. Showing the controls greyed out rather than hiding
              // them is deliberate: hidden, the reader is left wondering
              // where the font setting went.
              const SizedBox(height: 20),
              Opacity(
                opacity: printed ? 0.4 : 1,
                child: IgnorePointer(
                  key: const ValueKey('quranFontControls'),
                  ignoring: printed,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _SectionLabel('quran_screen.reading_font'.tr()),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          for (final entry in kQuranFonts.entries)
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(left: 8),
                                child: _FontChip(
                                  family: entry.key,
                                  label: arabic
                                      ? entry.value
                                      : entry.key == 'ScheherazadeNew'
                                            ? 'Scheherazade'
                                            : 'Amiri',
                                  selected: style.family == entry.key,
                                  onTap: () => ref
                                      .read(quranReadingStyleProvider.notifier)
                                      .setFamily(entry.key),
                                ),
                              ),
                            ),
                        ],
                      ),

                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: _SectionLabel(
                              'quran_screen.reading_size'.tr(),
                            ),
                          ),
                          Text(
                            arabic
                                ? toArabicDigits('${size.round()}')
                                : '${size.round()}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.gold,
                            ),
                          ),
                        ],
                      ),
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: AppColors.primary,
                          inactiveTrackColor: AppColors.divider,
                          thumbColor: AppColors.primary,
                          overlayColor: AppColors.primary.withValues(
                            alpha: 0.12,
                          ),
                          trackHeight: 3,
                        ),
                        child: Slider(
                          value: size,
                          min: kMinQuranFontSize,
                          max: kMaxQuranFontSize,
                          // One step per point. A continuous slider on a
                          // font size gives 21.7pt, which is not a size
                          // anyone means to pick.
                          divisions:
                              (kMaxQuranFontSize - kMinQuranFontSize).round(),
                          onChanged: (v) => ref
                              .read(quranFontSizeProvider.notifier)
                              .set(v),
                        ),
                      ),

                      const SizedBox(height: 6),
                      _BoldRow(
                        bold: style.bold,
                        // AmiriQuran ships a single weight, and Flutter
                        // synthesises a smeared fake bold for it that turns
                        // dense Uthmani diacritics to mush. The switch is
                        // offered only on the face that has a real Bold.
                        available: style.family == 'ScheherazadeNew',
                        onChanged: (v) => ref
                            .read(quranReadingStyleProvider.notifier)
                            .setBold(v),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 18),
              _SectionLabel('quran_screen.reading_preview'.tr()),
              const SizedBox(height: 8),
              _Preview(printed: printed, size: size),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
        color: AppColors.textSecondary,
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  final bool selected;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _Choice({
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryTint : AppColors.surface,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 19,
              color: selected ? AppColors.primary : AppColors.iconMuted,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.5,
                      color: AppColors.textSecondary,
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

/// A face shown in itself, so the choice is made by looking rather than by
/// reading the name of a font nobody has seen.
class _FontChip extends StatelessWidget {
  final String family;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FontChip({
    required this.family,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryTint : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'quran_screen.font_sample'.tr(),
              maxLines: 1,
              textScaler: TextScaler.noScaling,
              style: TextStyle(
                fontFamily: family,
                fontSize: 19,
                height: 1.9,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: selected ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BoldRow extends StatelessWidget {
  final bool bold;
  final bool available;
  final ValueChanged<bool> onChanged;

  const _BoldRow({
    required this.bold,
    required this.available,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'quran_screen.reading_bold'.tr(),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              if (!available) ...[
                const SizedBox(height: 3),
                Text(
                  'quran_screen.reading_bold_unavailable'.tr(),
                  style: TextStyle(
                    fontSize: 10.5,
                    height: 1.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
        Switch(
          value: available && bold,
          onChanged: available ? onChanged : null,
          activeThumbColor: AppColors.primary,
        ),
      ],
    );
  }
}

/// A verse set exactly as the reader will set it.
///
/// The whole point of the sheet is a decision about how the text looks, and
/// that is not answerable from a number and two font names.
class _Preview extends StatelessWidget {
  final bool printed;
  final double size;

  const _Preview({required this.printed, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.mushafPage,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
      ),
      child: printed
          // No preview of the printed page here. Its font is downloaded per
          // page and only renders that page's own glyph codes, so anything
          // shown in this box would be a different typesetting pretending to
          // be the page — worse than saying so.
          ? Text(
              'quran_screen.layout_printed_preview'.tr(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.5,
                height: 1.6,
                color: AppColors.textSecondary,
              ),
            )
          : Text(
              'quran_screen.font_preview_ayah'.tr(),
              textAlign: TextAlign.center,
              textScaler: TextScaler.noScaling,
              style: AppTextStyles.mushaf(
                fontSize: size,
                height: 2.0,
              ).copyWith(color: AppColors.mushafInk),
            ),
    );
  }
}
