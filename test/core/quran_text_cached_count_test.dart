import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sheikh_ahmed_app/core/quran/quran_text_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<QuranTextService> serviceWith(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    return QuranTextService(await SharedPreferences.getInstance());
  }

  test('counts stored surahs, ignoring the translation copies', () {
    // Each surah can be stored twice — once Arabic-only, once with the
    // translation. Counting both would report far more than 114 and the card
    // would claim "downloaded" while the reader still had gaps offline.
    return serviceWith({
      'quran.text.v3.1.ar': '[]',
      'quran.text.v3.2.ar': '[]',
      'quran.text.v3.1.tr': '[]',
      'quran.text.v3.2.tr': '[]',
    }).then((s) => expect(s.cachedSurahCount(), 2));
  });

  test('entries from an older cache generation do not count', () {
    // v2 was the previous generation, orphaned by the edition change. A bump: they will be
    // refetched, so counting them would mark the download complete when the
    // app is about to fetch all 114 again.
    return serviceWith({
      'quran.text.v2.1.ar': '[]',
      'quran.text.v3.1.ar': '[]',
    }).then((s) => expect(s.cachedSurahCount(), 1));
  });

  test('unrelated preferences are not counted', () {
    return serviceWith({
      'quran.tafsir.1': '{}',
      'flutter.someOtherSetting': 'x',
    }).then((s) => expect(s.cachedSurahCount(), 0));
  });
}
