import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sheikh_ahmed_app/features/quran/presentation/mushaf_page_view.dart';

/// The printed page is measured with a TextPainter and drawn with Text
/// widgets. Those two disagree about the device's font-size setting unless
/// told otherwise: a TextPainter does not apply it, a Text does. That gap is
/// what kept the lines overrunning the page even after the measurement itself
/// was made exact — and it only shows on a device whose owner has turned the
/// system font size up, which is why it survived a correct-looking fix.
void main() {
  const available = 356.0;
  const base = 40.0;
  const words = ['بِسْمِ', 'ٱللَّهِ', 'ٱلرَّحْمَٰنِ', 'ٱلرَّحِيمِ', 'وَٱلْحَمْدُ', 'لِلَّهِ'];

  double measureLine() {
    var total = 0.0;
    for (final w in words) {
      final painter = TextPainter(
        text: TextSpan(text: w, style: const TextStyle(fontSize: base)),
        textDirection: TextDirection.rtl,
        textScaler: TextScaler.noScaling,
      )..layout();
      total += painter.width;
      painter.dispose();
    }
    return total;
  }

  Widget page(double size, {required bool pinScale}) {
    return MediaQuery(
      // What a phone with "large" text set in Android's display settings
      // hands the app.
      data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Center(
          child: SizedBox(
            width: available,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final w in words)
                  Text(
                    w,
                    textScaler: pinScale ? TextScaler.noScaling : null,
                    style: TextStyle(fontSize: size, height: 1.0),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('the page holds its size when the system font size is raised', (
    tester,
  ) async {
    final size = mushafFontSize(
      lineWidthsAtBase: [measureLine()],
      base: base,
      available: available,
    );

    await tester.pumpWidget(page(size, pinScale: true));
    expect(tester.takeException(), isNull);
  });

  testWidgets('without that, the same page overflows', (tester) async {
    // Proves the assertion above is testing something: identical layout,
    // identical measurement, the one difference being whether the drawing
    // opts out of the system scale.
    final size = mushafFontSize(
      lineWidthsAtBase: [measureLine()],
      base: base,
      available: available,
    );

    await tester.pumpWidget(page(size, pinScale: false));
    expect(tester.takeException(), isNotNull);
  });

  test('both the measuring and the drawing opt out of scaling', () {
    // They have to agree, and agreeing on "no scaling" is what keeps the
    // fifteen-line grid the size the page was typeset at.
    final source = File(
      'lib/features/quran/presentation/mushaf_page_view.dart',
    ).readAsStringSync();
    expect(
      RegExp('TextScaler.noScaling').allMatches(source).length,
      greaterThanOrEqualTo(2),
      reason: 'the TextPainter and the Text must both pin it',
    );
  });
}
