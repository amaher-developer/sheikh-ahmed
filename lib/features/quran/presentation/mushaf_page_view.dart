import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
// Prefixed: easy_localization re-exports intl, whose TextDirection shadows
// Flutter's enum of the same name.
import 'package:flutter/material.dart' as material;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/quran/hizb_meta.dart';
import '../../../core/quran/mushaf_font_service.dart';
import '../../../core/quran/mushaf_page_data.dart';
import '../../../core/quran/mushaf_providers.dart';
import '../../../core/quran/surah_meta.dart';
import '../../../core/utils/arabic_numerals.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/khatim_pattern.dart';

/// One page of the printed Mus'haf, reproduced.
///
/// Every line is a Row with its words spaced apart to fill the width, which is
/// what makes the lines flush on both edges the way the printed page is. The
/// alternative — one Text per line with TextAlign.justify — does nothing here,
/// because Flutter only justifies lines that wrap, and each of these is a
/// single unwrapped line by construction.
///
/// The font size is chosen for the page as a whole rather than per line, so
/// the fifteen lines share a baseline grid as they do on paper.
class MushafPageView extends ConsumerWidget {
  final int page;

  /// Called with the surah and ayah of the word that was tapped.
  ///
  /// The page has no idea what the app wants to do about it — play from
  /// there, save a marker, open the tafsir — so it reports the verse and
  /// leaves the decision to the reader.
  final void Function(int surah, int ayah)? onAyahTap;

  /// The verse to mark as selected, as "surah:ayah".
  ///
  /// Without it a tap opens a sheet over a page that looks untouched, and
  /// there is nothing to say which verse the sheet is about — on a page of
  /// fifteen unbroken lines that is genuinely hard to work out.
  final String? selectedVerse;

  const MushafPageView({
    super.key,
    required this.page,
    this.onAyahTap,
    this.selectedVerse,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(mushafPageProvider(page));
    final font = ref.watch(mushafFontProvider(page));

    // Both the glyph layout and the page's own font are required; either one
    // alone renders as empty boxes, so they are awaited together.
    if (data.isLoading || font.isLoading) {
      return const _PageMessage(child: CircularProgressIndicator());
    }
    if (data.hasError || font.hasError) {
      return _PageMessage(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            'quran_screen.mushaf_load_error'.tr(),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
          ),
        ),
      );
    }

    final rows = data.requireValue.rows;
    final lines = [
      for (final r in rows)
        if (r.words != null) r.words!,
    ];
    final family = MushafFontService.familyFor(page);

