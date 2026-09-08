import 'package:flutter_test/flutter_test.dart';
import 'package:sheikh_ahmed_app/core/azkar/azkar_data.dart';

void main() {
  AzkarItem itemById(String id) => kAzkarCategories
      .expand((c) => c.items)
      .firstWhere((i) => i.id == id);

  test('a single-ayah reference names the surah and the ayah', () {
    // Ayat al-Kursi is al-Baqara 255. The instruction alone ("read Ayat
    // al-Kursi") tells someone who does not already know it nothing about
    // where to find it.
    expect(quranRefLabel(itemById('m1'), arabic: true), 'البقرة ٢٥٥');
    expect(quranRefLabel(itemById('m1'), arabic: false), 'Al-Baqara 255');
  });

  test('a multi-ayah reference is shown as a range', () {
    expect(quranRefLabel(itemById('m2a'), arabic: false), 'Al-Ikhlaas 1-4');
    expect(quranRefLabel(itemById('m2b'), arabic: true), 'الفلق ١-٥');
  });

  test('digits follow the language, not the device', () {
    // Arabic-Indic in Arabic, Western in English — the same rule the Quran
    // reader already applies to ayah numbers.
    final arabic = quranRefLabel(itemById('m2c'), arabic: true);
    expect(arabic.contains('٦'), isTrue);
    expect(RegExp(r'[0-9]').hasMatch(arabic), isFalse);
  });

  test('an ordinary dhikr carries no citation', () {
    // Most azkar are their own text; a reference line under them would be
    // noise, so the label has to come back empty rather than blank-ish.
    final plain = kAzkarCategories
        .expand((c) => c.items)
        .firstWhere((i) => i.quranRefs.isEmpty);
    expect(quranRefLabel(plain, arabic: true), isEmpty);
  });
}
