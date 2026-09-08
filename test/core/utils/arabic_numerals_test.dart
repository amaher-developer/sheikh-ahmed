import 'package:flutter_test/flutter_test.dart';
import 'package:sheikh_ahmed_app/core/utils/arabic_numerals.dart';

void main() {
  group('normalizeArabicDigits', () {
    test('converts Arabic-Indic digits to ASCII', () {
      expect(normalizeArabicDigits('١٢٣٤٥٦٧٨٩٠'), '1234567890');
    });

    test('converts Extended Arabic-Indic (Persian) digits to ASCII', () {
      expect(normalizeArabicDigits('۱۲۳۴۵۶۷۸۹۰'), '1234567890');
    });

    test('converts the Arabic decimal separator to a dot', () {
      expect(normalizeArabicDigits('١٢٫٥'), '12.5');
    });

    test('leaves ASCII input untouched', () {
      expect(normalizeArabicDigits('12.5'), '12.5');
    });
  });

  group('parseLocalizedNumber', () {
    // The app defaults to Arabic, so these are what a real user's keypad
    // actually produces — plain double.tryParse returns null for all of them.
    test('parses Arabic-Indic digits', () {
      expect(parseLocalizedNumber('١٢٣'), 123);
    });

    test('parses Arabic decimals', () {
      expect(parseLocalizedNumber('١٢٫٥'), 12.5);
    });

    test('parses ASCII decimals', () {
      expect(parseLocalizedNumber('12.5'), 12.5);
    });

    test('trims surrounding whitespace', () {
      expect(parseLocalizedNumber('  ٥٠  '), 50);
    });

    test('returns 0 for empty or non-numeric input', () {
      expect(parseLocalizedNumber(''), 0);
      expect(parseLocalizedNumber('abc'), 0);
    });
  });

  group('zakat maths on Arabic input', () {
    // End-to-end check of the numbers the calculator actually computes:
    // 85g nisab, 2.5% rate. Cash ١٠٠٠٠ + (١٠g gold x ٤٠٠٠) - ٢٠٠٠ debts.
    test('computes zakat correctly from Arabic-Indic entries', () {
      final cash = parseLocalizedNumber('١٠٠٠٠');
      final goldGrams = parseLocalizedNumber('١٠');
      final goldPrice = parseLocalizedNumber('٤٠٠٠');
      final debts = parseLocalizedNumber('٢٠٠٠');

      final totalWealth = cash + goldGrams * goldPrice - debts;
      final nisabValue = 85.0 * goldPrice;

      expect(totalWealth, 48000);
      expect(nisabValue, 340000);
      // Below nisab, so nothing is due.
      expect(totalWealth >= nisabValue, isFalse);
    });

    test('zakat due is 2.5% once above nisab', () {
      final goldPrice = parseLocalizedNumber('١٠٠');
      final cash = parseLocalizedNumber('٢٠٠٠٠');
      final nisabValue = 85.0 * goldPrice; // 8500
      expect(cash >= nisabValue, isTrue);
      expect(cash * 0.025, 500);
    });
  });
}