    return LayoutBuilder(
      builder: (context, constraints) {
        // The frame and its padding come off the width the lines have to
        // fit into: 7 outer + 1.6 rule + 3 + 1 rule + 10 inner, doubled.
        final width = constraints.maxWidth - 46;
        final widths = _lineWidths(lines, family);

        // Everything the frame takes off the height before a line can
        // use it: 7 outer padding + 1.6 rule + 3 + 1 rule + 6/4 inner,
        // doubled where it applies, plus the header, the page number and
        // the two rules between them.
        final chrome = 25.2 + _headerHeight + _footerHeight + 18;
        // Counted in printed line *slots*, not in lines of verse. A page
        // that opens a surah spends two of its fifteen slots on the
        // heading and the basmala and carries only thirteen lines — and
        // judging it by those thirteen called it a short page, centred it
        // at its natural spacing, and left the text bunched in the middle
        // with white above and below. Next to a neighbouring full page
        // spread over the whole height, that is the page that looks
        // squashed.
        final full = rows.length >= kLinesPerPage;
        final size = mushafFontSize(
          lineWidthsAtBase: widths,
          base: _baseSize,
          available: width,
          availableHeight: constraints.maxHeight - chrome,
          heightUnits: _heightUnits(rows, spaced: !full),
          heightConstant: _heightConstant(rows),
        );

        // The measured width of each row, in row order — 0 for a heading
        // or a basmala, which are not measured. Looking a row's width up
        // by searching for the row instead compares list identity, and a
        // second call to the rows getter builds new lists that don't
        // match: every lookup came back -1 and the page threw.
        final rowWidths = <double>[];
        var measured = 0;
        for (final row in rows) {
          rowWidths.add(row.words != null ? widths[measured++] : 0);
        }

        final arabic = context.locale.languageCode == "ar";
        final verseKeys = data.requireValue.verseKeys;
        // The surah the page opens in, which is what a printed page names
        // in its header even when the page ends inside the next one.
        final openingSurah = verseKeys.isEmpty
            ? null
            : surahByNumber(int.parse(verseKeys.first.split(":").first));

        return MushafPageFrame(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _PageHeader(
                  surah: openingSurah,
                  juz: data.requireValue.juz,
                  hizb: data.requireValue.hizbQuarter,
                  hasSajda: data.requireValue.hasSajda,
                  arabic: arabic,
                ),
                Divider(
                  height: 9,
                  color: AppColors.gold.withValues(alpha: 0.4),
                ),
                Expanded(
                  child: Column(
                    // Spread to fill only on a full page. The same rule
                    // as the horizontal one: pages 1 and 2 sit in a
                    // narrow frame and carry a handful of lines, and
                    // spacing those evenly down a phone screen left
                    // gaps between them you could park a line in. A
                    // short page is centred at its natural spacing, the
                    // way it is printed.
                    mainAxisAlignment: full
                        ? MainAxisAlignment.spaceEvenly
                        : MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < rows.length; i++)
                        if (rows[i].surahHeading != null)
                          _SurahHeading(
                            surah: surahByNumber(rows[i].surahHeading!),
                            arabic: arabic,
                            size: size,
                          )
                        else if (rows[i].isBasmala)
                          _BasmalaLine(size: size)
                        else if (rows[i].isBlank)
                          // A line the page prints nothing on, kept at
                          // its full height so the grid holds.
                          SizedBox(height: size)
                        else
                          _MushafLine(
                            words: rows[i].words!,
                            family: family,
                            size: size,
                            // Only a short page needs its own spacing;
                            // a full one gets it from spaceEvenly.
                            gap: full ? 0 : size * 0.55,
                            // Only a line that genuinely fills the page
                            // gets stretched to it. The first two pages
                            // are set in a narrow decorative frame and
                            // their lines are short by design, as is
                            // the closing line of any surah — pushing
                            // those out to the full width scattered a
                            // handful of words across the page.
                            justify:
                                rowWidths[i] * size / _baseSize >= width * 0.80,
                            onAyahTap: onAyahTap,
                            selectedVerse: selectedVerse,
                          ),
                    ],
                  ),
                ),
                Divider(
                  height: 9,
                  color: AppColors.gold.withValues(alpha: 0.4),
                ),
                // The page number, where a printed Mus'haf puts it. It
                // is also the only thing on screen that says where in
                // the book you are — the pages carry no other marker.
                _PageLabel(arabic ? toArabicDigits("$page") : "$page"),
              ],
            ),
          ),
        );
      },
    );
  }

  /// The natural width of each line at [_baseSize].
  ///
  /// Each word is measured on its own and the widths added up, because that
  /// is exactly how the line is drawn: a Row of separate Text children.
  /// Measuring the line as one joined string instead is a different shaping
  /// run and comes out a different width — enough that lines overflowed
  /// their Row and Flutter drew the striped overflow marker across the page.
  List<double> _lineWidths(List<List<MushafWord>> lines, String family) {
    final widths = <double>[];
    for (final line in lines) {
      var lineWidth = 0.0;
      for (final word in line) {
        final painter = TextPainter(
          text: TextSpan(
            text: word.glyph,
            style: TextStyle(fontFamily: family, fontSize: _baseSize),
          ),
          textDirection: material.TextDirection.rtl,
          // Explicit, and matching the Text widgets below. TextPainter
          // does not apply the system font scale and a Text does, so
          // leaving it implicit measured one size and drew another.
          textScaler: TextScaler.noScaling,
        )..layout();
        lineWidth += painter.width;
        painter.dispose();
      }
      widths.add(lineWidth);
    }
    return widths;
  }
}


