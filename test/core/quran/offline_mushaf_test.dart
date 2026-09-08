import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sheikh_ahmed_app/core/quran/bulk_download_providers.dart';
import 'package:sheikh_ahmed_app/core/quran/mushaf_page_service.dart';

void main() {
  group('offline readiness', () {
    test('the text alone is not a downloaded Mus\'haf', () {
      // The bug. The card counted only the 114 surahs of app text, showed a
      // tick, and then with the connection off the reader had no page layout
      // and no page font to draw from — so it fell back to the plain text
      // layout. From the outside that is "it downloaded, then showed me the
      // old Quran".
      const textOnly = TextDownloadState(cachedSurahs: 114, cachedPages: 0);
      expect(textOnly.isComplete, isFalse);
    });

    test('the pages alone are not one either', () {
      // The reader loads a surah before it can show any of its pages, so a
      // device with every page and no text gets the retry screen.
      const pagesOnly = TextDownloadState(
        cachedSurahs: 0,
        cachedPages: MushafPageService.totalPages,
      );
      expect(pagesOnly.isComplete, isFalse);
    });

    test('both halves together are', () {
      const both = TextDownloadState(
        cachedSurahs: 114,
        cachedPages: MushafPageService.totalPages,
      );
      expect(both.isComplete, isTrue);
    });

    test('a part-finished run is not complete', () {
      const partial = TextDownloadState(cachedSurahs: 114, cachedPages: 603);
      expect(partial.isComplete, isFalse);
    });

    test('overall progress counts the pages at their real weight', () {
      // 604 pages against 114 surahs. Treating the two stages as halves
      // would show the bar at 50% after the small, fast half.
      const afterText = TextDownloadState(cachedSurahs: 114, cachedPages: 0);
      expect(afterText.overallProgress, lessThan(0.2));

      const done = TextDownloadState(
        cachedSurahs: 114,
        cachedPages: MushafPageService.totalPages,
      );
      expect(done.overallProgress, 1.0);

      expect(const TextDownloadState().overallProgress, 0.0);
    });

    test('stage progress is per stage, and safe before one starts', () {
      expect(const TextDownloadState().progress, 0.0);
      expect(
        const TextDownloadState(completed: 302, total: 604).progress,
        closeTo(0.5, 0.001),
      );
      // A miscounted run cannot drive the bar past its end.
      expect(
        const TextDownloadState(completed: 700, total: 604).progress,
        1.0,
      );
    });

    test('copyWith keeps what it is not given', () {
      const before = TextDownloadState(
        running: true,
        stage: OfflineStage.pages,
        cachedSurahs: 114,
        cachedPages: 200,
        failures: 3,
      );
      final after = before.copyWith(completed: 201);

      expect(after.running, isTrue);
      expect(after.stage, OfflineStage.pages);
      expect(after.cachedSurahs, 114);
      expect(after.cachedPages, 200);
      expect(after.failures, 3);
      expect(after.completed, 201);
    });
  });

  group('what the run actually fetches', () {
    // Source-level, because the run itself needs a network and a device
    // filesystem. What matters is that it has not quietly gone back to
    // fetching text only — that regression is invisible until someone turns
    // their connection off, which is the worst time to find it.
    final source = File(
      'lib/core/quran/bulk_download_providers.dart',
    ).readAsStringSync();

    test('it downloads the page layouts', () {
      expect(source.contains('pageService.fetchPage(page)'), isTrue);
    });

    test('it downloads the page fonts', () {
      // Layout without the font renders a page of empty boxes.
      expect(source.contains('fontService.download(page)'), isTrue);
    });

    test('it still downloads the surah text', () {
      expect(source.contains('service.fetchSurah(surah.number)'), isTrue);
    });

    test('a page counts as stored only with both halves', () {
      expect(source.contains('data.intersection(fonts)'), isTrue);
    });

    test('it covers all 604 pages, not the ones already opened', () {
      expect(
        source.contains('page <= MushafPageService.totalPages'),
        isTrue,
      );
    });
  });

  group('page storage', () {
    final service = File(
      'lib/core/quran/mushaf_page_service.dart',
    ).readAsStringSync();

    test('pages are files, not preference entries', () {
      // 604 pages is several megabytes, and Android parses the whole
      // preferences file into memory on every cold start.
      expect(service.contains('_prefs.setString'), isFalse);
      expect(service.contains('getApplicationDocumentsDirectory'), isTrue);
    });

    test('a page is written to .part and renamed', () {
      // An interrupted write must not leave a truncated file that the
      // offline count would take for a stored page.
      expect(service.contains(".part'"), isTrue);
      expect(service.contains('part.rename(file.path)'), isTrue);
    });

    test('the old preference entries are cleaned up', () {
      expect(service.contains('purgeLegacyStorage'), isTrue);
      expect(
        File('lib/main.dart').readAsStringSync().contains(
          'purgeLegacyStorage()',
        ),
        isTrue,
      );
    });
  });
}
