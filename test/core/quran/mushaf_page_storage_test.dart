import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sheikh_ahmed_app/core/quran/mushaf_page_service.dart';

/// Points the service at a real temporary directory, so the file store can
/// be exercised for what it is rather than mocked away.
class _TempPathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _TempPathProvider(this.root);
  final String root;

  @override
  Future<String?> getApplicationDocumentsPath() async => root;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory temp;
  late SharedPreferences prefs;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('mushaf_pages_test');
    PathProviderPlatform.instance = _TempPathProvider(temp.path);
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  tearDown(() async {
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  /// Writes a page to the store the way a completed download leaves it.
  Future<void> storePage(int page) async {
    final dir = Directory('${temp.path}/mushaf_pages_v4');
    await dir.create(recursive: true);
    final data = MushafPageService.parseResponse(
      page,
      jsonDecode(
        '{"verses":[{"verse_key":"90:1","juz_number":30,"words":['
        '{"code_v1":"g1","line_number":1,"text_uthmani":"لَآ",'
        '"char_type_name":"word"}]}]}',
      ),
    );
    await File(
      '${dir.path}/p${page.toString().padLeft(3, '0')}.json',
    ).writeAsString(jsonEncode(data.toJson()));
  }

  test('a stored page is read back with no network', () async {
    // The whole point of the download: with the connection off, fetchPage
    // must return the page rather than throwing. Nothing here can reach the
    // network — a request would fail, so if this passes it came off disk.
    await storePage(594);

    final page = await MushafPageService(prefs).fetchPage(594);

    expect(page.page, 594);
    expect(page.juz, 30);
    expect(page.words, hasLength(1));
    expect(page.words.first.line, 1);
  });

  test('a page that was never stored is not silently empty', () async {
    // It has to fail rather than return a blank page, or an incomplete
    // download would show as a Mus'haf with pages missing their text.
    await expectLater(
      MushafPageService(prefs).fetchPage(1),
      throwsA(isA<MushafPageException>()),
    );
  });

  test('cachedPages reports what is actually on disk', () async {
    final service = MushafPageService(prefs);
    expect(await service.cachedPages(), isEmpty);

    await storePage(1);
    await storePage(42);
    await storePage(604);

    expect(await service.cachedPages(), {1, 42, 604});
    expect(await service.cachedPageCount(), 3);
  });

  test('a half-written page is not counted as stored', () async {
    // The .part file an interrupted download leaves behind. Counting it
    // would report the Mus'haf complete while one page could not be opened.
    final dir = Directory('${temp.path}/mushaf_pages_v4');
    await dir.create(recursive: true);
    await File('${dir.path}/p007.json.part').writeAsString('{"p":7,');

    expect(await MushafPageService(prefs).cachedPages(), isEmpty);
  });

  test('a corrupt stored page is dropped rather than thrown at the reader',
      () async {
    final dir = Directory('${temp.path}/mushaf_pages_v4');
    await dir.create(recursive: true);
    final file = File('${dir.path}/p007.json');
    await file.writeAsString('not json');

    // It cannot refetch here either, so it still fails — but as a page that
    // needs downloading, and the bad file is gone so it is not read again.
    await expectLater(
      MushafPageService(prefs).fetchPage(7),
      throwsA(isA<MushafPageException>()),
    );
    expect(await file.exists(), isFalse);
  });

  test('the preference entries the old storage left are removed', () async {
    SharedPreferences.setMockInitialValues({
      'mushaf.page.v3.1': '{"p":1}',
      'mushaf.page.v3.2': '{"p":2}',
      'mushaf.page.v2.9': '{"p":9}',
      'quran.bookmarks': <String>[],
    });
    final withLegacy = await SharedPreferences.getInstance();
    expect(withLegacy.getKeys().where((k) => k.startsWith('mushaf.page.')),
        hasLength(3));

    await MushafPageService(withLegacy).purgeLegacyStorage();

    expect(
      withLegacy.getKeys().where((k) => k.startsWith('mushaf.page.')),
      isEmpty,
    );
    // And it leaves everything else alone.
    expect(withLegacy.getKeys(), contains('quran.bookmarks'));
  });
}