/// How tall each kind of row is, as a multiple of the page's font size.
///
/// A line of verse is drawn at `height: 1.0`, so it is exactly one unit.
/// The heading and the basmala are set from these same numbers in
/// [_SurahHeading] and [_BasmalaLine] — change one and change the other,
/// or the page will be sized against rows it is not actually drawing.
const _lineUnits = 1.0;

/// The extra a short page's lines take from their own vertical padding.
const _shortPageGapUnits = 0.55;

/// 0.18 padding each side + 0.72 text at 1.4 line height.
const _headingUnits = 1.4;

/// The heading's fixed padding, which does not scale with the font.
const _headingConstant = 10.0;

/// 0.1 padding each side + 0.85 text at 1.5 line height.
const _basmalaUnits = 1.5;

/// The header and the page number, both set at a fixed size.
const _headerHeight = 27.0;
const _footerHeight = 19.0;

/// The page height these rows need, per unit of font size.
double _heightUnits(List<MushafRow> rows, {required bool spaced}) {
  var units = 0.0;
  for (final row in rows) {
    if (row.surahHeading != null) {
      units += _headingUnits;
    } else if (row.isBasmala) {
      units += _basmalaUnits;
    } else if (row.isBlank) {
      units += _lineUnits;
    } else {
      units += _lineUnits + (spaced ? _shortPageGapUnits : 0);
    }
  }
  return units;
}

/// The part of those rows that does not scale with the font size.
double _heightConstant(List<MushafRow> rows) {
  var fixed = 0.0;
  for (final row in rows) {
    if (row.surahHeading != null) fixed += _headingConstant;
  }
  return fixed;
}

/// The size lines are measured at before being scaled to the page.
const _baseSize = 40.0;

/// The font size at which the page fits the space it has, both ways.
///
/// Split out from the measuring so the arithmetic can be tested without a
/// font: the widths going in are whatever the engine measured, and what
/// matters is that the size coming out cannot let any of them exceed
/// [available].
///
/// Width alone is not enough. On a wide screen the width constraint is
/// slack and the size runs up to the 34pt cap, and fifteen lines at 34pt
/// are taller than a phone page — the lines then sit with no leading
/// between them, which is what "the page looks squashed" is. Giving the
/// height a say puts the air back, and the page is set by whichever of
/// the two dimensions is actually the tighter.
double mushafFontSize({
  required List<double> lineWidthsAtBase,
  required double base,
  required double available,
  double? availableHeight,
  double heightUnits = 0,
  double heightConstant = 0,
  double safety = 0.99,

  /// Leaves the page a margin of its own height rather than filling it to
  /// the last pixel, so there is always some leading between the lines.
  double heightSafety = 0.94,
}) {
  var scale = 1.0;
  for (final lineWidth in lineWidthsAtBase) {
    if (lineWidth <= 0) continue;
    final fit = available * safety / lineWidth;
    scale = scale < fit ? scale : fit;
  }

  if (availableHeight != null && availableHeight > 0 && heightUnits > 0) {
    final forHeight =
        (availableHeight * heightSafety - heightConstant) / heightUnits;
    final fit = forHeight / base;
    scale = scale < fit ? scale : fit;
  }
  // The floor is deliberately far below anything readable. Its job is to
  // stop a degenerate measurement producing a zero, not to guarantee a
  // minimum size — a floor that bound would put the overflow straight back.
  return (base * scale).clamp(6.0, 34.0);
}

class _MushafLine extends StatelessWidget {
  final List<MushafWord> words;
  final String family;
  final double size;
  final bool justify;
  final double gap;
  final void Function(int surah, int ayah)? onAyahTap;
  final String? selectedVerse;

  const _MushafLine({
    required this.words,
    required this.family,
    required this.size,
    required this.justify,
    this.gap = 0,
    this.onAyahTap,
    this.selectedVerse,
  });

  bool _isSelected(MushafWord w) => selectedVerse == '${w.surah}:${w.ayah}';

