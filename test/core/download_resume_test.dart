import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a stopped download leaves its .part file behind to resume from', () {
    // The regression this guards: the service used to delete .part on cancel,
    // so stopping al-Baqara (~115 MB) threw away the whole transfer and the
    // next attempt restarted at zero. Someone stopping and resuming could
    // never finish it, however many times they tried.
    final source = File('lib/core/quran/audio_download_service.dart')
        .readAsStringSync();
    final download = source.substring(source.indexOf('Future<void> download('));
    final body = download.substring(0, download.indexOf('Future<void> delete('));

    expect(
      body.contains("request.headers['Range']"),
      isTrue,
      reason: 'resume needs a Range request',
    );
    expect(
      body.contains('FileMode.append'),
      isTrue,
      reason: 'a resumed transfer must append, not truncate',
    );
    // The only delete left is the 416 case, where the partial is provably
    // longer than the file and cannot be a valid prefix of it.
    expect(
      RegExp(r'partFile\.delete\(\)').allMatches(body).length,
      1,
      reason: 'the .part file must survive cancellation',
    );
    expect(body.contains('416'), isTrue);
  });

  test('a short file is never promoted to a finished download', () {
    // Renaming on stream-end alone would turn a dropped connection into a
    // surah that just stops playing half way through, with nothing to show
    // the user why.
    final source = File('lib/core/quran/audio_download_service.dart')
        .readAsStringSync();
    expect(source.contains('await partFile.length() != total'), isTrue);
  });
}
