/// Converts ASCII digits to Eastern Arabic-Indic digits (٠-٩).
/// Used for locale-aware display of computed values (times, counters)
/// that are formatted from plain Dart numbers rather than through
/// easy_localization's own formatting.
String toArabicDigits(String input) {
  const western = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
  const eastern = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
  var result = input;
  for (var i = 0; i < western.length; i++) {
    result = result.replaceAll(western[i], eastern[i]);
  }
  return result;
}

/// Converts Arabic-Indic (٠-٩) and Extended Arabic-Indic (۰-۹) digits to
/// ASCII, and the Arabic decimal separator (٫) to a dot, so the result can
/// be fed to [double.tryParse]. The app runs in Arabic by default, so a
/// user typing on an Arabic keypad produces digits that `\d` and
/// `double.tryParse` both reject — every numeric input has to come through
/// here first.
String normalizeArabicDigits(String input) {
  final buffer = StringBuffer();
  for (final rune in input.runes) {
    if (rune >= 0x0660 && rune <= 0x0669) {
      buffer.writeCharCode(rune - 0x0660 + 0x30); // ٠-٩
    } else if (rune >= 0x06F0 && rune <= 0x06F9) {
      buffer.writeCharCode(rune - 0x06F0 + 0x30); // ۰-۹
    } else if (rune == 0x066B) {
      buffer.write('.'); // ٫ Arabic decimal separator
    } else {
      buffer.writeCharCode(rune);
    }
  }
  return buffer.toString();
}

/// Parses user-entered numeric text that may use Arabic-Indic digits.
/// Returns 0 for empty/invalid input so calculators can treat a blank
/// field as "nothing entered" rather than erroring.
double parseLocalizedNumber(String input) =>
    double.tryParse(normalizeArabicDigits(input).trim()) ?? 0;

const _arabicGregorianMonths = [
  'يناير',
  'فبراير',
  'مارس',
  'أبريل',
  'مايو',
  'يونيو',
  'يوليو',
  'أغسطس',
  'سبتمبر',
  'أكتوبر',
  'نوفمبر',
  'ديسمبر',
];

const _englishGregorianMonths = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// Formats the Gregorian calendar date as "D Month YYYY" — Arabic month
/// names and Arabic-Indic digits when [arabic] is true.
String formatGregorianDate(DateTime date, {required bool arabic}) {
  final months = arabic ? _arabicGregorianMonths : _englishGregorianMonths;
  final day = arabic ? toArabicDigits('${date.day}') : '${date.day}';
  final year = arabic ? toArabicDigits('${date.year}') : '${date.year}';
  return '$day ${months[date.month - 1]} $year';
}

/// Formats [time] as a locale-appropriate "h:mm" clock string (12-hour,
/// no AM/PM marker — matches the app's existing prayer-time display style).
String formatClockTime(DateTime time, {required bool arabicDigits}) {
  final hour12 = time.hour % 12 == 0 ? 12 : time.hour % 12;
  final minute = time.minute.toString().padLeft(2, '0');
  final text = '$hour12:$minute';
  return arabicDigits ? toArabicDigits(text) : text;
}