  /// The printed Mus'haf sets لفظ الجلالة in red, and that stays
  /// true inside a selected verse — the selection is a reading aid, the red
  /// is part of the text.
  Color _colorFor(MushafWord w) {
    if (w.isJalalah && !w.isEnd) return AppColors.jalalah;
    if (_isSelected(w)) return AppColors.primary;
    return AppColors.mushafInk;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: gap / 2),
      child: Directionality(
        textDirection: material.TextDirection.rtl,
        child: Row(
          mainAxisAlignment: justify
              ? MainAxisAlignment.spaceBetween
              : MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            for (final w in words)
              GestureDetector(
                // Every word is a tap target for its own verse, so the whole
                // ayah is touchable rather than only its closing rosette.
                behavior: HitTestBehavior.opaque,
                onTap: onAyahTap == null
                    ? null
                    : () => onAyahTap!(w.surah, w.ayah),
                child: Padding(
                  // A centred line has no distributed gaps of its own, so
                  // this keeps its words apart and gives each tap some room.
                  padding: EdgeInsets.symmetric(
                    horizontal: justify ? 0 : size * 0.06,
                  ),
                  child: Text(
                    w.glyph,
                    // A printed page is a fixed grid of fifteen lines whose
                    // glyphs are pre-shaped to fill it. Letting the device
                    // font-size setting resize them does not make the page
                    // more readable, it makes the lines overrun the page —
                    // which is exactly what it did. Readers who want larger
                    // text have the app's own layout, which honours it.
                    textScaler: TextScaler.noScaling,
                    style: TextStyle(
                      fontFamily: family,
                      fontSize: size,
                      height: 1.0,
                      // The selected verse takes the app green, which is the
                      // one colour on the page that is neither the ink nor
                      // the red of لفظ الجلالة, so it cannot be mistaken for
                      // either. A tinted background instead would break into
                      // separate blocks: a justified line spreads its words
                      // apart, so the fill would come out as chips rather
                      // than a continuous highlight.
                      color: _colorFor(w),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The banner a printed Mus'haf sets at the head of every surah.
///
/// It is what separates one surah from the next on the page, so it is
/// drawn as a band rather than a line of text: without it a surah ends
/// and the next begins mid-page with nothing between them.
class _SurahHeading extends StatelessWidget {
  final Surah surah;
  final bool arabic;
  final double size;

  const _SurahHeading({
    required this.surah,
    required this.arabic,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: size * 0.18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.goldTint,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.gold, width: 1.2),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            KhatimGlyph(
              size: size * 0.5,
              color: AppColors.gold,
              strokeWidth: 1.4,
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                'quran_screen.surah_named'.tr(
                  namedArgs: {'name': surahDisplayName(surah, arabic)},
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textScaler: TextScaler.noScaling,
                style: AppTextStyles.mushaf(
                  fontSize: size * 0.72,
                  height: 1.4,
                ).copyWith(color: AppColors.gold),
              ),
            ),
            const SizedBox(width: 10),
            KhatimGlyph(
              size: size * 0.5,
              color: AppColors.gold,
              strokeWidth: 1.4,
            ),
          ],
        ),
      ),
    );
  }
}

/// The basmala line that follows most surah headings.
///
/// Drawn from ordinary Uthmani text, not the page's glyph font: it is not
/// in the page data at all — it occupies one of the blank line numbers —
/// so there is no glyph for it to be drawn with.
class _BasmalaLine extends StatelessWidget {
  final double size;

  const _BasmalaLine({required this.size});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: size * 0.1),
      child: Text(
        'quran_screen.basmala'.tr(),
        textAlign: TextAlign.center,
        maxLines: 1,
        textScaler: TextScaler.noScaling,
        style: AppTextStyles.mushaf(
          fontSize: size * 0.85,
          height: 1.5,
        ).copyWith(color: AppColors.mushafInk),
      ),
    );
  }
}

/// What a printed page prints across the top: the surah on one side, the
/// juz and hizb on the other, and whether that surah is Makki or Madani —
/// the same things the paper page carries, in the same places.
class _PageHeader extends StatelessWidget {
  final Surah? surah;
  final int juz;

  /// The quarter-hizb the page opens in. A printed Mus'haf marks the أرباع
  /// in its margin; naming it here is the same information in the space a
  /// phone actually has.
  final HizbQuarter? hizb;

