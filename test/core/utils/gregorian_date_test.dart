import 'package:flutter_test/flutter_test.dart';
import 'package:sheikh_ahmed_app/core/utils/arabic_numerals.dart';

void main() {
  test('formats an Arabic Gregorian date with Arabic digits and month name', () {
    final label = formatGregorianDate(DateTime(2026, 8, 25), arabic: true);
    expect(label, '٢٥ أغسطس ٢٠٢٦');
  });

  test('formats an English Gregorian date', () {
    final label = formatGregorianDate(DateTime(2026, 8, 25), arabic: false);
    expect(label, '25 August 2026');
  });

  test('handles every month index without going out of range', () {
    for (var m = 1; m <= 12; m++) {
      expect(
        () => formatGregorianDate(DateTime(2026, m, 1), arabic: true),
        returnsNormally,
      );
    }
  });
}
