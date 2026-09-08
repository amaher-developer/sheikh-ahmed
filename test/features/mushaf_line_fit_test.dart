import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sheikh_ahmed_app/features/quran/presentation/mushaf_page_view.dart';

void main() {
  group('mushafFontSize', () {
    test('the widest line always fits the available width', () {
      // The reported overflow was 21px on a 356px row, so the widest line
      // wanted 377 at whatever size was chosen. Whatever the measurements,
      // the size that comes back must not allow that.
      const base = 40.0;
      const available = 356.0;
      final widths = [520.0, 545.0, 600.0, 533.0];

      final size = mushafFontSize(
        lineWidthsAtBase: widths,
        base: base,
        available: available,
      );

      for (final w in widths) {
        expect(
          w * size / base,
          lessThanOrEqualTo(available),
          reason: 'a line at the chosen size still exceeds the page',
        );
      }
    });

    test('it is the widest line that decides, not the last one measured', () {
      final size = mushafFontSize(
        lineWidthsAtBase: [400.0, 900.0, 410.0],
        base: 40,
        available: 356,
      );
      expect(900.0 * size / 40, lessThanOrEqualTo(356.0));
    });

    test('it never grows past the cap on a short page', () {
      // Al-Kawthar is three short lines. Without the cap the glyphs would be
      // scaled up to fill the width and the page would not look like a page.
      final size = mushafFontSize(
        lineWidthsAtBase: [90.0, 80.0, 60.0],
        base: 40,
        available: 356,
      );
      expect(size, 34.0);
    });

    test('empty or zero-width lines are skipped, not treated as a fit', () {
      final size = mushafFontSize(
        lineWidthsAtBase: [0.0, 600.0],
        base: 40,
        available: 356,
      );
      expect(600.0 * size / 40, lessThanOrEqualTo(356.0));
      expect(size, greaterThan(6.0));
    });

    test('a page with nothing measurable still returns a usable size', () {
      expect(
        mushafFontSize(lineWidthsAtBase: const [], base: 40, available: 356),
        34.0,
      );
    });
  });

  group('mushafFontSize, height', () {
    // Fifteen ordinary lines, no heading, on a page that is wide enough for
    // the width constraint to be slack — the shape that came out squashed.
    const fifteenNarrowLines = [
      120.0, 118.0, 121.0, 119.0, 120.0,
      117.0, 122.0, 118.0, 120.0, 119.0,
      121.0, 118.0, 120.0, 119.0, 120.0,
    ];

    test('height decides when the page is wider than it is tall', () {
      // Width alone would run this up to the 34pt cap, and fifteen lines at
      // 34 need 510px — more than the 420 this page has.
      final size = mushafFontSize(
        lineWidthsAtBase: fifteenNarrowLines,
        base: 40,
        available: 900,
        availableHeight: 420,
        heightUnits: 15,
      );

      expect(size, lessThan(34.0));
      expect(15 * size, lessThanOrEqualTo(420.0));
    });

    test('it leaves the lines some leading rather than filling to the edge', () {
      // A page set to exactly its own height has no space between its lines,
      // which is what "compressed" looks like.
      final size = mushafFontSize(
        lineWidthsAtBase: fifteenNarrowLines,
        base: 40,
        available: 900,
        availableHeight: 420,
        heightUnits: 15,
      );
      expect(15 * size, lessThan(420.0 * 0.96));
    });

    test('width still decides when width is the tighter of the two', () {
      final size = mushafFontSize(
        lineWidthsAtBase: [900.0],
        base: 40,
        available: 356,
        availableHeight: 4000,
        heightUnits: 15,
      );
      expect(900.0 * size / 40, lessThanOrEqualTo(356.0));
    });

    test('a heading and a basmala are counted against the height too', () {
      // Two extra rows on a page that already has fifteen lines. Sizing as
      // if they were not there is how a page overflows its frame.
      final withHeading = mushafFontSize(
        lineWidthsAtBase: fifteenNarrowLines,
        base: 40,
        available: 900,
        availableHeight: 420,
        heightUnits: 15 + 1.4 + 1.5,
        heightConstant: 10,
      );
      final without = mushafFontSize(
        lineWidthsAtBase: fifteenNarrowLines,
        base: 40,
        available: 900,
        availableHeight: 420,
        heightUnits: 15,
      );
      expect(withHeading, lessThan(without));
      expect(withHeading * (15 + 1.4 + 1.5) + 10, lessThanOrEqualTo(420.0));
    });

    test('omitting the height leaves the old width-only behaviour', () {
      // Every existing caller and test passes no height; they must be
      // unaffected rather than silently resized.
      expect(
        mushafFontSize(
          lineWidthsAtBase: fifteenNarrowLines,
          base: 40,
          available: 900,
        ),
        34.0,
      );
    });

    test('a height of nothing at all does not collapse the page', () {
      // A LayoutBuilder can report zero — or less, once the chrome is
      // subtracted — for one frame during a transition. Sizing off that
      // would blank the page.
      for (final h in [0.0, -30.0, double.nan]) {
        final size = mushafFontSize(
          lineWidthsAtBase: fifteenNarrowLines,
          base: 40,
          available: 900,
          availableHeight: h,
          heightUnits: 15,
        );
        expect(size, 34.0, reason: 'height $h');
      }
    });
  });
  testWidgets('a justified line laid out at that size does not overflow', (
    tester,
  ) async {
    // Measure-then-render, with the same style on both sides — which is the
    // property that broke: the old code measured the line as one joined
    // string and drew it as separate words, and the two shape differently.
    const available = 356.0;
    const base = 40.0;
    const words = ['بِسْمِ', 'ٱللَّهِ', 'ٱلرَّحْمَٰنِ', 'ٱلرَّحِيمِ', 'وَٱلْحَمْدُ'];
    const style = TextStyle(fontSize: base);

    var lineWidth = 0.0;
    for (final w in words) {
      final painter = TextPainter(
        text: const TextSpan(text: '', style: style).copyWithText(w),
        textDirection: TextDirection.rtl,
      )..layout();
      lineWidth += painter.width;
      painter.dispose();
    }

    final size = mushafFontSize(
      lineWidthsAtBase: [lineWidth],
      base: base,
      available: available,
    );

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.rtl,
        child: Center(
          child: SizedBox(
            width: available,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final w in words)
                  Text(w, style: TextStyle(fontSize: size, height: 1.0)),
              ],
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  test('the page is measured word by word, the way it is drawn', () {
    // The behavioural difference only shows with the real page font, which
    // is downloaded at runtime and so is not available here. What can be
    // pinned is the property that caused it: the measuring and the drawing
    // have to use the same shaping runs. Joining a line into one string to
    // measure it is a different run from drawing it as separate words, and
    // that gap is what put the striped overflow marker across the page.
    final source = File(
      'lib/features/quran/presentation/mushaf_page_view.dart',
    ).readAsStringSync();

    final measuring = source.substring(
      source.indexOf('List<double> _lineWidths('),
      source.indexOf('double mushafFontSize('),
    );
    expect(measuring.contains(".join(' ')"), isFalse);
    expect(measuring.contains('text: word.glyph'), isTrue);
  });
}



extension on TextSpan {
  TextSpan copyWithText(String text) => TextSpan(text: text, style: style);
}