  /// Whether a سجدة falls on this page. Worth its own mark rather than a
  /// line of text: a reciter needs to see it coming at a glance.
  final bool hasSajda;

  final bool arabic;

  const _PageHeader({
    required this.surah,
    required this.juz,
    required this.hizb,
    required this.hasSajda,
    required this.arabic,
  });

  /// "الحزب ٦" or "ربع الحزب ٦" — the quarter named the way a Mus'haf names
  /// it, rather than as a bare fraction.
  String _hizbLabel(HizbQuarter q) {
    final n = arabic ? toArabicDigits('${q.hizb}') : '${q.hizb}';
    const keys = [
      'quran_screen.hizb_n',
      'quran_screen.hizb_quarter',
      'quran_screen.hizb_half',
      'quran_screen.hizb_three_quarters',
    ];
    return keys[q.quarter].tr(namedArgs: {'n': n});
  }

  @override
  Widget build(BuildContext context) {
    final name = surah == null ? null : surahDisplayName(surah!, arabic);
    final place = surah == null
        ? null
        : (surah!.meccan ? 'quran_screen.meccan' : 'quran_screen.medinan').tr();
    final q = hizb;
    final right = [
      if (juz > 0)
        'quran_screen.juz_n'.tr(
          namedArgs: {'n': arabic ? toArabicDigits('$juz') : '$juz'},
        ),
      if (q != null) _hizbLabel(q),
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      // Pinned RTL so the surah sits on the right and the juz on the left
      // in either language. That is where a Mus'haf prints them; it is a
      // property of the page, not of the interface language.
      child: Directionality(
        textDirection: material.TextDirection.rtl,
        child: Row(
          children: [
            Expanded(
              child: _PageLabel(
                name == null ? "" : "$name · $place",
                align: TextAlign.right,
              ),
            ),
            if (hasSajda) const _SajdaMark(),
            Expanded(child: _PageLabel(right, align: TextAlign.left)),
          ],
        ),
      ),
    );
  }
}

/// The سجدة mark, ۩, as the printed Mus'haf sets it in the margin.
///
/// Given a tooltip rather than a caption because the glyph is the thing
/// readers already recognise; spelling it out would cost header width that
/// the surah name needs.
class _SajdaMark extends StatelessWidget {
  const _SajdaMark();

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'quran_screen.sajda'.tr(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text(
          '۩',
          textScaler: TextScaler.noScaling,
          style: TextStyle(fontSize: 13, height: 1.4, color: AppColors.gold),
        ),
      ),
    );
  }
}

/// The small centred line a printed page carries above and below its text:
/// the surah at the top, the page number at the bottom.
class _PageLabel extends StatelessWidget {
  final String text;
  final TextAlign align;

  const _PageLabel(this.text, {this.align = TextAlign.center});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(
        text,
        textAlign: align,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textScaler: TextScaler.noScaling,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.gold,
          height: 1.4,
        ),
      ),
    );
  }
}

class _PageMessage extends StatelessWidget {
  final Widget child;

  const _PageMessage({required this.child});

  @override
  Widget build(BuildContext context) {
    // Inside the page frame, not on a bare rectangle. Turning onto a page
    // that has not been fetched yet, an empty ground reads as the book
    // having ended; the ruled frame reads as a page still arriving.
    return MushafPageFrame(child: Center(child: child));
  }
}

/// The ruled border a printed Mus'haf page carries.
///
/// A heavier outer rule with a hairline inside it — two rather than one,
/// because a single line reads as a UI card border while the pair reads
/// as a page.
///
/// Public because the reader draws it empty while the first page is on
/// its way. Two copies of these measurements would drift, and the drift
/// would show as the frame changing size the moment the page arrived.
class MushafPageFrame extends StatelessWidget {
  final Widget child;

  const MushafPageFrame({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.mushafPage,
      padding: const EdgeInsets.all(7),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.gold, width: 1.6),
        ),
        padding: const EdgeInsets.all(3),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.gold.withValues(alpha: 0.5)),
          ),
          child: child,
        ),
      ),
    );
  }
}
